import {
  DomainError,
  DashboardStats,
  FIXED_TAX_RATE,
  type CashFlow,
  type PeriodReport,
  Product,
  billingPeriodContaining,
  formatDateOnly,
  formatMoney,
  todayIsoDate,
} from '@wawa/domain';
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { CashFlowSummary } from '../../../shared/ui/cash_flow_summary';
import { moneyTone } from '../../../shared/ui/money_tone';

export function DashboardScreen() {
  const { container } = useAuth();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [month, setMonth] = useState<PeriodReport | null>(null);
  const [todayFlow, setTodayFlow] = useState<CashFlow | null>(null);
  const [periodFlow, setPeriodFlow] = useState<CashFlow | null>(null);
  const [lowStock, setLowStock] = useState<Product[]>([]);
  const [pageError, setPageError] = useState('');

  useEffect(() => {
    void (async () => {
      const startDay = await container.getBillingStartDay.execute();
      const period = billingPeriodContaining(todayIsoDate(), startDay);
      const today = todayIsoDate();
      const [nextStats, products, monthReport, todayCash, periodCash] = await Promise.all([
        container.getDashboardStats.execute(),
        container.listProducts.execute(),
        container.getPeriodReport.execute(period.from, period.to),
        container.getCashFlow.execute(today, today),
        container.getCashFlow.execute(period.from, period.to),
      ]);
      setStats(nextStats);
      setLowStock(products.filter((product) => Product.isLowStock(product)));
      setMonth(monthReport);
      setTodayFlow(todayCash);
      setPeriodFlow(periodCash);
    })().catch((error) => {
      setPageError(error instanceof DomainError ? error.message : 'No se pudieron cargar las estadísticas.');
    });
  }, [container]);

  const taxPercent = Math.round(FIXED_TAX_RATE * 100);

  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm font-semibold text-primary">Hoy</p>
          <h1 className="text-2xl font-extrabold">Inicio</h1>
        </div>
        <Link to="/finanzas/resultados" className="btn-primary inline-flex h-12 items-center rounded-2xl px-5 text-sm font-semibold">
          Ver Resultados
        </Link>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
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
          {month ? (
            <section className="space-y-3">
              <h2 className="text-sm font-semibold text-primary">
                Este Período{month ? ` · ${formatDateOnly(month.from)} — ${formatDateOnly(month.to)}` : ''} · Impuesto {taxPercent}%
              </h2>
              <div className="grid gap-3 sm:grid-cols-3">
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
                <article className="rounded-3xl border border-line bg-white px-5 py-4">
                  <p className="text-sm font-medium text-muted">Venta Del Período</p>
                  <p className="mt-1 text-right text-2xl font-extrabold">{formatMoney(month.saleTotal)}</p>
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
