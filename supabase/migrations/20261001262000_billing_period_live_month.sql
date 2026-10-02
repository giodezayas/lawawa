-- Período vivo: día 1 del mes actual hasta hoy, salvo que lo fijen a mano.

alter table public.business_settings
  add column if not exists billing_period_live boolean not null default true;

update public.business_settings
set
  billing_period_live = true,
  billing_period_from = (date_trunc('month', current_date))::date,
  billing_period_to = current_date;

alter table public.business_settings
  alter column billing_period_from set default (date_trunc('month', current_date))::date;

alter table public.business_settings
  alter column billing_period_to set default current_date;
