-- Catálogo con stock calculado, compras y movimientos.
-- Entradas del IPV no suman al almacén salvo inbound_adds_stock.

alter table public.products
  add column if not exists min_stock numeric(12, 3) not null default 0;

alter table public.ipv_lines
  add column if not exists inbound_adds_stock boolean not null default false;

create table if not exists public.purchase_documents (
  id uuid primary key default gen_random_uuid(),
  purchased_on date not null,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

create table if not exists public.purchase_lines (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchase_documents (id) on delete cascade,
  product_id uuid not null references public.products (id),
  qty numeric(12, 3) not null,
  unit_cost numeric(12, 2) not null,
  created_at timestamptz not null default now(),
  constraint purchase_lines_qty_positive check (qty > 0),
  constraint purchase_lines_cost_non_negative check (unit_cost >= 0)
);

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id),
  kind text not null,
  qty numeric(12, 3) not null,
  unit_cost numeric(12, 2) not null default 0,
  occurred_on date not null,
  purchase_line_id uuid references public.purchase_lines (id) on delete cascade,
  ipv_line_id uuid references public.ipv_lines (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint stock_movements_kind_valid check (
    kind in ('purchase', 'ipv_sale', 'ipv_outbound', 'ipv_inbound')
  )
);

create unique index if not exists stock_movements_purchase_line_uniq
  on public.stock_movements (purchase_line_id)
  where purchase_line_id is not null;

create unique index if not exists stock_movements_ipv_kind_uniq
  on public.stock_movements (ipv_line_id, kind)
  where ipv_line_id is not null;

create or replace function public.refresh_product_cost(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.products
  set replenishment_cost = coalesce((
    select sum(qty * unit_cost) / nullif(sum(qty), 0)
    from public.purchase_lines
    where product_id = p_product_id
  ), replenishment_cost)
  where id = p_product_id;
end;
$$;

create or replace function public.register_purchase_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  purchased_on date;
begin
  select pd.purchased_on into purchased_on
  from public.purchase_documents pd
  where pd.id = new.purchase_id;

  insert into public.stock_movements (
    product_id, kind, qty, unit_cost, occurred_on, purchase_line_id
  )
  values (
    new.product_id, 'purchase', new.qty, new.unit_cost, purchased_on, new.id
  )
  on conflict do nothing;

  perform public.refresh_product_cost(new.product_id);
  return new;
end;
$$;

drop trigger if exists purchase_lines_register_stock on public.purchase_lines;
create trigger purchase_lines_register_stock
  after insert on public.purchase_lines
  for each row execute function public.register_purchase_stock();

create or replace function public.close_ipv(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  doc public.ipv_documents;
  line public.ipv_lines;
begin
  if not public.is_active_internal_user() then
    raise exception 'No autorizado';
  end if;

  select * into doc
  from public.ipv_documents
  where id = p_id
  for update;

  if doc.id is null then
    raise exception 'No encontramos ese IPV.';
  end if;

  if doc.status = 'closed' then
    raise exception 'Este IPV ya está cerrado y no se puede editar';
  end if;

  for line in
    select * from public.ipv_lines where ipv_id = p_id
  loop
    if line.sold_qty <> 0 then
      insert into public.stock_movements (
        product_id, kind, qty, unit_cost, occurred_on, ipv_line_id
      )
      values (
        line.product_id, 'ipv_sale', -line.sold_qty, line.replenishment_cost, doc.work_date, line.id
      )
      on conflict do nothing;
    end if;

    if line.outbound_qty <> 0 then
      insert into public.stock_movements (
        product_id, kind, qty, unit_cost, occurred_on, ipv_line_id
      )
      values (
        line.product_id, 'ipv_outbound', -line.outbound_qty, line.replenishment_cost, doc.work_date, line.id
      )
      on conflict do nothing;
    end if;

    if line.inbound_qty <> 0 and line.inbound_adds_stock then
      insert into public.stock_movements (
        product_id, kind, qty, unit_cost, occurred_on, ipv_line_id
      )
      values (
        line.product_id, 'ipv_inbound', line.inbound_qty, line.replenishment_cost, doc.work_date, line.id
      )
      on conflict do nothing;
    end if;
  end loop;

  update public.ipv_documents
  set
    status = 'closed',
    closed_by = auth.uid(),
    closed_at = now()
  where id = p_id;
end;
$$;

insert into public.stock_movements (product_id, kind, qty, unit_cost, occurred_on, ipv_line_id)
select
  line.product_id,
  'ipv_sale',
  -line.sold_qty,
  line.replenishment_cost,
  doc.work_date,
  line.id
from public.ipv_lines line
join public.ipv_documents doc on doc.id = line.ipv_id
where doc.status = 'closed' and line.sold_qty <> 0
on conflict do nothing;

insert into public.stock_movements (product_id, kind, qty, unit_cost, occurred_on, ipv_line_id)
select
  line.product_id,
  'ipv_outbound',
  -line.outbound_qty,
  line.replenishment_cost,
  doc.work_date,
  line.id
from public.ipv_lines line
join public.ipv_documents doc on doc.id = line.ipv_id
where doc.status = 'closed' and line.outbound_qty <> 0
on conflict do nothing;

create or replace view public.product_catalog
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
  costs.last_purchase_price,
  coalesce(costs.average_cost, p.replenishment_cost) as average_cost
from public.products p
left join (
  select product_id, sum(qty) as qty
  from public.stock_movements
  group by product_id
) stock on stock.product_id = p.id
left join (
  select
    product_id,
    sum(qty * unit_cost) / nullif(sum(qty), 0) as average_cost,
    (array_agg(unit_cost order by created_at desc))[1] as last_purchase_price
  from public.purchase_lines
  group by product_id
) costs on costs.product_id = p.id;

alter table public.purchase_documents enable row level security;
alter table public.purchase_lines enable row level security;
alter table public.stock_movements enable row level security;

drop policy if exists purchase_documents_all_internal on public.purchase_documents;
create policy purchase_documents_all_internal
  on public.purchase_documents
  for all
  to authenticated
  using (public.is_active_internal_user())
  with check (public.is_active_internal_user());

drop policy if exists purchase_lines_all_internal on public.purchase_lines;
create policy purchase_lines_all_internal
  on public.purchase_lines
  for all
  to authenticated
  using (public.is_active_internal_user())
  with check (public.is_active_internal_user());

drop policy if exists stock_movements_select_internal on public.stock_movements;
create policy stock_movements_select_internal
  on public.stock_movements
  for select
  to authenticated
  using (public.is_active_internal_user());

grant execute on function public.close_ipv(uuid) to authenticated;
