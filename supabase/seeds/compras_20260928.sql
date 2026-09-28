-- Compras 28 sep 2026. Efectivo. Idempotente por producto+día.
-- 2 compras además del pan: Aceite 12 × 2362.50 = 28350 (venta 3000).
-- Jabón Harmony 70g 100 × 310 (venta 370).
-- Pan: 9 Pan Bon × 400 (venta 480) y 4 Pan De Hamburguesa × 430 (venta 500).

do $$
declare
  actor uuid;
  doc uuid;
  work date := date '2026-09-28';
begin
  select id into actor
    from public.profiles
    order by case when email ilike '%gdzayas%' then 0 else 1 end, created_at
    limit 1;

  if actor is null then
    raise exception 'No hay usuario en profiles para created_by.';
  end if;

  insert into public.products (name, sale_price, purchase_price, replenishment_cost, min_stock, is_active)
  values
    ('Aceite', 3000, 2362.50, 2362.50, 0, true),
    ('Jabón Harmony 70g', 370, 310, 310, 0, true),
    ('Pan Bon', 480, 400, 400, 0, true),
    ('Pan De Hamburguesa', 500, 430, 430, 0, true)
  on conflict (name) do update set
    sale_price = excluded.sale_price,
    purchase_price = excluded.purchase_price,
    replenishment_cost = excluded.replenishment_cost,
    is_active = true;

  delete from public.purchase_lines line
  using public.purchase_documents d, public.products p
  where line.purchase_id = d.id
    and line.product_id = p.id
    and d.purchased_on = work
    and p.name = 'Jabón Kare 75g';

  delete from public.purchase_documents d
  where d.purchased_on = work
    and not exists (
      select 1 from public.purchase_lines line where line.purchase_id = d.id
    );

  update public.products
  set sale_price = 300, purchase_price = 240, replenishment_cost = 240
  where name = 'Jabón Kare 75g';

  if not exists (
    select 1
    from public.purchase_lines line
    join public.purchase_documents d on d.id = line.purchase_id
    join public.products p on p.id = line.product_id
    where d.purchased_on = work
      and p.name = 'Aceite'
  ) then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (work, 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, 12, 2362.50
    from public.products p
    where p.name = 'Aceite';
  end if;

  if not exists (
    select 1
    from public.purchase_lines line
    join public.purchase_documents d on d.id = line.purchase_id
    join public.products p on p.id = line.product_id
    where d.purchased_on = work
      and p.name = 'Jabón Harmony 70g'
  ) then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (work, 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, 100, 310
    from public.products p
    where p.name = 'Jabón Harmony 70g';
  end if;

  if not exists (
    select 1
    from public.purchase_lines line
    join public.purchase_documents d on d.id = line.purchase_id
    join public.products p on p.id = line.product_id
    where d.purchased_on = work
      and p.name in ('Pan Bon', 'Pan De Hamburguesa')
  ) then
    insert into public.purchase_documents (purchased_on, payment_method, created_by)
    values (work, 'cash', actor)
    returning id into doc;

    insert into public.purchase_lines (purchase_id, product_id, qty, unit_cost)
    select doc, p.id, v.qty, v.unit_cost
    from (
      values
        ('Pan Bon', 9::numeric, 400::numeric),
        ('Pan De Hamburguesa', 4, 430)
    ) as v(name, qty, unit_cost)
    join public.products p on p.name = v.name;
  end if;
end $$;
