import { StockMovement, type StockMovementKind } from '@wawa/domain';
import type { Database } from '../supabase/database.types';

type MovementRow = Database['public']['Tables']['stock_movements']['Row'];

const kinds: readonly StockMovementKind[] = [
  'purchase',
  'ipv_sale',
  'ipv_outbound',
  'ipv_inbound',
  'ipv_close',
  'adjustment',
];

function asKind(value: string): StockMovementKind {
  return kinds.find((kind) => kind === value) ?? 'adjustment';
}

export function mapStockMovement(row: MovementRow): StockMovement {
  return StockMovement.create({
    id: row.id,
    productId: row.product_id,
    kind: asKind(row.kind),
    qty: Number(row.qty),
    unitCost: Number(row.unit_cost),
    occurredOn: row.occurred_on,
  });
}
