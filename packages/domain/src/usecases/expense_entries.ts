import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import { expenseCadences, type ExpenseCadence, type ExpenseEntry } from '../entities/expense';
import type { PeriodReport } from '../entities/period_report';
import type { ExpenseRepository } from '../repositories/expense_repository';
import { isBillingRange } from '../shared/billing_period';

function isCadence(value: string): value is ExpenseCadence {
  return expenseCadences.some((item) => item === value);
}

function requireExpense(input: { name: string; occurredOn: string; cadence: ExpenseCadence; amount: number }) {
  if (!input.name.trim() || !/^\d{4}-\d{2}-\d{2}$/.test(input.occurredOn) || input.amount < 0 || !isCadence(input.cadence)) {
    throw new DomainError('El gasto necesita concepto, fecha, frecuencia e importe.', InventoryErrorCodes.invalidInput);
  }
}

export class ListExpenseEntriesUseCase {
  constructor(private readonly expenseRepository: ExpenseRepository) {}

  execute(): Promise<ExpenseEntry[]> {
    return this.expenseRepository.listEntries();
  }
}

export class GetExpenseEntryUseCase {
  constructor(private readonly expenseRepository: ExpenseRepository) {}

  async execute(id: string): Promise<ExpenseEntry> {
    const entry = await this.expenseRepository.getEntry(id);
    if (!entry) {
      throw new DomainError('No encontramos ese gasto.', InventoryErrorCodes.notFound);
    }
    return entry;
  }
}

export class CreateExpenseEntryUseCase {
  constructor(private readonly expenseRepository: ExpenseRepository) {}

  execute(input: {
    name: string;
    occurredOn: string;
    cadence: ExpenseCadence;
    amount: number;
    notes: string;
    createdBy: string;
  }): Promise<ExpenseEntry> {
    requireExpense(input);
    return this.expenseRepository.createEntry({ ...input, name: input.name.trim() });
  }
}

export class UpdateExpenseEntryUseCase {
  constructor(private readonly expenseRepository: ExpenseRepository) {}

  execute(input: {
    id: string;
    name: string;
    occurredOn: string;
    cadence: ExpenseCadence;
    amount: number;
    notes: string;
  }): Promise<ExpenseEntry> {
    requireExpense(input);
    return this.expenseRepository.updateEntry({ ...input, name: input.name.trim() });
  }
}

export class DeleteExpenseEntryUseCase {
  constructor(private readonly expenseRepository: ExpenseRepository) {}

  execute(id: string): Promise<void> {
    return this.expenseRepository.removeEntry(id);
  }
}

export class GetPeriodReportUseCase {
  constructor(private readonly expenseRepository: ExpenseRepository) {}

  execute(from: string, to: string): Promise<PeriodReport> {
    if (!isBillingRange(from, to)) {
      throw new DomainError('El rango de fechas no es válido.', InventoryErrorCodes.invalidInput);
    }
    return this.expenseRepository.getPeriodReport(from, to);
  }
}

export class GetBillingPeriodUseCase {
  constructor(private readonly expenseRepository: ExpenseRepository) {}

  execute() {
    return this.expenseRepository.getBillingPeriod();
  }
}

export class SetBillingPeriodUseCase {
  constructor(private readonly expenseRepository: ExpenseRepository) {}

  execute(from: string, to: string) {
    if (!isBillingRange(from, to)) {
      throw new DomainError('El rango de fechas no es válido.', InventoryErrorCodes.invalidInput);
    }
    return this.expenseRepository.setBillingPeriod(from, to);
  }
}

export class CloseBillingPeriodUseCase {
  constructor(private readonly expenseRepository: ExpenseRepository) {}

  execute(from: string, to: string): Promise<void> {
    if (!isBillingRange(from, to)) {
      throw new DomainError('El rango de fechas no es válido.', InventoryErrorCodes.invalidInput);
    }
    return this.expenseRepository.closeBillingPeriod(from, to);
  }
}
