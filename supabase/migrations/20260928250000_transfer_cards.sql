-- Recaudo por Tarjeta P y Tarjeta F. Extracciones por tarjeta.

alter table public.ipv_documents
  add column if not exists transfer_p_collected numeric(12, 2) not null default 0;

alter table public.ipv_documents
  add column if not exists transfer_f_collected numeric(12, 2) not null default 0;

do $$
begin
  perform set_config('wawa.bypass_ipv_protect', 'on', true);
  update public.ipv_documents
  set
    transfer_p_collected = transfer_collected,
    transfer_f_collected = 0
  where transfer_p_collected = 0
    and transfer_f_collected = 0
    and transfer_collected > 0;
end;
$$;

alter table public.ipv_documents
  drop constraint if exists ipv_documents_cash_non_negative;

alter table public.ipv_documents
  add constraint ipv_documents_cash_non_negative check (
    cash_collected >= 0
    and transfer_collected >= 0
    and transfer_p_collected >= 0
    and transfer_f_collected >= 0
  );

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
  return new;
end;
$$;

drop trigger if exists ipv_documents_sync_transfer_cards on public.ipv_documents;
create trigger ipv_documents_sync_transfer_cards
  before insert or update on public.ipv_documents
  for each row execute function public.sync_ipv_transfer_cards();

alter table public.cash_moves
  add column if not exists card text not null default 'p';

alter table public.cash_moves
  drop constraint if exists cash_moves_card_valid;

alter table public.cash_moves
  add constraint cash_moves_card_valid check (card in ('p', 'f'));
