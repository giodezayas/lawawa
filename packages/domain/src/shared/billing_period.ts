import { addDays, endOfMonth, startOfMonth, todayIsoDate } from './date';

export type BillingPeriodBounds = { from: string; to: string };

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

export function isBillingRange(from: string, to: string): boolean {
  return ISO_DATE.test(from) && ISO_DATE.test(to) && to >= from;
}

export function defaultBillingPeriod(): BillingPeriodBounds {
  const today = todayIsoDate();
  return { from: startOfMonth(today), to: today };
}

export function isLiveCurrentMonth(from: string, to: string): boolean {
  const live = defaultBillingPeriod();
  return from === live.from && to === live.to;
}

export function shiftCalendarMonth(from: string, direction: number): BillingPeriodBounds {
  const date = new Date(`${from.slice(0, 7)}-01T00:00:00`);
  date.setMonth(date.getMonth() + direction);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const start = `${year}-${month}-01`;
  const end = endOfMonth(start);
  const today = todayIsoDate();
  if (start <= today && today <= end) {
    return { from: start, to: today };
  }
  return { from: start, to: end };
}

export function previousCalendarMonth(): BillingPeriodBounds {
  return shiftCalendarMonth(startOfMonth(), -1);
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
