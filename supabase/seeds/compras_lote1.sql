-- Lote 1 de compras (31 ago, 1 sep, 7 sep 2026). Idempotente por fecha.
-- Efectivo. Precio de venta en 0 hasta que lo pongan en el catálogo.

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

  -- Productos: costo de la línea. Venta 0.
  insert into public.products (name, sale_price, purchase_price, replenishment_cost, min_stock, is_active)
  values
    ('Mega', 250, 180, 180, 0, true),
    ('Keks Morados', 220, 170, 170, 0, true),
    ('Keks Azul', 220, 170, 170, 0, true),
    ('Efsane', 220, 170, 170, 0, true),
    ('Papel Higiénico', 690, 590, 590, 0, true),
    ('Pasta De Tomate', 650, 600, 600, 0, true),
    ('Gomitas', 350, 300, 300, 0, true),
    ('Sazón Tropical Verde', 70, 48, 48, 0, true),
    ('Sazón Tropical Naranja', 70, 48, 48, 0, true),
    ('Sazón Mina', 60, 38, 38, 0, true),
    ('Cuadrito De Pollo', 30, 18, 18, 0, true),
    ('Azúcar Saco 25 kg', 0, 403.64, 403.64, 0, false),
    ('Azúcar 1 lb', 500, 403.64, 403.64, 0, true),
    ('Azúcar 1 kg', 1100, 888, 888, 0, true),
    ('Refresco Instantáneo Golden', 150, 120, 120, 0, true),
    ('Detergente Yamy 900g', 850, 700, 700, 0, true)
  on conflict (name) do update set
    sale_price = excluded.sale_price,
    purchase_price = excluded.purchase_price,
    replenishment_cost = excluded.replenishment_cost,
    is_active = excluded.is_active;

  if not exists (select 1 from public.purchase_documents where purchased_on = date '2026-08-31') then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-08-31', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, v.qty, v.unit_cost
    from (
      values
        ('Mega', 24::numeric, 180::numeric),
        ('Keks Morados', 24, 170),
        ('Keks Azul', 24, 170),
        ('Efsane', 24, 170),
        ('Papel Higiénico', 20, 590),
        ('Pasta De Tomate', 24, 600),
        ('Gomitas', 24, 300)
    ) as v(name, qty, unit_cost)
    join public.products p on p.name = v.name;
  end if;

  if not exists (select 1 from public.purchase_documents where purchased_on = date '2026-09-01') then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-01', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, v.qty, v.unit_cost
    from (
      values
        ('Sazón Tropical Verde', 24::numeric, 48::numeric),
        ('Sazón Tropical Naranja', 24, 48),
        ('Sazón Mina', 50, 38),
        ('Cuadrito De Pollo', 192, 18),
        ('Azúcar Saco 25 kg', 55, 403.64)
    ) as v(name, qty, unit_cost)
    join public.products p on p.name = v.name;
  end if;

  if not exists (select 1 from public.purchase_documents where purchased_on = date '2026-09-07') then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-07', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, v.qty, v.unit_cost
    from (
      values
        ('Refresco Instantáneo Golden', 240::numeric, 120::numeric),
        ('Detergente Yamy 900g', 15, 700)
    ) as v(name, qty, unit_cost)
    join public.products p on p.name = v.name;
  end if;

  if to_regclass('public.product_packs') is not null then
    insert into public.product_packs (packed_product_id, bulk_product_id, bulk_qty)
    select packed.id, bulk.id, v.bulk_qty
    from (
      values
        ('Azúcar 1 lb', 'Azúcar Saco 25 kg', 1::numeric),
        ('Azúcar 1 kg', 'Azúcar Saco 25 kg', 2.2)
    ) as v(packed_name, bulk_name, bulk_qty)
    join public.products packed on packed.name = v.packed_name
    join public.products bulk on bulk.name = v.bulk_name
    on conflict (packed_product_id) do update set
      bulk_product_id = excluded.bulk_product_id,
      bulk_qty = excluded.bulk_qty;
  end if;
end $$;
