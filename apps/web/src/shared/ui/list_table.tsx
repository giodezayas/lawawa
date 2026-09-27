import type { ReactNode } from 'react';
import { TextField } from './text_field';

export function DateRangeFields({
  fromId,
  toId,
  from,
  to,
  onFrom,
  onTo,
}: {
  fromId: string;
  toId: string;
  from: string;
  to: string;
  onFrom: (value: string) => void;
  onTo: (value: string) => void;
}) {
  return (
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
