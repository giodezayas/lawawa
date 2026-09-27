export type CashFlowProps = {
  readonly from: string;
  readonly to: string;
  readonly cashIn: number;
  readonly transferIn: number;
  readonly cashOut: number;
  readonly transferOut: number;
};

export type CashFlow = Readonly<CashFlowProps>;

export const CashFlow = {
  create(props: CashFlowProps): CashFlow {
    return Object.freeze({ ...props });
  },

  cashNet(flow: CashFlow): number {
    return Math.round((flow.cashIn - flow.cashOut) * 100) / 100;
  },

  transferNet(flow: CashFlow): number {
    return Math.round((flow.transferIn - flow.transferOut) * 100) / 100;
  },
};
