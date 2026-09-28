-- Lote 4 (20–22 y 24–26 sep 2026). Efectivo. Idempotente por producto+día.
-- 20/9: 2 cajas Ritz = 48×340, venta 450.
-- 21/9: 72 Cerveza Marinero ×380. Arroz 60×700 (reposición 730, venta 900).
-- 22/9: Mayonesa, Sovio, Café, Toallitas. Pasta De Tomate 24×630 (venta 750).
-- 24/9: Silver Bright 25×750. Roxy 48×160. Cono 24×160. Biskiato 48×100.
-- Palitos 40×150. Panqueques Hola 48×150 y Time 24×150. Leche evaporada 24×680.
-- 25/9: Azúcar Saco 55 lb ×441 = 24255.
-- 26/9: 1 caja Ritz 24×340 y 1 caja Marinero 24×380.

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
    ('Refresco Ritz Cola', 450, 340, 340, 0, true),
    ('Cerveza Marinero', 480, 380, 380, 0, true),
    ('Mayonesa', 1150, 930, 930, 0, true),
    ('Galletas Sovio De Fresa', 120, 85, 85, 0, true),
    ('Café', 1100, 790, 790, 0, true),
    ('Toallitas Húmedas', 820, 670, 670, 0, true),
    ('Pasta De Tomate', 750, 630, 630, 0, true),
    ('Detergente Silver Bright', 900, 750, 750, 0, true),
    ('Roxy', 220, 160, 160, 0, true),
    ('Palitos Salados', 200, 150, 150, 0, true),
    ('Panqueques Hola', 220, 150, 150, 0, true),
    ('Panqueques Time', 220, 150, 150, 0, true),
    ('Leche Evaporada', 850, 680, 680, 0, true)
  on conflict (name) do update set
    sale_price = excluded.sale_price,
    purchase_price = excluded.purchase_price,
    replenishment_cost = excluded.replenishment_cost;

  if not exists (
    select 1
    from public.purchase_lines line
    join public.purchase_documents d on d.id = line.purchase_id
    join public.products p on p.id = line.product_id
    where d.purchased_on = date '2026-09-20'
      and p.name = 'Refresco Ritz Cola'
  ) then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-20', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, 48, 340
    from public.products p
    where p.name = 'Refresco Ritz Cola';
  end if;

  if not exists (
    select 1
    from public.purchase_lines line
    join public.purchase_documents d on d.id = line.purchase_id
    join public.products p on p.id = line.product_id
    where d.purchased_on = date '2026-09-21'
      and p.name = 'Cerveza Marinero'
  ) then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-21', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, 72, 380
    from public.products p
    where p.name = 'Cerveza Marinero';
  end if;

  update public.products
  set sale_price = 900, purchase_price = 700, replenishment_cost = 730
  where name = 'Arroz 1 kg';

  update public.products
  set sale_price = 290
  where name = 'Galletas Sala Saltbock';

  if not exists (
    select 1
    from public.purchase_lines line
    join public.purchase_documents d on d.id = line.purchase_id
    join public.products p on p.id = line.product_id
    where d.purchased_on = date '2026-09-21'
      and p.name = 'Arroz 1 kg'
  ) then
    select d.id into doc
    from public.purchase_documents d
    join public.purchase_lines line on line.purchase_id = d.id
    join public.products p on p.id = line.product_id
    where d.purchased_on = date '2026-09-21'
      and p.name = 'Cerveza Marinero'
    limit 1;

    if doc is null then
      insert into public.purchase_documents (purchased_on, payment_method, created_by)
      values (date '2026-09-21', 'cash', actor)
      returning id into doc;
    end if;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, 60, 700
    from public.products p
    where p.name = 'Arroz 1 kg';
  end if;

  if not exists (
    select 1
    from public.purchase_lines line
    join public.purchase_documents d on d.id = line.purchase_id
    join public.products p on p.id = line.product_id
    where d.purchased_on = date '2026-09-22'
      and p.name = 'Mayonesa'
  ) then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-22', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, v.qty, v.unit_cost
    from (
      values
        ('Mayonesa', 12::numeric, 930::numeric),
        ('Galletas Sovio De Fresa', 24, 85),
        ('Café', 20, 790),
        ('Toallitas Húmedas', 4, 670),
        ('Pasta De Tomate', 24, 630)
    ) as v(name, qty, unit_cost)
    join public.products p on p.name = v.name;
  end if;

  update public.products
  set sale_price = 750, purchase_price = 630, replenishment_cost = 630
  where name = 'Pasta De Tomate';

  if not exists (
    select 1
    from public.purchase_lines line
    join public.purchase_documents d on d.id = line.purchase_id
    join public.products p on p.id = line.product_id
    where d.purchased_on = date '2026-09-22'
      and p.name = 'Pasta De Tomate'
  ) then
    select d.id into doc
    from public.purchase_documents d
    join public.purchase_lines line on line.purchase_id = d.id
    join public.products p on p.id = line.product_id
    where d.purchased_on = date '2026-09-22'
      and p.name = 'Mayonesa'
    limit 1;

    if doc is null then
      insert into public.purchase_documents (purchased_on, payment_method, created_by)
      values (date '2026-09-22', 'cash', actor)
      returning id into doc;
    end if;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, 24, 630
    from public.products p
    where p.name = 'Pasta De Tomate';
  end if;

  if not exists (
    select 1
    from public.purchase_lines line
    join public.purchase_documents d on d.id = line.purchase_id
    join public.products p on p.id = line.product_id
    where d.purchased_on = date '2026-09-24'
      and p.name = 'Detergente Silver Bright'
  ) then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-24', 'cash', actor)
    returning id into doc;
  else
    select d.id into doc
    from public.purchase_documents d
    join public.purchase_lines line on line.purchase_id = d.id
    join public.products p on p.id = line.product_id
    where d.purchased_on = date '2026-09-24'
      and p.name = 'Detergente Silver Bright'
    limit 1;
  end if;

  insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
  select doc, p.id, v.qty, v.unit_cost
  from (
    values
      ('Detergente Silver Bright', 25::numeric, 750::numeric),
      ('Roxy', 48, 160),
      ('Cono Richy', 24, 160),
      ('Biskiato', 48, 100),
      ('Palitos Salados', 40, 150),
      ('Panqueques Hola', 48, 150),
      ('Panqueques Time', 24, 150),
      ('Leche Evaporada', 24, 680)
  ) as v(name, qty, unit_cost)
  join public.products p on p.name = v.name
  where not exists (
    select 1
    from public.purchase_lines existing
    where existing.purchase_id = doc
      and existing.product_id = p.id
  );

  if not exists (
    select 1
    from public.purchase_lines line
    join public.purchase_documents d on d.id = line.purchase_id
    join public.products p on p.id = line.product_id
    where d.purchased_on = date '2026-09-25'
      and p.name = 'Azúcar Saco 25 kg'
  ) then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-25', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, 55, 441
    from public.products p
    where p.name = 'Azúcar Saco 25 kg';
  end if;

  if not exists (
    select 1
    from public.purchase_lines line
    join public.purchase_documents d on d.id = line.purchase_id
    join public.products p on p.id = line.product_id
    where d.purchased_on = date '2026-09-26'
      and p.name in ('Refresco Ritz Cola', 'Cerveza Marinero')
  ) then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-26', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, v.qty, v.unit_cost
    from (
      values
        ('Refresco Ritz Cola', 24::numeric, 340::numeric),
        ('Cerveza Marinero', 24, 380)
    ) as v(name, qty, unit_cost)
    join public.products p on p.name = v.name;
  end if;
end $$;
