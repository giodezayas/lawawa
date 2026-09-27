-- Precios de venta lote 2. Galletas y chupa se cuentan por unidad de venta.

do $$
declare
  chupa uuid;
  galleta uuid;
begin
  update public.products
  set name = 'Chupa Chups'
  where name = 'Chupa Chups Paquete 24';

  insert into public.products (name, sale_price, purchase_price, replenishment_cost, min_stock, is_active)
  values
    ('Cono Richy', 190, 160, 160, 0, true),
    ('Niks', 220, 175, 175, 0, true),
    ('Chupa Chups', 80, 65.83, 65.83, 0, true),
    ('Galletas Sala Saltbock', 270, 221.43, 221.43, 0, true),
    ('Barolle', 160, 130, 130, 0, true),
    ('Sorbeto Trixmax', 150, 105, 105, 0, true),
    ('Sorbeto Crispy', 220, 155, 155, 0, true),
    ('Dona', 220, 165, 165, 0, true),
    ('Biskiato', 140, 100, 100, 0, true)
  on conflict (name) do update set
    sale_price = excluded.sale_price,
    purchase_price = excluded.purchase_price,
    replenishment_cost = excluded.replenishment_cost;

  select id into chupa from public.products where name = 'Chupa Chups';
  select id into galleta from public.products where name = 'Galletas Sala Saltbock';

  if chupa is not null then
    update public.purchase_lines
    set qty = 96, unit_cost = 65.83
    where product_id = chupa and qty = 4 and unit_cost = 1580;

    update public.ipv_lines
    set product_name = 'Chupa Chups'
    where product_id = chupa;
  end if;

  if galleta is not null then
    update public.purchase_lines
    set qty = 168, unit_cost = 221.43
    where product_id = galleta and qty = 24 and unit_cost = 1550;
  end if;
end $$;
