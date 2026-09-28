-- Movimientos entre efectivo y transferencia (extracciones / depósitos).

create table if not exists public.cash_moves (
  id uuid primary key default gen_random_uuid(),
  occurred_on date not null,
  kind text not null,
  amount numeric(12, 2) not null,
  notes text not null default '',
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint cash_moves_kind_valid check (kind in ('transfer_to_cash', 'cash_to_transfer')),
  constraint cash_moves_amount_positive check (amount > 0)
);

alter table public.cash_moves enable row level security;

drop policy if exists cash_moves_all_internal on public.cash_moves;
create policy cash_moves_all_internal
  on public.cash_moves
  for all
  to authenticated
  using (public.is_active_internal_user())
  with check (public.is_active_internal_user());

create or replace function public.forbid_closed_billing_date()
returns trigger
language plpgsql
as $$
declare
  check_date date;
begin
  if tg_table_name in ('expense_entries', 'cash_moves') then
    check_date := case when tg_op = 'DELETE' then old.occurred_on else new.occurred_on end;
  else
    check_date := case when tg_op = 'DELETE' then old.work_date else new.work_date end;
  end if;

  if public.date_in_closed_billing_period(check_date) then
    raise exception 'Ese período de facturación ya está cerrado.';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists cash_moves_forbid_closed_period on public.cash_moves;
create trigger cash_moves_forbid_closed_period
  before insert or update or delete on public.cash_moves
  for each row execute function public.forbid_closed_billing_date();

create or replace function public.cash_flow_report(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  ipv_cash numeric(12, 2);
  ipv_transfer numeric(12, 2);
  cash_purchases numeric(12, 2);
  transfer_purchases numeric(12, 2);
  transfer_to_cash numeric(12, 2);
  cash_to_transfer numeric(12, 2);
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
  into ipv_cash, ipv_transfer
  from public.ipv_documents
  where work_date between p_from and p_to;

  select coalesce(sum(line.qty * line.unit_cost), 0) into cash_purchases
  from public.purchase_lines line
  join public.purchase_documents doc on doc.id = line.purchase_id
  where doc.purchased_on between p_from and p_to
    and doc.payment_method = 'cash';

  select coalesce(sum(line.qty * line.unit_cost), 0) into transfer_purchases
  from public.purchase_lines line
  join public.purchase_documents doc on doc.id = line.purchase_id
  where doc.purchased_on between p_from and p_to
    and doc.payment_method = 'transfer';

  select coalesce(sum(amount), 0) into transfer_to_cash
  from public.cash_moves
  where occurred_on between p_from and p_to
    and kind = 'transfer_to_cash';

  select coalesce(sum(amount), 0) into cash_to_transfer
  from public.cash_moves
  where occurred_on between p_from and p_to
    and kind = 'cash_to_transfer';

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'ipv_cash', round(ipv_cash, 2),
    'ipv_transfer', round(ipv_transfer, 2),
    'cash_purchases', round(cash_purchases, 2),
    'transfer_purchases', round(transfer_purchases, 2),
    'transfer_to_cash', round(transfer_to_cash, 2),
    'cash_to_transfer', round(cash_to_transfer, 2),
    'cash_in', round(ipv_cash + transfer_to_cash, 2),
    'transfer_in', round(ipv_transfer + cash_to_transfer, 2),
    'cash_out', round(cash_purchases + cash_to_transfer, 2),
    'transfer_out', round(transfer_purchases + transfer_to_cash, 2)
  );
end;
$$;

grant execute on function public.cash_flow_report(date, date) to authenticated;
