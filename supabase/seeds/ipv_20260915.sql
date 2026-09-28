-- IPV 15 sep 2026. Chupa, Dolcero, sopitas, gelatina y Nikito: compra del 15, a la venta.
-- Pan Bon: apertura 5, entrada 9, 5 vendidas, queda 9. Donna = Dona. Transferencia 10540.
-- Nikito: 36 a la venta, 0 vendidas (los 8 “Niks” del papel no salen de este lote).
-- Las 24 Cristal del 14 eran lote nuevo (las 72 del 1/9 ya se vendieron el 7–10);
-- si el 14 corrió sin sumar al almacén, aquí se registra el inbound.

do $$
declare
  actor uuid;
  ipv uuid;
  ipv_line public.ipv_lines;
  pack public.product_packs;
  bulk_left numeric(12, 3);
  consume numeric(12, 3);
  work date := date '2026-09-15';
begin
  select id into actor
    from public.profiles
    order by case when email ilike '%gdzayas%' then 0 else 1 end, created_at
    limit 1;

  if actor is null then
    raise exception 'No hay usuario en profiles para created_by.';
  end if;

  perform set_config('wawa.bypass_ipv_protect', 'on', true);

  update public.ipv_lines ipv_row
  set inbound_adds_stock = true
  from public.ipv_documents d, public.products p
  where ipv_row.ipv_id = d.id
    and d.work_date = date '2026-09-14'
    and ipv_row.product_id = p.id
    and p.name = 'Cerveza Cristal'
    and ipv_row.inbound_qty > 0;

  insert into public.stock_movements (
    product_id, kind, qty, unit_cost, occurred_on, ipv_line_id
  )
  select
    ipv_row.product_id,
    'ipv_inbound',
    ipv_row.inbound_qty,
    ipv_row.replenishment_cost,
    d.work_date,
    ipv_row.id
  from public.ipv_lines ipv_row
  join public.ipv_documents d on d.id = ipv_row.ipv_id
  join public.products p on p.id = ipv_row.product_id
  where d.work_date = date '2026-09-14'
    and p.name = 'Cerveza Cristal'
    and ipv_row.inbound_qty > 0
    and not exists (
      select 1
      from public.stock_movements m
      where m.ipv_line_id = ipv_row.id
        and m.kind = 'ipv_inbound'
    );

  if exists (select 1 from public.ipv_documents where work_date = work) then
    perform set_config('wawa.bypass_ipv_protect', 'on', true);
    update public.ipv_lines ipv_row
    set sold_qty = 0
    from public.products p
    where ipv_row.ipv_id = (select id from public.ipv_documents where work_date = work)
      and ipv_row.product_id = p.id
      and p.name = 'Galletas Nikito';
    delete from public.stock_movements m
    using public.ipv_lines ipv_row
    join public.products p on p.id = ipv_row.product_id
    where m.ipv_line_id = ipv_row.id
      and m.kind = 'ipv_sale'
      and ipv_row.ipv_id = (select id from public.ipv_documents where work_date = work)
      and p.name = 'Galletas Nikito';
    update public.ipv_documents doc
    set
      transfer_collected = 10540,
      cash_collected = greatest(
        (select coalesce(sum(row.sale_total), 0) from public.ipv_lines row where row.ipv_id = doc.id) - 10540,
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
      ('Pasta De Tomate', 0, 2, 650, false, 2),
      ('Azúcar 1 kg', 0, 2, 1100, false, 3),
      ('Azúcar 1 lb', 0, 3, 500, false, 4),
      ('Arroz 1 kg', 0, 2, 800, false, 5),
      ('Gomitas', 0, 4, 350, false, 6),
      ('Keks Azul', 0, 1, 220, false, 7),
      ('Pan Bon', 9, 5, 500, false, 8),
      ('Sazón Tropical Verde', 0, 4, 70, false, 9),
      ('Sazón Guama', 0, 14, 60, false, 10),
      ('Sazón Mina', 0, 7, 60, false, 11),
      ('Cuadrito De Pollo', 0, 2, 30, false, 12),
      ('Ron HC', 0, 0, 800, false, 13),
      ('Galletas Sala Saltbock', 0, 8, 270, false, 14),
      ('Jabón Kare 75g', 0, 20, 300, false, 15),
      ('Detergente Yamy 900g', 0, 4, 850, false, 16),
      ('Cono Richy', 0, 2, 190, false, 17),
      ('Chupa Chups', 100, 8, 80, false, 18),
      ('Agua Ciego Montero 500 ml', 0, 0, 220, false, 19),
      ('Refresco Ritz Cola', 0, 16, 450, false, 21),
      ('Barolle', 0, 8, 160, false, 22),
      ('Biskiato', 0, 3, 140, false, 23),
      ('Sorbeto Trixmax', 0, 3, 150, false, 24),
      ('Sorbeto Crispy', 0, 1, 220, false, 25),
      ('Dona', 0, 1, 220, false, 26),
      ('Cerveza Cristal', 0, 22, 500, false, 27),
      ('Dolcero', 24, 0, 220, false, 28),
      ('Sopitas Pollo', 24, 0, 300, false, 29),
      ('Gelatina Naranja', 24, 0, 350, false, 30),
      ('Galletas Nikito', 36, 0, 350, false, 31)
  ) as v(name, inbound_qty, sold_qty, sale_price, adds_stock, sort_order)
  join public.products p on p.name = v.name;

  if exists (
    select 1
    from public.ipv_lines
    where ipv_id = ipv
      and closing_qty < 0
  ) then
    raise exception 'Vendidos por encima del stock el 15 sep: %',
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
    transfer_collected = 10540,
    cash_collected = (
      select coalesce(sum(sale_total), 0) from public.ipv_lines where ipv_id = ipv
    ) - 10540
  where id = ipv;

  if (
    select cash_collected from public.ipv_documents where id = ipv
  ) < 0 then
    raise exception 'La transferencia de 10540 supera la venta del IPV.';
  end if;

  update public.ipv_documents
  set status = 'closed', closed_by = actor, closed_at = now()
  where id = ipv;
end $$;
