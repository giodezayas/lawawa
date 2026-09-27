-- Pan diario. Fecha de lote real. Efectivo. Idempotente por producto+día.
-- 5–6: 15 Pan Bon ×420. 7–8 y 11–14: 10×420. 9: hamburguesa. 10: 10 Pan Bon ×420.

do $$
declare
  actor uuid;
  doc uuid;
  rec record;
begin
  select id into actor
    from public.profiles
    order by case when email ilike '%gdzayas%' then 0 else 1 end, created_at
    limit 1;

  if actor is null then
    raise exception 'No hay usuario en profiles para created_by.';
  end if;

  insert into public.products (name, sale_price, purchase_price, replenishment_cost, min_stock, is_active)
  values
    ('Pan Bon', 480, 400, 400, 0, true),
    ('Pan De Hamburguesa', 500, 480, 480, 0, true)
  on conflict (name) do update set
    sale_price = excluded.sale_price,
    purchase_price = excluded.purchase_price,
    replenishment_cost = excluded.replenishment_cost;

  for rec in
    select v.purchased_on, v.name, v.qty, v.unit_cost
    from (
      values
        (date '2026-09-05', 'Pan Bon', 15::numeric, 420::numeric),
        (date '2026-09-06', 'Pan Bon', 15, 420),
        (date '2026-09-07', 'Pan Bon', 10, 420),
        (date '2026-09-08', 'Pan Bon', 10, 420),
        (date '2026-09-09', 'Pan De Hamburguesa', 10, 480),
        (date '2026-09-10', 'Pan Bon', 10, 420),
        (date '2026-09-11', 'Pan Bon', 10, 420),
        (date '2026-09-12', 'Pan Bon', 10, 420),
        (date '2026-09-13', 'Pan Bon', 10, 420),
        (date '2026-09-14', 'Pan Bon', 10, 420),
        (date '2026-09-15', 'Pan Bon', 10, 400),
        (date '2026-09-16', 'Pan Bon', 10, 400),
        (date '2026-09-17', 'Pan Bon', 10, 400),
        (date '2026-09-18', 'Pan Bon', 10, 400),
        (date '2026-09-19', 'Pan Bon', 10, 400),
        (date '2026-09-20', 'Pan Bon', 10, 400),
        (date '2026-09-21', 'Pan Bon', 10, 400),
        (date '2026-09-22', 'Pan Bon', 10, 400),
        (date '2026-09-23', 'Pan Bon', 10, 400),
        (date '2026-09-24', 'Pan Bon', 10, 400),
        (date '2026-09-25', 'Pan Bon', 10, 400),
        (date '2026-09-26', 'Pan Bon', 3, 400)
    ) as v(purchased_on, name, qty, unit_cost)
  loop
    if exists (
      select 1
      from public.purchase_lines line
      join public.purchase_documents d on d.id = line.purchase_id
      join public.products p on p.id = line.product_id
      where d.purchased_on = rec.purchased_on
        and p.name = rec.name
    ) then
      continue;
    end if;

    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (rec.purchased_on, 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, rec.qty, rec.unit_cost
    from public.products p
    where p.name = rec.name;
  end loop;
end $$;
