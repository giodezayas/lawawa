-- IPV 17 sep 2026. Yeya: compra 364 ese día, a la venta. Azúcar lb: entrada 6 embolsa.
-- Verde: queda 1 (lote de 24). Pan Bon: compra 10, 5 vendidas; al cierre quedan 4 (apertura del 18).
-- Pan Bon a 480 desde este día. Transferencia 7570.

do $$
declare
  actor uuid;
  ipv uuid;
  ipv_line public.ipv_lines;
  pack public.product_packs;
  bulk_left numeric(12, 3);
  consume numeric(12, 3);
  work date := date '2026-09-17';
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
    set sale_price = 480
    from public.ipv_documents d, public.products p
    where ipv_row.ipv_id = d.id
      and d.work_date = work
      and ipv_row.product_id = p.id
      and p.name = 'Pan Bon';
    update public.ipv_documents doc
    set
      transfer_collected = 7570,
      cash_collected = greatest(
        (select coalesce(sum(row.sale_total), 0) from public.ipv_lines row where row.ipv_id = doc.id) - 7570,
        0
      )
    where doc.work_date = work;

    update public.stock_movements m
    set qty = 4 - s.other
    from public.products p
    join (
      select coalesce(sum(mov.qty), 0) as other
      from public.stock_movements mov
      join public.products pan on pan.id = mov.product_id
      where pan.name = 'Pan Bon'
        and mov.occurred_on <= work
        and not (
          mov.kind = 'adjustment'
          and mov.occurred_on = work
          and mov.ipv_line_id is null
        )
    ) s on true
    where m.product_id = p.id
      and p.name = 'Pan Bon'
      and m.kind = 'adjustment'
      and m.occurred_on = work
      and m.ipv_line_id is null;

    insert into public.stock_movements (
      product_id, kind, qty, unit_cost, occurred_on
    )
    select
      p.id,
      'adjustment',
      4 - s.other,
      p.replenishment_cost,
      work
    from public.products p
    join (
      select coalesce(sum(mov.qty), 0) as other
      from public.stock_movements mov
      join public.products pan on pan.id = mov.product_id
      where pan.name = 'Pan Bon'
        and mov.occurred_on <= work
        and not (
          mov.kind = 'adjustment'
          and mov.occurred_on = work
          and mov.ipv_line_id is null
        )
    ) s on true
    where p.name = 'Pan Bon'
      and 4 - s.other <> 0
      and not exists (
        select 1
        from public.stock_movements existing
        where existing.product_id = p.id
          and existing.kind = 'adjustment'
          and existing.occurred_on = work
          and existing.ipv_line_id is null
      );

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
      ('Papel Higiénico', 0::numeric, 1::numeric, 690::numeric, false, 1),
      ('Pasta De Tomate', 0, 2, 650, false, 2),
      ('Azúcar 1 kg', 0, 2, 1100, false, 3),
      ('Azúcar 1 lb', 6, 6, 500, true, 4),
      ('Arroz 1 kg', 0, 2, 800, false, 5),
      ('Gomitas', 0, 2, 350, false, 6),
      ('Pan Bon', 10, 5, 480, false, 7),
      ('Sazón Tropical Verde', 0, 1, 70, false, 8),
      ('Sazón Guama', 0, 3, 60, false, 9),
      ('Sazón Mina', 0, 0, 60, false, 10),
      ('Cuadrito De Pollo', 0, 0, 30, false, 11),
      ('Ron HC', 0, 0, 800, false, 12),
      ('Galletas Sala Saltbock', 0, 10, 270, false, 13),
      ('Detergente Yamy 900g', 0, 0, 850, false, 14),
      ('Cono Richy', 0, 6, 190, false, 15),
      ('Chupa Chups', 0, 9, 80, false, 16),
      ('Agua Ciego Montero 500 ml', 0, 2, 220, false, 17),
      ('Refresco Ritz Cola', 0, 6, 450, false, 18),
      ('Biskiato', 0, 4, 140, false, 19),
      ('Sorbeto Trixmax', 0, 3, 150, false, 20),
      ('Sorbeto Crispy', 0, 2, 220, false, 21),
      ('Dona', 0, 2, 220, false, 22),
      ('Dolcero', 0, 2, 220, false, 23),
      ('Sopitas Pollo', 0, 3, 300, false, 24),
      ('Gelatina Naranja', 0, 2, 350, false, 25),
      ('Galletas Nikito', 0, 6, 350, false, 26),
      ('Huevos Sorpresa', 0, 3, 120, false, 27),
      ('Espaguetis 500g', 0, 1, 500, false, 28),
      ('Keks Rosados', 0, 10, 220, false, 29),
      ('Sal Paquete 2 lb', 0, 0, 550, false, 30),
      ('Cerveza Hollandia', 0, 5, 480, false, 31),
      ('Ron 5 Shot', 0, 0, 550, false, 32),
      ('Refresco Instantáneo Yeya', 364, 10, 160, false, 33)
  ) as v(name, inbound_qty, sold_qty, sale_price, adds_stock, sort_order)
  join public.products p on p.name = v.name;

  if exists (
    select 1
    from public.ipv_lines
    where ipv_id = ipv
      and closing_qty < 0
  ) then
      raise exception 'Vendidos por encima del stock el 17 sep: %',
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
    transfer_collected = 7570,
    cash_collected = (
      select coalesce(sum(sale_total), 0) from public.ipv_lines where ipv_id = ipv
    ) - 7570
  where id = ipv;

  if (
    select cash_collected from public.ipv_documents where id = ipv
  ) < 0 then
    raise exception 'La transferencia de 7570 supera la venta del IPV.';
  end if;

  update public.ipv_documents
  set status = 'closed', closed_by = actor, closed_at = now()
  where id = ipv;

  perform set_config('wawa.bypass_ipv_protect', 'on', true);

  insert into public.stock_movements (
    product_id, kind, qty, unit_cost, occurred_on
  )
  select
    p.id,
    'adjustment',
    4 - s.other,
    p.replenishment_cost,
    work
  from public.products p
  join (
    select coalesce(sum(mov.qty), 0) as other
    from public.stock_movements mov
    join public.products pan on pan.id = mov.product_id
    where pan.name = 'Pan Bon'
      and mov.occurred_on <= work
      and not (
        mov.kind = 'adjustment'
        and mov.occurred_on = work
        and mov.ipv_line_id is null
      )
  ) s on true
  where p.name = 'Pan Bon'
    and 4 - s.other <> 0
    and not exists (
      select 1
      from public.stock_movements existing
      where existing.product_id = p.id
        and existing.kind = 'adjustment'
        and existing.occurred_on = work
        and existing.ipv_line_id is null
    );
end $$;
