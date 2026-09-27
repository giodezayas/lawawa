-- Roles: admin, manager, trabajador.
-- Catálogo de productos + IPV por turno (un documento, se cierra y no se edita).

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    'trabajador'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

alter table public.profiles alter column role drop default;
alter table public.profiles alter column role type text using role::text;

update public.profiles set role = 'admin' where role in ('owner', 'admin');
update public.profiles set role = 'trabajador' where role in ('staff', 'trabajador');
update public.profiles set role = 'manager' where role = 'manager';

drop type if exists public.app_role cascade;

create type public.app_role as enum ('admin', 'manager', 'trabajador');

alter table public.profiles
  alter column role type public.app_role using role::public.app_role;

alter table public.profiles
  alter column role set default 'trabajador';

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce((new.raw_user_meta_data ->> 'role')::public.app_role, 'trabajador')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'ipv_shift') then
    create type public.ipv_shift as enum ('manana', 'noche');
  end if;
  if not exists (select 1 from pg_type where typname = 'ipv_status') then
    create type public.ipv_status as enum ('open', 'closed');
  end if;
end
$$;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sale_price numeric(12, 2) not null default 0,
  replenishment_cost numeric(12, 2) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint products_name_unique unique (name),
  constraint products_sale_price_non_negative check (sale_price >= 0),
  constraint products_cost_non_negative check (replenishment_cost >= 0)
);

create table if not exists public.ipv_documents (
  id uuid primary key default gen_random_uuid(),
  work_date date not null,
  shift public.ipv_shift not null,
  status public.ipv_status not null default 'open',
  created_by uuid not null references public.profiles (id),
  closed_by uuid references public.profiles (id),
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ipv_documents_unique_day unique (work_date)
);

create table if not exists public.ipv_lines (
  id uuid primary key default gen_random_uuid(),
  ipv_id uuid not null references public.ipv_documents (id) on delete cascade,
  product_id uuid not null references public.products (id),
  product_name text not null,
  opening_qty numeric(12, 3) not null default 0,
  inbound_qty numeric(12, 3) not null default 0,
  outbound_qty numeric(12, 3) not null default 0,
  sold_qty numeric(12, 3) not null default 0,
  sale_price numeric(12, 2) not null default 0,
  replenishment_cost numeric(12, 2) not null default 0,
  closing_qty numeric(12, 3) generated always as
    (opening_qty + inbound_qty - outbound_qty - sold_qty) stored,
  sale_total numeric(12, 2) generated always as
    (round(sold_qty * sale_price, 2)) stored,
  gross_profit numeric(12, 2) generated always as
    (round(sold_qty * (sale_price - replenishment_cost), 2)) stored,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ipv_lines_unique_product unique (ipv_id, product_id)
);

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
  before update on public.products
  for each row execute function public.set_updated_at();

drop trigger if exists ipv_documents_set_updated_at on public.ipv_documents;
create trigger ipv_documents_set_updated_at
  before update on public.ipv_documents
  for each row execute function public.set_updated_at();

drop trigger if exists ipv_lines_set_updated_at on public.ipv_lines;
create trigger ipv_lines_set_updated_at
  before update on public.ipv_lines
  for each row execute function public.set_updated_at();

create or replace function public.protect_closed_ipv_document()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and old.status = 'closed' then
    raise exception 'Este IPV ya está cerrado y no se puede editar';
  end if;

  if tg_op = 'UPDATE' and new.status = 'closed' and old.status = 'open' then
    new.closed_at = coalesce(new.closed_at, now());
    new.closed_by = coalesce(new.closed_by, auth.uid());
  end if;

  return new;
end;
$$;

drop trigger if exists protect_closed_ipv_document on public.ipv_documents;
create trigger protect_closed_ipv_document
  before update on public.ipv_documents
  for each row execute function public.protect_closed_ipv_document();

create or replace function public.protect_closed_ipv_lines()
returns trigger
language plpgsql
as $$
declare
  doc_status public.ipv_status;
  doc_id uuid;
begin
  doc_id := coalesce(new.ipv_id, old.ipv_id);
  select status into doc_status from public.ipv_documents where id = doc_id;

  if doc_status = 'closed' then
    raise exception 'Este IPV ya está cerrado y no se puede editar';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

drop trigger if exists protect_closed_ipv_lines on public.ipv_lines;
create trigger protect_closed_ipv_lines
  before insert or update or delete on public.ipv_lines
  for each row execute function public.protect_closed_ipv_lines();

alter table public.products enable row level security;
alter table public.ipv_documents enable row level security;
alter table public.ipv_lines enable row level security;

drop policy if exists products_all_internal on public.products;
create policy products_all_internal
  on public.products
  for all
  to authenticated
  using (public.is_active_internal_user())
  with check (public.is_active_internal_user());

drop policy if exists ipv_documents_all_internal on public.ipv_documents;
create policy ipv_documents_all_internal
  on public.ipv_documents
  for all
  to authenticated
  using (public.is_active_internal_user())
  with check (public.is_active_internal_user());

drop policy if exists ipv_lines_all_internal on public.ipv_lines;
create policy ipv_lines_all_internal
  on public.ipv_lines
  for all
  to authenticated
  using (public.is_active_internal_user())
  with check (public.is_active_internal_user());
