import {
  DomainError,
  DECLARED_MONTHLY_SALARY,
  SALE_TAX_0510122_EXEMPT,
  SALARY_TAX_0520522_EXEMPT,
  defaultBillingPeriod,
  formatDateOnly,
  formatMoney,
  periodTaxes,
  shiftCalendarMonth,
} from '@wawa/domain';
import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../../../app/providers/auth_provider';
import { ExportButtons } from '../../../shared/ui/export_buttons';

export function TaxesScreen() {
  const { container } = useAuth();
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [saleTotal, setSaleTotal] = useState(0);
  const [pageError, setPageError] = useState('');

  useEffect(() => {
    void container.getBillingPeriod
      .execute()
      .then((period) => {
        setFrom(period.from);
        setTo(period.to);
      })
      .catch((error) => {
        setPageError(error instanceof DomainError ? error.message : 'No se pudo cargar el período.');
      });
  }, [container]);

  useEffect(() => {
    if (!from || !to) {
      return;
    }
    let cancelled = false;
    void container.getPeriodReport
      .execute(from, to)
      .then((report) => {
        if (!cancelled) {
          setSaleTotal(report.saleTotal);
        }
      })
      .catch((error) => {
        if (cancelled) {
          return;
        }
        setPageError(error instanceof DomainError ? error.message : 'No se pudo armar el corte de impuestos.');
      });
    return () => {
      cancelled = true;
    };
  }, [container, from, to]);

  function shift(direction: number) {
    if (!from || !to) {
      return;
    }
    const next = shiftCalendarMonth(from, direction);
    setFrom(next.from);
    setTo(next.to);
  }

  const taxes = useMemo(() => periodTaxes(saleTotal), [saleTotal]);

  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold">Impuestos</h1>
          <p className="mt-1 text-sm text-muted">
            Venta del período: 10% (0114022) y 5% sobre la venta menos $ 3,260.00 (0510122). El salario al trabajador
            sigue en $ 1,500.00 al día; a Hacienda se declaran $ 7,000.00 al mes.
          </p>
        </div>
        <ExportButtons
          title={`Impuestos ${from} ${to}`}
          fileName={`impuestos_${from}_${to}`}
          columns={['Tributo', 'Base', 'Importe']}
          rows={[
            ['0114022', formatMoney(saleTotal), formatMoney(taxes.sale.tribute0114022)],
            ['0510122', formatMoney(Math.max(saleTotal - SALE_TAX_0510122_EXEMPT, 0)), formatMoney(taxes.sale.tribute0510122)],
            ['0810132', formatMoney(taxes.salary.declaredSalary), formatMoney(taxes.salary.tribute0810132)],
            ['0820232', formatMoney(taxes.salary.declaredSalary), formatMoney(taxes.salary.tribute0820232)],
            ['0520522', formatMoney(Math.max(taxes.salary.declaredSalary - SALARY_TAX_0520522_EXEMPT, 0)), formatMoney(taxes.salary.tribute0520522)],
            ['Total', '', formatMoney(taxes.total)],
          ]}
        />
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <button type="button" className="btn-outline h-10 rounded-2xl px-4 text-sm font-semibold" onClick={() => shift(-1)}>
          Anterior
        </button>
        <p className="text-sm font-semibold">
          {from && to ? `${formatDateOnly(from)} — ${formatDateOnly(to)}` : 'Cargando...'}
        </p>
        <button type="button" className="btn-outline h-10 rounded-2xl px-4 text-sm font-semibold" onClick={() => shift(1)}>
          Siguiente
        </button>
        <button
          type="button"
          className="btn-outline h-10 rounded-2xl px-4 text-sm font-semibold"
          onClick={() => {
            const live = defaultBillingPeriod();
            setFrom(live.from);
            setTo(live.to);
          }}
        >
          Este Mes
        </button>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
      <section className="space-y-3">
        <h2 className="text-sm font-semibold text-primary">Sobre La Venta</h2>
        <p className="text-sm text-muted">Venta Del Período {formatMoney(saleTotal)}</p>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <article className="rounded-3xl border border-line bg-white px-5 py-4">
            <p className="text-sm font-medium text-muted">0114022 · 10%</p>
            <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(taxes.sale.tribute0114022)}</p>
          </article>
          <article className="rounded-3xl border border-line bg-white px-5 py-4">
            <p className="text-sm font-medium text-muted">0510122 · 5% Menos $ 3,260.00</p>
            <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(taxes.sale.tribute0510122)}</p>
          </article>
          <article className="rounded-3xl border-2 border-accent bg-white px-5 py-4">
            <p className="text-sm font-medium text-muted">Subtotal Venta</p>
            <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(taxes.sale.total)}</p>
          </article>
        </div>
      </section>
      <section className="space-y-3">
        <h2 className="text-sm font-semibold text-primary">Sobre El Salario Declarado</h2>
        <p className="text-sm text-muted">
            Se pagan $ 1,500.00 diarios al trabajador. Declarados {formatMoney(DECLARED_MONTHLY_SALARY)} al mes.
        </p>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <article className="rounded-3xl border border-line bg-white px-5 py-4">
            <p className="text-sm font-medium text-muted">0810132 · 12.5%</p>
            <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(taxes.salary.tribute0810132)}</p>
          </article>
          <article className="rounded-3xl border border-line bg-white px-5 py-4">
            <p className="text-sm font-medium text-muted">0820232 · 5%</p>
            <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(taxes.salary.tribute0820232)}</p>
          </article>
          <article className="rounded-3xl border border-line bg-white px-5 py-4">
            <p className="text-sm font-medium text-muted">0520522 · 3% Menos $ 3,740.00</p>
            <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(taxes.salary.tribute0520522)}</p>
          </article>
          <article className="rounded-3xl border-2 border-accent bg-white px-5 py-4">
            <p className="text-sm font-medium text-muted">Subtotal Salario</p>
            <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(taxes.salary.total)}</p>
          </article>
        </div>
      </section>
      <section className="rounded-3xl border border-line bg-white px-5 py-4">
        <p className="text-sm font-medium text-muted">Total A Pagar</p>
        <p className="mt-1 text-right text-3xl font-extrabold text-danger">{formatMoney(taxes.total)}</p>
      </section>
    </div>
  );
}
