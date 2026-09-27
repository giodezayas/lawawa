-- IPV 12 sep 2026. Entrada = a la venta (Pan Bon y Ritz ya comprados).
-- Transferencia 2700, resto efectivo.

do $$
declare
  actor uuid;
  ipv uuid;
  ipv_line public.ipv_lines;
  pack public.product_packs;
  bulk_left numeric(12, 3);
  consume numeric(12, 3);
  work date := date '2026-09-12';
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
    update public.ipv_documents doc
    set
      transfer_collected = 2700,
      cash_collected = greatest(
        (select coalesce(sum(row.sale_total), 0) from public.ipv_lines row where row.ipv_id = doc.id) - 2700,
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
      ('Azúcar 1 kg', 0, 0, 1100, false, 3),
      ('Azúcar 1 lb', 0, 2, 500, false, 4),
      ('Arroz 1 kg', 0, 0, 800, false, 5),
      ('Gomitas', 0, 2, 350, false, 6),
      ('Keks Azul', 0, 2, 220, false, 7),
      ('Keks Morados', 0, 1, 220, false, 8),
      ('Pan Bon', 10, 4, 500, false, 9),
      ('Sazón Tropical Naranja', 0, 1, 70, false, 10),
      ('Sazón Tropical Verde', 0, 6, 70, false, 11),
      ('Sazón Guama', 0, 7, 60, false, 12),
      ('Sazón Mina', 0, 0, 60, false, 13),
      ('Cuadrito De Pollo', 0, 5, 30, false, 14),
      ('Jaba', 0, 1, 10, false, 15),
      ('Ron HC', 0, 0, 800, false, 16),
      ('Galletas Sala Saltbock', 0, 2, 270, false, 17),
      ('Jabón Kare 75g', 0, 3, 300, false, 18),
      ('Detergente Yamy 900g', 0, 0, 850, false, 19),
      ('Refresco Instantáneo Golden', 0, 32, 150, false, 20),
      ('Cono Richy', 0, 1, 190, false, 21),
      ('Chupa Chups', 0, 8, 80, false, 22),
      ('Niks', 0, 4, 220, false, 23),
      ('Vinagre 300 ml', 0, 0, 300, false, 24),
      ('Agua Ciego Montero 500 ml', 0, 0, 220, false, 25),
      ('Refresco Ritz Cola', 72, 11, 450, false, 26),
      ('Cerveza W', 0, 1, 460, false, 27)
  ) as v(name, inbound_qty, sold_qty, sale_price, adds_stock, sort_order)
  join public.products p on p.name = v.name;

  if exists (
    select 1
    from public.ipv_lines
    where ipv_id = ipv
      and closing_qty < 0
  ) then
    raise exception 'Hay un producto con vendidos por encima del stock del 12 sep.';
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
    transfer_collected = 2700,
    cash_collected = (
      select coalesce(sum(sale_total), 0) from public.ipv_lines where ipv_id = ipv
    ) - 2700
  where id = ipv;

  if (
    select cash_collected from public.ipv_documents where id = ipv
  ) < 0 then
    raise exception 'La transferencia de 2700 supera la venta del IPV.';
  end if;

  update public.ipv_documents
  set status = 'closed', closed_by = actor, closed_at = now()
  where id = ipv;
end $$;
