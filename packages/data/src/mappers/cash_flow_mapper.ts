import { CashFlow } from '@wawa/domain';
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

export function mapCashFlow(payload: Json): CashFlow {
  const row = asRecord(payload);
  return CashFlow.create({
    from: asString(row.from),
    to: asString(row.to),
    cashIn: asNumber(row.cash_in),
    transferIn: asNumber(row.transfer_in),
    cashOut: asNumber(row.cash_out),
    transferOut: asNumber(row.transfer_out),
    ipvCash: asNumber(row.ipv_cash),
    ipvTransfer: asNumber(row.ipv_transfer),
    cashPurchases: asNumber(row.cash_purchases),
    transferPurchases: asNumber(row.transfer_purchases),
    transferToCash: asNumber(row.transfer_to_cash),
    cashToTransfer: asNumber(row.cash_to_transfer),
    ipvSalary: asNumber(row.ipv_salary),
    ipvSetAside: asNumber(row.ipv_set_aside),
    cashOpening: asNumber(row.cash_opening),
    cashOpeningOn: typeof row.cash_opening_on === 'string' ? row.cash_opening_on : null,
    firstSaleOn: typeof row.first_sale_on === 'string' ? row.first_sale_on : null,
  });
}
