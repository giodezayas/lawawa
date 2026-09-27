import { PeriodReport, type PeriodLineProps } from '@wawa/domain';
import type { Json } from '../supabase/database.types';

function asRecord(value: Json): Record<string, Json | undefined> {
  return value !== null && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function asNumber(value: Json | undefined): number {
  return typeof value === 'number' ? value : Number(value ?? 0);
}

function asString(value: Json | undefined): string {
  return typeof value === 'string' ? value : String(value ?? '');
}

export function mapPeriodReport(payload: Json): PeriodReport {
  const row = asRecord(payload);
  const rawLines = Array.isArray(row.lines) ? row.lines : [];
  const lines: PeriodLineProps[] = rawLines.map((item) => {
    const line = asRecord(item);
    return {
      categoryId: asString(line.category_id),
      name: asString(line.name),
      kind: asString(line.kind),
      cadence: asString(line.cadence),
      source: asString(line.source),
      occurredOn: asString(line.occurred_on),
      amount: asNumber(line.amount),
    };
  });

  return PeriodReport.create({
    from: asString(row.from),
    to: asString(row.to),
    days: asNumber(row.days),
    taxRate: asNumber(row.tax_rate),
    saleTotal: asNumber(row.sale_total),
    purchaseTotal: asNumber(row.purchase_total),
    grossProfit: asNumber(row.gross_profit),
    expenseTotal: asNumber(row.expense_total),
    utilidad: asNumber(row.utilidad),
    tax: asNumber(row.tax),
    net: asNumber(row.net),
    closed: Boolean(row.closed),
    lines,
  });
}
