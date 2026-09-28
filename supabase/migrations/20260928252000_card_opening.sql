-- Saldo conocido en cada tarjeta al empezar a partir P y F. No mueve caja.

create table if not exists public.card_opening (
  id boolean primary key default true check (id),
  as_of date not null,
  p_amount numeric(12, 2) not null default 0,
  f_amount numeric(12, 2) not null default 0,
  notes text not null default '',
  updated_by uuid references public.profiles (id),
  updated_at timestamptz not null default now(),
  constraint card_opening_amounts_non_negative check (p_amount >= 0 and f_amount >= 0)
);

alter table public.card_opening enable row level security;

drop policy if exists card_opening_all_internal on public.card_opening;
grant select, insert, update, delete on public.card_opening to authenticated;
