import { addDays, todayIsoDate } from './date';

export type BillingPeriodBounds = { from: string; to: string };

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

export function isBillingRange(from: string, to: string): boolean {
  return ISO_DATE.test(from) && ISO_DATE.test(to) && to >= from;
}

export function defaultBillingPeriod(): BillingPeriodBounds {
  return { from: '2026-08-31', to: todayIsoDate() };
}

export function shiftBillingRange(from: string, to: string, direction: number): BillingPeriodBounds {
  const start = new Date(`${from}T00:00:00`);
  const end = new Date(`${to}T00:00:00`);
  const span = Math.round((end.getTime() - start.getTime()) / 86400000) + 1;
  if (direction > 0) {
    const nextFrom = addDays(to, 1);
    return { from: nextFrom, to: addDays(nextFrom, span - 1) };
  }
  const nextTo = addDays(from, -1);
  return { from: addDays(nextTo, -(span - 1)), to: nextTo };
}
