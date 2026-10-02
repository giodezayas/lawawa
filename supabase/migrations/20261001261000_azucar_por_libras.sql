-- Azúcar por libras en el IPV: lo vendido se resta del saco al cerrar.
-- Azúcar 1 lb / 1 kg sigue embolsando por Entradas + Suma Al Inventario.

alter table public.product_packs
  add column if not exists consume_on text not null default 'inbound';

alter table public.product_packs
  drop constraint if exists product_packs_consume_on_valid;

alter table public.product_packs
  add constraint product_packs_consume_on_valid check (consume_on in ('inbound', 'sale'));

do $$
declare
  saco uuid;
  lb uuid;
  packed uuid;
begin
  select id into saco from public.products where name = 'Azúcar Saco 25 kg';
  if saco is null then
    raise exception 'Falta el producto Azúcar Saco 25 kg.';
  end if;

  select id into lb from public.products where name = 'Azúcar 1 lb';

  insert into public.products (name, sale_price, purchase_price, replenishment_cost, min_stock, is_active)
  select
    'Azúcar Por Libras',
    coalesce(lb_prod.sale_price, 550),
    coalesce(lb_prod.purchase_price, saco_prod.purchase_price, 0),
    coalesce(lb_prod.replenishment_cost, saco_prod.replenishment_cost, 0),
    0,
    true
  from public.products saco_prod
  left join public.products lb_prod on lb_prod.id = lb
  where saco_prod.id = saco
  on conflict (name) do update set is_active = true;

  select id into packed from public.products where name = 'Azúcar Por Libras';

  insert into public.product_packs (packed_product_id, bulk_product_id, bulk_qty, consume_on)
  values (packed, saco, 1, 'sale')
  on conflict (packed_product_id) do update set
    bulk_product_id = excluded.bulk_product_id,
    bulk_qty = excluded.bulk_qty,
    consume_on = excluded.consume_on;
end;
$$;

create or replace function public.apply_ipv_line_stock(p_line public.ipv_lines, p_work_date date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  pack public.product_packs;
  bulk_left numeric(12, 3);
  consume numeric(12, 3);
  sale_from_sack boolean := false;
begin
  select * into pack
  from public.product_packs
  where packed_product_id = p_line.product_id;

  sale_from_sack := pack.packed_product_id is not null and pack.consume_on = 'sale';

  if p_line.sold_qty <> 0 and not sale_from_sack then
    insert into public.stock_movements (
      product_id, kind, qty, unit_cost, occurred_on, ipv_line_id
    )
    values (
      p_line.product_id, 'ipv_sale', -p_line.sold_qty, p_line.replenishment_cost, p_work_date, p_line.id
    )
    on conflict (ipv_line_id, kind) where ipv_line_id is not null
    do update set
      qty = excluded.qty,
      unit_cost = excluded.unit_cost,
      occurred_on = excluded.occurred_on,
      product_id = excluded.product_id;
  else
    delete from public.stock_movements
    where ipv_line_id = p_line.id and kind = 'ipv_sale';
  end if;

  if p_line.outbound_qty <> 0 then
    insert into public.stock_movements (
      product_id, kind, qty, unit_cost, occurred_on, ipv_line_id
    )
    values (
      p_line.product_id, 'ipv_outbound', -p_line.outbound_qty, p_line.replenishment_cost, p_work_date, p_line.id
    )
    on conflict (ipv_line_id, kind) where ipv_line_id is not null
    do update set
      qty = excluded.qty,
      unit_cost = excluded.unit_cost,
      occurred_on = excluded.occurred_on,
      product_id = excluded.product_id;
  else
    delete from public.stock_movements
    where ipv_line_id = p_line.id and kind = 'ipv_outbound';
  end if;

  if sale_from_sack then
    consume := p_line.sold_qty * pack.bulk_qty;

    if consume <> 0 then
      select coalesce(sum(qty), 0) into bulk_left
      from public.stock_movements
      where product_id = pack.bulk_product_id
        and not (kind = 'ipv_pack' and ipv_line_id = p_line.id);

      if bulk_left < consume then
        raise exception
          'No hay suficiente % para las libras vendidas (faltan %).',
          (select name from public.products where id = pack.bulk_product_id),
          consume - bulk_left;
      end if;

      insert into public.stock_movements (
        product_id, kind, qty, unit_cost, occurred_on, ipv_line_id
      )
      values (
        pack.bulk_product_id,
        'ipv_pack',
        -consume,
        p_line.replenishment_cost,
        p_work_date,
        p_line.id
      )
      on conflict (ipv_line_id, kind) where ipv_line_id is not null
      do update set
        qty = excluded.qty,
        unit_cost = excluded.unit_cost,
        occurred_on = excluded.occurred_on,
        product_id = excluded.product_id;
    else
      delete from public.stock_movements
      where ipv_line_id = p_line.id and kind = 'ipv_pack';
    end if;

    delete from public.stock_movements
    where ipv_line_id = p_line.id and kind in ('ipv_inbound', 'ipv_close');
    return;
  end if;

  if p_line.inbound_qty <> 0 and p_line.inbound_adds_stock then
    insert into public.stock_movements (
      product_id, kind, qty, unit_cost, occurred_on, ipv_line_id
    )
    values (
      p_line.product_id, 'ipv_inbound', p_line.inbound_qty, p_line.replenishment_cost, p_work_date, p_line.id
    )
    on conflict (ipv_line_id, kind) where ipv_line_id is not null
    do update set
      qty = excluded.qty,
      unit_cost = excluded.unit_cost,
      occurred_on = excluded.occurred_on,
      product_id = excluded.product_id;

    if pack.packed_product_id is not null then
      consume := p_line.inbound_qty * pack.bulk_qty;

      select coalesce(sum(qty), 0) into bulk_left
      from public.stock_movements
      where product_id = pack.bulk_product_id
        and not (kind = 'ipv_pack' and ipv_line_id = p_line.id);

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
        pack.bulk_product_id,
        'ipv_pack',
        -consume,
        p_line.replenishment_cost,
        p_work_date,
        p_line.id
      )
      on conflict (ipv_line_id, kind) where ipv_line_id is not null
      do update set
        qty = excluded.qty,
        unit_cost = excluded.unit_cost,
        occurred_on = excluded.occurred_on,
        product_id = excluded.product_id;
    else
      delete from public.stock_movements
      where ipv_line_id = p_line.id and kind = 'ipv_pack';
    end if;
  else
    delete from public.stock_movements
    where ipv_line_id = p_line.id and kind in ('ipv_inbound', 'ipv_pack');
  end if;

  perform public.align_ipv_line_stock(p_line, p_work_date);
end;
$$;
