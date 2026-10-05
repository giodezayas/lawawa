-- Inicio del IPV = cierre del día anterior. Precio y costo salen del producto.

create or replace function public.ipv_line_defaults(p_ipv_id uuid, p_product_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  work date;
  opening numeric(12, 3);
  catalog_name text;
  catalog_price numeric(12, 2);
  catalog_cost numeric(12, 2);
  catalog_stock numeric(12, 3);
begin
  if not public.is_active_internal_user() then
    raise exception 'No autorizado';
  end if;

  select work_date into work
  from public.ipv_documents
  where id = p_ipv_id;

  if work is null then
    raise exception 'No encontramos ese IPV.';
  end if;

  select name, sale_price, replenishment_cost, stock_qty
  into catalog_name, catalog_price, catalog_cost, catalog_stock
  from public.product_catalog
  where id = p_product_id;

  if catalog_name is null then
    raise exception 'No encontramos ese producto.';
  end if;

  select line.closing_qty into opening
  from public.ipv_lines line
  join public.ipv_documents doc on doc.id = line.ipv_id
  where line.product_id = p_product_id
    and doc.work_date < work
  order by doc.work_date desc
  limit 1;

  return jsonb_build_object(
    'opening_qty', coalesce(opening, catalog_stock),
    'sale_price', catalog_price,
    'replenishment_cost', catalog_cost,
    'product_name', catalog_name
  );
end;
$$;

create or replace function public.seed_ipv_lines(p_ipv_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  work date;
begin
  if not public.is_active_internal_user() then
    raise exception 'No autorizado';
  end if;

  select work_date into work
  from public.ipv_documents
  where id = p_ipv_id;

  if work is null then
    raise exception 'No encontramos ese IPV.';
  end if;

  insert into public.ipv_lines (
    ipv_id,
    product_id,
    product_name,
    opening_qty,
    inbound_qty,
    outbound_qty,
    sold_qty,
    sale_price,
    replenishment_cost,
    inbound_adds_stock,
    sort_order
  )
  select
    p_ipv_id,
    catalog.id,
    catalog.name,
    coalesce(prev.closing_qty, catalog.stock_qty),
    0,
    0,
    0,
    catalog.sale_price,
    catalog.replenishment_cost,
    false,
    row_number() over (order by catalog.name) - 1
  from public.product_catalog catalog
  left join lateral (
    select line.closing_qty
    from public.ipv_lines line
    join public.ipv_documents doc on doc.id = line.ipv_id
    where line.product_id = catalog.id
      and doc.work_date < work
    order by doc.work_date desc
    limit 1
  ) prev on true
  where catalog.is_active
    and coalesce(prev.closing_qty, catalog.stock_qty) > 0
    and not exists (
      select 1
      from public.ipv_lines existing
      where existing.ipv_id = p_ipv_id
        and existing.product_id = catalog.id
    );
end;
$$;

grant execute on function public.ipv_line_defaults(uuid, uuid) to authenticated;
grant execute on function public.seed_ipv_lines(uuid) to authenticated;
