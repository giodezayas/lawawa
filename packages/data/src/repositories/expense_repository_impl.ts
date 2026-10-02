import {
  DomainError,
  InventoryErrorCodes,
  PeriodReport,
  type CreateExpenseEntryInput,
  type ExpenseEntry,
  type ExpenseRepository,
  type UpdateExpenseEntryInput,
  defaultBillingPeriod,
  isLiveCurrentMonth,
} from '@wawa/domain';
import { mapExpenseEntry } from '../mappers/expense_mapper';
import { mapPeriodReport } from '../mappers/period_report_mapper';
import type { AppSupabaseClient } from '../supabase/client';

export class ExpenseRepositoryImpl implements ExpenseRepository {
  constructor(private readonly client: AppSupabaseClient) {}

  async listEntries(): Promise<ExpenseEntry[]> {
    const { data, error } = await this.client
      .from('expense_entries')
      .select('*')
      .order('occurred_on', { ascending: false });

    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
    return (data ?? []).map(mapExpenseEntry);
  }

  async getEntry(id: string): Promise<ExpenseEntry | null> {
    const { data, error } = await this.client.from('expense_entries').select('*').eq('id', id).maybeSingle();
    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
    return data ? mapExpenseEntry(data) : null;
  }

  async createEntry(input: CreateExpenseEntryInput): Promise<ExpenseEntry> {
    const { data, error } = await this.client
      .from('expense_entries')
      .insert({
        name: input.name,
        occurred_on: input.occurredOn,
        cadence: input.cadence,
        amount: input.amount,
        notes: input.notes,
        created_by: input.createdBy,
      })
      .select('*')
      .single();

    if (error || !data) {
      throw new DomainError(error?.message ?? 'No se pudo guardar el gasto.', InventoryErrorCodes.invalidInput);
    }
    return mapExpenseEntry(data);
  }

  async updateEntry(input: UpdateExpenseEntryInput): Promise<ExpenseEntry> {
    const { data, error } = await this.client
      .from('expense_entries')
      .update({
        name: input.name,
        occurred_on: input.occurredOn,
        cadence: input.cadence,
        amount: input.amount,
        notes: input.notes,
      })
      .eq('id', input.id)
      .select('*')
      .single();

    if (error || !data) {
      throw new DomainError(error?.message ?? 'No se pudo guardar el gasto.', InventoryErrorCodes.invalidInput);
    }
    return mapExpenseEntry(data);
  }

  async removeEntry(id: string): Promise<void> {
    const { error } = await this.client.from('expense_entries').delete().eq('id', id);
    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
  }

  async getPeriodReport(from: string, to: string): Promise<PeriodReport> {
    const { data, error } = await this.client.rpc('period_report', { p_from: from, p_to: to });
    if (error || data === null) {
      throw new DomainError(error?.message ?? 'No se pudo armar el corte.', InventoryErrorCodes.invalidInput);
    }
    const report = mapPeriodReport(data);
    return PeriodReport.create({
      ...report,
      purchaseTotal: await this.sumPurchases(from, to),
    });
  }

  private async sumPurchases(from: string, to: string): Promise<number> {
    const { data: documents, error: documentsError } = await this.client
      .from('purchase_documents')
      .select('id')
      .gte('purchased_on', from)
      .lte('purchased_on', to);

    if (documentsError) {
      throw new DomainError(documentsError.message, InventoryErrorCodes.invalidInput);
    }

    const ids = (documents ?? []).map((row) => row.id);
    if (ids.length === 0) {
      return 0;
    }

    const { data: lines, error: linesError } = await this.client
      .from('purchase_lines')
      .select('qty, unit_cost')
      .in('purchase_id', ids);

    if (linesError) {
      throw new DomainError(linesError.message, InventoryErrorCodes.invalidInput);
    }

    const total = (lines ?? []).reduce((sum, line) => sum + Number(line.qty) * Number(line.unit_cost), 0);
    return Math.round(total * 100) / 100;
  }

  async getBillingPeriod() {
    const fallback = defaultBillingPeriod();
    const { data, error } = await this.client
      .from('business_settings')
      .select('billing_period_from, billing_period_to, billing_period_live')
      .limit(1)
      .maybeSingle();
    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
    if (data?.billing_period_live !== false) {
      return fallback;
    }
    const from = data?.billing_period_from;
    const to = data?.billing_period_to;
    if (typeof from === 'string' && typeof to === 'string' && to >= from) {
      return { from, to };
    }
    return fallback;
  }

  async setBillingPeriod(from: string, to: string) {
    const { data: existing, error: readError } = await this.client.from('business_settings').select('id').limit(1).maybeSingle();
    if (readError) {
      throw new DomainError(readError.message, InventoryErrorCodes.invalidInput);
    }
    if (!existing) {
      throw new DomainError('No hay ajustes del negocio.', InventoryErrorCodes.notFound);
    }
    const live = isLiveCurrentMonth(from, to);
    const { data, error } = await this.client
      .from('business_settings')
      .update({ billing_period_from: from, billing_period_to: to, billing_period_live: live })
      .eq('id', existing.id)
      .select('billing_period_from, billing_period_to, billing_period_live')
      .single();
    if (error || !data?.billing_period_from || !data.billing_period_to) {
      throw new DomainError(error?.message ?? 'No se pudo guardar el período.', InventoryErrorCodes.invalidInput);
    }
    if (data.billing_period_live !== false) {
      return defaultBillingPeriod();
    }
    return { from: data.billing_period_from, to: data.billing_period_to };
  }

  async closeBillingPeriod(from: string, to: string): Promise<void> {
    const { error } = await this.client.rpc('close_billing_period', { p_from: from, p_to: to });
    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
  }
}
