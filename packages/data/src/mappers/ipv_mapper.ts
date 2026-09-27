import { IpvDocument, IpvLine, type IpvShift, type IpvStatus } from '@wawa/domain';
import type { Database } from '../supabase/database.types';

type DocumentRow = Database['public']['Tables']['ipv_documents']['Row'];
type LineRow = Database['public']['Tables']['ipv_lines']['Row'];

export function mapIpvLine(row: LineRow): IpvLine {
  return IpvLine.create({
    id: row.id,
    ipvId: row.ipv_id,
    productId: row.product_id,
    productName: row.product_name,
    openingQty: Number(row.opening_qty),
    inboundQty: Number(row.inbound_qty),
    outboundQty: Number(row.outbound_qty),
    closingQty: Number(row.closing_qty),
    salePrice: Number(row.sale_price),
    replenishmentCost: Number(row.replenishment_cost),
    soldQty: Number(row.sold_qty),
    saleTotal: Number(row.sale_total),
    grossProfit: Number(row.gross_profit),
    inboundAddsStock: row.inbound_adds_stock,
    sortOrder: row.sort_order,
  });
}

export function mapIpvDocument(row: DocumentRow, lines: LineRow[] = []): IpvDocument {
  return IpvDocument.create({
    id: row.id,
    workDate: row.work_date,
    shift: row.shift as IpvShift,
    status: row.status as IpvStatus,
    createdBy: row.created_by,
    closedBy: row.closed_by,
    closedAt: row.closed_at ? new Date(row.closed_at) : null,
    cashCollected: Number(row.cash_collected ?? 0),
    transferCollected: Number(row.transfer_collected ?? 0),
    lines: lines
      .slice()
      .sort((left, right) => left.sort_order - right.sort_order)
      .map(mapIpvLine),
  });
}
