-- IPV 20 sep 2026. Ritz: a la venta (compra del 20, 48). Pan Bon: 9 a la venta, 7 vendidas, queda 6.

do $$
declare
  actor uuid;
  ipv uuid;
  ipv_line public.ipv_lines;
  pack public.product_packs;
  bulk_left numeric(12, 3);
  consume numeric(12, 3);
  work date := date '2026-09-20';
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
      transfer_collected = 3580,
      cash_collected = greatest(
        (select coalesce(sum(row.sale_total), 0) from public.ipv_lines row where row.ipv_id = doc.id) - 3580,
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
      ('Papel Higiénico', 0::numeric, 2::numeric, 690::numeric, false, 1),
      ('Pasta De Tomate', 0, 0, 650, false, 2),
      ('Azúcar 1 kg', 0, 3, 1100, false, 3),
      ('Azúcar 1 lb', 0, 5, 500, false, 4),
      ('Gomitas', 0, 0, 350, false, 5),
      ('Pan Bon', 9, 7, 480, false, 6),
      ('Sazón Mina', 0, 0, 60, false, 7),
      ('Sazón Guama', 0, 20, 60, false, 8),
      ('Cuadrito De Pollo', 0, 6, 30, false, 9),
      ('Ron HC', 0, 0, 800, false, 10),
      ('Galletas Sala Saltbock', 0, 2, 270, false, 11),
      ('Cono Richy', 0, 3, 190, false, 12),
      ('Chupa Chups', 0, 9, 80, false, 13),
      ('Agua Ciego Montero 500 ml', 0, 0, 220, false, 14),
      ('Refresco Ritz Cola', 48, 4, 450, false, 15),
      ('Sorbeto Trixmax', 0, 4, 150, false, 16),
      ('Sorbeto Crispy', 0, 4, 220, false, 17),
      ('Dolcero', 0, 0, 220, false, 18),
      ('Sopitas Pollo', 0, 1, 300, false, 19),
      ('Gelatina Naranja', 0, 0, 350, false, 20),
      ('Galletas Nikito', 0, 0, 350, false, 21),
      ('Huevos Sorpresa', 0, 5, 120, false, 22),
      ('Espaguetis 500g', 0, 2, 500, false, 23),
      ('Keks Rosados', 0, 2, 220, false, 24),
      ('Sal Paquete 2 lb', 0, 0, 550, false, 25),
      ('Cerveza Hollandia', 0, 1, 480, false, 26),
      ('Ron 5 Shot', 0, 0, 550, false, 27),
      ('Refresco Instantáneo Yeya', 0, 28, 160, false, 28),
      ('Barolle', 0, 3, 160, false, 29)
  ) as v(name, inbound_qty, sold_qty, sale_price, adds_stock, sort_order)
  join public.products p on p.name = v.name;

  if exists (
    select 1
    from public.ipv_lines
    where ipv_id = ipv
      and closing_qty < 0
  ) then
    raise exception 'Vendidos por encima del stock el 20 sep: %',
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
    transfer_collected = 3580,
    cash_collected = (
      select coalesce(sum(sale_total), 0) from public.ipv_lines where ipv_id = ipv
    ) - 3580
  where id = ipv;

  if (
    select cash_collected from public.ipv_documents where id = ipv
  ) < 0 then
    raise exception 'La transferencia de 3580 supera la venta del IPV.';
  end if;

  update public.ipv_documents
  set status = 'closed', closed_by = actor, closed_at = now()
  where id = ipv;
end $$;
