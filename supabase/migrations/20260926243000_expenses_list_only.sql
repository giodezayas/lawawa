-- Gastos = solo la lista registrada. Sin tipos ni prorrateo automático.

alter table public.expense_entries
  add column if not exists name text;

update public.expense_entries entry
set name = category.name
from public.expense_categories category
where entry.category_id = category.id
  and (entry.name is null or trim(entry.name) = '');

update public.expense_entries
set name = 'Gasto'
where name is null or trim(name) = '';

alter table public.expense_entries
  alter column name set not null;

alter table public.expense_entries
  alter column category_id drop not null;

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
  expense_total numeric(12, 2);
  utilidad numeric(12, 2);
  tax_amount numeric(12, 2);
  lines jsonb;
begin
  if not public.is_active_internal_user() then
    raise exception 'No autorizado';
  end if;

  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'El rango de fechas no es válido.';
  end if;

  days := (p_to - p_from) + 1;

  select
    coalesce(sum(line.sale_total), 0),
    coalesce(sum(line.gross_profit), 0)
  into sale_total, gross_profit
  from public.ipv_lines line
  join public.ipv_documents doc on doc.id = line.ipv_id
  where doc.work_date between p_from and p_to;

  select coalesce(sum(amount), 0) into expense_total
  from public.expense_entries
  where occurred_on between p_from and p_to;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'category_id', id,
        'name', name,
        'kind', 'variable',
        'cadence', 'none',
        'source', 'entry',
        'occurred_on', occurred_on,
        'amount', amount
      )
      order by occurred_on, name
    ),
    '[]'::jsonb
  )
  into lines
  from public.expense_entries
  where occurred_on between p_from and p_to;

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
