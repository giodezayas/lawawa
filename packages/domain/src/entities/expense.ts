export const expenseKinds = ['fixed', 'variable'] as const;
export type ExpenseKind = (typeof expenseKinds)[number];

export const expenseCadences = ['once', 'daily', 'weekly', 'monthly'] as const;
export type ExpenseCadence = (typeof expenseCadences)[number];

export type ExpenseCategoryProps = {
  readonly id: string;
  readonly name: string;
  readonly kind: ExpenseKind;
  readonly cadence: ExpenseCadence;
  readonly defaultAmount: number;
  readonly isActive: boolean;
};

export type ExpenseCategory = Readonly<ExpenseCategoryProps>;

export type ExpenseEntryProps = {
  readonly id: string;
  readonly name: string;
  readonly occurredOn: string;
  readonly cadence: ExpenseCadence;
  readonly amount: number;
  readonly notes: string;
};

export type ExpenseEntry = Readonly<ExpenseEntryProps>;

export const ExpenseCategory = {
  create(props: ExpenseCategoryProps): ExpenseCategory {
    return Object.freeze({ ...props });
  },

  kindLabel(kind: ExpenseKind): string {
    return kind === 'fixed' ? 'Fijo' : 'Variable';
  },

  cadenceLabel(cadence: ExpenseCadence): string {
    switch (cadence) {
      case 'daily':
        return 'Diario';
      case 'weekly':
        return 'Semanal';
      case 'monthly':
        return 'Mensual';
      case 'once':
        return 'Una Vez';
    }
  },
};

export const ExpenseEntry = {
  create(props: ExpenseEntryProps): ExpenseEntry {
    return Object.freeze({ ...props });
  },

  cadenceLabel(cadence: ExpenseCadence): string {
    return ExpenseCategory.cadenceLabel(cadence);
  },
};
