-- Saldo real al empezar a registrar P y F. No mueve caja. Idempotente.

do $$
declare
  actor uuid;
begin
  select id into actor
    from public.profiles
    order by case when email ilike '%gdzayas%' then 0 else 1 end, created_at
    limit 1;

  if actor is null then
    raise exception 'No hay usuario en profiles para updated_by.';
  end if;

  insert into public.card_opening (id, as_of, p_amount, f_amount, notes, updated_by, updated_at)
  values (
    true,
    date '2026-09-28',
    34170,
    61468,
    'Conteo inicial P 34170 / F 61468',
    actor,
    now()
  )
  on conflict (id) do update set
    as_of = excluded.as_of,
    p_amount = excluded.p_amount,
    f_amount = excluded.f_amount,
    notes = excluded.notes,
    updated_by = excluded.updated_by,
    updated_at = now();
end $$;
