import { endOfMonth } from '../shared/date';
import { IPV_DAILY_SALARY } from './ipv';
import { saleTaxes } from './tax';

export const IPV_OWNER_COUNT = 2;

export type IpvDayCut = {
  readonly grossProfit: number;
  readonly taxableGrossProfit: number;
  readonly salary: number;
  readonly otherExpenses: number;
  readonly expenseTotal: number;
  readonly tax: number;
  readonly tribute0114022: number;
  readonly tribute0510122: number;
  readonly utilidad: number;
  readonly net: number;
  readonly ownerShare: number;
};

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

export function ipvDayCut(input: {
  saleTotal: number;
  grossProfit: number;
  taxableGrossProfit?: number;
  salary?: number;
  otherExpenses?: number;
}): IpvDayCut {
  const salary = input.salary ?? IPV_DAILY_SALARY;
  const otherExpenses = input.otherExpenses ?? 0;
  const expenseTotal = roundMoney(salary + otherExpenses);
  const utilidad = roundMoney(input.grossProfit - expenseTotal);
  const taxes = saleTaxes(input.saleTotal);
  const net = roundMoney(utilidad - taxes.total);
  return {
    grossProfit: roundMoney(input.grossProfit),
    taxableGrossProfit: roundMoney(input.taxableGrossProfit ?? 0),
    salary,
    otherExpenses: roundMoney(otherExpenses),
    expenseTotal,
    tax: taxes.total,
    tribute0114022: taxes.tribute0114022,
    tribute0510122: taxes.tribute0510122,
    utilidad,
    net,
    ownerShare: roundMoney(net / IPV_OWNER_COUNT),
  };
}

export function taxableGrossProfit(
  lines: readonly { productId: string; grossProfit: number }[],
  products: readonly { id: string; countsForTax: boolean }[],
): number {
  return roundMoney(
    lines.reduce((sum, line) => {
      const product = products.find((item) => item.id === line.productId);
      const counts = product ? product.countsForTax : true;
      return sum + (counts ? line.grossProfit : 0);
    }, 0),
  );
}

export function otherExpensesOnDate(
  entries: readonly { occurredOn: string; name: string; amount: number; cadence: string }[],
  workDate: string,
): number {
  if (!workDate) {
    return 0;
  }
  const monthDays = Number(endOfMonth(workDate).slice(8, 10));
  return roundMoney(
    entries.reduce((sum, entry) => {
      if (entry.name === 'Salario') {
        return sum;
      }
      const start = entry.occurredOn.slice(0, 10);
      if (start > workDate) {
        return sum;
      }
      if (entry.cadence === 'daily') {
        return sum + entry.amount;
      }
      if (entry.cadence === 'weekly') {
        return sum + entry.amount / 7;
      }
      if (entry.cadence === 'monthly') {
        return sum + entry.amount / monthDays;
      }
      return start === workDate ? sum + entry.amount : sum;
    }, 0),
  );
}
