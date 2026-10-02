-- Cada producto puede tributar o no. El 25% usa solo la ganancia de los que sí.

alter table public.products
  add column if not exists counts_for_tax boolean not null default true;

drop view if exists public.dashboard_stats;
drop view if exists public.product_catalog;

create view public.product_catalog
with (security_invoker = true)
as
select
  p.id,
  p.name,
  p.sale_price,
  p.replenishment_cost,
  p.min_stock,
  p.is_active,
  p.counts_for_tax,
  p.created_at,
  p.updated_at,
  coalesce(stock.qty, 0) as stock_qty,
  p.purchase_price::numeric as last_purchase_price,
  p.replenishment_cost::numeric as average_cost
from public.products p
left join (
  select product_id, sum(qty) as qty
  from public.stock_movements
  group by product_id
) stock on stock.product_id = p.id;

create view public.dashboard_stats
with (security_invoker = true)
as
select
  (
    select count(*)::int
    from public.products
    where is_active
  ) as product_count,
  (
    select count(*)::int
    from public.product_catalog
    where is_active and min_stock > 0 and stock_qty <= min_stock
  ) as low_stock_count,
  (
    select coalesce(sum(stock_qty), 0)
    from public.product_catalog
    where is_active
  ) as stock_units,
  (
    select count(*)::int
    from public.ipv_documents
    where work_date = current_date
  ) as ipv_today_count,
  (
    select coalesce(max(status::text), 'none')
    from public.ipv_documents
    where work_date = current_date
  ) as ipv_today_status,
  (
    select coalesce(sum(line.sale_total), 0)
    from public.ipv_lines line
    join public.ipv_documents doc on doc.id = line.ipv_id
    where doc.work_date = current_date
  ) as sale_today,
  (
    select coalesce(sum(line.gross_profit), 0)
    from public.ipv_lines line
    join public.ipv_documents doc on doc.id = line.ipv_id
    where doc.work_date = current_date
  ) as profit_today,
  (
    select coalesce(sum(line.sale_total), 0)
    from public.ipv_lines line
    join public.ipv_documents doc on doc.id = line.ipv_id
    where date_trunc('month', doc.work_date) = date_trunc('month', current_date)
  ) as sale_month,
  (
    select coalesce(sum(line.gross_profit), 0)
    from public.ipv_lines line
    join public.ipv_documents doc on doc.id = line.ipv_id
    where date_trunc('month', doc.work_date) = date_trunc('month', current_date)
  ) as profit_month,
  (
    select coalesce(sum(pl.qty * pl.unit_cost), 0)
    from public.purchase_lines pl
    join public.purchase_documents pd on pd.id = pl.purchase_id
    where pd.purchased_on = current_date
  ) as purchase_today,
  (
    select count(*)::int
    from public.profiles
    where is_active
  ) as active_user_count;

grant select on public.product_catalog to authenticated;
grant select on public.dashboard_stats to authenticated;

create or replace function public.period_report(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  days int;
  tax_rate numeric(6, 4) := 0.25;
  sale_total numeric(12, 2);
  purchase_total numeric(12, 2);
  gross_profit numeric(12, 2);
  taxable_gross numeric(12, 2);
  expense_total numeric(12, 2) := 0;
  utilidad numeric(12, 2);
  tax_amount numeric(12, 2);
  lines jsonb := '[]'::jsonb;
  entry public.expense_entries;
  overlap_from date;
  overlap_to date;
  overlap_days int;
  line_amount numeric(12, 2);
  line_source text;
  closed boolean;
begin
  if not public.is_active_internal_user() then
    raise exception 'No autorizado';
  end if;

  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'El rango de fechas no es válido.';
  end if;

  days := (p_to - p_from) + 1;

  select exists (
    select 1
    from public.billing_period_closes
    where period_from = p_from
      and period_to = p_to
  ) into closed;

  select
    coalesce(sum(line.sale_total), 0),
    coalesce(sum(line.gross_profit), 0),
    coalesce(sum(line.gross_profit) filter (where coalesce(product.counts_for_tax, true)), 0)
  into sale_total, gross_profit, taxable_gross
  from public.ipv_lines line
  join public.ipv_documents doc on doc.id = line.ipv_id
  left join public.products product on product.id = line.product_id
  where doc.work_date between p_from and p_to;

  select coalesce(sum(pl.qty * pl.unit_cost), 0)
  into purchase_total
  from public.purchase_lines pl
  join public.purchase_documents d on d.id = pl.purchase_id
  where d.purchased_on between p_from and p_to;

  for entry in
    select * from public.expense_entries
    where occurred_on <= p_to
    order by occurred_on, name
  loop
    line_amount := 0;
    line_source := 'entry';

    if entry.cadence = 'once' then
      if entry.occurred_on between p_from and p_to then
        line_amount := entry.amount;
      end if;
    else
      overlap_from := greatest(p_from, entry.occurred_on);
      overlap_to := p_to;
      if overlap_from <= overlap_to then
        overlap_days := (overlap_to - overlap_from) + 1;
        line_source := 'accrual';
        if entry.cadence = 'daily' then
          line_amount := round(entry.amount * overlap_days, 2);
        elsif entry.cadence = 'weekly' then
          line_amount := round(entry.amount * overlap_days / 7.0, 2);
        else
          line_amount := entry.amount;
        end if;
      end if;
    end if;

    if line_amount <> 0 then
      expense_total := expense_total + line_amount;
      lines := lines || jsonb_build_array(jsonb_build_object(
        'category_id', entry.id,
        'name', entry.name,
        'kind', 'variable',
        'cadence', entry.cadence,
        'source', line_source,
        'occurred_on', entry.occurred_on,
        'amount', line_amount
      ));
    end if;
  end loop;

  utilidad := round(gross_profit - expense_total, 2);
  tax_amount := round(greatest(taxable_gross - expense_total, 0) * tax_rate, 2);

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'days', days,
    'tax_rate', tax_rate,
    'sale_total', sale_total,
    'purchase_total', purchase_total,
    'gross_profit', gross_profit,
    'taxable_gross_profit', taxable_gross,
    'expense_total', expense_total,
    'utilidad', utilidad,
    'tax', tax_amount,
    'net', round(utilidad - tax_amount, 2),
    'closed', closed,
    'lines', lines
  );
end;
$$;

grant execute on function public.period_report(date, date) to authenticated;
