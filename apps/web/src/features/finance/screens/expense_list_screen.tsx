import { DomainError, ExpenseEntry, formatDateOnly, formatMoney } from '@wawa/domain';
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { useConfirm } from '../../../shared/ui/confirm_dialog';
import { DateRangeFields, ScrollTable, TableSpinner, inDateRange } from '../../../shared/ui/list_table';
import { ExportButtons } from '../../../shared/ui/export_buttons';

type SortKey = 'occurredOn' | 'name' | 'amount';

export function ExpenseListScreen() {
  const { container } = useAuth();
  const confirm = useConfirm();
  const [rows, setRows] = useState<ExpenseEntry[]>([]);
  const [pageError, setPageError] = useState('');
  const [loading, setLoading] = useState(true);
  const [fromDate, setFromDate] = useState('');
  const [toDate, setToDate] = useState('');
  const [sortKey, setSortKey] = useState<SortKey>('occurredOn');
  const [sortAsc, setSortAsc] = useState(false);
  const [deletingId, setDeletingId] = useState('');

  async function load() {
    setLoading(true);
    try {
      const period = await container.getBillingPeriod.execute();
      setRows(await container.listExpenseEntries.execute());
      setFromDate((current) => current || period.from);
      setToDate((current) => current || period.to);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load().catch((error) => {
      setLoading(false);
      setPageError(error instanceof DomainError ? error.message : 'No se pudieron cargar los gastos.');
    });
  }, [container]);

  const filtered = useMemo(
    () => rows.filter((entry) => inDateRange(entry.occurredOn, fromDate, toDate)),
    [rows, fromDate, toDate],
  );

  const sorted = useMemo(() => {
    return filtered.slice().sort((left, right) => {
      const direction = sortAsc ? 1 : -1;
      if (sortKey === 'occurredOn') {
        return left.occurredOn.localeCompare(right.occurredOn) * direction;
      }
      if (sortKey === 'name') {
        return left.name.localeCompare(right.name) * direction;
      }
      return (left.amount - right.amount) * direction;
    });
  }, [filtered, sortKey, sortAsc]);

  function toggleSort(key: SortKey) {
    if (sortKey === key) {
      setSortAsc((value) => !value);
      return;
    }
    setSortKey(key);
    setSortAsc(true);
  }

  async function handleDelete(id: string) {
    if (!(await confirm({ message: '¿Borrar este gasto?' }))) {
      return;
    }
    setDeletingId(id);
    setPageError('');
    try {
      await container.deleteExpenseEntry.execute(id);
      await load();
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo borrar el gasto.');
    } finally {
      setDeletingId('');
    }
  }

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold">Gastos</h1>
          <p className="mt-1 text-sm text-muted">
            Lista de gastos. Diario, semanal y mensual se calculan en el período de facturación desde la fecha.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <ExportButtons
            title="Gastos"
            fileName="gastos"
            columns={['Fecha', 'Concepto', 'Notas', 'Frecuencia', 'Importe']}
            rows={sorted.map((entry) => [
              formatDateOnly(entry.occurredOn),
              entry.name,
              entry.notes,
              ExpenseEntry.cadenceLabel(entry.cadence),
              formatMoney(entry.amount),
            ])}
            disabled={loading || sorted.length === 0}
          />
          <Link
            to="/finanzas/gastos/nuevo"
            className="page-cta btn-primary inline-flex h-12 items-center rounded-2xl px-5 text-sm font-semibold"
          >
            Registrar Gasto
          </Link>
        </div>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
      <DateRangeFields
        fromId="expense-from"
        toId="expense-to"
        from={fromDate}
        to={toDate}
        onFrom={setFromDate}
        onTo={setToDate}
      />
      <p className="text-sm text-muted">
        {loading ? 'Cargando Gastos...' : `${sorted.length} Gasto${sorted.length === 1 ? '' : 's'} En El Rango`}
      </p>
      <ScrollTable>
        <table className="min-w-full text-sm">
          <thead className="sticky top-0 z-10 bg-surface">
            <tr className="border-b border-line text-left">
              <th>
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('occurredOn')}>
                  Fecha
                </button>
              </th>
              <th>
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('name')}>
                  Concepto
                </button>
              </th>
              <th className="hidden px-4 py-3 font-semibold md:table-cell">Notas</th>
              <th className="px-4 py-3 font-semibold">Frecuencia</th>
              <th className="text-right">
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('amount')}>
                  Importe
                </button>
              </th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <TableSpinner colSpan={6} label="Cargando Gastos..." />
            ) : sorted.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-muted">
                  {rows.length === 0
                    ? 'No hay gastos. Pulsa Registrar Gasto para añadir el primero.'
                    : 'No hay gastos en esas fechas.'}
                </td>
              </tr>
            ) : (
              sorted.map((entry) => (
                <tr key={entry.id} className="border-t border-line">
                  <td className="px-4 py-3">{formatDateOnly(entry.occurredOn)}</td>
                  <td className="px-4 py-3">{entry.name}</td>
                  <td className="hidden px-4 py-3 md:table-cell">{entry.notes || '—'}</td>
                  <td className="px-4 py-3">{ExpenseEntry.cadenceLabel(entry.cadence)}</td>
                  <td className="px-4 py-3 text-right text-danger">{formatMoney(entry.amount)}</td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex justify-end gap-3">
                      <Link to={`/finanzas/gastos/${entry.id}`} className="font-semibold text-primary">
                        Ver
                      </Link>
                      <button
                        type="button"
                        className="text-danger"
                        disabled={deletingId === entry.id}
                        onClick={() => void handleDelete(entry.id)}
                      >
                        {deletingId === entry.id ? 'Borrando...' : 'Borrar'}
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </ScrollTable>
    </div>
  );
}
