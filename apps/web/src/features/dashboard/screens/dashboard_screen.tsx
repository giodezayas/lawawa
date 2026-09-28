import {
  DomainError,
  DashboardStats,
  FIXED_TAX_RATE,
  User,
  CardLedger,
  type CashFlow,
  PeriodReport,
  Product,
  formatDateOnly,
  formatMoney,
  todayIsoDate,
} from '@wawa/domain';
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { CashFlowSummary } from '../../../shared/ui/cash_flow_summary';
import { moneyTone } from '../../../shared/ui/money_tone';
import { PrimaryButton } from '../../../shared/ui/primary_button';
import { TextField } from '../../../shared/ui/text_field';

export function DashboardScreen() {
  const { container, user } = useAuth();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [month, setMonth] = useState<PeriodReport | null>(null);
  const [todayFlow, setTodayFlow] = useState<CashFlow | null>(null);
  const [periodFlow, setPeriodFlow] = useState<CashFlow | null>(null);
  const [cards, setCards] = useState<ReturnType<typeof CardLedger.from> | null>(null);
  const [lowStock, setLowStock] = useState<Product[]>([]);
  const [pageError, setPageError] = useState('');
  const [periodFrom, setPeriodFrom] = useState(todayIsoDate());
  const [periodTo, setPeriodTo] = useState(todayIsoDate());
  const [savingPeriod, setSavingPeriod] = useState(false);
  const canManage = user ? User.canManageStaff(user) : false;

  async function load(from?: string, to?: string) {
    const period = from && to ? { from, to } : await container.getBillingPeriod.execute();
    setPeriodFrom(period.from);
    setPeriodTo(period.to);
    const today = todayIsoDate();
      const [nextStats, products, monthReport, todayCash, periodCash, ipvs, opening] = await Promise.all([
        container.getDashboardStats.execute(),
        container.listProducts.execute(),
        container.getPeriodReport.execute(period.from, period.to),
        container.getCashFlow.execute(today, today),
        container.getCashFlow.execute(period.from, period.to),
        container.listIpvs.execute(),
        container.getCardOpening.execute(),
      ]);
      const ledgerTo = opening && opening.asOf > period.to ? opening.asOf : period.to;
      const moveFrom = opening && opening.asOf < period.from ? opening.asOf : period.from;
      const moves = opening
        ? await container.listCashMoves.execute(moveFrom, ledgerTo)
        : [];
      setStats(nextStats);
      setLowStock(products.filter((product) => Product.isLowStock(product)));
      setMonth(monthReport);
      setTodayFlow(todayCash);
      setPeriodFlow(periodCash);
      setCards(CardLedger.from(ipvs, moves, period.from, period.to, opening));
  }

  useEffect(() => {
    void load().catch((error) => {
      setPageError(error instanceof DomainError ? error.message : 'No se pudieron cargar las estadísticas.');
    });
  }, [container]);

  async function savePeriod() {
    setSavingPeriod(true);
    setPageError('');
    try {
      const saved = await container.setBillingPeriod.execute(periodFrom, periodTo);
      await load(saved.from, saved.to);
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo guardar el período.');
    } finally {
      setSavingPeriod(false);
    }
  }

  const taxPercent = Math.round(FIXED_TAX_RATE * 100);

  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm font-semibold text-primary">Hoy</p>
          <h1 className="text-2xl font-extrabold">Inicio</h1>
        </div>
        <Link to="/finanzas/resultados" className="page-cta btn-primary inline-flex h-12 items-center rounded-2xl px-5 text-sm font-semibold">
          Ver Resultados
        </Link>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
      <section className="space-y-3 rounded-3xl border border-line bg-white px-5 py-4">
        <h2 className="text-sm font-semibold text-primary">Período De Trabajo</h2>
        <p className="text-sm text-muted">
          Caja, resultados e impuestos usan estas fechas. Así no se pierde el 31 de agosto u otros días fuera del mes.
        </p>
        <div className="grid gap-3 sm:grid-cols-2">
          <TextField
            label="Desde *"
            type="date"
            value={periodFrom}
            onChange={(event) => setPeriodFrom(event.target.value)}
            disabled={!canManage}
          />
          <TextField
            label="Hasta *"
            type="date"
            value={periodTo}
            onChange={(event) => setPeriodTo(event.target.value)}
            disabled={!canManage}
          />
        </div>
        {canManage ? (
          <PrimaryButton type="button" loading={savingPeriod} onClick={() => void savePeriod()}>
            Guardar Período
          </PrimaryButton>
        ) : null}
      </section>
      {!stats ? (
        pageError ? null : <p className="text-sm text-muted">Cargando Estadísticas...</p>
      ) : (
        <>
          <section className="space-y-3">
            <h2 className="text-sm font-semibold text-primary">Operación De Hoy</h2>
            <div className="grid gap-3 sm:grid-cols-3">
              <article className="rounded-3xl border border-line bg-white px-5 py-4">
                <p className="text-sm font-medium text-muted">Venta</p>
                <p className="mt-1 text-right text-2xl font-extrabold">{formatMoney(stats.saleToday)}</p>
              </article>
              <article className="rounded-3xl border border-line bg-white px-5 py-4">
                <p className="text-sm font-medium text-muted">Ganancia Bruta</p>
                <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(stats.profitToday)}`}>
                  {formatMoney(stats.profitToday)}
                </p>
              </article>
              <article className="rounded-3xl border border-line bg-white px-5 py-4">
                <p className="text-sm font-medium text-muted">IPV</p>
                <p className="mt-1 text-2xl font-extrabold">{DashboardStats.ipvTodayLabel(stats.ipvTodayStatus)}</p>
              </article>
            </div>
          </section>
          {todayFlow ? <CashFlowSummary flow={todayFlow} title="Caja De Hoy" /> : null}
          {periodFlow ? (
            <CashFlowSummary
              flow={periodFlow}
              title={`Caja Del Período${month ? ` · ${formatDateOnly(month.from)} — ${formatDateOnly(month.to)}` : ''}`}
            />
          ) : null}
          {cards ? (
            <section className="space-y-3">
              <div className="flex flex-wrap items-end justify-between gap-3">
                <h2 className="text-sm font-semibold text-primary">Tarjetas</h2>
                <Link to="/finanzas/tarjetas" className="text-sm font-semibold text-primary">
                  Manejar Tarjetas
                </Link>
              </div>
              <div className="grid gap-3 sm:grid-cols-2">
                <article className="rounded-3xl border-2 border-accent bg-white px-5 py-4">
                  <p className="text-sm font-medium text-muted">Tarjeta P</p>
                  <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(cards.p.balance)}`}>
                    {formatMoney(cards.p.balance)}
                  </p>
                  <p className="mt-2 text-right text-xs text-muted">
                    Inicial {formatMoney(cards.p.opening)} · Recibido {formatMoney(cards.p.received)} · Extraído{' '}
                    {formatMoney(cards.p.withdrawn)}
                  </p>
                </article>
                <article className="rounded-3xl border-2 border-accent bg-white px-5 py-4">
                  <p className="text-sm font-medium text-muted">Tarjeta F</p>
                  <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(cards.f.balance)}`}>
                    {formatMoney(cards.f.balance)}
                  </p>
                  <p className="mt-2 text-right text-xs text-muted">
                    Inicial {formatMoney(cards.f.opening)} · Recibido {formatMoney(cards.f.received)} · Extraído{' '}
                    {formatMoney(cards.f.withdrawn)}
                  </p>
                </article>
              </div>
            </section>
          ) : null}
          {month ? (
            <section className="space-y-3">
              <h2 className="text-sm font-semibold text-primary">
                Este Período{month ? ` · ${formatDateOnly(month.from)} — ${formatDateOnly(month.to)}` : ''} · Impuesto {taxPercent}%
              </h2>
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                <article className="rounded-3xl border border-line bg-white px-5 py-4">
                  <p className="text-sm font-medium text-muted">Venta Del Período</p>
                  <p className="mt-1 text-right text-2xl font-extrabold">{formatMoney(month.saleTotal)}</p>
                </article>
                <article className="rounded-3xl border border-line bg-white px-5 py-4">
                  <p className="text-sm font-medium text-muted">Invertido</p>
                  <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(month.purchaseTotal)}</p>
                </article>
                <article className="rounded-3xl border border-line bg-white px-5 py-4">
                  <p className="text-sm font-medium text-muted">Venta Vs Invertido</p>
                  <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(PeriodReport.vsInvested(month))}`}>
                    {formatMoney(PeriodReport.vsInvested(month))}
                  </p>
                </article>
                <article className="rounded-3xl border border-line bg-white px-5 py-4">
                  <p className="text-sm font-medium text-muted">Impuestos A Pagar</p>
                  <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(month.tax)}</p>
                </article>
                <article className="rounded-3xl border border-line bg-white px-5 py-4">
                  <p className="text-sm font-medium text-muted">Te Quedas</p>
                  <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(month.net)}`}>
                    {formatMoney(month.net)}
                  </p>
                </article>
              </div>
            </section>
          ) : null}
          {lowStock.length > 0 ? (
            <section className="space-y-3">
              <h2 className="text-sm font-semibold text-primary">Bajo Stock</h2>
              <div className="overflow-x-auto rounded-3xl border border-line bg-white">
                <table className="min-w-full text-sm">
                  <thead>
                    <tr className="border-b border-line text-left">
                      <th className="px-4 py-3 font-semibold">Producto</th>
                      <th className="px-4 py-3 text-right font-semibold">Stock</th>
                      <th className="px-4 py-3 text-right font-semibold">Mínimo</th>
                    </tr>
                  </thead>
                  <tbody>
                    {lowStock.map((product) => (
                      <tr key={product.id} className="border-t border-line">
                        <td className="px-4 py-3">
                          <Link to={`/inventario/productos/${product.id}`} className="font-semibold text-primary">
                            {product.name}
                          </Link>
                        </td>
                        <td className="px-4 py-3 text-right">{product.stockQty}</td>
                        <td className="px-4 py-3 text-right">{product.minStock}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          ) : null}
        </>
      )}
    </div>
  );
}
