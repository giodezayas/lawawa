-- IPV 25 sep 2026. Azúcar lb: entrada 5 (embolsar), 10 vendidas. Pan Bon: compra 9, 7 vendidas.
-- Saco de 55 lb: compra del 25 (ya en apertura). Transferencia 8000.

do $$
declare
  actor uuid;
  ipv uuid;
  ipv_line public.ipv_lines;
  pack public.product_packs;
  bulk_left numeric(12, 3);
  consume numeric(12, 3);
  work date := date '2026-09-25';
begin
  select id into actor
    from public.profiles
    order by case when email ilike '%gdzayas%' then 0 else 1 end, created_at
    limit 1;

  if actor is null then
    raise exception 'No hay usuario en profiles para created_by.';
  end if;

  update public.products
  set sale_price = 480
  where name = 'Pan Bon';

  update public.products
  set sale_price = 750, purchase_price = 630, replenishment_cost = 630
  where name = 'Pasta De Tomate';

  update public.products
  set sale_price = 550, purchase_price = 460, replenishment_cost = 460
  where name = 'Espaguetis 500g';

  update public.products
  set sale_price = 180, purchase_price = 155, replenishment_cost = 155
  where name = 'Refresco Instantáneo Yeya';

  update public.products
  set sale_price = 850
  where name = 'Arroz 1 kg';

  update public.products
  set sale_price = 550
  where name = 'Azúcar 1 lb';

  update public.products
  set sale_price = 290
  where name = 'Galletas Sala Saltbock';

  if exists (select 1 from public.ipv_documents where work_date = work) then
    perform set_config('wawa.bypass_ipv_protect', 'on', true);
    update public.ipv_lines ipv_row
    set inbound_qty = 9, sold_qty = 7
    from public.products p
    where ipv_row.ipv_id = (select id from public.ipv_documents where work_date = work)
      and ipv_row.product_id = p.id
      and p.name = 'Pan Bon';
    update public.ipv_documents doc
    set
      transfer_collected = 8000,
      cash_collected = greatest(
        (select coalesce(sum(row.sale_total), 0) from public.ipv_lines row where row.ipv_id = doc.id) - 8000,
        0
      )
    where doc.work_date = work;
    return;
  end if;

  insert into public.ipv_documents (work_date, shift, created_by)
  values (work, 'manana', actor)
  returning id into ipv;

  insert into public.ipv_lines (
    ipv_id, product_id, product_name, opening_qty, inbound_qty, outbound_qty, sold_qty,
    sale_price, replenishment_cost, inbound_adds_stock, sort_order
  )
  select
    ipv,
    p.id,
    p.name,
    coalesce((
      select sum(m.qty)
      from public.stock_movements m
      where m.product_id = p.id
        and m.occurred_on <= work
    ), 0),
    v.inbound_qty,
    0,
    v.sold_qty,
    v.sale_price,
    p.replenishment_cost,
    v.adds_stock,
    v.sort_order
  from (
    values
      ('Papel Higiénico', 0::numeric, 3::numeric, 690::numeric, false, 1),
      ('Pasta De Tomate', 0, 0, 750, false, 2),
      ('Azúcar 1 kg', 0, 0, 1100, false, 3),
      ('Azúcar 1 lb', 5, 10, 550, true, 4),
      ('Gomitas', 0, 2, 350, false, 5),
      ('Pan Bon', 9, 7, 480, false, 6),
      ('Sazón Guama', 0, 14, 60, false, 7),
      ('Sazón Mina', 0, 5, 60, false, 8),
      ('Cuadrito De Pollo', 0, 14, 30, false, 9),
      ('Ron HC', 0, 0, 800, false, 10),
      ('Galletas Sala Saltbock', 0, 2, 290, false, 11),
      ('Cono Richy', 0, 6, 190, false, 12),
      ('Chupa Chups', 0, 4, 80, false, 13),
      ('Agua Ciego Montero 500 ml', 0, 1, 220, false, 14),
      ('Refresco Ritz Cola', 0, 15, 450, false, 15),
      ('Sorbeto Crispy', 0, 1, 220, false, 16),
      ('Dona', 0, 1, 220, false, 17),
      ('Dolcero', 0, 3, 220, false, 18),
      ('Sopitas Pollo', 0, 0, 300, false, 19),
      ('Gelatina Naranja', 0, 0, 350, false, 20),
      ('Galletas Nikito', 0, 5, 350, false, 21),
      ('Espaguetis 500g', 0, 2, 550, false, 22),
      ('Keks Rosados', 0, 6, 220, false, 23),
      ('Sal Paquete 2 lb', 0, 0, 550, false, 24),
      ('Arroz 1 kg', 0, 3, 850, false, 25),
      ('Ron 5 Shot', 0, 3, 550, false, 26),
      ('Refresco Instantáneo Yeya', 0, 11, 180, false, 27),
      ('Mayonesa', 0, 1, 1150, false, 29),
      ('Toallitas Húmedas', 0, 2, 820, false, 30),
      ('Café', 0, 1, 1100, false, 31),
      ('Cerveza Marinero', 0, 2, 480, false, 32),
      ('Leche Evaporada', 0, 2, 850, false, 33),
      ('Palitos Salados', 0, 7, 200, false, 34),
      ('Detergente Silver Bright', 0, 1, 900, false, 35),
      ('Sorbeto Delux', 48, 1, 150, false, 36),
      ('Roxy', 48, 1, 220, false, 37),
      ('Biskiato', 48, 0, 140, false, 38)
  ) as v(name, inbound_qty, sold_qty, sale_price, adds_stock, sort_order)
  join public.products p on p.name = v.name;

  if exists (
    select 1
    from public.ipv_lines
    where ipv_id = ipv
      and closing_qty < 0
  ) then
    raise exception 'Vendidos por encima del stock el 25 sep: %',
      (
        select string_agg(
          format(
            '%s (apertura %s, entrada %s, vendidos %s)',
            product_name,
            opening_qty,
            inbound_qty,
            sold_qty
          ),
          '; '
        )
        from public.ipv_lines
        where ipv_id = ipv
          and closing_qty < 0
      );
  end if;

  for ipv_line in
    select * from public.ipv_lines where ipv_id = ipv
  loop
    if ipv_line.sold_qty <> 0 then
      insert into public.stock_movements (
        product_id, kind, qty, unit_cost, occurred_on, ipv_line_id
      )
      values (
        ipv_line.product_id, 'ipv_sale', -ipv_line.sold_qty, ipv_line.replenishment_cost, work, ipv_line.id
      )
      on conflict do nothing;
    end if;

    if ipv_line.inbound_qty <> 0 and ipv_line.inbound_adds_stock then
      insert into public.stock_movements (
        product_id, kind, qty, unit_cost, occurred_on, ipv_line_id
      )
      values (
        ipv_line.product_id, 'ipv_inbound', ipv_line.inbound_qty, ipv_line.replenishment_cost, work, ipv_line.id
      )
      on conflict do nothing;

      select * into pack
      from public.product_packs
      where packed_product_id = ipv_line.product_id;

      if pack.packed_product_id is not null then
        consume := ipv_line.inbound_qty * pack.bulk_qty;
        select coalesce(sum(qty), 0) into bulk_left
        from public.stock_movements
        where product_id = pack.bulk_product_id;

        if bulk_left < consume then
          raise exception
            'No hay suficiente % para embolsar (faltan %).',
            (select name from public.products where id = pack.bulk_product_id),
            consume - bulk_left;
        end if;

        insert into public.stock_movements (
          product_id, kind, qty, unit_cost, occurred_on, ipv_line_id
        )
        values (
          pack.bulk_product_id, 'ipv_pack', -consume, ipv_line.replenishment_cost, work, ipv_line.id
        )
        on conflict do nothing;
      end if;
    end if;
  end loop;

  update public.ipv_documents
  set
    transfer_collected = 8000,
    cash_collected = (
      select coalesce(sum(sale_total), 0) from public.ipv_lines where ipv_id = ipv
    ) - 8000
  where id = ipv;

  if (
    select cash_collected from public.ipv_documents where id = ipv
  ) < 0 then
    raise exception 'La transferencia de 8000 supera la venta del IPV.';
  end if;

  update public.ipv_documents
  set status = 'closed', closed_by = actor, closed_at = now()
  where id = ipv;
end $$;
