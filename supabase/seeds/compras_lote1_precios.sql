-- Precios de venta del lote 1. Azúcar se vende por libra y por kg.

do $$
declare
  bulk uuid;
  lb uuid;
  kg uuid;
begin
  update public.products set name = 'Efsane' where name = 'Eesane';
  update public.products set name = 'Refresco Instantáneo Golden' where name = 'Repesco Instantáneo Golden';

  insert into public.products (name, sale_price, purchase_price, replenishment_cost, min_stock, is_active)
  values
    ('Azúcar 1 lb', 500, 403.64, 403.64, 0, true),
    ('Azúcar 1 kg', 1100, 888, 888, 0, true)
  on conflict (name) do update set
    sale_price = excluded.sale_price,
    purchase_price = excluded.purchase_price,
    replenishment_cost = excluded.replenishment_cost;

  select id into bulk from public.products where name = 'Azúcar 25 kg';
  select id into lb from public.products where name = 'Azúcar 1 lb';
  select id into kg from public.products where name = 'Azúcar 1 kg';

  if bulk is not null and lb is not null then
    update public.purchase_lines
    set product_id = lb, qty = 55, unit_cost = 403.64
    where product_id = bulk;

    update public.ipv_lines
    set product_id = lb, product_name = 'Azúcar 1 lb'
    where product_id = bulk;

    delete from public.products where id = bulk;
  end if;

  update public.products set sale_price = 250 where name = 'Mega';
  update public.products set sale_price = 220 where name in ('Efsane', 'Keks Morados', 'Keks Azul');
  update public.products set sale_price = 70 where name in ('Sazón Tropical Verde', 'Sazón Tropical Naranja');
  update public.products set sale_price = 60 where name = 'Sazón Mina';
  update public.products set sale_price = 30 where name = 'Cuadrito De Pollo';
  update public.products set sale_price = 150 where name = 'Refresco Instantáneo Golden';
  update public.products set sale_price = 350 where name = 'Gomitas';
  update public.products set sale_price = 690 where name = 'Papel Higiénico';
  update public.products set sale_price = 650 where name = 'Pasta De Tomate';
  update public.products set sale_price = 850 where name = 'Detergente Yamy 900g';
  update public.products set sale_price = 500 where name = 'Azúcar 1 lb';
  update public.products set sale_price = 1100 where name = 'Azúcar 1 kg';
end $$;
