export const cashMoveKinds = ['transfer_to_cash', 'cash_to_transfer'] as const;
export type CashMoveKind = (typeof cashMoveKinds)[number];

export const transferCards = ['p', 'f'] as const;
export type TransferCard = (typeof transferCards)[number];

export type CashMoveProps = {
  readonly id: string;
  readonly occurredOn: string;
  readonly kind: CashMoveKind;
  readonly card: TransferCard;
  readonly amount: number;
  readonly notes: string;
};

export type CashMove = Readonly<CashMoveProps>;

export const CashMove = {
  create(props: CashMoveProps): CashMove {
    return Object.freeze({ ...props });
  },

  kindLabel(kind: CashMoveKind): string {
    return kind === 'transfer_to_cash' ? 'Extracción A Efectivo' : 'Depósito Desde Efectivo';
  },

  cardLabel(card: TransferCard): string {
    return card === 'p' ? 'Tarjeta P' : 'Tarjeta F';
  },
};
