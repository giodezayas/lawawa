-- Período de facturación manual (desde / hasta) para no perder compras fuera del mes.

alter table public.business_settings
  add column if not exists billing_period_from date;

alter table public.business_settings
  add column if not exists billing_period_to date;

update public.business_settings
set
  billing_period_from = coalesce(billing_period_from, date '2026-08-31'),
  billing_period_to = coalesce(billing_period_to, current_date);

alter table public.business_settings
  alter column billing_period_from set default date '2026-08-31';

alter table public.business_settings
  alter column billing_period_to set default current_date;

alter table public.business_settings
  alter column billing_period_from set not null;

alter table public.business_settings
  alter column billing_period_to set not null;

alter table public.business_settings
  drop constraint if exists business_settings_billing_period_range_valid;

alter table public.business_settings
  add constraint business_settings_billing_period_range_valid
  check (billing_period_to >= billing_period_from);
