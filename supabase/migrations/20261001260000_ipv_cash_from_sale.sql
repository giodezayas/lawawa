-- Efectivo del IPV = venta de líneas menos Tarjeta P menos Tarjeta F.

alter table public.ipv_documents
  drop constraint if exists ipv_documents_cash_non_negative;

alter table public.ipv_documents
  add constraint ipv_documents_cash_non_negative check (
    transfer_collected >= 0
    and transfer_p_collected >= 0
    and transfer_f_collected >= 0
  );

create or replace function public.ipv_cash_from_sale(p_id uuid, p_transfer_p numeric, p_transfer_f numeric)
returns numeric
language sql
stable
as $$
  select round(
    coalesce((select sum(sale_total) from public.ipv_lines where ipv_id = p_id), 0)
    - coalesce(p_transfer_p, 0)
    - coalesce(p_transfer_f, 0)
  , 2);
$$;

create or replace function public.sync_ipv_transfer_cards()
returns trigger
language plpgsql
as $$
begin
  if coalesce(new.transfer_p_collected, 0) + coalesce(new.transfer_f_collected, 0) = 0
    and coalesce(new.transfer_collected, 0) > 0 then
    new.transfer_p_collected := new.transfer_collected;
    new.transfer_f_collected := 0;
  else
    new.transfer_collected := coalesce(new.transfer_p_collected, 0) + coalesce(new.transfer_f_collected, 0);
  end if;
  new.cash_collected := public.ipv_cash_from_sale(
    new.id,
    new.transfer_p_collected,
    new.transfer_f_collected
  );
  return new;
end;
$$;

create or replace function public.refresh_ipv_cash()
returns trigger
language plpgsql
as $$
declare
  target uuid;
begin
  target := coalesce(new.ipv_id, old.ipv_id);
  perform set_config('wawa.bypass_ipv_protect', 'on', true);
  update public.ipv_documents
  set cash_collected = public.ipv_cash_from_sale(id, transfer_p_collected, transfer_f_collected)
  where id = target;
  return coalesce(new, old);
end;
$$;

drop trigger if exists ipv_lines_refresh_cash on public.ipv_lines;
create trigger ipv_lines_refresh_cash
  after insert or update or delete on public.ipv_lines
  for each row execute function public.refresh_ipv_cash();

do $$
begin
  perform set_config('wawa.bypass_ipv_protect', 'on', true);
  update public.ipv_documents
  set cash_collected = public.ipv_cash_from_sale(id, transfer_p_collected, transfer_f_collected)
  where cash_collected is distinct from public.ipv_cash_from_sale(id, transfer_p_collected, transfer_f_collected);
end;
$$;
