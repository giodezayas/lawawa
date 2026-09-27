-- Salida != venta. El trabajador anota vendidos; el stock final se calcula.

alter table public.ipv_lines drop column if exists sale_total;
alter table public.ipv_lines drop column if exists gross_profit;
alter table public.ipv_lines drop column if exists sold_qty;

alter table public.ipv_lines
  add column sold_qty numeric(12, 3) not null default 0;

alter table public.ipv_lines drop column if exists closing_qty;

alter table public.ipv_lines
  add column closing_qty numeric(12, 3) generated always as
    (opening_qty + inbound_qty - outbound_qty - sold_qty) stored;

alter table public.ipv_lines
  add column sale_total numeric(12, 2) generated always as
    (round(sold_qty * sale_price, 2)) stored;

alter table public.ipv_lines
  add column gross_profit numeric(12, 2) generated always as
    (round(sold_qty * (sale_price - replenishment_cost), 2)) stored;
