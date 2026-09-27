-- Lote 2 (7, 8, 10 y 12 sep 2026). Idempotente. Efectivo.
-- Galletas Sala Saltbock: compra el 7 sep (antes el 9). 24 cajas × 7 = 168 paqueticos.
-- 8/2 en el papel se toma como 8 sep (sigue al 7/9).
-- Chupa: 4 paquetes × 24 = 96 unidades. 4×1580 = 6320 (el 4320 no cierra el total).
-- Galletas: 24 cajas × 7 paqueticos = 168. Conteo y venta por paquetico.
-- Azúcar: 49000 no cuadra; 2×24000 + Yamy 10500 = 58500. Stock del saco en lb (110).
-- Cono Richy 12/9: 24×140 no cierra; 3840 ⇒ 160.

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
    ('Gomitas', 350, 300, 300, 0, true),
    ('Cono Richy', 190, 155, 155, 0, true),
    ('Niks', 220, 175, 175, 0, true),
    ('Chupa Chups', 80, 65.83, 65.83, 0, true),
    ('Galletas Sala Saltbock', 270, 221.43, 221.43, 0, true),
    ('Azúcar Saco 25 kg', 0, 436.36, 436.36, 0, false),
    ('Azúcar 1 lb', 500, 436.36, 436.36, 0, true),
    ('Azúcar 1 kg', 1100, 960, 960, 0, true),
    ('Detergente Yamy 900g', 0, 700, 700, 0, true),
    ('Barolle', 160, 130, 130, 0, true),
    ('Sorbeto Trixmax', 150, 105, 105, 0, true),
    ('Sorbeto Crispy', 220, 155, 155, 0, true),
    ('Dona', 220, 165, 165, 0, true),
    ('Biskiato', 140, 100, 100, 0, true)
  on conflict (name) do update set
    sale_price = case
      when excluded.sale_price = 0 then public.products.sale_price
      else excluded.sale_price
    end,
    purchase_price = excluded.purchase_price,
    replenishment_cost = excluded.replenishment_cost,
    is_active = case
      when public.products.name = 'Azúcar Saco 25 kg' then false
      else public.products.is_active
    end;

  if not exists (select 1 from public.purchase_documents where purchased_on = date '2026-09-08') then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-08', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, v.qty, v.unit_cost
    from (
      values
        ('Gomitas', 48::numeric, 300::numeric),
        ('Cono Richy', 24, 155),
        ('Niks', 48, 175),
        ('Chupa Chups', 96, 65.83)
    ) as v(name, qty, unit_cost)
    join public.products p on p.name = v.name;
  end if;

  if not exists (
    select 1
    from public.purchase_lines pl
    join public.products p on p.id = pl.product_id
    where p.name = 'Galletas Sala Saltbock'
  ) then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-07', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, 168, 221.43
    from public.products p
    where p.name = 'Galletas Sala Saltbock';
  end if;

  update public.purchase_documents d
  set purchased_on = date '2026-09-07'
  where d.purchased_on = date '2026-09-09'
    and exists (
      select 1
      from public.purchase_lines pl
      join public.products p on p.id = pl.product_id
      where pl.purchase_id = d.id
        and p.name = 'Galletas Sala Saltbock'
    )
    and not exists (
      select 1
      from public.purchase_lines pl
      join public.products p on p.id = pl.product_id
      where pl.purchase_id = d.id
        and p.name <> 'Galletas Sala Saltbock'
    );

  if not exists (select 1 from public.purchase_documents where purchased_on = date '2026-09-10') then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-10', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, v.qty, v.unit_cost
    from (
      values
        ('Azúcar Saco 25 kg', 110::numeric, 436.36::numeric),
        ('Detergente Yamy 900g', 15, 700)
    ) as v(name, qty, unit_cost)
    join public.products p on p.name = v.name;
  end if;

  if not exists (select 1 from public.purchase_documents where purchased_on = date '2026-09-12') then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-12', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, v.qty, v.unit_cost
    from (
      values
        ('Barolle', 24::numeric, 130::numeric),
        ('Sorbeto Trixmax', 24, 105),
        ('Sorbeto Crispy', 24, 155),
        ('Dona', 24, 165),
        ('Biskiato', 24, 100),
        ('Cono Richy', 24, 160)
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
