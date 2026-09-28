-- Costos reales de sazón. Ganancia = venta − costo de reposición.

do $$
declare
  rec record;
begin
  perform set_config('wawa.bypass_ipv_protect', 'on', true);

  for rec in
    select *
    from (
      values
        ('Sazón Mina', 38::numeric, 158::numeric),
        ('Sazón Tropical Verde', 48, 100),
        ('Sazón Tropical Naranja', 48, 100)
    ) as v(name, correct_cost, wrong_cost)
  loop
    if not exists (select 1 from public.products where name = rec.name) then
      raise exception 'No está % en el catálogo.', rec.name;
    end if;

    update public.purchase_lines line
    set unit_cost = rec.correct_cost
    from public.products p
    where line.product_id = p.id
      and p.name = rec.name
      and line.unit_cost = rec.wrong_cost;

    update public.products
    set purchase_price = rec.correct_cost, replenishment_cost = rec.correct_cost
    where name = rec.name;

    update public.ipv_lines
    set replenishment_cost = rec.correct_cost
    where product_id = (select id from public.products where name = rec.name);

    perform public.refresh_product_cost((select id from public.products where name = rec.name));
  end loop;
end $$;
