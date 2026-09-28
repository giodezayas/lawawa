-- Manager y admin pueden corregir un IPV cerrado. El trabajador no.

create or replace function public.protect_closed_ipv_document()
returns trigger
language plpgsql
as $$
begin
  if current_setting('wawa.bypass_ipv_protect', true) = 'on' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'closed' and not public.is_staff_manager() then
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

  if doc_status = 'closed' and not public.is_staff_manager() then
    raise exception 'Este IPV ya está cerrado y no se puede editar';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
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
begin
  if p_line.sold_qty <> 0 then
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

    select * into pack
    from public.product_packs
    where packed_product_id = p_line.product_id;

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

create or replace function public.sync_closed_ipv_line_stock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  doc public.ipv_documents;
begin
  if tg_op = 'DELETE' then
    return old;
  end if;

  if current_setting('wawa.bypass_ipv_protect', true) = 'on' then
    return new;
  end if;

  select * into doc from public.ipv_documents where id = new.ipv_id;
  if doc.status = 'closed' then
    perform public.apply_ipv_line_stock(new, doc.work_date);
  end if;

  return new;
end;
$$;

drop trigger if exists ipv_lines_sync_closed_stock on public.ipv_lines;
create trigger ipv_lines_sync_closed_stock
  after insert or update on public.ipv_lines
  for each row execute function public.sync_closed_ipv_line_stock();

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
    perform public.apply_ipv_line_stock(line, doc.work_date);
  end loop;

  update public.ipv_documents
  set
    status = 'closed',
    closed_by = auth.uid(),
    closed_at = now()
  where id = p_id;
end;
$$;
