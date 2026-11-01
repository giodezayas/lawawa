import { formatDateOnly, formatMoney, type PeriodDayStat } from '@wawa/domain';
import { useState } from 'react';

function dayNumber(workDate: string) {
  return String(Number(workDate.slice(8, 10)));
}

export function PeriodCharts({ days }: { days: readonly PeriodDayStat[] }) {
  const [active, setActive] = useState<PeriodDayStat | null>(null);
  if (days.length === 0) {
    return null;
  }
  const maxSale = Math.max(...days.map((day) => day.saleTotal), 1);
  const maxQty = Math.max(...days.map((day) => day.topSoldQty), 1);
  const best = days.reduce((winner, day) => (day.saleTotal > winner.saleTotal ? day : winner));

  return (
    <section className="space-y-6">
      <div className="space-y-3">
        <div className="flex flex-wrap items-end justify-between gap-2">
          <h2 className="text-sm font-semibold text-primary">Ventas Del Período</h2>
          <p className="text-xs text-muted">
            Mejor Día {formatDateOnly(best.workDate)} · {formatMoney(best.saleTotal)}
          </p>
        </div>
        <div className="rounded-3xl border border-line bg-white px-4 py-4">
          <div className="mb-3 min-h-12 text-sm">
            {active ? (
              <p>
                <span className="font-semibold">Día {dayNumber(active.workDate)}</span>
                <span className="text-muted"> · Venta {formatMoney(active.saleTotal)}</span>
                <span className="text-muted"> · Efectivo {formatMoney(active.cashCollected)}</span>
                <span className="text-muted"> · Transferencia {formatMoney(active.transferCollected)}</span>
              </p>
            ) : (
              <p className="text-muted">Pasa el mouse por un día.</p>
            )}
          </div>
          <div className="overflow-x-auto">
            <div className="flex h-44 min-w-[36rem] items-end gap-1">
              {days.map((day) => {
                const height = Math.max(8, Math.round((day.saleTotal / maxSale) * 100));
                const peak = day.workDate === best.workDate;
                const on = active?.workDate === day.workDate;
                return (
                  <div
                    key={day.workDate}
                    className="flex h-full min-w-0 flex-1 flex-col justify-end"
                    onMouseEnter={() => setActive(day)}
                    onMouseLeave={() => setActive(null)}
                  >
                    <div
                      className={`w-full rounded-t-lg ${peak ? 'bg-accent' : 'bg-primary'} ${on ? 'opacity-70' : ''}`}
                      style={{ height: `${height}%` }}
                    />
                    <span className="mt-1 text-center text-[10px] font-semibold text-muted">{dayNumber(day.workDate)}</span>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
      <div className="space-y-3">
        <h2 className="text-sm font-semibold text-primary">Más Vendido Por Día</h2>
        <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
          {days.map((day) => (
            <article key={day.workDate} className="rounded-2xl border border-line bg-white px-3 py-3">
              <div className="flex items-baseline justify-between gap-2">
                <p className="text-xs font-semibold text-primary">{dayNumber(day.workDate)}</p>
                <p className="text-xs text-muted">{day.topSoldQty} Uds</p>
              </div>
              <p className="mt-1 truncate text-sm font-extrabold">{day.topProductName}</p>
              <div className="mt-2 h-1.5 rounded-full bg-cream-dark">
                <div
                  className="h-1.5 rounded-full bg-accent"
                  style={{ width: `${Math.max(8, Math.round((day.topSoldQty / maxQty) * 100))}%` }}
                />
              </div>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
