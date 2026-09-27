-- Sistema interno La Wawa: perfiles, roles y ajustes del negocio.
-- Ejecutar en el SQL Editor del proyecto Supabase (gratis).

create extension if not exists "pgcrypto";

do $$
begin
  if not exists (select 1 from pg_type where typname = 'app_role') then
    create type public.app_role as enum ('owner', 'admin', 'staff');
  end if;
end
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  full_name text not null default '',
  role public.app_role not null default 'staff',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.business_settings (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'La Wawa',
  timezone text not null default 'America/Santo_Domingo',
  updated_at timestamptz not null default now()
);

insert into public.business_settings (name)
select 'La Wawa'
where not exists (select 1 from public.business_settings);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

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
    coalesce((new.raw_user_meta_data ->> 'role')::public.app_role, 'staff')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.is_active_internal_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select is_active from public.profiles where id = auth.uid()),
    false
  );
$$;

create or replace function public.protect_profile_privileges()
returns trigger
language plpgsql
as $$
begin
  -- SQL Editor runs as postgres; clients use service_role or are blocked.
  if auth.role() = 'service_role'
     or current_user in ('postgres', 'supabase_admin') then
    return new;
  end if;

  if new.role is distinct from old.role
     or new.is_active is distinct from old.is_active
     or new.email is distinct from old.email then
    raise exception 'Solo un administrador del sistema puede cambiar rol, estado o email';
  end if;

  return new;
end;
$$;

drop trigger if exists protect_profile_privileges on public.profiles;
create trigger protect_profile_privileges
  before update on public.profiles
  for each row execute function public.protect_profile_privileges();

alter table public.profiles enable row level security;
alter table public.business_settings enable row level security;

drop policy if exists profiles_select_internal on public.profiles;
create policy profiles_select_internal
  on public.profiles
  for select
  to authenticated
  using (public.is_active_internal_user());

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid() and public.is_active_internal_user())
  with check (id = auth.uid() and public.is_active_internal_user());

drop policy if exists business_settings_select_internal on public.business_settings;
create policy business_settings_select_internal
  on public.business_settings
  for select
  to authenticated
  using (public.is_active_internal_user());
