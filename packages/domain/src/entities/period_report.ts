export const FIXED_TAX_RATE = 0.25;

export type PeriodLineProps = {
  readonly categoryId: string;
  readonly name: string;
  readonly kind: string;
  readonly cadence: string;
  readonly source: string;
  readonly occurredOn: string;
  readonly amount: number;
};

export type PeriodReportProps = {
  readonly from: string;
  readonly to: string;
  readonly days: number;
  readonly taxRate: number;
  readonly saleTotal: number;
  readonly purchaseTotal: number;
  readonly grossProfit: number;
  readonly expenseTotal: number;
  readonly utilidad: number;
  readonly tax: number;
  readonly net: number;
  readonly closed: boolean;
  readonly lines: readonly PeriodLineProps[];
};

export type PeriodReport = Readonly<PeriodReportProps>;

export const PeriodReport = {
  create(props: PeriodReportProps): PeriodReport {
    return Object.freeze({
      ...props,
      lines: Object.freeze([...props.lines]),
    });
  },

  sourceLabel(source: string): string {
    return source === 'accrual' ? 'Calculado' : 'Registrado';
  },

  cadenceLabel(cadence: string): string {
    if (cadence === 'daily') {
      return 'Diario';
    }
    if (cadence === 'weekly') {
      return 'Semanal';
    }
    if (cadence === 'monthly') {
      return 'Mensual';
    }
    return 'Una Vez';
  },

  vsInvested(report: PeriodReport): number {
    return Math.round((report.saleTotal - report.purchaseTotal) * 100) / 100;
  },
};
