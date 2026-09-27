import type { ExpenseCadence, ExpenseEntry } from '../entities/expense';
import type { PeriodReport } from '../entities/period_report';

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

export interface ExpenseRepository {
  listEntries(): Promise<ExpenseEntry[]>;
  getEntry(id: string): Promise<ExpenseEntry | null>;
  createEntry(input: CreateExpenseEntryInput): Promise<ExpenseEntry>;
  updateEntry(input: UpdateExpenseEntryInput): Promise<ExpenseEntry>;
  removeEntry(id: string): Promise<void>;
  getPeriodReport(from: string, to: string): Promise<PeriodReport>;
  getBillingStartDay(): Promise<number>;
  setBillingStartDay(startDay: number): Promise<number>;
  closeBillingPeriod(from: string, to: string): Promise<void>;
}
