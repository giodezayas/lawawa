function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

export const SALE_TAX_0114022_RATE = 0.1;
export const SALE_TAX_0510122_RATE = 0.05;
export const SALE_TAX_0510122_EXEMPT = 3260;
export const DECLARED_MONTHLY_SALARY = 7000;
export const SALARY_TAX_0810132_RATE = 0.125;
export const SALARY_TAX_0820232_RATE = 0.05;
export const SALARY_TAX_0520522_RATE = 0.03;
export const SALARY_TAX_0520522_EXEMPT = 3740;

export type SaleTaxBreakdown = {
  readonly tribute0114022: number;
  readonly tribute0510122: number;
  readonly total: number;
};

export type SalaryTaxBreakdown = {
  readonly declaredSalary: number;
  readonly tribute0810132: number;
  readonly tribute0820232: number;
  readonly tribute0520522: number;
  readonly total: number;
};

export type PeriodTaxBreakdown = {
  readonly sale: SaleTaxBreakdown;
  readonly salary: SalaryTaxBreakdown;
  readonly total: number;
};

export function saleTaxes(saleTotal: number): SaleTaxBreakdown {
  const tribute0114022 = roundMoney(Math.max(saleTotal, 0) * SALE_TAX_0114022_RATE);
  const tribute0510122 = roundMoney(Math.max(saleTotal - SALE_TAX_0510122_EXEMPT, 0) * SALE_TAX_0510122_RATE);
  return {
    tribute0114022,
    tribute0510122,
    total: roundMoney(tribute0114022 + tribute0510122),
  };
}

export function salaryTaxes(): SalaryTaxBreakdown {
  const tribute0810132 = roundMoney(DECLARED_MONTHLY_SALARY * SALARY_TAX_0810132_RATE);
  const tribute0820232 = roundMoney(DECLARED_MONTHLY_SALARY * SALARY_TAX_0820232_RATE);
  const tribute0520522 = roundMoney(
    Math.max(DECLARED_MONTHLY_SALARY - SALARY_TAX_0520522_EXEMPT, 0) * SALARY_TAX_0520522_RATE,
  );
  return {
    declaredSalary: DECLARED_MONTHLY_SALARY,
    tribute0810132,
    tribute0820232,
    tribute0520522,
    total: roundMoney(tribute0810132 + tribute0820232 + tribute0520522),
  };
}

export function periodTaxes(saleTotal: number): PeriodTaxBreakdown {
  const sale = saleTaxes(saleTotal);
  const salary = salaryTaxes();
  return {
    sale,
    salary,
    total: roundMoney(sale.total + salary.total),
  };
}

export function applyPeriodTaxes<T extends { saleTotal: number; utilidad: number; tax: number; net: number }>(report: T): T {
  const taxes = periodTaxes(report.saleTotal);
  return {
    ...report,
    tax: taxes.total,
    net: roundMoney(report.utilidad - taxes.total),
  };
}
