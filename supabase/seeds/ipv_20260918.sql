-- IPV 18 sep 2026. Azúcar kg y lb: entrada embolsa. Pan Bon: apertura 4, compra 10, 8 vendidas.
-- Barolle 24 a la venta (compra del 16). Refresco instantáneo = Yeya. Transferencia 5220.

do $$
declare
  actor uuid;
  ipv uuid;
  ipv_line public.ipv_lines;
  pack public.product_packs;
  bulk_left numeric(12, 3);
  consume numeric(12, 3);
  work date := date '2026-09-18';
begin
  select id into actor
    from public.profiles
    order by case when email ilike '%gdzayas%' then 0 else 1 end, created_at
    limit 1;

  if actor is null then
    raise exception 'No hay usuario en profiles para created_by.';
  end if;

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
      transfer_collected = 5220,
      cash_collected = greatest(
        (select coalesce(sum(row.sale_total), 0) from public.ipv_lines row where row.ipv_id = doc.id) - 5220,
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
      ('Papel Higiénico', 0::numeric, 1::numeric, 690::numeric, false, 1),
      ('Pasta De Tomate', 0, 4, 650, false, 2),
      ('Azúcar 1 kg', 5, 3, 1100, true, 3),
      ('Azúcar 1 lb', 6, 5, 500, true, 4),
      ('Arroz 1 kg', 0, 2, 800, false, 5),
      ('Gomitas', 0, 2, 350, false, 6),
      ('Pan Bon', 10, 8, 480, false, 7),
      ('Sazón Guama', 0, 14, 60, false, 8),
      ('Sazón Mina', 0, 1, 60, false, 9),
      ('Cuadrito De Pollo', 0, 1, 30, false, 10),
      ('Ron HC', 0, 0, 800, false, 11),
      ('Galletas Sala Saltbock', 0, 23, 270, false, 12),
      ('Detergente Yamy 900g', 0, 1, 850, false, 13),
      ('Cono Richy', 0, 0, 190, false, 14),
      ('Chupa Chups', 0, 7, 80, false, 15),
      ('Agua Ciego Montero 500 ml', 0, 2, 220, false, 16),
      ('Refresco Ritz Cola', 0, 8, 450, false, 17),
      ('Biskiato', 0, 1, 140, false, 18),
      ('Sorbeto Trixmax', 0, 4, 150, false, 19),
      ('Sorbeto Crispy', 0, 0, 220, false, 20),
      ('Dona', 0, 1, 220, false, 21),
      ('Dolcero', 0, 5, 220, false, 22),
      ('Sopitas Pollo', 0, 2, 300, false, 23),
      ('Gelatina Naranja', 0, 0, 350, false, 24),
      ('Galletas Nikito', 0, 1, 350, false, 25),
      ('Huevos Sorpresa', 0, 0, 120, false, 26),
      ('Espaguetis 500g', 0, 7, 500, false, 27),
      ('Keks Rosados', 0, 0, 220, false, 28),
      ('Sal Paquete 2 lb', 0, 2, 550, false, 29),
      ('Cerveza Hollandia', 0, 8, 480, false, 30),
      ('Ron 5 Shot', 0, 1, 550, false, 31),
      ('Refresco Instantáneo Yeya', 0, 40, 160, false, 32),
      ('Barolle', 24, 8, 160, false, 33)
  ) as v(name, inbound_qty, sold_qty, sale_price, adds_stock, sort_order)
  join public.products p on p.name = v.name;

  if exists (
    select 1
    from public.ipv_lines
    where ipv_id = ipv
      and closing_qty < 0
  ) then
      raise exception 'Vendidos por encima del stock el 18 sep: %',
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
    transfer_collected = 5220,
    cash_collected = (
      select coalesce(sum(sale_total), 0) from public.ipv_lines where ipv_id = ipv
    ) - 5220
  where id = ipv;

  if (
    select cash_collected from public.ipv_documents where id = ipv
  ) < 0 then
    raise exception 'La transferencia de 5220 supera la venta del IPV.';
  end if;

  update public.ipv_documents
  set status = 'closed', closed_by = actor, closed_at = now()
  where id = ipv;
end $$;
