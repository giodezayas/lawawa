import type { IpvDocument } from './ipv';
import type { CashMove, TransferCard } from './cash_move';

export type CardSlice = {
  readonly card: TransferCard;
  readonly received: number;
  readonly withdrawn: number;
  readonly deposited: number;
  readonly balance: number;
};

function round2(value: number) {
  return Math.round(value * 100) / 100;
}

export const CardLedger = {
  from(documents: readonly IpvDocument[], moves: readonly CashMove[], from: string, to: string): {
    p: CardSlice;
    f: CardSlice;
  } {
    const p = { card: 'p' as const, received: 0, withdrawn: 0, deposited: 0, balance: 0 };
    const f = { card: 'f' as const, received: 0, withdrawn: 0, deposited: 0, balance: 0 };

    for (const document of documents) {
      if (document.workDate < from || document.workDate > to) {
        continue;
      }
      p.received = round2(p.received + document.transferPCollected);
      f.received = round2(f.received + document.transferFCollected);
    }

    for (const move of moves) {
      if (move.occurredOn < from || move.occurredOn > to) {
        continue;
      }
      const slice = move.card === 'p' ? p : f;
      if (move.kind === 'transfer_to_cash') {
        slice.withdrawn = round2(slice.withdrawn + move.amount);
      } else {
        slice.deposited = round2(slice.deposited + move.amount);
      }
    }

    p.balance = round2(p.received + p.deposited - p.withdrawn);
    f.balance = round2(f.received + f.deposited - f.withdrawn);
    return { p, f };
  },
};
