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

export const CardLedger = {
  from(
    documents: readonly IpvDocument[],
    moves: readonly CashMove[],
    from: string,
    to: string,
    opening: CardOpening | null,
  ): {
    p: CardSlice;
    f: CardSlice;
  } {
    const p = { card: 'p' as const, opening: 0, received: 0, withdrawn: 0, deposited: 0, balance: 0 };
    const f = { card: 'f' as const, opening: 0, received: 0, withdrawn: 0, deposited: 0, balance: 0 };

    if (!opening) {
      return { p, f };
    }

    p.opening = opening.pAmount;
    f.opening = opening.fAmount;
    const trackFrom = opening.asOf;
    const activityTo = opening.asOf > to ? opening.asOf : to;

    for (const document of documents) {
      if (!inRange(document.workDate, trackFrom, activityTo) || !inRange(document.workDate, from, to)) {
        continue;
      }
      p.received = round2(p.received + document.transferPCollected);
      f.received = round2(f.received + document.transferFCollected);
    }

    for (const move of moves) {
      if (!inRange(move.occurredOn, trackFrom, activityTo) || !inRange(move.occurredOn, from, to)) {
        continue;
      }
      const slice = move.card === 'p' ? p : f;
      if (move.kind === 'transfer_to_cash') {
        slice.withdrawn = round2(slice.withdrawn + move.amount);
      } else {
        slice.deposited = round2(slice.deposited + move.amount);
      }
    }

    const pAll = { received: 0, withdrawn: 0, deposited: 0 };
    const fAll = { received: 0, withdrawn: 0, deposited: 0 };
    for (const document of documents) {
      if (!inRange(document.workDate, trackFrom, activityTo)) {
        continue;
      }
      pAll.received = round2(pAll.received + document.transferPCollected);
      fAll.received = round2(fAll.received + document.transferFCollected);
    }
    for (const move of moves) {
      if (!inRange(move.occurredOn, trackFrom, activityTo)) {
        continue;
      }
      const all = move.card === 'p' ? pAll : fAll;
      if (move.kind === 'transfer_to_cash') {
        all.withdrawn = round2(all.withdrawn + move.amount);
      } else {
        all.deposited = round2(all.deposited + move.amount);
      }
    }

    p.balance = round2(p.opening + pAll.received + pAll.deposited - pAll.withdrawn);
    f.balance = round2(f.opening + fAll.received + fAll.deposited - fAll.withdrawn);
    return { p, f };
  },
};
