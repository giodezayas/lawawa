-- Al cerrar el IPV el stock del catálogo queda igual al stock final.
-- Compras se pueden editar/borrar: el movimiento de stock se actualiza.

alter table public.stock_movements
  drop constraint if exists stock_movements_kind_valid;

alter table public.stock_movements
  add constraint stock_movements_kind_valid check (
    kind in (
      'purchase',
      'ipv_sale',
      'ipv_outbound',
      'ipv_inbound',
      'ipv_close',
      'adjustment'
    )
  );

create or replace function public.refresh_purchase_line_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  purchased_on date;
begin
  if tg_op = 'DELETE' then
    perform public.refresh_product_cost(old.product_id);
    return old;
  end if;

  select pd.purchased_on into purchased_on
  from public.purchase_documents pd
  where pd.id = new.purchase_id;

  if tg_op = 'UPDATE' then
    update public.stock_movements
    set
      product_id = new.product_id,
      qty = new.qty,
      unit_cost = new.unit_cost,
      occurred_on = purchased_on
    where purchase_line_id = new.id;

    if old.product_id <> new.product_id then
      perform public.refresh_product_cost(old.product_id);
    end if;
  end if;

  perform public.refresh_product_cost(new.product_id);
  return new;
end;
$$;

drop trigger if exists purchase_lines_refresh_stock on public.purchase_lines;
create trigger purchase_lines_refresh_stock
  after update or delete on public.purchase_lines
  for each row execute function public.refresh_purchase_line_stock();

create or replace function public.refresh_purchase_date_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.purchased_on is distinct from old.purchased_on then
    update public.stock_movements movement
    set occurred_on = new.purchased_on
    from public.purchase_lines line
    where line.purchase_id = new.id
      and movement.purchase_line_id = line.id;
  end if;
  return new;
end;
$$;

drop trigger if exists purchase_documents_refresh_date on public.purchase_documents;
create trigger purchase_documents_refresh_date
  after update of purchased_on on public.purchase_documents
  for each row execute function public.refresh_purchase_date_stock();

create or replace function public.align_ipv_line_stock(
  p_line public.ipv_lines,
  p_work_date date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  ledger numeric(12, 3);
  delta numeric(12, 3);
begin
  select coalesce(sum(qty), 0) into ledger
  from public.stock_movements
  where product_id = p_line.product_id
    and not (kind = 'ipv_close' and ipv_line_id = p_line.id);

  delta := p_line.closing_qty - ledger;

  if delta = 0 then
    delete from public.stock_movements
    where ipv_line_id = p_line.id
      and kind = 'ipv_close';
    return;
  end if;

  insert into public.stock_movements (
    product_id, kind, qty, unit_cost, occurred_on, ipv_line_id
  )
  values (
    p_line.product_id, 'ipv_close', delta, p_line.replenishment_cost, p_work_date, p_line.id
  )
  on conflict (ipv_line_id, kind) where ipv_line_id is not null
  do update set
    qty = excluded.qty,
    unit_cost = excluded.unit_cost,
    occurred_on = excluded.occurred_on;
end;
$$;

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

    perform public.align_ipv_line_stock(line, doc.work_date);
  end loop;

  update public.ipv_documents
  set
    status = 'closed',
    closed_by = auth.uid(),
    closed_at = now()
  where id = p_id;
end;
$$;

do $$
declare
  doc public.ipv_documents;
  line public.ipv_lines;
begin
  for doc in
    select * from public.ipv_documents
    where status = 'closed'
    order by work_date, created_at
  loop
    for line in
      select * from public.ipv_lines where ipv_id = doc.id
    loop
      perform public.align_ipv_line_stock(line, doc.work_date);
    end loop;
  end loop;
end;
$$;

create or replace function public.adjust_product_stock(p_id uuid, p_qty numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_qty numeric(12, 3);
  delta numeric(12, 3);
begin
  if not public.is_active_internal_user() then
    raise exception 'No autorizado';
  end if;

  if p_qty < 0 then
    raise exception 'El stock no puede ser negativo.';
  end if;

  if not exists (select 1 from public.products where id = p_id) then
    raise exception 'No encontramos ese producto.';
  end if;

  select coalesce(sum(qty), 0) into current_qty
  from public.stock_movements
  where product_id = p_id;

  delta := p_qty - current_qty;
  if delta = 0 then
    return;
  end if;

  insert into public.stock_movements (
    product_id, kind, qty, occurred_on
  )
  values (
    p_id, 'adjustment', delta, current_date
  );
end;
$$;

grant execute on function public.close_ipv(uuid) to authenticated;
grant execute on function public.adjust_product_stock(uuid, numeric) to authenticated;
