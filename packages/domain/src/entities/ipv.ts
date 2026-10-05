import { addDays } from '../shared/date';
import type { CardOpening } from './card_opening';
import type { ExpenseEntry } from './expense';
import { PurchaseDocument } from './purchase';

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

  latest(documents: readonly IpvDocument[]): IpvDocument | null {
    return documents.reduce<IpvDocument | null>((best, row) => {
      if (!best || row.workDate > best.workDate || (row.workDate === best.workDate && row.id > best.id)) {
        return row;
      }
      return best;
    }, null);
  },

  recaudoInRange(documents: readonly IpvDocument[], from: string, to: string): { cash: number; transfer: number } {
    return documents.reduce(
      (sum, row) => {
        if (row.workDate < from || row.workDate > to) {
          return sum;
        }
        return {
          cash: roundMoney(sum.cash + row.cashCollected),
          transfer: roundMoney(sum.transfer + row.transferCollected),
        };
      },
      { cash: 0, transfer: 0 },
    );
  },

  cajaInRange(
    documents: readonly IpvDocument[],
    purchases: readonly PurchaseDocument[],
    expenses: readonly ExpenseEntry[],
    from: string,
    to: string,
    opening?: Pick<CardOpening, 'cashAsOf' | 'cashAmount'> | null,
  ): { cash: number; transfer: number } {
    const hasCount = Boolean(opening && to >= opening.cashAsOf);
    const cashFrom = hasCount && opening ? addDays(opening.cashAsOf, 1) : from;
    const recaudoCash = cashFrom <= to ? IpvDocument.recaudoInRange(documents, cashFrom, to).cash : 0;
    const recaudoTransfer = IpvDocument.recaudoInRange(documents, from, to).transfer;
    let cashPurchases = 0;
    let transferPurchases = 0;
    for (const purchase of purchases) {
      const total = PurchaseDocument.total(purchase);
      if (purchase.purchasedOn >= from && purchase.purchasedOn <= to && purchase.paymentMethod === 'transfer') {
        transferPurchases += total;
      }
      if (cashFrom <= to && purchase.purchasedOn >= cashFrom && purchase.purchasedOn <= to && purchase.paymentMethod !== 'transfer') {
        cashPurchases += total;
      }
    }
    const expenseTotal =
      cashFrom <= to
        ? expenses.reduce((sum, entry) => {
            if (entry.occurredOn < cashFrom || entry.occurredOn > to) {
              return sum;
            }
            return sum + entry.amount;
          }, 0)
        : 0;
    const counted = hasCount && opening ? opening.cashAmount : 0;
    return {
      cash: roundMoney(counted + recaudoCash - cashPurchases - expenseTotal),
      transfer: roundMoney(recaudoTransfer - transferPurchases),
    };
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

  cashAfterSetAside(cashCollected: number, grossProfit: number): number {
    return roundMoney(cashCollected - grossProfit);
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
