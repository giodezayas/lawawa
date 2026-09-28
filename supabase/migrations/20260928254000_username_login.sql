-- Login by username. Auth still stores a hidden email (usuario@users.lawawa.local).

alter table public.profiles add column if not exists username text;

update public.profiles
set username = lower(regexp_replace(split_part(email, '@', 1), '[^a-z0-9._-]', '', 'g'))
where username is null or username = '';

update public.profiles
set username = 'u' || replace(id::text, '-', '')
where username is null or username = '' or username !~ '^[a-z]';

update public.profiles p
set username = p.username || substr(replace(p.id::text, '-', ''), 1, 4)
from (
  select id, username, row_number() over (partition by username order by created_at) as n
  from public.profiles
) d
where p.id = d.id and d.n > 1;

alter table public.profiles alter column username set not null;

create unique index if not exists profiles_username_key on public.profiles (username);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  login_name text;
begin
  login_name := coalesce(
    nullif(lower(trim(new.raw_user_meta_data ->> 'username')), ''),
    lower(regexp_replace(split_part(coalesce(new.email, ''), '@', 1), '[^a-z0-9._-]', '', 'g'))
  );
  if login_name is null or login_name = '' or login_name !~ '^[a-z]' then
    login_name := 'u' || replace(new.id::text, '-', '');
  end if;

  insert into public.profiles (id, email, username, full_name, role)
  values (
    new.id,
    coalesce(new.email, ''),
    login_name,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce((new.raw_user_meta_data ->> 'role')::public.app_role, 'trabajador')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.resolve_login(p_login text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  needle text := lower(trim(p_login));
  found text;
begin
  if needle = '' then
    return null;
  end if;

  select email into found
  from public.profiles
  where is_active
    and (username = needle or lower(email) = needle)
  limit 1;

  return found;
end;
$$;

revoke all on function public.resolve_login(text) from public;
grant execute on function public.resolve_login(text) to anon, authenticated;

create or replace function public.ensure_staff_login(
  p_username text,
  p_password text,
  p_full_name text,
  p_role public.app_role
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  new_id uuid;
  clean_user text;
  clean_email text;
  instance uuid;
  existing public.profiles;
begin
  clean_user := lower(trim(p_username));
  if clean_user !~ '^[a-z][a-z0-9._-]{2,31}$' then
    raise exception 'El usuario no es válido.';
  end if;

  if char_length(p_password) < 6 then
    raise exception 'La contraseña debe tener al menos 6 caracteres.';
  end if;

  clean_email := clean_user || '@users.lawawa.local';

  select * into existing from public.profiles where username = clean_user;
  if existing.id is not null then
    update auth.users
    set encrypted_password = crypt(p_password, gen_salt('bf')),
        updated_at = now()
    where id = existing.id;
    perform set_config('wawa.bypass_profile_protect', 'on', true);
    update public.profiles
    set full_name = coalesce(p_full_name, existing.full_name),
        role = p_role,
        is_active = true
    where id = existing.id;
    return existing.id;
  end if;

  if exists (select 1 from public.profiles where email = clean_email) then
    raise exception 'Ese usuario ya está en el equipo.';
  end if;

  new_id := gen_random_uuid();
  select coalesce((select id from auth.instances limit 1), '00000000-0000-0000-0000-000000000000'::uuid)
  into instance;

  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  )
  values (
    instance,
    new_id,
    'authenticated',
    'authenticated',
    clean_email,
    crypt(p_password, gen_salt('bf')),
    now(),
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
    jsonb_build_object('full_name', coalesce(p_full_name, ''), 'role', p_role::text, 'username', clean_user),
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

  insert into auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  )
  values (
    gen_random_uuid(),
    new_id,
    jsonb_build_object('sub', new_id::text, 'email', clean_email),
    'email',
    clean_email,
    now(),
    now(),
    now()
  );

  perform set_config('wawa.bypass_profile_protect', 'on', true);

  insert into public.profiles (id, email, username, full_name, role, is_active)
  values (new_id, clean_email, clean_user, coalesce(p_full_name, ''), p_role, true)
  on conflict (id) do update
    set email = excluded.email,
        username = excluded.username,
        full_name = excluded.full_name,
        role = excluded.role,
        is_active = true;

  return new_id;
end;
$$;

drop function if exists public.invite_staff(text, text, text, public.app_role);

create or replace function public.invite_staff(
  p_username text,
  p_password text,
  p_full_name text,
  p_role public.app_role
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
begin
  if not public.is_staff_manager() then
    raise exception 'No autorizado';
  end if;

  if p_role = 'admin' and not public.is_admin() then
    raise exception 'Solo un admin puede crear otro admin.';
  end if;

  if exists (select 1 from public.profiles where username = lower(trim(p_username))) then
    raise exception 'Ese usuario ya está en el equipo.';
  end if;

  return public.ensure_staff_login(p_username, p_password, p_full_name, p_role);
end;
$$;

revoke all on function public.invite_staff(text, text, text, public.app_role) from public;
grant execute on function public.invite_staff(text, text, text, public.app_role) to authenticated;

revoke all on function public.ensure_staff_login(text, text, text, public.app_role) from public;

select public.ensure_staff_login('adrian', 'Wawa2026', 'Adrian Pelegrino', 'admin');
select public.ensure_staff_login('lorena', 'Wawa2026', 'Lorena Mondouy', 'manager');
select public.ensure_staff_login('mayren', 'Wawa2026', 'Mayren Angel', 'manager');
select public.ensure_staff_login('abraham', 'Wawa2026', 'Abraham De Zayas', 'trabajador');
