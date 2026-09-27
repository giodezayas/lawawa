-- Impuesto fijo 25% sobre utilidad positiva. Ya no se lee de business_settings.

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
  gross_profit numeric(12, 2);
  expense_total numeric(12, 2) := 0;
  utilidad numeric(12, 2);
  tax_amount numeric(12, 2);
  lines jsonb := '[]'::jsonb;
  category public.expense_categories;
  recorded numeric(12, 2);
  accrued numeric(12, 2);
  line_amount numeric(12, 2);
  line_source text;
  month_days numeric;
begin
  if not public.is_active_internal_user() then
    raise exception 'No autorizado';
  end if;

  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'El rango de fechas no es válido.';
  end if;

  days := (p_to - p_from) + 1;
  month_days := extract(day from (date_trunc('month', p_from) + interval '1 month - 1 day'));

  select
    coalesce(sum(line.sale_total), 0),
    coalesce(sum(line.gross_profit), 0)
  into sale_total, gross_profit
  from public.ipv_lines line
  join public.ipv_documents doc on doc.id = line.ipv_id
  where doc.work_date between p_from and p_to;

  for category in
    select * from public.expense_categories
    where is_active
    order by name
  loop
    select coalesce(sum(amount), 0) into recorded
    from public.expense_entries
    where category_id = category.id
      and occurred_on between p_from and p_to;

    if category.cadence = 'none' then
      line_amount := recorded;
      line_source := 'entry';
    elsif recorded > 0 then
      line_amount := recorded;
      line_source := 'entry';
    else
      if category.cadence = 'daily' then
        accrued := round(category.default_amount * days, 2);
      elsif category.cadence = 'weekly' then
        accrued := round(category.default_amount * days / 7.0, 2);
      else
        accrued := round(category.default_amount * days / nullif(month_days, 0), 2);
      end if;
      line_amount := accrued;
      line_source := 'accrual';
    end if;

    if line_amount <> 0 then
      expense_total := expense_total + line_amount;
      lines := lines || jsonb_build_array(jsonb_build_object(
        'category_id', category.id,
        'name', category.name,
        'kind', category.kind,
        'cadence', category.cadence,
        'source', line_source,
        'amount', line_amount
      ));
    end if;
  end loop;

  utilidad := round(gross_profit - expense_total, 2);
  tax_amount := round(greatest(utilidad, 0) * tax_rate, 2);

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'days', days,
    'tax_rate', tax_rate,
    'sale_total', sale_total,
    'gross_profit', gross_profit,
    'expense_total', expense_total,
    'utilidad', utilidad,
    'tax', tax_amount,
    'net', round(utilidad - tax_amount, 2),
    'lines', lines
  );
end;
$$;
