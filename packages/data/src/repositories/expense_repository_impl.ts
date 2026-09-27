import {
  DomainError,
  InventoryErrorCodes,
  type CreateExpenseEntryInput,
  type ExpenseEntry,
  type ExpenseRepository,
  type PeriodReport,
  type UpdateExpenseEntryInput,
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
    return mapPeriodReport(data);
  }

  async getBillingStartDay(): Promise<number> {
    const { data, error } = await this.client.from('business_settings').select('billing_start_day').limit(1).maybeSingle();
    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
    return Number(data?.billing_start_day ?? 1);
  }

  async setBillingStartDay(startDay: number): Promise<number> {
    const { data: existing, error: readError } = await this.client.from('business_settings').select('id').limit(1).maybeSingle();
    if (readError) {
      throw new DomainError(readError.message, InventoryErrorCodes.invalidInput);
    }
    if (!existing) {
      throw new DomainError('No hay ajustes del negocio.', InventoryErrorCodes.notFound);
    }
    const { data, error } = await this.client
      .from('business_settings')
      .update({ billing_start_day: startDay })
      .eq('id', existing.id)
      .select('billing_start_day')
      .single();
    if (error || !data) {
      throw new DomainError(error?.message ?? 'No se pudo guardar el período.', InventoryErrorCodes.invalidInput);
    }
    return Number(data.billing_start_day);
  }

  async closeBillingPeriod(from: string, to: string): Promise<void> {
    const { error } = await this.client.rpc('close_billing_period', { p_from: from, p_to: to });
    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
  }
}
