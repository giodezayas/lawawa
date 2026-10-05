import { DomainError, SalesInsight, defaultBillingPeriod, formatDateOnly, formatMoney, shiftCalendarMonth } from '@wawa/domain';
import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../../../app/providers/auth_provider';
import { ExportButtons } from '../../../shared/ui/export_buttons';
import { moneyTone } from '../../../shared/ui/money_tone';

function formatPct(value: number) {
  return `${value.toLocaleString('en-US', { minimumFractionDigits: 1, maximumFractionDigits: 1 })} %`;
}

function StatCard({
  label,
  title,
  detail,
  tone = '',
}: {
  label: string;
  title: string;
  detail: string;
  tone?: string;
}) {
  return (
    <article className="rounded-3xl border border-line bg-white px-5 py-4">
      <p className="text-sm font-medium text-muted">{label}</p>
      <p className={`mt-1 text-lg font-extrabold ${tone}`}>{title}</p>
      <p className="mt-1 text-sm text-muted">{detail}</p>
    </article>
  );
}

export function ReportsScreen() {
  const { container } = useAuth();
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [pageError, setPageError] = useState('');
  const [loading, setLoading] = useState(true);
  const [insight, setInsight] = useState<ReturnType<typeof SalesInsight.fromIpvs> | null>(null);

  useEffect(() => {
    void container.getBillingPeriod
      .execute()
      .then((period) => {
        setFrom(period.from);
        setTo(period.to);
      })
      .catch((error) => {
        setPageError(error instanceof DomainError ? error.message : 'No se pudieron armar las estadísticas.');
      });
  }, [container]);

  useEffect(() => {
    if (!from || !to) {
      return;
    }
    void (async () => {
      setLoading(true);
      try {
        const ipvs = await container.listIpvs.execute();
        setInsight(SalesInsight.fromIpvs(ipvs, from, to));
      } catch (error) {
        setPageError(error instanceof DomainError ? error.message : 'No se pudieron armar las estadísticas.');
      } finally {
        setLoading(false);
      }
    })();
  }, [container, from, to]);

  function shift(direction: number) {
    if (!from || !to) {
      return;
    }
    const next = shiftCalendarMonth(from, direction);
    setFrom(next.from);
    setTo(next.to);
  }

  const productRows = useMemo(() => {
    if (!insight) {
      return [];
    }
    return insight.products.map((row) => [
      row.productName,
      String(row.soldQty),
      formatMoney(row.saleTotal),
      formatMoney(row.profit),
      formatPct(row.marginPct),
    ]);
  }, [insight]);

  const dayRows = useMemo(() => {
    if (!insight) {
      return [];
    }
    return insight.days.map((row) => [
      formatDateOnly(row.workDate),
      formatMoney(row.saleTotal),
      formatMoney(row.profit),
      formatMoney(row.cashCollected),
      formatMoney(row.transferCollected),
    ]);
  }, [insight]);

  const productColumns = ['Producto', 'Unidades', 'Venta', 'Ganancia', 'Margen'];
  const dayColumns = ['Fecha', 'Venta', 'Ganancia', 'Efectivo', 'Transferencia'];

  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold">Reportes</h1>
          <p className="mt-1 text-sm text-muted">
            Estadísticas de IPV en el rango. Ganancia = venta menos costo de lo vendido. Margen = ganancia / venta.
          </p>
        </div>
        <ExportButtons
          title={`Reportes ${from} ${to}`}
          fileName={`reportes_${from}_${to}`}
          columns={productColumns}
          rows={productRows}
          disabled={loading || productRows.length === 0}
        />
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <button type="button" className="btn-outline h-10 rounded-2xl px-4 text-sm font-semibold" onClick={() => shift(-1)}>
          Anterior
        </button>
        <p className="text-sm font-semibold">
          {from && to ? `${formatDateOnly(from)} — ${formatDateOnly(to)}` : 'Cargando Período...'}
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
      {loading || !insight ? (
        pageError ? null : <p className="text-sm text-muted">Cargando Reportes...</p>
      ) : (
        <>
          <section className="space-y-3">
            <h2 className="text-sm font-semibold text-primary">Productos</h2>
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
              <StatCard
                label="Más Vendido"
                title={insight.mostSold?.productName ?? '—'}
                detail={insight.mostSold ? `${insight.mostSold.soldQty} Unidades · ${formatMoney(insight.mostSold.saleTotal)}` : 'Sin Ventas En El Rango'}
              />
              <StatCard
                label="Menos Vendido"
                title={insight.leastSold?.productName ?? '—'}
                detail={insight.leastSold ? `${insight.leastSold.soldQty} Unidades · ${formatMoney(insight.leastSold.saleTotal)}` : 'Sin Ventas En El Rango'}
              />
              <StatCard
                label="Mayor Ganancia"
                title={insight.mostProfitProduct?.productName ?? '—'}
                detail={insight.mostProfitProduct ? formatMoney(insight.mostProfitProduct.profit) : 'Sin Ventas En El Rango'}
                tone={insight.mostProfitProduct ? moneyTone(insight.mostProfitProduct.profit) : ''}
              />
              <StatCard
                label="Menor Ganancia"
                title={insight.leastProfitProduct?.productName ?? '—'}
                detail={insight.leastProfitProduct ? formatMoney(insight.leastProfitProduct.profit) : 'Sin Ventas En El Rango'}
                tone={insight.leastProfitProduct ? moneyTone(insight.leastProfitProduct.profit) : ''}
              />
              <StatCard
                label="Mayor Margen"
                title={insight.bestMargin?.productName ?? '—'}
                detail={insight.bestMargin ? formatPct(insight.bestMargin.marginPct) : 'Sin Ventas En El Rango'}
              />
              <StatCard
                label="Menor Margen"
                title={insight.worstMargin?.productName ?? '—'}
                detail={insight.worstMargin ? formatPct(insight.worstMargin.marginPct) : 'Sin Ventas En El Rango'}
              />
            </div>
          </section>
          <section className="space-y-3">
            <h2 className="text-sm font-semibold text-primary">Días</h2>
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
              <StatCard
                label="Mayor Venta"
                title={insight.bestSaleDay ? formatDateOnly(insight.bestSaleDay.workDate) : '—'}
                detail={insight.bestSaleDay ? formatMoney(insight.bestSaleDay.saleTotal) : 'Sin IPV En El Rango'}
              />
              <StatCard
                label="Menor Venta"
                title={insight.worstSaleDay ? formatDateOnly(insight.worstSaleDay.workDate) : '—'}
                detail={insight.worstSaleDay ? formatMoney(insight.worstSaleDay.saleTotal) : 'Sin IPV En El Rango'}
              />
              <StatCard
                label="Mayor Ganancia"
                title={insight.bestProfitDay ? formatDateOnly(insight.bestProfitDay.workDate) : '—'}
                detail={insight.bestProfitDay ? formatMoney(insight.bestProfitDay.profit) : 'Sin IPV En El Rango'}
                tone={insight.bestProfitDay ? moneyTone(insight.bestProfitDay.profit) : ''}
              />
              <StatCard
                label="Menor Ganancia"
                title={insight.worstProfitDay ? formatDateOnly(insight.worstProfitDay.workDate) : '—'}
                detail={insight.worstProfitDay ? formatMoney(insight.worstProfitDay.profit) : 'Sin IPV En El Rango'}
                tone={insight.worstProfitDay ? moneyTone(insight.worstProfitDay.profit) : ''}
              />
              <StatCard
                label="Más Transferencia"
                title={insight.mostTransferDay ? formatDateOnly(insight.mostTransferDay.workDate) : '—'}
                detail={insight.mostTransferDay ? formatMoney(insight.mostTransferDay.transferCollected) : 'Sin IPV En El Rango'}
              />
              <StatCard
                label="Menos Transferencia"
                title={insight.leastTransferDay ? formatDateOnly(insight.leastTransferDay.workDate) : '—'}
                detail={insight.leastTransferDay ? formatMoney(insight.leastTransferDay.transferCollected) : 'Sin IPV En El Rango'}
              />
            </div>
          </section>
          <section className="space-y-3">
            <div className="flex flex-wrap items-end justify-between gap-3">
              <h2 className="text-sm font-semibold text-primary">Ranking De Productos</h2>
              <ExportButtons
                title={`Productos ${from} ${to}`}
                fileName={`reportes_productos_${from}_${to}`}
                columns={productColumns}
                rows={productRows}
                disabled={productRows.length === 0}
              />
            </div>
            <div className="max-h-[28rem] overflow-auto rounded-3xl border border-line bg-surface">
              <table className="min-w-full text-sm">
                <thead className="sticky top-0 z-10 bg-surface">
                  <tr className="border-b border-line text-left">
                    <th className="px-4 py-3 font-semibold">Producto</th>
                    <th className="px-4 py-3 text-right font-semibold">Unidades</th>
                    <th className="px-4 py-3 text-right font-semibold">Venta</th>
                    <th className="px-4 py-3 text-right font-semibold">Ganancia</th>
                    <th className="px-4 py-3 text-right font-semibold">Margen</th>
                  </tr>
                </thead>
                <tbody>
                  {insight.products.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="px-4 py-8 text-center text-muted">
                        No hay IPV con productos en esas fechas.
                      </td>
                    </tr>
                  ) : (
                    insight.products.map((row) => (
                      <tr key={row.productId} className="border-t border-line">
                        <td className="px-4 py-3">{row.productName}</td>
                        <td className="px-4 py-3 text-right">{row.soldQty}</td>
                        <td className="px-4 py-3 text-right">{formatMoney(row.saleTotal)}</td>
                        <td className={`px-4 py-3 text-right ${moneyTone(row.profit)}`}>{formatMoney(row.profit)}</td>
                        <td className="px-4 py-3 text-right">{formatPct(row.marginPct)}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </section>
          <section className="space-y-3">
            <div className="flex flex-wrap items-end justify-between gap-3">
              <h2 className="text-sm font-semibold text-primary">Días Del Rango</h2>
              <ExportButtons
                title={`Días ${from} ${to}`}
                fileName={`reportes_dias_${from}_${to}`}
                columns={dayColumns}
                rows={dayRows}
                disabled={dayRows.length === 0}
              />
            </div>
            <div className="max-h-[28rem] overflow-auto rounded-3xl border border-line bg-surface">
              <table className="min-w-full text-sm">
                <thead className="sticky top-0 z-10 bg-surface">
                  <tr className="border-b border-line text-left">
                    <th className="px-4 py-3 font-semibold">Fecha</th>
                    <th className="px-4 py-3 text-right font-semibold">Venta</th>
                    <th className="px-4 py-3 text-right font-semibold">Ganancia</th>
                    <th className="px-4 py-3 text-right font-semibold">Efectivo</th>
                    <th className="px-4 py-3 text-right font-semibold">Transferencia</th>
                  </tr>
                </thead>
                <tbody>
                  {insight.days.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="px-4 py-8 text-center text-muted">
                        No hay IPV en esas fechas.
                      </td>
                    </tr>
                  ) : (
                    insight.days.map((row) => (
                      <tr key={row.workDate} className="border-t border-line">
                        <td className="px-4 py-3">{formatDateOnly(row.workDate)}</td>
                        <td className="px-4 py-3 text-right">{formatMoney(row.saleTotal)}</td>
                        <td className={`px-4 py-3 text-right ${moneyTone(row.profit)}`}>{formatMoney(row.profit)}</td>
                        <td className="px-4 py-3 text-right">{formatMoney(row.cashCollected)}</td>
                        <td className="px-4 py-3 text-right">{formatMoney(row.transferCollected)}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </section>
        </>
      )}
    </div>
  );
}
