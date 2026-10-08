-- Monthly expenses keep applying after their start date. Charge each IPV day its share so Resultados matches the IPV cut.

create or replace function public.period_report(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  days int;
  tax_rate numeric(6, 4) := 0;
  sale_tax numeric(12, 2);
  salary_tax numeric(12, 2);
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
    elsif entry.cadence = 'monthly' then
      select coalesce(sum(round(
        entry.amount / extract(day from (date_trunc('month', doc.work_date) + interval '1 month' - interval '1 day'))::numeric,
        2
      )), 0)
      into line_amount
      from public.ipv_documents doc
      where doc.work_date between p_from and p_to
        and doc.work_date >= entry.occurred_on;
      if line_amount <> 0 then
        line_source := 'accrual';
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
  sale_tax := round(greatest(sale_total, 0) * 0.10, 2) + round(greatest(sale_total - 3260, 0) * 0.05, 2);
  salary_tax := round(7000 * 0.125, 2) + round(7000 * 0.05, 2) + round(greatest(7000 - 3740, 0) * 0.03, 2);
  tax_amount := round(sale_tax + salary_tax, 2);

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
