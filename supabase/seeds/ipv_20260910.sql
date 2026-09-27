-- IPV 10 sep 2026. Azúcar entrada 5 kg y 5 lb. Pan Bon: compra 10 ese día.
-- Transferencia 10470, resto efectivo.

do $$
declare
  actor uuid;
  ipv uuid;
  doc uuid;
  ipv_line public.ipv_lines;
  pack public.product_packs;
  bulk_left numeric(12, 3);
  consume numeric(12, 3);
  work date := date '2026-09-10';
begin
  select id into actor
    from public.profiles
    order by case when email ilike '%gdzayas%' then 0 else 1 end, created_at
    limit 1;

  if actor is null then
    raise exception 'No hay usuario en profiles para created_by.';
  end if;

  if not exists (
    select 1
    from public.purchase_lines pl
    join public.purchase_documents d on d.id = pl.purchase_id
    join public.products p on p.id = pl.product_id
    where d.purchased_on = work
      and p.name = 'Pan Bon'
  ) then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (work, 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, 10, 420
    from public.products p
    where p.name = 'Pan Bon';
  end if;

  if exists (select 1 from public.ipv_documents where work_date = work) then
    perform set_config('wawa.bypass_ipv_protect', 'on', true);
    update public.ipv_documents doc
    set
      transfer_collected = 10470,
      cash_collected = greatest(
        (select coalesce(sum(row.sale_total), 0) from public.ipv_lines row where row.ipv_id = doc.id) - 10470,
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
    v.inbound_qty > 0,
    v.sort_order
  from (
    values
      ('Papel Higiénico', 0::numeric, 2::numeric, 690::numeric, 1),
      ('Pasta De Tomate', 0, 0, 650, 2),
      ('Azúcar 1 kg', 5, 2, 1100, 3),
      ('Azúcar 1 lb', 5, 0, 500, 4),
      ('Arroz 1 kg', 0, 3, 800, 5),
      ('Gomitas', 0, 3, 350, 6),
      ('Mega', 0, 1, 250, 7),
      ('Keks Azul', 0, 2, 220, 8),
      ('Keks Morados', 0, 3, 220, 9),
      ('Pan De Hamburguesa', 0, 3, 500, 10),
      ('Pan Bon', 0, 6, 500, 11),
      ('Sazón Tropical Naranja', 0, 1, 70, 12),
      ('Sazón Tropical Verde', 0, 2, 70, 13),
      ('Sazón Guama', 0, 6, 60, 14),
      ('Sazón Mina', 0, 0, 60, 15),
      ('Cuadrito De Pollo', 0, 0, 30, 16),
      ('Ron HC', 0, 0, 800, 17),
      ('Galletas Sala Saltbock', 0, 2, 270, 18),
      ('Jabón Kare 75g', 0, 26, 300, 19),
      ('Detergente Yamy 900g', 0, 7, 850, 20),
      ('Refresco Instantáneo Golden', 0, 61, 150, 21),
      ('Cono Richy', 0, 4, 190, 22),
      ('Chupa Chups', 0, 13, 80, 23),
      ('Niks', 0, 3, 220, 24),
      ('Vinagre 300 ml', 0, 2, 300, 25),
      ('Agua Ciego Montero 500 ml', 0, 1, 220, 26),
      ('Cerveza Cristal', 0, 8, 500, 27)
  ) as v(name, inbound_qty, sold_qty, sale_price, sort_order)
  join public.products p on p.name = v.name;

  if exists (
    select 1
    from public.ipv_lines
    where ipv_id = ipv
      and closing_qty < 0
  ) then
    raise exception 'Hay un producto con vendidos por encima del stock del 10 sep.';
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
    transfer_collected = 10470,
    cash_collected = (
      select coalesce(sum(sale_total), 0) from public.ipv_lines where ipv_id = ipv
    ) - 10470
  where id = ipv;

  if (
    select cash_collected from public.ipv_documents where id = ipv
  ) < 0 then
    raise exception 'La transferencia de 10470 supera la venta del IPV.';
  end if;

  update public.ipv_documents
  set status = 'closed', closed_by = actor, closed_at = now()
  where id = ipv;
end $$;
