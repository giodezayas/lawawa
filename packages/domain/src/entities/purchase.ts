export const paymentMethods = ['cash', 'transfer'] as const;
export type PaymentMethod = (typeof paymentMethods)[number];

export type PurchaseLineProps = {
  readonly id: string;
  readonly purchaseId: string;
  readonly productId: string;
  readonly productName: string;
  readonly qty: number;
  readonly unitCost: number;
};

export type PurchaseLine = Readonly<PurchaseLineProps>;

export type PurchaseDocumentProps = {
  readonly id: string;
  readonly purchasedOn: string;
  readonly paymentMethod: PaymentMethod;
  readonly createdBy: string;
  readonly lines: readonly PurchaseLine[];
};

export type PurchaseDocument = Readonly<PurchaseDocumentProps>;

export const PurchaseLine = {
  create(props: PurchaseLineProps): PurchaseLine {
    return Object.freeze({ ...props });
  },

  lineTotal(line: PurchaseLine): number {
    return Math.round(line.qty * line.unitCost * 100) / 100;
  },
};

export const PurchaseDocument = {
  create(props: PurchaseDocumentProps): PurchaseDocument {
    return Object.freeze({
      ...props,
      lines: Object.freeze([...props.lines]),
    });
  },

  total(document: PurchaseDocument): number {
    return document.lines.reduce((sum, line) => sum + PurchaseLine.lineTotal(line), 0);
  },

  paymentLabel(method: PaymentMethod): string {
    return method === 'cash' ? 'Efectivo' : 'Transferencia';
  },
};
