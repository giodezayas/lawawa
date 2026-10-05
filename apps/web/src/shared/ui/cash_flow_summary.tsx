import { CashFlow, formatMoney } from '@wawa/domain';
import { moneyTone } from './money_tone';

type RecaudoSummaryProps = {
  title: string;
  cash: number;
  transfer: number;
};

export function RecaudoSummary({ title, cash, transfer }: RecaudoSummaryProps) {
  return (
    <section className="space-y-3">
      <h2 className="text-sm font-semibold text-primary">{title}</h2>
      <div className="grid gap-3 sm:grid-cols-2">
        <article className="rounded-3xl border border-line bg-white px-5 py-4">
          <p className="text-sm font-medium text-muted">Efectivo</p>
          <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(cash)}`}>{formatMoney(cash)}</p>
        </article>
        <article className="rounded-3xl border border-line bg-white px-5 py-4">
          <p className="text-sm font-medium text-muted">Transferencia</p>
          <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(transfer)}`}>{formatMoney(transfer)}</p>
        </article>
      </div>
    </section>
  );
}

type CashFlowSummaryProps = {
  flow: CashFlow;
  title: string;
};

export function CashFlowSummary({ flow, title }: CashFlowSummaryProps) {
  return <RecaudoSummary title={title} cash={CashFlow.cashNet(flow)} transfer={CashFlow.transferNet(flow)} />;
}
