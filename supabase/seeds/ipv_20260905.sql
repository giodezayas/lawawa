-- IPV 5 sep 2026. Lo que salió a la venta (verde vendido 0). Azúcar: entrada + Suma Al Inventario.

do $$
declare
  actor uuid;
  ipv uuid;
  ipv_line public.ipv_lines;
  pack public.product_packs;
  bulk_left numeric(12, 3);
  consume numeric(12, 3);
  work date := date '2026-09-05';
begin
  select id into actor
    from public.profiles
    order by case when email ilike '%gdzayas%' then 0 else 1 end, created_at
    limit 1;

  if actor is null then
    raise exception 'No hay usuario en profiles para created_by.';
  end if;

  insert into public.products (name, sale_price, purchase_price, replenishment_cost, min_stock, is_active)
  values ('Jaba', 10, 7, 7, 0, true)
  on conflict (name) do update set
    sale_price = excluded.sale_price,
    purchase_price = excluded.purchase_price,
    replenishment_cost = excluded.replenishment_cost;

  if not exists (
    select 1
    from public.purchase_lines pl
    join public.products p on p.id = pl.product_id
    where p.name = 'Jaba'
  ) then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (date '2026-09-01', 'cash', actor)
    returning id into ipv;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select ipv, p.id, 1000, 7
    from public.products p
    where p.name = 'Jaba';
  end if;

  if exists (select 1 from public.ipv_documents where work_date = work) then
    perform set_config('wawa.bypass_ipv_protect', 'on', true);
    select id into ipv from public.ipv_documents where work_date = work;

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
      0,
      0,
      0,
      70,
      p.replenishment_cost,
      false,
      12
    from public.products p
    where p.name = 'Sazón Tropical Verde'
      and not exists (
        select 1 from public.ipv_lines existing
        where existing.ipv_id = ipv and existing.product_id = p.id
      );

    update public.ipv_documents doc
    set
      transfer_collected = 5000,
      cash_collected = greatest(
        (select coalesce(sum(row.sale_total), 0) from public.ipv_lines row where row.ipv_id = doc.id) - 5000,
        0
      )
    where doc.id = ipv;
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
    case
      when v.inbound_qty > 0 then 0
      else coalesce((
        select sum(m.qty)
        from public.stock_movements m
        where m.product_id = p.id
          and m.occurred_on <= work
      ), 0)
    end,
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
      ('Pasta De Tomate', 0, 4, 650, 2),
      ('Azúcar 1 lb', 15, 3, 500, 3),
      ('Azúcar 1 kg', 5, 5, 1100, 4),
      ('Arroz 1 kg', 0, 6, 800, 5),
      ('Gomitas', 0, 7, 350, 6),
      ('Mega', 0, 8, 250, 7),
      ('Keks Azul', 0, 4, 220, 8),
      ('Keks Morados', 0, 4, 220, 9),
      ('Efsane', 0, 5, 220, 10),
      ('Sazón Tropical Naranja', 0, 6, 70, 11),
      ('Sazón Tropical Verde', 0, 0, 70, 12),
      ('Sazón Mina', 0, 1, 60, 13),
      ('Cuadrito De Pollo', 0, 2, 30, 14),
      ('Pan Bon', 0, 15, 500, 15),
      ('Jaba', 0, 11, 10, 16)
  ) as v(name, inbound_qty, sold_qty, sale_price, sort_order)
  join public.products p on p.name = v.name;

  if exists (
    select 1
    from public.ipv_lines
    where ipv_id = ipv
      and closing_qty < 0
  ) then
    raise exception 'Hay un producto con vendidos por encima del stock del 5 sep.';
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
    transfer_collected = 5000,
    cash_collected = (
      select coalesce(sum(sale_total), 0) from public.ipv_lines where ipv_id = ipv
    ) - 5000
  where id = ipv;

  if (
    select cash_collected from public.ipv_documents where id = ipv
  ) < 0 then
    raise exception 'La transferencia de 5000 supera la venta del IPV.';
  end if;

  update public.ipv_documents
  set status = 'closed', closed_by = actor, closed_at = now()
  where id = ipv;
end $$;
