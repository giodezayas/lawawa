-- IPV 22 sep 2026. Azúcar lb: entrada 4 (embolsar). Pasta 24, mayo, Sovio, toallitas, café, Marinero: a la venta.
-- Pan Bon: compra 10, 7 vendidas. Precios nuevos: pasta 750/630, espaguetis 550/460, Yeya 180/155, arroz 880, azúcar lb 550.
-- Hollandia: 3. Mr Max: 0. Barolle: 7 vendidos (no 17). Arroz 60 del 21 al almacén.

do $$
declare
  actor uuid;
  ipv uuid;
  doc uuid;
  ipv_line public.ipv_lines;
  pack public.product_packs;
  bulk_left numeric(12, 3);
  consume numeric(12, 3);
  work date := date '2026-09-22';
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
  set sale_price = 880
  where name = 'Arroz 1 kg';

  update public.products
  set sale_price = 550
  where name = 'Azúcar 1 lb';

  update public.products
  set sale_price = 290
  where name = 'Galletas Sala Saltbock';

  perform set_config('wawa.bypass_ipv_protect', 'on', true);

  if not exists (
    select 1
    from public.purchase_lines line
    join public.purchase_documents d on d.id = line.purchase_id
    join public.products p on p.id = line.product_id
    where d.purchased_on = date '2026-09-21'
      and p.name = 'Arroz 1 kg'
  ) then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-21', 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, 60, 700
    from public.products p
    where p.name = 'Arroz 1 kg';
  end if;

  if exists (select 1 from public.ipv_documents where work_date = work) then
    perform set_config('wawa.bypass_ipv_protect', 'on', true);
    update public.ipv_lines ipv_row
    set sold_qty = 7
    from public.ipv_documents d, public.products p
    where ipv_row.ipv_id = d.id
      and d.work_date = work
      and ipv_row.product_id = p.id
      and p.name = 'Barolle';
    update public.stock_movements m
    set qty = -7
    from public.ipv_lines ipv_row
    join public.ipv_documents d on d.id = ipv_row.ipv_id
    join public.products p on p.id = ipv_row.product_id
    where m.ipv_line_id = ipv_row.id
      and m.kind = 'ipv_sale'
      and d.work_date = work
      and p.name = 'Barolle';
    update public.ipv_lines ipv_row
    set sold_qty = 3
    from public.ipv_documents d, public.products p
    where ipv_row.ipv_id = d.id
      and d.work_date = work
      and ipv_row.product_id = p.id
      and p.name = 'Cerveza Hollandia';
    update public.stock_movements m
    set qty = -3
    from public.ipv_lines ipv_row
    join public.ipv_documents d on d.id = ipv_row.ipv_id
    join public.products p on p.id = ipv_row.product_id
    where m.ipv_line_id = ipv_row.id
      and m.kind = 'ipv_sale'
      and d.work_date = work
      and p.name = 'Cerveza Hollandia';
    update public.ipv_documents doc
    set
      transfer_collected = 6190,
      cash_collected = greatest(
        (select coalesce(sum(row.sale_total), 0) from public.ipv_lines row where row.ipv_id = doc.id) - 6190,
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
      ('Pasta De Tomate', 24, 0, 750, true, 2),
      ('Azúcar 1 kg', 0, 0, 1100, false, 3),
      ('Azúcar 1 lb', 4, 6, 550, true, 4),
      ('Gomitas', 0, 2, 350, false, 5),
      ('Pan Bon', 10, 7, 480, false, 6),
      ('Sazón Guama', 0, 7, 60, false, 7),
      ('Sazón Mina', 0, 3, 60, false, 8),
      ('Cuadrito De Pollo', 0, 11, 30, false, 9),
      ('Ron HC', 0, 0, 800, false, 10),
      ('Galletas Sala Saltbock', 0, 8, 290, false, 11),
      ('Cono Richy', 0, 4, 190, false, 12),
      ('Chupa Chups', 0, 8, 80, false, 13),
      ('Agua Ciego Montero 500 ml', 0, 1, 220, false, 14),
      ('Refresco Ritz Cola', 0, 10, 450, false, 15),
      ('Sorbeto Trixmax', 0, 0, 150, false, 16),
      ('Sorbeto Crispy', 0, 0, 220, false, 17),
      ('Dona', 0, 3, 220, false, 18),
      ('Dolcero', 0, 1, 220, false, 19),
      ('Sopitas Pollo', 0, 0, 300, false, 20),
      ('Gelatina Naranja', 0, 1, 350, false, 21),
      ('Galletas Nikito', 0, 4, 350, false, 22),
      ('Huevos Sorpresa', 0, 13, 120, false, 23),
      ('Espaguetis 500g', 0, 3, 550, false, 24),
      ('Keks Rosados', 0, 3, 220, false, 25),
      ('Sal Paquete 2 lb', 0, 1, 550, false, 26),
      ('Cerveza Hollandia', 0, 3, 480, false, 27),
      ('Ron 5 Shot', 0, 0, 550, false, 28),
      ('Refresco Instantáneo Yeya', 0, 29, 180, false, 29),
      ('Barolle', 0, 7, 160, false, 30),
      ('Arroz 1 kg', 0, 3, 880, false, 31),
      ('Mayonesa', 12, 1, 1150, false, 32),
      ('Galletas Sovio De Fresa', 24, 5, 120, false, 33),
      ('Toallitas Húmedas', 4, 1, 820, false, 34),
      ('Café', 20, 0, 1100, false, 35),
      ('Cerveza Marinero', 72, 55, 480, false, 36)
  ) as v(name, inbound_qty, sold_qty, sale_price, adds_stock, sort_order)
  join public.products p on p.name = v.name;

  if exists (
    select 1
    from public.ipv_lines
    where ipv_id = ipv
      and closing_qty < 0
  ) then
    raise exception 'Vendidos por encima del stock el 22 sep: %',
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
    transfer_collected = 6190,
    cash_collected = (
      select coalesce(sum(sale_total), 0) from public.ipv_lines where ipv_id = ipv
    ) - 6190
  where id = ipv;

  if (
    select cash_collected from public.ipv_documents where id = ipv
  ) < 0 then
    raise exception 'La transferencia de 6190 supera la venta del IPV.';
  end if;

  update public.ipv_documents
  set status = 'closed', closed_by = actor, closed_at = now()
  where id = ipv;
end $$;
