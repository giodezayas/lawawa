-- Precios de venta, compra y reposición se guardan en el producto.
-- Borrar IPV cerrado o producto con historial.

alter table public.products
  add column if not exists purchase_price numeric(12, 2) not null default 0;

alter table public.products
  drop constraint if exists products_purchase_price_non_negative;

alter table public.products
  add constraint products_purchase_price_non_negative check (purchase_price >= 0);

update public.products p
set purchase_price = coalesce((
  select unit_cost
  from public.purchase_lines
  where product_id = p.id
  order by created_at desc
  limit 1
), purchase_price);

create or replace function public.refresh_product_cost(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.products
  set purchase_price = coalesce((
    select unit_cost
    from public.purchase_lines
    where product_id = p_product_id
    order by created_at desc
    limit 1
  ), purchase_price)
  where id = p_product_id;
end;
$$;

drop view if exists public.product_catalog;

create view public.product_catalog
with (security_invoker = true)
as
select
  p.id,
  p.name,
  p.sale_price,
  p.replenishment_cost,
  p.min_stock,
  p.is_active,
  p.created_at,
  p.updated_at,
  coalesce(stock.qty, 0) as stock_qty,
  p.purchase_price::numeric as last_purchase_price,
  p.replenishment_cost::numeric as average_cost
from public.products p
left join (
  select product_id, sum(qty) as qty
  from public.stock_movements
  group by product_id
) stock on stock.product_id = p.id;

create or replace function public.protect_closed_ipv_document()
returns trigger
language plpgsql
as $$
begin
  if current_setting('wawa.bypass_ipv_protect', true) = 'on' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'closed' then
    raise exception 'Este IPV ya está cerrado y no se puede editar';
  end if;

  if tg_op = 'UPDATE' and new.status = 'closed' and old.status = 'open' then
    new.closed_at = coalesce(new.closed_at, now());
    new.closed_by = coalesce(new.closed_by, auth.uid());
  end if;

  return new;
end;
$$;

create or replace function public.protect_closed_ipv_lines()
returns trigger
language plpgsql
as $$
declare
  doc_status public.ipv_status;
  doc_id uuid;
begin
  if current_setting('wawa.bypass_ipv_protect', true) = 'on' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  doc_id := coalesce(new.ipv_id, old.ipv_id);
  select status into doc_status from public.ipv_documents where id = doc_id;

  if doc_status = 'closed' then
    raise exception 'Este IPV ya está cerrado y no se puede editar';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

create or replace function public.delete_ipv(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_active_internal_user() then
    raise exception 'No autorizado';
  end if;

  if not exists (select 1 from public.ipv_documents where id = p_id) then
    raise exception 'No encontramos ese IPV.';
  end if;

  perform set_config('wawa.bypass_ipv_protect', 'on', true);

  delete from public.stock_movements
  where ipv_line_id in (select id from public.ipv_lines where ipv_id = p_id);

  delete from public.ipv_documents where id = p_id;
end;
$$;

create or replace function public.delete_product(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_active_internal_user() then
    raise exception 'No autorizado';
  end if;

  if not exists (select 1 from public.products where id = p_id) then
    raise exception 'No encontramos ese producto.';
  end if;

  perform set_config('wawa.bypass_ipv_protect', 'on', true);

  delete from public.stock_movements where product_id = p_id;
  delete from public.purchase_lines where product_id = p_id;
  delete from public.ipv_lines where product_id = p_id;
  delete from public.purchase_documents
  where id not in (select purchase_id from public.purchase_lines);
  delete from public.products where id = p_id;
end;
$$;

grant execute on function public.delete_ipv(uuid) to authenticated;
grant execute on function public.delete_product(uuid) to authenticated;
