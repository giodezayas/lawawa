-- IPV 8 sep 2026. Azúcar: entrada 5 lb y 5 kg. Transferencia 6590, resto efectivo.

do $$
declare
  actor uuid;
  ipv uuid;
  ipv_line public.ipv_lines;
  pack public.product_packs;
  bulk_left numeric(12, 3);
  consume numeric(12, 3);
  work date := date '2026-09-08';
begin
  select id into actor
    from public.profiles
    order by case when email ilike '%gdzayas%' then 0 else 1 end, created_at
    limit 1;

  if actor is null then
    raise exception 'No hay usuario en profiles para created_by.';
  end if;

  update public.purchase_lines pl
  set unit_cost = 300
  from public.products p
  where pl.product_id = p.id
    and p.name = 'Cerveza Cristal'
    and pl.qty = 72
    and pl.unit_cost = 0;

  update public.products
  set sale_price = 500, purchase_price = 300, replenishment_cost = 300
  where name = 'Cerveza Cristal';

  perform set_config('wawa.bypass_ipv_protect', 'on', true);

  update public.ipv_lines ipv_row
  set sale_price = 500, replenishment_cost = 300
  from public.products p
  where ipv_row.product_id = p.id
    and p.name = 'Cerveza Cristal';

  update public.stock_movements m
  set unit_cost = 300
  from public.ipv_lines ipv_row
  join public.products p on p.id = ipv_row.product_id
  where m.ipv_line_id = ipv_row.id
    and p.name = 'Cerveza Cristal';

  update public.ipv_documents doc
  set
    transfer_collected = 9580,
    cash_collected = greatest(
      (select coalesce(sum(row.sale_total), 0) from public.ipv_lines row where row.ipv_id = doc.id) - 9580,
      0
    )
  where doc.work_date = date '2026-09-07';

  update public.ipv_lines ipv_row
  set opening_qty = coalesce((
    select sum(m.qty)
    from public.stock_movements m
    where m.product_id = ipv_row.product_id
      and m.occurred_on <= doc.work_date
      and not (m.kind in ('ipv_sale', 'ipv_inbound', 'ipv_pack', 'ipv_outbound', 'ipv_close') and m.ipv_line_id = ipv_row.id)
  ), 0)
  from public.products p, public.ipv_documents doc
  where ipv_row.ipv_id = doc.id
    and ipv_row.product_id = p.id
    and p.name = 'Vinagre 300 ml'
    and doc.work_date in (date '2026-09-07', date '2026-09-08');

  if exists (select 1 from public.ipv_documents where work_date = work) then
    perform set_config('wawa.bypass_ipv_protect', 'on', true);
    update public.ipv_documents doc
    set
      transfer_collected = 6590,
      cash_collected = greatest(
        (select coalesce(sum(row.sale_total), 0) from public.ipv_lines row where row.ipv_id = doc.id) - 6590,
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
      ('Papel Higiénico', 0::numeric, 1::numeric, 690::numeric, 1),
      ('Pasta De Tomate', 0, 0, 650, 2),
      ('Azúcar 1 lb', 5, 2, 500, 3),
      ('Azúcar 1 kg', 5, 3, 1100, 4),
      ('Arroz 1 kg', 0, 1, 800, 5),
      ('Gomitas', 0, 4, 350, 6),
      ('Mega', 0, 1, 250, 7),
      ('Keks Azul', 0, 1, 220, 8),
      ('Keks Morados', 0, 0, 220, 9),
      ('Efsane', 0, 2, 220, 10),
      ('Sazón Tropical Naranja', 0, 1, 70, 11),
      ('Sazón Tropical Verde', 0, 0, 70, 12),
      ('Sazón Mina', 0, 2, 60, 13),
      ('Sazón Guama', 0, 1, 60, 14),
      ('Cuadrito De Pollo', 0, 10, 30, 15),
      ('Pan Bon', 0, 9, 500, 16),
      ('Jaba', 0, 2, 10, 17),
      ('Cerveza Cristal', 0, 31, 500, 18),
      ('Galletas Sala Saltbock', 0, 7, 270, 19),
      ('Jabón Kare 75g', 0, 0, 300, 20),
      ('Detergente Yamy 900g', 0, 2, 850, 21),
      ('Refresco Instantáneo Golden', 0, 40, 150, 22),
      ('Cono Richy', 0, 2, 190, 23),
      ('Chupa Chups', 0, 5, 80, 24),
      ('Niks', 0, 4, 220, 25),
      ('Vinagre 300 ml', 0, 0, 300, 26),
      ('Agua Ciego Montero 500 ml', 0, 0, 220, 27)
  ) as v(name, inbound_qty, sold_qty, sale_price, sort_order)
  join public.products p on p.name = v.name;

  if exists (
    select 1
    from public.ipv_lines
    where ipv_id = ipv
      and closing_qty < 0
  ) then
    raise exception 'Hay un producto con vendidos por encima del stock del 8 sep.';
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
    transfer_collected = 6590,
    cash_collected = (
      select coalesce(sum(sale_total), 0) from public.ipv_lines where ipv_id = ipv
    ) - 6590
  where id = ipv;

  if (
    select cash_collected from public.ipv_documents where id = ipv
  ) < 0 then
    raise exception 'La transferencia de 6590 supera la venta del IPV.';
  end if;

  update public.ipv_documents
  set status = 'closed', closed_by = actor, closed_at = now()
  where id = ipv;
end $$;
