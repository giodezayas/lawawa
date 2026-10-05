import { CardOpening } from '@wawa/domain';
import type { Database } from '../supabase/database.types';

type Row = Database['public']['Tables']['card_opening']['Row'];

export function mapCardOpening(row: Row): CardOpening {
  return CardOpening.create({
    asOf: row.as_of,
    pAmount: Number(row.p_amount),
    fAmount: Number(row.f_amount),
    cashAsOf: row.cash_as_of,
    cashAmount: Number(row.cash_amount),
    notes: row.notes,
  });
}
