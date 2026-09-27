import { CashFlow, formatMoney } from '@wawa/domain';
import { moneyTone } from './money_tone';

type CashFlowSummaryProps = {
  flow: CashFlow;
  title: string;
};

export function CashFlowSummary({ flow, title }: CashFlowSummaryProps) {
  return (
    <section className="space-y-3">
      <h2 className="text-sm font-semibold text-primary">{title}</h2>
      <div className="grid gap-3 sm:grid-cols-2">
        <article className="rounded-3xl border border-line bg-white px-5 py-4">
          <p className="text-sm font-medium text-muted">Efectivo</p>
          <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(CashFlow.cashNet(flow))}`}>
            {formatMoney(CashFlow.cashNet(flow))}
          </p>
          <p className="mt-2 text-right text-xs text-muted">
            Entra {formatMoney(flow.cashIn)} · Compras {formatMoney(flow.cashOut)}
          </p>
        </article>
        <article className="rounded-3xl border border-line bg-white px-5 py-4">
          <p className="text-sm font-medium text-muted">Transferencia</p>
          <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(CashFlow.transferNet(flow))}`}>
            {formatMoney(CashFlow.transferNet(flow))}
          </p>
          <p className="mt-2 text-right text-xs text-muted">
            Entra {formatMoney(flow.transferIn)} · Compras {formatMoney(flow.transferOut)}
          </p>
        </article>
      </div>
    </section>
  );
}
