import { ExpenseCategory, ExpenseEntry, type ExpenseCadence, type ExpenseKind } from '@wawa/domain';
import type { Database } from '../supabase/database.types';

type CategoryRow = Database['public']['Tables']['expense_categories']['Row'];
type EntryRow = Database['public']['Tables']['expense_entries']['Row'];

const kinds: readonly ExpenseKind[] = ['fixed', 'variable'];
const cadences: readonly ExpenseCadence[] = ['once', 'daily', 'weekly', 'monthly'];

function mapCadence(value: string): ExpenseCadence {
  if (value === 'none') {
    return 'once';
  }
  return cadences.find((cadence) => cadence === value) ?? 'once';
}

export function mapExpenseCategory(row: CategoryRow): ExpenseCategory {
  return ExpenseCategory.create({
    id: row.id,
    name: row.name,
    kind: kinds.find((kind) => kind === row.kind) ?? 'variable',
    cadence: mapCadence(row.cadence),
    defaultAmount: Number(row.default_amount),
    isActive: row.is_active,
  });
}

export function mapExpenseEntry(row: EntryRow): ExpenseEntry {
  return ExpenseEntry.create({
    id: row.id,
    name: row.name || 'Gasto',
    occurredOn: row.occurred_on,
    cadence: mapCadence(row.cadence),
    amount: Number(row.amount),
    notes: row.notes,
  });
}
