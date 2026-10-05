-- El mes en curso siempre es día 1 hasta hoy.

update public.business_settings
set
  billing_period_live = true,
  billing_period_from = (date_trunc('month', current_date))::date,
  billing_period_to = current_date;
