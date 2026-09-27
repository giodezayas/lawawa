import type { ExpenseCadence, ExpenseEntry } from '../entities/expense';
import type { PeriodReport } from '../entities/period_report';
import type { BillingPeriodBounds } from '../shared/billing_period';

export type CreateExpenseEntryInput = {
  name: string;
  occurredOn: string;
  cadence: ExpenseCadence;
  amount: number;
  notes: string;
  createdBy: string;
};

export type UpdateExpenseEntryInput = {
  id: string;
  name: string;
  occurredOn: string;
  cadence: ExpenseCadence;
  amount: number;
  notes: string;
};

export type { BillingPeriodBounds };

export interface ExpenseRepository {
  listEntries(): Promise<ExpenseEntry[]>;
  getEntry(id: string): Promise<ExpenseEntry | null>;
  createEntry(input: CreateExpenseEntryInput): Promise<ExpenseEntry>;
  updateEntry(input: UpdateExpenseEntryInput): Promise<ExpenseEntry>;
  removeEntry(id: string): Promise<void>;
  getPeriodReport(from: string, to: string): Promise<PeriodReport>;
  getBillingPeriod(): Promise<BillingPeriodBounds>;
  setBillingPeriod(from: string, to: string): Promise<BillingPeriodBounds>;
  closeBillingPeriod(from: string, to: string): Promise<void>;
}
