export const ipvShifts = ['manana', 'noche'] as const;
export type IpvShift = (typeof ipvShifts)[number];

export const ipvStatuses = ['open', 'closed'] as const;
export type IpvStatus = (typeof ipvStatuses)[number];

export const IPV_DAILY_SALARY = 1500;

export type IpvLineProps = {
  readonly id: string;
  readonly ipvId: string;
  readonly productId: string;
  readonly productName: string;
  readonly openingQty: number;
  readonly inboundQty: number;
  readonly outboundQty: number;
  readonly closingQty: number;
  readonly salePrice: number;
  readonly replenishmentCost: number;
  readonly soldQty: number;
  readonly saleTotal: number;
  readonly grossProfit: number;
  readonly inboundAddsStock: boolean;
  readonly sortOrder: number;
};

export type IpvLine = Readonly<IpvLineProps>;

export type IpvDocumentProps = {
  readonly id: string;
  readonly workDate: string;
  readonly shift: IpvShift;
  readonly status: IpvStatus;
  readonly createdBy: string;
  readonly closedBy: string | null;
  readonly closedAt: Date | null;
  readonly cashCollected: number;
  readonly transferPCollected: number;
  readonly transferFCollected: number;
  readonly transferCollected: number;
  readonly lines: readonly IpvLine[];
};

export type IpvDocument = Readonly<IpvDocumentProps>;

export const IpvLine = {
  create(props: IpvLineProps): IpvLine {
    return Object.freeze({ ...props });
  },

  compute(input: {
    openingQty: number;
    inboundQty: number;
    outboundQty: number;
    soldQty: number;
    salePrice: number;
    replenishmentCost: number;
  }): { closingQty: number; saleTotal: number; grossProfit: number } {
    const closingQty = input.openingQty + input.inboundQty - input.outboundQty - input.soldQty;
    return {
      closingQty,
      saleTotal: roundMoney(input.soldQty * input.salePrice),
      grossProfit: roundMoney(input.soldQty * (input.salePrice - input.replenishmentCost)),
    };
  },
};

export const IpvDocument = {
  create(props: IpvDocumentProps): IpvDocument {
    return Object.freeze({
      ...props,
      lines: Object.freeze([...props.lines]),
    });
  },

  isOpen(document: IpvDocument): boolean {
    return document.status === 'open';
  },

  shiftLabel(shift: IpvShift): string {
    return shift === 'manana' ? 'Mañana' : 'Noche';
  },

  statusLabel(status: IpvStatus): string {
    return status === 'open' ? 'Abierto' : 'Cerrado';
  },

  transferTotal(document: IpvDocument): number {
    return document.transferPCollected + document.transferFCollected;
  },

  cashFromSale(saleTotal: number, transferPCollected: number, transferFCollected: number): number {
    return roundMoney(saleTotal - transferPCollected - transferFCollected);
  },

  profitAfterSalary(document: IpvDocument): number {
    return roundMoney(IpvDocument.grossProfit(document) - IPV_DAILY_SALARY);
  },

  cashAfterSalary(cashCollected: number): number {
    return roundMoney(cashCollected - IPV_DAILY_SALARY);
  },

  saleTotal(document: IpvDocument): number {
    return document.lines.reduce((sum, line) => sum + line.saleTotal, 0);
  },

  grossProfit(document: IpvDocument): number {
    return document.lines.reduce((sum, line) => sum + line.grossProfit, 0);
  },
};

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}
