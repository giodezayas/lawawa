import { PurchaseDocument, PurchaseLine, type PaymentMethod } from '@wawa/domain';
import type { Database } from '../supabase/database.types';

type DocumentRow = Database['public']['Tables']['purchase_documents']['Row'];
type LineRow = Database['public']['Tables']['purchase_lines']['Row'];

export function mapPurchaseLine(row: LineRow, productName: string): PurchaseLine {
  return PurchaseLine.create({
    id: row.id,
    purchaseId: row.purchase_id,
    productId: row.product_id,
    productName,
    qty: Number(row.qty),
    unitCost: Number(row.unit_cost),
  });
}

export function mapPurchaseDocument(
  row: DocumentRow,
  lines: Array<{ row: LineRow; productName: string }>,
): PurchaseDocument {
  return PurchaseDocument.create({
    id: row.id,
    purchasedOn: row.purchased_on,
    paymentMethod: (row.payment_method === 'transfer' ? 'transfer' : 'cash') as PaymentMethod,
    createdBy: row.created_by,
    lines: lines.map((line) => mapPurchaseLine(line.row, line.productName)),
  });
}
