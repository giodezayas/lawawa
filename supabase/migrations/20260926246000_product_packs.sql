-- Embolsar (azúcar 1 lb / 1 kg) descuenta del saco al cerrar el IPV.

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
      'ipv_pack',
      'adjustment'
    )
  );

create table if not exists public.product_packs (
  packed_product_id uuid primary key references public.products (id) on delete cascade,
  bulk_product_id uuid not null references public.products (id) on delete restrict,
  bulk_qty numeric(12, 3) not null check (bulk_qty > 0)
);

alter table public.product_packs enable row level security;

drop policy if exists product_packs_select_internal on public.product_packs;
create policy product_packs_select_internal
  on public.product_packs
  for select
  to authenticated
  using (public.is_active_internal_user());

grant select on public.product_packs to authenticated;

insert into public.product_packs (packed_product_id, bulk_product_id, bulk_qty)
select packed.id, bulk.id, v.bulk_qty
from (
  values
    ('Azúcar 1 lb', 'Azúcar Saco 25 kg', 1::numeric),
    ('Azúcar 1 kg', 'Azúcar Saco 25 kg', 2.2)
) as v(packed_name, bulk_name, bulk_qty)
join public.products packed on packed.name = v.packed_name
join public.products bulk on bulk.name = v.bulk_name
on conflict (packed_product_id) do update set
  bulk_product_id = excluded.bulk_product_id,
  bulk_qty = excluded.bulk_qty;

create or replace function public.close_ipv(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  doc public.ipv_documents;
  line public.ipv_lines;
  pack public.product_packs;
  bulk_left numeric(12, 3);
  consume numeric(12, 3);
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

      select * into pack
      from public.product_packs
      where packed_product_id = line.product_id;

      if pack.packed_product_id is not null then
        consume := line.inbound_qty * pack.bulk_qty;

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
          pack.bulk_product_id,
          'ipv_pack',
          -consume,
          line.replenishment_cost,
          doc.work_date,
          line.id
        )
        on conflict do nothing;
      end if;
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

grant execute on function public.close_ipv(uuid) to authenticated;
