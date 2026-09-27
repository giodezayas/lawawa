-- Equipo: admin/manager invitán usuarios. Inicio lee dashboard_stats.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and is_active
      and role = 'admin'
  );
$$;

create or replace function public.is_staff_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and is_active
      and role in ('admin', 'manager')
  );
$$;

create or replace function public.protect_profile_privileges()
returns trigger
language plpgsql
as $$
begin
  if auth.role() = 'service_role'
     or current_user in ('postgres', 'supabase_admin') then
    return new;
  end if;

  if current_setting('wawa.bypass_profile_protect', true) = 'on' then
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

drop policy if exists profiles_update_staff on public.profiles;
drop policy if exists profiles_delete_staff on public.profiles;

create or replace function public.invite_staff(
  p_email text,
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
  clean_email text;
  instance uuid;
begin
  if not public.is_staff_manager() then
    raise exception 'No autorizado';
  end if;

  if p_role = 'admin' and not public.is_admin() then
    raise exception 'Solo un admin puede crear otro admin.';
  end if;

  clean_email := lower(trim(p_email));
  if clean_email = '' or position('@' in clean_email) = 0 then
    raise exception 'El correo no es válido.';
  end if;

  if char_length(p_password) < 6 then
    raise exception 'La contraseña debe tener al menos 6 caracteres.';
  end if;

  if exists (select 1 from public.profiles where email = clean_email) then
    raise exception 'Ese correo ya está en el equipo.';
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
    jsonb_build_object('full_name', coalesce(p_full_name, ''), 'role', p_role::text),
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

  insert into public.profiles (id, email, full_name, role, is_active)
  values (new_id, clean_email, coalesce(p_full_name, ''), p_role, true)
  on conflict (id) do update
    set email = excluded.email,
        full_name = excluded.full_name,
        role = excluded.role,
        is_active = true;

  return new_id;
end;
$$;

create or replace function public.update_staff(
  p_id uuid,
  p_full_name text,
  p_role public.app_role,
  p_is_active boolean,
  p_password text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  target public.profiles;
begin
  if not public.is_staff_manager() then
    raise exception 'No autorizado';
  end if;

  select * into target from public.profiles where id = p_id;
  if target.id is null then
    raise exception 'No encontramos ese usuario.';
  end if;

  if (target.role = 'admin' or p_role = 'admin') and not public.is_admin() then
    raise exception 'Solo un admin puede cambiar un admin.';
  end if;

  if p_id = auth.uid() and not p_is_active then
    raise exception 'No puedes desactivar tu propia cuenta.';
  end if;

  if target.role = 'admin' and not p_is_active then
    if (
      select count(*) from public.profiles
      where role = 'admin' and is_active and id <> p_id
    ) = 0 then
      raise exception 'Debe quedar al menos un admin activo.';
    end if;
  end if;

  perform set_config('wawa.bypass_profile_protect', 'on', true);

  update public.profiles
  set
    full_name = coalesce(p_full_name, ''),
    role = p_role,
    is_active = p_is_active
  where id = p_id;

  if p_password is not null and char_length(p_password) > 0 then
    if char_length(p_password) < 6 then
      raise exception 'La contraseña debe tener al menos 6 caracteres.';
    end if;

    update auth.users
    set
      encrypted_password = crypt(p_password, gen_salt('bf')),
      updated_at = now()
    where id = p_id;
  end if;
end;
$$;

create or replace function public.delete_staff(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target public.profiles;
begin
  if not public.is_staff_manager() then
    raise exception 'No autorizado';
  end if;

  if p_id = auth.uid() then
    raise exception 'No puedes borrar tu propia cuenta.';
  end if;

  select * into target from public.profiles where id = p_id;
  if target.id is null then
    raise exception 'No encontramos ese usuario.';
  end if;

  if target.role = 'admin' and not public.is_admin() then
    raise exception 'Solo un admin puede borrar a otro admin.';
  end if;

  if target.role = 'admin' then
    if (
      select count(*) from public.profiles
      where role = 'admin' and is_active and id <> p_id
    ) = 0 then
      raise exception 'Debe quedar al menos un admin activo.';
    end if;
  end if;

  delete from auth.users where id = p_id;
end;
$$;

drop view if exists public.dashboard_stats;
create view public.dashboard_stats
with (security_invoker = true)
as
select
  (
    select count(*)::int
    from public.products
    where is_active
  ) as product_count,
  (
    select count(*)::int
    from public.product_catalog
    where is_active and min_stock > 0 and stock_qty <= min_stock
  ) as low_stock_count,
  (
    select coalesce(sum(stock_qty), 0)
    from public.product_catalog
    where is_active
  ) as stock_units,
  (
    select count(*)::int
    from public.ipv_documents
    where work_date = current_date
  ) as ipv_today_count,
  (
    select coalesce(max(status::text), 'none')
    from public.ipv_documents
    where work_date = current_date
  ) as ipv_today_status,
  (
    select coalesce(sum(line.sale_total), 0)
    from public.ipv_lines line
    join public.ipv_documents doc on doc.id = line.ipv_id
    where doc.work_date = current_date
  ) as sale_today,
  (
    select coalesce(sum(line.gross_profit), 0)
    from public.ipv_lines line
    join public.ipv_documents doc on doc.id = line.ipv_id
    where doc.work_date = current_date
  ) as profit_today,
  (
    select coalesce(sum(line.sale_total), 0)
    from public.ipv_lines line
    join public.ipv_documents doc on doc.id = line.ipv_id
    where date_trunc('month', doc.work_date) = date_trunc('month', current_date)
  ) as sale_month,
  (
    select coalesce(sum(line.gross_profit), 0)
    from public.ipv_lines line
    join public.ipv_documents doc on doc.id = line.ipv_id
    where date_trunc('month', doc.work_date) = date_trunc('month', current_date)
  ) as profit_month,
  (
    select coalesce(sum(pl.qty * pl.unit_cost), 0)
    from public.purchase_lines pl
    join public.purchase_documents pd on pd.id = pl.purchase_id
    where pd.purchased_on = current_date
  ) as purchase_today,
  (
    select count(*)::int
    from public.profiles
    where is_active
  ) as active_user_count;

grant execute on function public.invite_staff(text, text, text, public.app_role) to authenticated;
grant execute on function public.update_staff(uuid, text, public.app_role, boolean, text) to authenticated;
grant execute on function public.delete_staff(uuid) to authenticated;
grant select on public.dashboard_stats to authenticated;
