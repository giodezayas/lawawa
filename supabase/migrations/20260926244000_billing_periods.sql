-- Período de facturación (día 1 o del 20 al 20) + frecuencia de gasto + cierre del corte.

alter table public.business_settings
  add column if not exists billing_start_day smallint not null default 1;

alter table public.business_settings
  drop constraint if exists business_settings_billing_start_day_valid;

alter table public.business_settings
  add constraint business_settings_billing_start_day_valid
  check (billing_start_day between 1 and 28);

alter table public.expense_entries
  add column if not exists cadence text not null default 'once';

alter table public.expense_entries
  drop constraint if exists expense_entries_cadence_valid;

alter table public.expense_entries
  add constraint expense_entries_cadence_valid
  check (cadence in ('once', 'daily', 'weekly', 'monthly'));

create table if not exists public.billing_period_closes (
  period_from date not null,
  period_to date not null,
  closed_by uuid not null references public.profiles (id),
  closed_at timestamptz not null default now(),
  primary key (period_from, period_to),
  constraint billing_period_closes_range_valid check (period_to >= period_from)
);

alter table public.billing_period_closes enable row level security;

drop policy if exists billing_period_closes_select_internal on public.billing_period_closes;
create policy billing_period_closes_select_internal
  on public.billing_period_closes
  for select
  to authenticated
  using (public.is_active_internal_user());

create or replace function public.date_in_closed_billing_period(p_date date)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.billing_period_closes
    where p_date between period_from and period_to
  );
$$;

create or replace function public.forbid_closed_billing_date()
returns trigger
language plpgsql
as $$
declare
  check_date date;
begin
  if tg_table_name = 'expense_entries' then
    check_date := case when tg_op = 'DELETE' then old.occurred_on else new.occurred_on end;
  else
    check_date := case when tg_op = 'DELETE' then old.work_date else new.work_date end;
  end if;

  if public.date_in_closed_billing_period(check_date) then
    raise exception 'Ese período de facturación ya está cerrado.';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists expense_entries_forbid_closed_period on public.expense_entries;
create trigger expense_entries_forbid_closed_period
  before insert or update or delete on public.expense_entries
  for each row execute function public.forbid_closed_billing_date();

drop trigger if exists ipv_documents_forbid_closed_period on public.ipv_documents;
create trigger ipv_documents_forbid_closed_period
  before insert or update or delete on public.ipv_documents
  for each row execute function public.forbid_closed_billing_date();

create or replace function public.close_billing_period(p_from date, p_to date)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff_manager() then
    raise exception 'No autorizado';
  end if;

  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'El rango de fechas no es válido.';
  end if;

  if exists (
    select 1
    from public.ipv_documents
    where work_date between p_from and p_to
      and status = 'open'
  ) then
    raise exception 'Cierra los IPV abiertos de este período primero.';
  end if;

  insert into public.billing_period_closes (period_from, period_to, closed_by)
  values (p_from, p_to, auth.uid())
  on conflict (period_from, period_to) do nothing;
end;
$$;

create or replace function public.period_report(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  days int;
  tax_rate numeric(6, 4) := 0.25;
  sale_total numeric(12, 2);
  gross_profit numeric(12, 2);
  expense_total numeric(12, 2) := 0;
  utilidad numeric(12, 2);
  tax_amount numeric(12, 2);
  lines jsonb := '[]'::jsonb;
  entry public.expense_entries;
  overlap_from date;
  overlap_to date;
  overlap_days int;
  line_amount numeric(12, 2);
  line_source text;
  closed boolean;
begin
  if not public.is_active_internal_user() then
    raise exception 'No autorizado';
  end if;

  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'El rango de fechas no es válido.';
  end if;

  days := (p_to - p_from) + 1;

  select exists (
    select 1
    from public.billing_period_closes
    where period_from = p_from
      and period_to = p_to
  ) into closed;

  select
    coalesce(sum(line.sale_total), 0),
    coalesce(sum(line.gross_profit), 0)
  into sale_total, gross_profit
  from public.ipv_lines line
  join public.ipv_documents doc on doc.id = line.ipv_id
  where doc.work_date between p_from and p_to;

  for entry in
    select * from public.expense_entries
    where occurred_on <= p_to
    order by occurred_on, name
  loop
    line_amount := 0;
    line_source := 'entry';

    if entry.cadence = 'once' then
      if entry.occurred_on between p_from and p_to then
        line_amount := entry.amount;
      end if;
    else
      overlap_from := greatest(p_from, entry.occurred_on);
      overlap_to := p_to;
      if overlap_from <= overlap_to then
        overlap_days := (overlap_to - overlap_from) + 1;
        line_source := 'accrual';
        if entry.cadence = 'daily' then
          line_amount := round(entry.amount * overlap_days, 2);
        elsif entry.cadence = 'weekly' then
          line_amount := round(entry.amount * overlap_days / 7.0, 2);
        else
          line_amount := entry.amount;
        end if;
      end if;
    end if;

    if line_amount <> 0 then
      expense_total := expense_total + line_amount;
      lines := lines || jsonb_build_array(jsonb_build_object(
        'category_id', entry.id,
        'name', entry.name,
        'kind', 'variable',
        'cadence', entry.cadence,
        'source', line_source,
        'occurred_on', entry.occurred_on,
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
    'closed', closed,
    'lines', lines
  );
end;
$$;

grant execute on function public.date_in_closed_billing_period(date) to authenticated;
grant execute on function public.close_billing_period(date, date) to authenticated;
grant execute on function public.period_report(date, date) to authenticated;
