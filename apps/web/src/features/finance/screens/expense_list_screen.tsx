import { DomainError, ExpenseEntry, formatDateOnly, formatMoney } from '@wawa/domain';
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';

type SortKey = 'occurredOn' | 'name' | 'amount';

export function ExpenseListScreen() {
  const { container } = useAuth();
  const [rows, setRows] = useState<ExpenseEntry[]>([]);
  const [pageError, setPageError] = useState('');
  const [sortKey, setSortKey] = useState<SortKey>('occurredOn');
  const [sortAsc, setSortAsc] = useState(false);
  const [deletingId, setDeletingId] = useState('');

  async function load() {
    setRows(await container.listExpenseEntries.execute());
  }

  useEffect(() => {
    void load().catch((error) => {
      setPageError(error instanceof DomainError ? error.message : 'No se pudieron cargar los gastos.');
    });
  }, [container]);

  const sorted = useMemo(() => {
    return rows.slice().sort((left, right) => {
      const direction = sortAsc ? 1 : -1;
      if (sortKey === 'occurredOn') {
        return left.occurredOn.localeCompare(right.occurredOn) * direction;
      }
      if (sortKey === 'name') {
        return left.name.localeCompare(right.name) * direction;
      }
      return (left.amount - right.amount) * direction;
    });
  }, [rows, sortKey, sortAsc]);

  function toggleSort(key: SortKey) {
    if (sortKey === key) {
      setSortAsc((value) => !value);
      return;
    }
    setSortKey(key);
    setSortAsc(true);
  }

  async function handleDelete(id: string) {
    if (!window.confirm('¿Borrar este gasto?')) {
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
        <Link
          to="/finanzas/gastos/nuevo"
          className="page-cta btn-primary inline-flex h-12 items-center rounded-2xl px-5 text-sm font-semibold"
        >
          Registrar Gasto
        </Link>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
      <div className="overflow-x-auto rounded-3xl border border-line bg-surface">
        <table className="min-w-full text-sm">
          <thead>
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
            {sorted.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-muted">
                  No hay gastos. Pulsa Registrar Gasto para añadir el primero.
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
      </div>
    </div>
  );
}
