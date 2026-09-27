-- The SQL Editor is postgres, not service_role. Allow bootstrap role changes there.

create or replace function public.protect_profile_privileges()
returns trigger
language plpgsql
as $$
begin
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
