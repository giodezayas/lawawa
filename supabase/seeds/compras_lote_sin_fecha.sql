-- Compras sin fecha en el papel. Fecha de lote 1 sep 2026 (otro documento; no mezcla el 1/9 original).
-- Agua 22×100, venta 220.

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
    ('Agua Ciego Montero 500 ml', 220, 100, 100, 0, true),
    ('Cerveza Cristal', 500, 300, 300, 0, true),
    ('Cerveza W', 460, 380, 380, 0, true),
    ('Refresco Ritz Cola', 450, 340, 340, 0, true),
    ('Vinagre 300 ml', 300, 230, 230, 0, true),
    ('Sazón Guama', 60, 50, 50, 0, true),
    ('Arroz 1 kg', 800, 680, 680, 0, true),
    ('Jabón Kare 75g', 300, 240, 240, 0, true),
    ('Ron HC', 800, 0, 0, 0, true),
    ('Jaba', 10, 7, 7, 0, true)
  on conflict (name) do update set
    sale_price = excluded.sale_price,
    purchase_price = excluded.purchase_price,
    replenishment_cost = excluded.replenishment_cost;

  update public.purchase_lines line
  set unit_cost = 100
  from public.products p, public.purchase_documents d
  where line.product_id = p.id
    and line.purchase_id = d.id
    and p.name = 'Agua Ciego Montero 500 ml'
    and d.purchased_on = date '2026-09-01'
    and line.qty = 22
    and line.unit_cost = 1000;

  update public.purchase_lines pl
  set qty = 4
  from public.products p
  where pl.product_id = p.id
    and p.name = 'Ron HC'
    and pl.qty = 3
    and pl.unit_cost = 0;

  update public.purchase_lines pl
  set qty = 12
  from public.products p
  where pl.product_id = p.id
    and p.name = 'Vinagre 300 ml'
    and pl.qty = 2
    and pl.unit_cost = 0;

  update public.purchase_lines pl
  set unit_cost = 230
  from public.products p
  where pl.product_id = p.id
    and p.name = 'Vinagre 300 ml'
    and pl.qty = 12
    and pl.unit_cost = 0;

  update public.purchase_lines pl
  set unit_cost = 300
  from public.products p
  where pl.product_id = p.id
    and p.name = 'Cerveza Cristal'
    and pl.qty = 72
    and pl.unit_cost = 0;

  if exists (
    select 1
    from public.purchase_lines line
    join public.purchase_documents d on d.id = line.purchase_id
    join public.products p on p.id = line.product_id
    where d.purchased_on = date '2026-09-01'
      and p.name = 'Agua Ciego Montero 500 ml'
  ) then
    select d.id into doc
    from public.purchase_documents d
    join public.purchase_lines line on line.purchase_id = d.id
    join public.products p on p.id = line.product_id
    where d.purchased_on = date '2026-09-01'
      and p.name = 'Agua Ciego Montero 500 ml'
    limit 1;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, 1000, 7
    from public.products p
    where p.name = 'Jaba'
      and not exists (
        select 1
        from public.purchase_lines existing
        where existing.purchase_id = doc
          and existing.product_id = p.id
      );
    return;
  end if;

  insert into public.purchase_documents (purchased_on, payment_method, created_by)
  values (date '2026-09-01', 'cash', actor)
  returning id into doc;

  insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
  select doc, p.id, v.qty, v.unit_cost
  from (
    values
      ('Agua Ciego Montero 500 ml', 22::numeric, 100::numeric),
      ('Cerveza Cristal', 72, 300),
      ('Cerveza W', 48, 380),
      ('Refresco Ritz Cola', 72, 340),
      ('Vinagre 300 ml', 12, 230),
      ('Sazón Guama', 150, 50),
      ('Arroz 1 kg', 30, 680),
      ('Jabón Kare 75g', 72, 240),
      ('Ron HC', 4, 0),
      ('Jaba', 1000, 7)
  ) as v(name, qty, unit_cost)
  join public.products p on p.name = v.name;
end $$;
