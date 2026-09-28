-- Tres extracciones de transferencia a efectivo. Idempotente por monto+nota.
-- Fechas del 27/9 para que entren en el período actual (31/8–27/9). Cámbialas si fueron otro día.

do $$
declare
  actor uuid;
begin
  select id into actor
    from public.profiles
    order by case when email ilike '%gdzayas%' then 0 else 1 end, created_at
    limit 1;

  if actor is null then
    raise exception 'No hay usuario en profiles para created_by.';
  end if;

  insert into public.cash_moves (occurred_on, kind, card, amount, notes, created_by)
  select date '2026-09-27', 'transfer_to_cash', 'p', 27000, 'Extracción 1', actor
  where not exists (
    select 1 from public.cash_moves
    where kind = 'transfer_to_cash' and amount = 27000 and notes = 'Extracción 1'
  );

  insert into public.cash_moves (occurred_on, kind, card, amount, notes, created_by)
  select date '2026-09-27', 'transfer_to_cash', 'p', 30000, 'Extracción 2', actor
  where not exists (
    select 1 from public.cash_moves
    where kind = 'transfer_to_cash' and amount = 30000 and notes = 'Extracción 2'
  );

  insert into public.cash_moves (occurred_on, kind, card, amount, notes, created_by)
  select date '2026-09-27', 'transfer_to_cash', 'p', 5000, 'Extracción 3', actor
  where not exists (
    select 1 from public.cash_moves
    where kind = 'transfer_to_cash' and amount = 5000 and notes = 'Extracción 3'
  );
end $$;
