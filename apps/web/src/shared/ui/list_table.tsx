import type { ReactNode } from 'react';
import { defaultBillingPeriod, formatDateOnly, shiftCalendarMonth } from '@wawa/domain';
import { TextField } from './text_field';

export function DateRangeFields({
  fromId,
  toId,
  from,
  to,
  onFrom,
  onTo,
  onRange,
}: {
  fromId: string;
  toId: string;
  from: string;
  to: string;
  onFrom: (value: string) => void;
  onTo: (value: string) => void;
  onRange?: (from: string, to: string) => void;
}) {
  function apply(next: { from: string; to: string }) {
    if (onRange) {
      onRange(next.from, next.to);
      return;
    }
    onFrom(next.from);
    onTo(next.to);
  }

  const anchor = from || to || undefined;

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center gap-3">
        <button
          type="button"
          className="btn-outline h-10 rounded-2xl px-4 text-sm font-semibold"
          onClick={() => apply(shiftCalendarMonth(anchor ?? defaultBillingPeriod().from, -1))}
        >
          Anterior
        </button>
        <p className="text-sm font-semibold">
          {from && to ? `${formatDateOnly(from)} — ${formatDateOnly(to)}` : 'Mes En Curso'}
        </p>
        <button
          type="button"
          className="btn-outline h-10 rounded-2xl px-4 text-sm font-semibold"
          onClick={() => apply(shiftCalendarMonth(anchor ?? defaultBillingPeriod().from, 1))}
        >
          Siguiente
        </button>
        <button
          type="button"
          className="btn-outline h-10 rounded-2xl px-4 text-sm font-semibold"
          onClick={() => apply(defaultBillingPeriod())}
        >
          Este Mes
        </button>
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        <TextField
          id={fromId}
          label="Desde"
          type="date"
          value={from}
          onChange={(event) => onFrom(event.target.value)}
        />
        <TextField id={toId} label="Hasta" type="date" value={to} onChange={(event) => onTo(event.target.value)} />
      </div>
    </div>
  );
}

export function inDateRange(iso: string, from: string, to: string) {
  if (from && iso < from) {
    return false;
  }
  if (to && iso > to) {
    return false;
  }
  return true;
}

export function ScrollTable({ children }: { children: ReactNode }) {
  return <div className="max-h-[28rem] overflow-auto rounded-3xl border border-line bg-surface">{children}</div>;
}

export function TableSpinner({ colSpan, label }: { colSpan: number; label: string }) {
  return (
    <tr>
      <td colSpan={colSpan} className="px-4 py-16">
        <div className="flex flex-col items-center gap-3">
          <div
            className="h-10 w-10 animate-spin rounded-full border-2 border-primary/20 border-t-primary"
            aria-hidden="true"
          />
          <p className="text-sm text-muted">{label}</p>
        </div>
      </td>
    </tr>
  );
}
