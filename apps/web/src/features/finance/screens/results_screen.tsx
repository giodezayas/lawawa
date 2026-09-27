import {
  DomainError,
  FIXED_TAX_RATE,
  PeriodReport,
  User,
  billingPeriodContaining,
  billingPeriodLabel,
  formatDateOnly,
  formatMoney,
  shiftBillingPeriod,
  todayIsoDate,
} from '@wawa/domain';
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { PrimaryButton } from '../../../shared/ui/primary_button';
import { moneyTone } from '../../../shared/ui/money_tone';

export function ResultsScreen() {
  const { container, user } = useAuth();
  const [startDay, setStartDay] = useState(1);
  const [anchor, setAnchor] = useState(todayIsoDate());
  const [report, setReport] = useState<PeriodReport | null>(null);
  const [pageError, setPageError] = useState('');
  const [savingPeriod, setSavingPeriod] = useState(false);
  const [closing, setClosing] = useState(false);

  const bounds = billingPeriodContaining(anchor, startDay);
  const taxPercent = Math.round(FIXED_TAX_RATE * 100);
  const canManage = user ? User.canManageStaff(user) : false;

  async function load(nextFrom = bounds.from, nextTo = bounds.to) {
    setReport(await container.getPeriodReport.execute(nextFrom, nextTo));
  }

  useEffect(() => {
    void container.getBillingStartDay
      .execute()
      .then((day) => {
        setStartDay(day);
        setAnchor(todayIsoDate());
      })
      .catch((error) => {
        setPageError(error instanceof DomainError ? error.message : 'No se pudo cargar el período.');
      });
  }, [container]);

  useEffect(() => {
    void load().catch((error) => {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo armar el corte.');
    });
  }, [container, bounds.from, bounds.to]);

  async function saveStartDay(day: number) {
    setSavingPeriod(true);
    setPageError('');
    try {
      const saved = await container.setBillingStartDay.execute(day);
      setStartDay(saved);
      setAnchor(todayIsoDate());
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo guardar el período.');
    } finally {
      setSavingPeriod(false);
    }
  }

  async function closePeriod() {
    if (!window.confirm('¿Cerrar este período de facturación? No se podrán editar gastos ni IPV de esas fechas.')) {
      return;
    }
    setClosing(true);
    setPageError('');
    try {
      await container.closeBillingPeriod.execute(bounds.from, bounds.to);
      await load();
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo cerrar el período.');
    } finally {
      setClosing(false);
    }
  }

  function shift(direction: number) {
    const next = shiftBillingPeriod(bounds.from, bounds.to, startDay, direction);
    setAnchor(next.from);
  }

  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold">Resultados</h1>
          <p className="mt-1 text-sm text-muted">
            {billingPeriodLabel(startDay)}. Impuesto fijo {taxPercent}% sobre utilidad positiva.
          </p>
        </div>
        {report?.closed ? (
          <p className="text-sm font-semibold text-danger">Período Cerrado</p>
        ) : canManage ? (
          <PrimaryButton type="button" className="page-cta" loading={closing} loadingLabel="Cerrando..." onClick={() => void closePeriod()}>
            Cerrar Período
          </PrimaryButton>
        ) : null}
      </div>
      {canManage ? (
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            className={`h-12 min-w-[10rem] flex-1 rounded-2xl px-5 text-sm font-semibold sm:flex-none ${startDay === 1 ? 'btn-primary' : 'btn-outline'}`}
            disabled={savingPeriod}
            onClick={() => void saveStartDay(1)}
          >
            Día 1 Al Último
          </button>
          <button
            type="button"
            className={`h-12 min-w-[10rem] flex-1 rounded-2xl px-5 text-sm font-semibold sm:flex-none ${startDay === 20 ? 'btn-primary' : 'btn-outline'}`}
            disabled={savingPeriod}
            onClick={() => void saveStartDay(20)}
          >
            Del 20 Al 20
          </button>
        </div>
      ) : null}
      <div className="flex flex-wrap items-center gap-3">
        <button type="button" className="btn-outline h-10 rounded-2xl px-4 text-sm font-semibold" onClick={() => shift(-1)}>
          Anterior
        </button>
        <p className="text-sm font-semibold">
          {formatDateOnly(bounds.from)} — {formatDateOnly(bounds.to)}
        </p>
        <button type="button" className="btn-outline h-10 rounded-2xl px-4 text-sm font-semibold" onClick={() => shift(1)}>
          Siguiente
        </button>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
      {!report ? (
        pageError ? null : <p className="text-sm text-muted">Cargando Corte...</p>
      ) : (
        <>
          <section className="space-y-3">
            <h2 className="text-sm font-semibold text-primary">Ventas</h2>
            <div className="grid gap-3 sm:grid-cols-2">
              <article className="rounded-3xl border border-line bg-white px-5 py-4">
                <p className="text-sm font-medium text-muted">Venta</p>
                <p className="mt-1 text-right text-2xl font-extrabold">{formatMoney(report.saleTotal)}</p>
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
            <h2 className="text-sm font-semibold text-primary">Impuesto Y Lo Que Te Quedas</h2>
            <div className="grid gap-3 sm:grid-cols-3">
              <article className="rounded-3xl border border-line bg-white px-5 py-4">
                <p className="text-sm font-medium text-muted">Utilidad</p>
                <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(report.utilidad)}`}>
                  {formatMoney(report.utilidad)}
                </p>
              </article>
              <article className="rounded-3xl border border-line bg-white px-5 py-4">
                <p className="text-sm font-medium text-muted">Impuesto {taxPercent}%</p>
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
