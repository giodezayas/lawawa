-- Gastos fijos/variables y corte semanal o mensual.
-- Utilidad = ganancia bruta IPV - gastos. Impuesto 25% sobre utilidad positiva.

alter table public.business_settings
  add column if not exists tax_rate numeric(6, 4) not null default 0.25;

update public.business_settings
set tax_rate = 0.25
where tax_rate is null or tax_rate = 0;

create table if not exists public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text not null,
  cadence text not null,
  default_amount numeric(12, 2) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expense_categories_name_unique unique (name),
  constraint expense_categories_kind_valid check (kind in ('fixed', 'variable')),
  constraint expense_categories_cadence_valid check (cadence in ('daily', 'weekly', 'monthly', 'none')),
  constraint expense_categories_amount_non_negative check (default_amount >= 0)
);

create table if not exists public.expense_entries (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.expense_categories (id),
  occurred_on date not null,
  amount numeric(12, 2) not null,
  notes text not null default '',
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint expense_entries_amount_non_negative check (amount >= 0)
);

drop trigger if exists expense_categories_set_updated_at on public.expense_categories;
create trigger expense_categories_set_updated_at
  before update on public.expense_categories
  for each row execute function public.set_updated_at();

insert into public.expense_categories (name, kind, cadence, default_amount)
values
  ('Comunales', 'fixed', 'monthly', 4200),
  ('Salario', 'fixed', 'daily', 1500),
  ('Tenedor De Libros', 'variable', 'none', 0),
  ('Transporte', 'variable', 'none', 0),
  ('Inspectores', 'variable', 'none', 0),
  ('Otros', 'variable', 'none', 0)
on conflict (name) do nothing;

create or replace function public.period_report(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  days int;
  tax_rate numeric(6, 4);
  sale_total numeric(12, 2);
  gross_profit numeric(12, 2);
  expense_total numeric(12, 2) := 0;
  utilidad numeric(12, 2);
  tax_amount numeric(12, 2);
  lines jsonb := '[]'::jsonb;
  category public.expense_categories;
  recorded numeric(12, 2);
  accrued numeric(12, 2);
  line_amount numeric(12, 2);
  line_source text;
  month_days numeric;
begin
  if not public.is_active_internal_user() then
    raise exception 'No autorizado';
  end if;

  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'El rango de fechas no es válido.';
  end if;

  days := (p_to - p_from) + 1;
  month_days := extract(day from (date_trunc('month', p_from) + interval '1 month - 1 day'));

  select coalesce(max(bs.tax_rate), 0.25) into tax_rate
  from public.business_settings bs;

  select
    coalesce(sum(line.sale_total), 0),
    coalesce(sum(line.gross_profit), 0)
  into sale_total, gross_profit
  from public.ipv_lines line
  join public.ipv_documents doc on doc.id = line.ipv_id
  where doc.work_date between p_from and p_to;

  for category in
    select * from public.expense_categories
    where is_active
    order by name
  loop
    select coalesce(sum(amount), 0) into recorded
    from public.expense_entries
    where category_id = category.id
      and occurred_on between p_from and p_to;

    if category.cadence = 'none' then
      line_amount := recorded;
      line_source := 'entry';
    elsif recorded > 0 then
      line_amount := recorded;
      line_source := 'entry';
    else
      if category.cadence = 'daily' then
        accrued := round(category.default_amount * days, 2);
      elsif category.cadence = 'weekly' then
        accrued := round(category.default_amount * days / 7.0, 2);
      else
        accrued := round(category.default_amount * days / nullif(month_days, 0), 2);
      end if;
      line_amount := accrued;
      line_source := 'accrual';
    end if;

    if line_amount <> 0 then
      expense_total := expense_total + line_amount;
      lines := lines || jsonb_build_array(jsonb_build_object(
        'category_id', category.id,
        'name', category.name,
        'kind', category.kind,
        'cadence', category.cadence,
        'source', line_source,
        'amount', line_amount
      ));
    end if;
  end loop;

  utilidad := round(gross_profit - expense_total, 2);
  tax_amount := round(greatest(utilidad, 0) * tax_rate, 2);

  return jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'days', days,
    'tax_rate', tax_rate,
    'sale_total', sale_total,
    'gross_profit', gross_profit,
    'expense_total', expense_total,
    'utilidad', utilidad,
    'tax', tax_amount,
    'net', round(utilidad - tax_amount, 2),
    'lines', lines
  );
end;
$$;

alter table public.expense_categories enable row level security;
alter table public.expense_entries enable row level security;

drop policy if exists expense_categories_all_internal on public.expense_categories;
create policy expense_categories_all_internal
  on public.expense_categories
  for all
  to authenticated
  using (public.is_active_internal_user())
  with check (public.is_active_internal_user());

drop policy if exists expense_entries_all_internal on public.expense_entries;
create policy expense_entries_all_internal
  on public.expense_entries
  for all
  to authenticated
  using (public.is_active_internal_user())
  with check (public.is_active_internal_user());

drop policy if exists business_settings_update_internal on public.business_settings;
create policy business_settings_update_internal
  on public.business_settings
  for update
  to authenticated
  using (public.is_staff_manager())
  with check (public.is_staff_manager());

grant execute on function public.period_report(date, date) to authenticated;
