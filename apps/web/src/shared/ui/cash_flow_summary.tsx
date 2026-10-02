import { CashFlow, formatDateOnly, formatMoney } from '@wawa/domain';
import { moneyTone } from './money_tone';

type CashFlowSummaryProps = {
  flow: CashFlow;
  title: string;
};

export function CashFlowSummary({ flow, title }: CashFlowSummaryProps) {
  return (
    <section className="space-y-3">
      <h2 className="text-sm font-semibold text-primary">{title}</h2>
      <p className="text-sm text-muted">
        Recaudo IPV menos reposiciones, más pases entre efectivo y transferencia.
        {flow.firstSaleOn
          ? ` Empieza el ${formatDateOnly(flow.firstSaleOn)}, con la primera venta. Las compras de antes son inversión y no entran aquí.`
          : ' Todavía no hay venta, así que no hay flujo de caja.'}
      </p>
      <div className="grid gap-3 sm:grid-cols-2">
        <article className="rounded-3xl border border-line bg-white px-5 py-4">
          <p className="text-sm font-medium text-muted">Efectivo</p>
          <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(CashFlow.cashNet(flow))}`}>
            {formatMoney(CashFlow.cashNet(flow))}
          </p>
          <p className="mt-2 text-right text-xs text-muted">
            IPV {formatMoney(flow.ipvCash)} · De Transferencia {formatMoney(flow.transferToCash)} · Compras{' '}
            {formatMoney(flow.cashPurchases)}
            {flow.ipvSalary > 0 ? ` · Salario ${formatMoney(flow.ipvSalary)}` : ''}
            {flow.cashToTransfer > 0 ? ` · A Transferencia ${formatMoney(flow.cashToTransfer)}` : ''}
          </p>
        </article>
        <article className="rounded-3xl border border-line bg-white px-5 py-4">
          <p className="text-sm font-medium text-muted">Transferencia</p>
          <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(CashFlow.transferNet(flow))}`}>
            {formatMoney(CashFlow.transferNet(flow))}
          </p>
          <p className="mt-2 text-right text-xs text-muted">
            IPV {formatMoney(flow.ipvTransfer)} · Compras {formatMoney(flow.transferPurchases)} · Extracciones{' '}
            {formatMoney(flow.transferToCash)}
            {flow.cashToTransfer > 0 ? ` · De Efectivo ${formatMoney(flow.cashToTransfer)}` : ''}
          </p>
        </article>
      </div>
    </section>
  );
}
