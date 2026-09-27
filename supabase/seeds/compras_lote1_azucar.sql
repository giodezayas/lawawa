-- Azúcar: compra en libras del saco (55 lb). IPV embolsa 1 lb y 1 kg (2.2 lb).

do $$
declare
  saco uuid;
  lb uuid;
  kg uuid;
begin
  insert into public.products (name, sale_price, purchase_price, replenishment_cost, min_stock, is_active)
  values
    ('Azúcar Saco 25 kg', 0, 403.64, 403.64, 0, false),
    ('Azúcar 1 lb', 500, 403.64, 403.64, 0, true),
    ('Azúcar 1 kg', 1100, 888, 888, 0, true)
  on conflict (name) do update set
    sale_price = excluded.sale_price,
    purchase_price = excluded.purchase_price,
    replenishment_cost = excluded.replenishment_cost,
    is_active = excluded.is_active;

  select id into saco from public.products where name = 'Azúcar Saco 25 kg';
  select id into lb from public.products where name = 'Azúcar 1 lb';
  select id into kg from public.products where name = 'Azúcar 1 kg';

  update public.purchase_lines line
  set product_id = saco, qty = 55, unit_cost = 403.64
  from public.products p
  where line.product_id = p.id
    and p.name in ('Azúcar 25 kg', 'Azúcar 1 lb', 'Azúcar Saco 25 kg')
    and (
      (line.qty = 1 and line.unit_cost = 22200)
      or (line.qty = 55)
    );

  if exists (select 1 from public.products where name = 'Azúcar 25 kg') then
    update public.ipv_lines
    set product_id = saco, product_name = 'Azúcar Saco 25 kg'
    where product_id = (select id from public.products where name = 'Azúcar 25 kg');
    delete from public.products where name = 'Azúcar 25 kg';
  end if;

  if to_regclass('public.product_packs') is not null then
    insert into public.product_packs (packed_product_id, bulk_product_id, bulk_qty)
    values
      (lb, saco, 1),
      (kg, saco, 2.2)
    on conflict (packed_product_id) do update set
      bulk_product_id = excluded.bulk_product_id,
      bulk_qty = excluded.bulk_qty;
  end if;

  perform public.refresh_product_cost(saco);
  perform public.refresh_product_cost(lb);
  perform public.refresh_product_cost(kg);
end $$;
