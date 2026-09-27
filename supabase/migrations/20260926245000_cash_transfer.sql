-- Recaudo IPV en efectivo/transferencia y compras por el mismo medio.

alter table public.ipv_documents
  add column if not exists cash_collected numeric(12, 2) not null default 0;

alter table public.ipv_documents
  add column if not exists transfer_collected numeric(12, 2) not null default 0;

alter table public.ipv_documents
  drop constraint if exists ipv_documents_cash_non_negative;

alter table public.ipv_documents
  add constraint ipv_documents_cash_non_negative check (cash_collected >= 0 and transfer_collected >= 0);

alter table public.purchase_documents
  add column if not exists payment_method text not null default 'cash';

alter table public.purchase_documents
  drop constraint if exists purchase_documents_payment_method_valid;

alter table public.purchase_documents
  add constraint purchase_documents_payment_method_valid
  check (payment_method in ('cash', 'transfer'));

create or replace function public.cash_flow_report(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  cash_in numeric(12, 2);
  transfer_in numeric(12, 2);
  cash_out numeric(12, 2);
  transfer_out numeric(12, 2);
begin
  if not public.is_active_internal_user() then
    raise exception 'No autorizado';
  end if;

  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'El rango de fechas no es válido.';
  end if;

  select
    coalesce(sum(cash_collected), 0),
    coalesce(sum(transfer_collected), 0)
  into cash_in, transfer_in
  from public.ipv_documents
  where work_date between p_from and p_to;

  select coalesce(sum(line.qty * line.unit_cost), 0) into cash_out
  from public.purchase_lines line
  join public.purchase_documents doc on doc.id = line.purchase_id
  where doc.purchased_on between p_from and p_to
    and doc.payment_method = 'cash';

  select coalesce(sum(line.qty * line.unit_cost), 0) into transfer_out
  from public.purchase_lines line
  join public.purchase_documents doc on doc.id = line.purchase_id
  where doc.purchased_on between p_from and p_to
    and doc.payment_method = 'transfer';

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'cash_in', cash_in,
    'transfer_in', transfer_in,
    'cash_out', round(cash_out, 2),
    'transfer_out', round(transfer_out, 2)
  );
end;
$$;

grant execute on function public.cash_flow_report(date, date) to authenticated;
