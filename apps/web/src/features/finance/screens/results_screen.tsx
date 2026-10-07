import {
  DomainError,
  PeriodReport,
  User,
  defaultBillingPeriod,
  formatDateOnly,
  formatMoney,
  shiftCalendarMonth,
} from '@wawa/domain';
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { useConfirm } from '../../../shared/ui/confirm_dialog';
import { PrimaryButton } from '../../../shared/ui/primary_button';
import { moneyTone } from '../../../shared/ui/money_tone';
import { ExportButtons } from '../../../shared/ui/export_buttons';

export function ResultsScreen() {
  const { container, user } = useAuth();
  const confirm = useConfirm();
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [report, setReport] = useState<PeriodReport | null>(null);
  const [pageError, setPageError] = useState('');
  const [closing, setClosing] = useState(false);

  const canManage = user ? User.canManageStaff(user) : false;

  async function load(nextFrom = from, nextTo = to) {
    setReport(await container.getPeriodReport.execute(nextFrom, nextTo));
  }

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
      .then((next) => {
        if (!cancelled) {
          setReport(next);
        }
      })
      .catch((error) => {
        if (cancelled) {
          return;
        }
        setPageError(error instanceof DomainError ? error.message : 'No se pudo armar el corte.');
      });
    return () => {
      cancelled = true;
    };
  }, [container, from, to]);

  async function closePeriod() {
    if (
      !(await confirm({
        title: 'Cerrar Período',
        message: '¿Cerrar este período de facturación? No se podrán editar gastos ni IPV de esas fechas.',
        confirmLabel: 'Cerrar',
      }))
    ) {
      return;
    }
    setClosing(true);
    setPageError('');
    try {
      await container.closeBillingPeriod.execute(from, to);
      await load();
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo cerrar el período.');
    } finally {
      setClosing(false);
    }
  }

  function shift(direction: number) {
    if (!from || !to) {
      return;
    }
    const next = shiftCalendarMonth(from, direction);
    setFrom(next.from);
    setTo(next.to);
  }

  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold">Resultados</h1>
          <p className="mt-1 text-sm text-muted">
            El rango por defecto es el día 1 de este mes hasta hoy.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {report ? (
            <ExportButtons
              title={`Resultados ${from} ${to}`}
              fileName={`resultados_${from}_${to}`}
              columns={['Concepto', 'Importe']}
              rows={[
                ['Venta', formatMoney(report.saleTotal)],
                ['Invertido', formatMoney(report.purchaseTotal)],
                [`Ganancia Bruta`, formatMoney(report.grossProfit)],
                ['Gastos', formatMoney(report.expenseTotal)],
                ['Utilidad', formatMoney(report.utilidad)],
                ['Impuestos A Pagar', formatMoney(report.tax)],
                ['Te Quedas', formatMoney(report.net)],
                ...report.lines.map((line) => [line.name, formatMoney(line.amount)]),
              ]}
            />
          ) : null}
          {report?.closed ? (
            <p className="text-sm font-semibold text-danger">Período Cerrado</p>
          ) : canManage ? (
            <PrimaryButton type="button" className="page-cta" loading={closing} loadingLabel="Cerrando..." onClick={() => void closePeriod()}>
              Cerrar Período
            </PrimaryButton>
          ) : null}
        </div>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <button type="button" className="btn-outline h-10 rounded-2xl px-4 text-sm font-semibold" onClick={() => shift(-1)}>
          Anterior
        </button>
        <p className="text-sm font-semibold">
          {formatDateOnly(from)} — {formatDateOnly(to)}
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
      {!report ? (
        pageError ? null : <p className="text-sm text-muted">Cargando Corte...</p>
      ) : (
        <>
          <section className="space-y-3">
            <h2 className="text-sm font-semibold text-primary">Ventas</h2>
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              <article className="rounded-3xl border border-line bg-white px-5 py-4">
                <p className="text-sm font-medium text-muted">Venta</p>
                <p className="mt-1 text-right text-2xl font-extrabold">{formatMoney(report.saleTotal)}</p>
              </article>
              <article className="rounded-3xl border border-line bg-white px-5 py-4">
                <p className="text-sm font-medium text-muted">Invertido</p>
                <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(report.purchaseTotal)}</p>
              </article>
              <article className="rounded-3xl border border-line bg-white px-5 py-4">
                <p className="text-sm font-medium text-muted">Ganancia Bruta</p>
                <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(report.grossProfit)}`}>
                  {formatMoney(report.grossProfit)}
                </p>
              </article>
            </div>
          </section>
          <section className="space-y-3">
            <div className="flex flex-wrap items-end justify-between gap-3">
              <h2 className="text-sm font-semibold text-primary">Gastos Del Corte</h2>
              <Link to="/finanzas/gastos" className="text-sm font-semibold text-primary">
                Ver Lista
              </Link>
            </div>
            <article className="rounded-3xl border border-line bg-white px-5 py-4 sm:max-w-sm">
              <p className="text-sm font-medium text-muted">Total</p>
              <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(report.expenseTotal)}</p>
            </article>
            <div className="overflow-x-auto rounded-3xl border border-line bg-surface">
              <table className="min-w-full text-sm">
                <thead>
                  <tr className="border-b border-line text-left">
                    <th className="px-4 py-3 font-semibold">Desde</th>
                    <th className="px-4 py-3 font-semibold">Concepto</th>
                    <th className="px-4 py-3 font-semibold">Frecuencia</th>
                    <th className="px-4 py-3 text-right font-semibold">Importe En El Corte</th>
                  </tr>
                </thead>
                <tbody>
                  {report.lines.length === 0 ? (
                    <tr>
                      <td colSpan={4} className="px-4 py-8 text-center text-muted">
                        Este corte no tiene gastos.
                      </td>
                    </tr>
                  ) : (
                    report.lines.map((line) => (
                      <tr key={line.categoryId} className="border-t border-line">
                        <td className="px-4 py-3">{formatDateOnly(line.occurredOn)}</td>
                        <td className="px-4 py-3">
                          <Link to={`/finanzas/gastos/${line.categoryId}`} className="font-semibold text-primary">
                            {line.name}
                          </Link>
                        </td>
                        <td className="px-4 py-3">{PeriodReport.cadenceLabel(line.cadence)}</td>
                        <td className="px-4 py-3 text-right text-danger">{formatMoney(line.amount)}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </section>
          <section className="space-y-3">
            <div className="flex flex-wrap items-end justify-between gap-3">
              <h2 className="text-sm font-semibold text-primary">Impuesto Y Lo Que Te Quedas</h2>
              <Link to="/finanzas/impuestos" className="text-sm font-semibold text-primary">
                Ver Impuestos
              </Link>
            </div>
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              <article className="rounded-3xl border border-line bg-white px-5 py-4">
                <p className="text-sm font-medium text-muted">Utilidad</p>
                <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(report.utilidad)}`}>
                  {formatMoney(report.utilidad)}
                </p>
              </article>
              <article className="rounded-3xl border border-line bg-white px-5 py-4">
                <p className="text-sm font-medium text-muted">Impuestos A Pagar</p>
                <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(report.tax)}</p>
              </article>
              <article className="rounded-3xl border border-line bg-white px-5 py-4">
                <p className="text-sm font-medium text-muted">Te Quedas</p>
                <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(report.net)}`}>
                  {formatMoney(report.net)}
                </p>
              </article>
            </div>
          </section>
        </>
      )}
    </div>
  );
}
