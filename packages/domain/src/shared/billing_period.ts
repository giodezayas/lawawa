import { addDays, endOfMonth, startOfMonth, todayIsoDate } from './date';

export const BILLING_START_DAY_MIN = 1;
export const BILLING_START_DAY_MAX = 28;

function clampStartDay(startDay: number): number {
  if (!Number.isFinite(startDay)) {
    return 1;
  }
  return Math.min(BILLING_START_DAY_MAX, Math.max(BILLING_START_DAY_MIN, Math.trunc(startDay)));
}

function isoFromParts(year: number, monthIndex: number, day: number): string {
  const date = new Date(year, monthIndex, day);
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function billingPeriodContaining(isoDate = todayIsoDate(), startDay = 1): { from: string; to: string } {
  const day = clampStartDay(startDay);
  if (day === 1) {
    return { from: startOfMonth(isoDate), to: endOfMonth(isoDate) };
  }

  const date = new Date(`${isoDate}T00:00:00`);
  const year = date.getFullYear();
  const monthIndex = date.getMonth();
  const dateDay = date.getDate();

  if (dateDay >= day) {
    return {
      from: isoFromParts(year, monthIndex, day),
      to: isoFromParts(year, monthIndex + 1, day - 1),
    };
  }

  return {
    from: isoFromParts(year, monthIndex - 1, day),
    to: isoFromParts(year, monthIndex, day - 1),
  };
}

export function shiftBillingPeriod(from: string, to: string, startDay: number, direction: number): { from: string; to: string } {
  const pivot = direction > 0 ? addDays(to, 1) : addDays(from, -1);
  return billingPeriodContaining(pivot, startDay);
}

export function billingPeriodLabel(startDay: number): string {
  const day = clampStartDay(startDay);
  return day === 1 ? 'Del Día 1 Al Último Del Mes' : `Del Día ${day} Al ${day - 1} Del Mes Siguiente`;
}
