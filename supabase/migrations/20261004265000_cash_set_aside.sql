-- Caja en efectivo = recaudo IPV menos ganancia del día (gastos, impuesto y dueños se apartan).

create or replace function public.cash_flow_report(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  first_sale date;
  flow_from date;
  ipv_cash numeric(12, 2);
  ipv_transfer numeric(12, 2);
  cash_purchases numeric(12, 2);
  transfer_purchases numeric(12, 2);
  transfer_to_cash numeric(12, 2);
  cash_to_transfer numeric(12, 2);
  ipv_salary numeric(12, 2);
  ipv_set_aside numeric(12, 2);
begin
  if not public.is_active_internal_user() then
    raise exception 'No autorizado';
  end if;

  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'El rango de fechas no es válido.';
  end if;

  select min(doc.work_date) into first_sale
  from public.ipv_documents doc
  where exists (
    select 1
    from public.ipv_lines line
    where line.ipv_id = doc.id
      and line.sold_qty > 0
  );

  if first_sale is null or first_sale > p_to then
    return jsonb_build_object(
      'from', p_from,
      'to', p_to,
      'first_sale_on', first_sale,
      'ipv_cash', 0,
      'ipv_transfer', 0,
      'cash_purchases', 0,
      'transfer_purchases', 0,
      'transfer_to_cash', 0,
      'cash_to_transfer', 0,
      'ipv_salary', 0,
      'ipv_set_aside', 0,
      'cash_in', 0,
      'transfer_in', 0,
      'cash_out', 0,
      'transfer_out', 0
    );
  end if;

  flow_from := greatest(p_from, first_sale);

  select
    coalesce(sum(cash_collected), 0),
    coalesce(sum(transfer_collected), 0)
  into ipv_cash, ipv_transfer
  from public.ipv_documents
  where work_date between flow_from and p_to;

  select coalesce(sum(line.qty * line.unit_cost), 0) into cash_purchases
  from public.purchase_lines line
  join public.purchase_documents doc on doc.id = line.purchase_id
  where doc.purchased_on between flow_from and p_to
    and doc.payment_method = 'cash';

  select coalesce(sum(line.qty * line.unit_cost), 0) into transfer_purchases
  from public.purchase_lines line
  join public.purchase_documents doc on doc.id = line.purchase_id
  where doc.purchased_on between flow_from and p_to
    and doc.payment_method = 'transfer';

  select coalesce(sum(amount), 0) into transfer_to_cash
  from public.cash_moves
  where occurred_on between flow_from and p_to
    and kind = 'transfer_to_cash';

  select coalesce(sum(amount), 0) into cash_to_transfer
  from public.cash_moves
  where occurred_on between flow_from and p_to
    and kind = 'cash_to_transfer';

  select coalesce(sum(amount), 0) into ipv_salary
  from public.expense_entries
  where occurred_on between flow_from and p_to
    and ipv_id is not null;

  select coalesce(sum(line.gross_profit), 0) into ipv_set_aside
  from public.ipv_lines line
  join public.ipv_documents doc on doc.id = line.ipv_id
  where doc.work_date between flow_from and p_to;

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'first_sale_on', first_sale,
    'ipv_cash', round(ipv_cash, 2),
    'ipv_transfer', round(ipv_transfer, 2),
    'cash_purchases', round(cash_purchases, 2),
    'transfer_purchases', round(transfer_purchases, 2),
    'transfer_to_cash', round(transfer_to_cash, 2),
    'cash_to_transfer', round(cash_to_transfer, 2),
    'ipv_salary', round(ipv_salary, 2),
    'ipv_set_aside', round(ipv_set_aside, 2),
    'cash_in', round(ipv_cash + transfer_to_cash, 2),
    'transfer_in', round(ipv_transfer + cash_to_transfer, 2),
    'cash_out', round(cash_purchases + cash_to_transfer + ipv_set_aside, 2),
    'transfer_out', round(transfer_purchases + transfer_to_cash, 2)
  );
end;
$$;

grant execute on function public.cash_flow_report(date, date) to authenticated;
