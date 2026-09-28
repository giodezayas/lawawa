-- IPV 14 sep 2026. Azúcar 1 lb: entrada 8 (embolsar). Pan Bon: 10 a la venta, 5 vendidas, queda 5.
-- Cristal 24: lote que sí suma al almacén (las 72 del 1/9 ya se habían vendido).
-- Transferencia 4900.

do $$
declare
  actor uuid;
  ipv uuid;
  ipv_line public.ipv_lines;
  pack public.product_packs;
  bulk_left numeric(12, 3);
  consume numeric(12, 3);
  work date := date '2026-09-14';
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
      transfer_collected = 4900,
      cash_collected = greatest(
        (select coalesce(sum(row.sale_total), 0) from public.ipv_lines row where row.ipv_id = doc.id) - 4900,
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
      ('Pasta De Tomate', 0, 1, 650, false, 2),
      ('Azúcar 1 kg', 0, 1, 1100, false, 3),
      ('Azúcar 1 lb', 8, 6, 500, true, 4),
      ('Arroz 1 kg', 0, 4, 800, false, 5),
      ('Gomitas', 0, 3, 350, false, 6),
      ('Keks Azul', 0, 2, 220, false, 7),
      ('Pan Bon', 10, 5, 500, false, 8),
      ('Sazón Tropical Verde', 0, 1, 70, false, 9),
      ('Sazón Guama', 0, 10, 60, false, 10),
      ('Sazón Mina', 0, 0, 60, false, 11),
      ('Cuadrito De Pollo', 0, 11, 30, false, 12),
      ('Ron HC', 0, 0, 800, false, 13),
      ('Galletas Sala Saltbock', 0, 1, 270, false, 14),
      ('Jabón Kare 75g', 0, 4, 300, false, 15),
      ('Detergente Yamy 900g', 0, 2, 850, false, 16),
      ('Refresco Instantáneo Golden', 0, 10, 150, false, 17),
      ('Cono Richy', 0, 0, 190, false, 18),
      ('Chupa Chups', 0, 6, 80, false, 19),
      ('Niks', 0, 5, 220, false, 20),
      ('Vinagre 300 ml', 0, 8, 300, false, 21),
      ('Agua Ciego Montero 500 ml', 0, 1, 220, false, 22),
      ('Refresco Ritz Cola', 0, 3, 450, false, 23),
      ('Biskiato', 0, 10, 140, false, 24),
      ('Barolle', 0, 5, 160, false, 25),
      ('Sorbeto Trixmax', 0, 2, 150, false, 26),
      ('Sorbeto Crispy', 0, 1, 220, false, 27),
      ('Dona', 0, 2, 220, false, 28),
      ('Cerveza Cristal', 24, 1, 500, true, 29)
  ) as v(name, inbound_qty, sold_qty, sale_price, adds_stock, sort_order)
  join public.products p on p.name = v.name;

  if exists (
    select 1
    from public.ipv_lines
    where ipv_id = ipv
      and closing_qty < 0
  ) then
    raise exception 'Hay un producto con vendidos por encima del stock del 14 sep.';
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
    transfer_collected = 4900,
    cash_collected = (
      select coalesce(sum(sale_total), 0) from public.ipv_lines where ipv_id = ipv
    ) - 4900
  where id = ipv;

  if (
    select cash_collected from public.ipv_documents where id = ipv
  ) < 0 then
    raise exception 'La transferencia de 4900 supera la venta del IPV.';
  end if;

  update public.ipv_documents
  set status = 'closed', closed_by = actor, closed_at = now()
  where id = ipv;
end $$;
