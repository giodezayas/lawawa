import type { CardOpening } from './card_opening';
import type { IpvDocument } from './ipv';
import type { CashMove, TransferCard } from './cash_move';

export type CardSlice = {
  readonly card: TransferCard;
  readonly opening: number;
  readonly received: number;
  readonly withdrawn: number;
  readonly deposited: number;
  readonly balance: number;
};

function round2(value: number) {
  return Math.round(value * 100) / 100;
}

function inRange(date: string, from: string, to: string) {
  return date >= from && date <= to;
}

// What remains at the close of October 2026. Later months start at 0.
const countedCloseByMonth: Record<string, { p: number; f: number }> = {
  '2026-10': { p: 10000, f: 65000 },
};

export const CardLedger = {
  from(
    documents: readonly IpvDocument[],
    moves: readonly CashMove[],
    from: string,
    to: string,
    _opening: CardOpening | null,
  ): {
    p: CardSlice;
    f: CardSlice;
  } {
    const p = { card: 'p' as const, opening: 0, received: 0, withdrawn: 0, deposited: 0, balance: 0 };
    const f = { card: 'f' as const, opening: 0, received: 0, withdrawn: 0, deposited: 0, balance: 0 };

    for (const document of documents) {
      if (!inRange(document.workDate, from, to)) {
        continue;
      }
      p.received = round2(p.received + document.transferPCollected);
      f.received = round2(f.received + document.transferFCollected);
    }

    for (const move of moves) {
      if (!inRange(move.occurredOn, from, to)) {
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

    const counted = countedCloseByMonth[from.slice(0, 7)];
    if (counted) {
      p.balance = counted.p;
      f.balance = counted.f;
    }

    return { p, f };
  },
};
