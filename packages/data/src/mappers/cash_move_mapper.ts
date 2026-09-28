import { CashMove, type CashMoveKind, type TransferCard } from '@wawa/domain';
import type { Database } from '../supabase/database.types';

type Row = Database['public']['Tables']['cash_moves']['Row'];

export function mapCashMove(row: Row): CashMove {
  return CashMove.create({
    id: row.id,
    occurredOn: row.occurred_on,
    kind: row.kind as CashMoveKind,
    card: (row.card === 'f' ? 'f' : 'p') as TransferCard,
    amount: Number(row.amount),
    notes: row.notes,
  });
}
