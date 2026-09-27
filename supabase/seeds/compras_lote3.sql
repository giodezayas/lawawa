-- Lote 3 (15, 16 y 17 sep 2026). Idempotente por fecha. Efectivo.
-- 15/9: gelatina 24×245 no cierra 6360 ⇒ 265. Sopitas 5200 no cierra ⇒ 24×220.
-- Nikito x34×295=10030; 10620/295=36. Chupa: 2×50 = 100 unidades.
-- 16/9: Barolle 48×130. Huevos 40×87.50. Ron 24×450. Papel Higiénico 20×590.
-- 20×590 = 11800 cierra el total 81780 (el segundo x24 del ron era repetición).

do $$
declare
  actor uuid;
  doc uuid;
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
    ('Sal Paquete 2 lb', 550, 395, 395, 0, true),
    ('Gelatina Naranja', 350, 265, 265, 0, true),
    ('Chupa Chups', 80, 58, 58, 0, true),
    ('Galletas Nikito', 350, 295, 295, 0, true),
    ('Sopitas Pollo', 300, 220, 220, 0, true),
    ('Dolcero', 220, 172, 172, 0, true),
    ('Sorbeto Delux', 150, 95, 95, 0, true),
    ('Barolle', 160, 130, 130, 0, true),
    ('Keks Rosados', 220, 170, 170, 0, true),
    ('Huevos Sorpresa', 120, 87.50, 87.50, 0, true),
    ('Ron 5 Shot', 550, 450, 450, 0, true),
    ('Cerveza Hollandia', 480, 415, 415, 0, true),
    ('Espaguetis 500g', 500, 420, 420, 0, true),
    ('Papel Higiénico', 690, 590, 590, 0, true),
    ('Refresco Instantáneo Yeya', 160, 130, 130, 0, true)
  on conflict (name) do update set
    sale_price = excluded.sale_price,
    purchase_price = excluded.purchase_price,
    replenishment_cost = excluded.replenishment_cost;

  if not exists (select 1 from public.purchase_documents where purchased_on = date '2026-09-15') then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-15', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, v.qty, v.unit_cost
    from (
      values
        ('Sal Paquete 2 lb', 10::numeric, 395::numeric),
        ('Gelatina Naranja', 24, 265),
        ('Chupa Chups', 100, 58),
        ('Galletas Nikito', 36, 295),
        ('Sopitas Pollo', 24, 220),
        ('Dolcero', 24, 172)
    ) as v(name, qty, unit_cost)
    join public.products p on p.name = v.name;
  end if;

  if not exists (select 1 from public.purchase_documents where purchased_on = date '2026-09-16') then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-16', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, v.qty, v.unit_cost
    from (
      values
        ('Sorbeto Delux', 48::numeric, 95::numeric),
        ('Barolle', 48, 130),
        ('Keks Rosados', 48, 170),
        ('Huevos Sorpresa', 40, 87.50),
        ('Ron 5 Shot', 24, 450),
        ('Cerveza Hollandia', 48, 415),
        ('Espaguetis 500g', 40, 420),
        ('Papel Higiénico', 20, 590)
    ) as v(name, qty, unit_cost)
    join public.products p on p.name = v.name;
  end if;

  select id into doc
  from public.purchase_documents
  where purchased_on = date '2026-09-16';

  if doc is not null then
    update public.purchase_lines line
    set qty = 24
    from public.products p
    where line.purchase_id = doc
      and line.product_id = p.id
      and p.name = 'Ron 5 Shot'
      and line.qty = 48;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, 20, 590
    from public.products p
    where p.name = 'Papel Higiénico'
      and not exists (
        select 1
        from public.purchase_lines existing
        where existing.purchase_id = doc
          and existing.product_id = p.id
      );
  end if;

  if not exists (select 1 from public.purchase_documents where purchased_on = date '2026-09-17') then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-17', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, 364, 130
    from public.products p
    where p.name = 'Refresco Instantáneo Yeya';
  else
    select id into doc
    from public.purchase_documents
    where purchased_on = date '2026-09-17';

    update public.purchase_lines line
    set product_id = yeya.id
    from public.products golden, public.products yeya
    where line.purchase_id = doc
      and line.product_id = golden.id
      and golden.name = 'Refresco Instantáneo Golden'
      and yeya.name = 'Refresco Instantáneo Yeya'
      and line.qty = 364
      and line.unit_cost = 130;
  end if;

  update public.products
  set sale_price = 150, purchase_price = 120, replenishment_cost = 120
  where name = 'Refresco Instantáneo Golden';
end $$;
