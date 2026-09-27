import { DomainError, PurchaseDocument, formatDateOnly, formatMoney, type CashFlow } from '@wawa/domain';
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { useConfirm } from '../../../shared/ui/confirm_dialog';
import { CashFlowSummary } from '../../../shared/ui/cash_flow_summary';
import { DateRangeFields, ScrollTable, TableSpinner, inDateRange } from '../../../shared/ui/list_table';

type SortKey = 'purchasedOn' | 'total';

export function PurchaseListScreen() {
  const { container } = useAuth();
  const confirm = useConfirm();
  const [rows, setRows] = useState<Awaited<ReturnType<typeof container.listPurchases.execute>>>([]);
  const [flow, setFlow] = useState<CashFlow | null>(null);
  const [pageError, setPageError] = useState('');
  const [loading, setLoading] = useState(true);
  const [fromDate, setFromDate] = useState('');
  const [toDate, setToDate] = useState('');
  const [sortKey, setSortKey] = useState<SortKey>('purchasedOn');
  const [sortAsc, setSortAsc] = useState(false);
  const [deletingId, setDeletingId] = useState('');

  async function load() {
    setLoading(true);
    try {
      const period = await container.getBillingPeriod.execute();
      const [nextRows, nextFlow] = await Promise.all([
        container.listPurchases.execute(),
        container.getCashFlow.execute(period.from, period.to),
      ]);
      setRows(nextRows);
      setFlow(nextFlow);
      setFromDate((current) => current || period.from);
      setToDate((current) => current || period.to);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load().catch((error) => {
      setLoading(false);
      setPageError(error instanceof DomainError ? error.message : 'No se pudieron cargar las compras.');
    });
  }, [container]);

  async function handleDelete(id: string) {
    if (!(await confirm({ message: '¿Borrar esta compra? El stock se va a recalcular.' }))) {
      return;
    }
    setDeletingId(id);
    setPageError('');
    try {
      await container.deletePurchase.execute(id);
      await load();
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo borrar la compra.');
    } finally {
      setDeletingId('');
    }
  }

  const filtered = useMemo(
    () => rows.filter((document) => inDateRange(document.purchasedOn, fromDate, toDate)),
    [rows, fromDate, toDate],
  );

  const sorted = useMemo(() => {
    return filtered.slice().sort((left, right) => {
      const direction = sortAsc ? 1 : -1;
      if (sortKey === 'purchasedOn') {
        return left.purchasedOn.localeCompare(right.purchasedOn) * direction;
      }
      return (PurchaseDocument.total(left) - PurchaseDocument.total(right)) * direction;
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

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold">Compras</h1>
          <p className="mt-1 text-sm text-muted">
            Cada compra suma stock y actualiza el costo de reposición. El mismo producto se
            puede comprar todas las veces que haga falta.
          </p>
        </div>
        <Link
          to="/inventario/compras/nueva"
          className="page-cta btn-primary inline-flex h-12 items-center rounded-2xl px-5 text-sm font-semibold"
        >
          Registrar Compra
        </Link>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
      {flow ? <CashFlowSummary flow={flow} title="Caja Del Período" /> : null}
      <DateRangeFields
        fromId="purchase-from"
        toId="purchase-to"
        from={fromDate}
        to={toDate}
        onFrom={setFromDate}
        onTo={setToDate}
      />
      <p className="text-sm text-muted">
        {loading ? 'Cargando Compras...' : `${sorted.length} Compra${sorted.length === 1 ? '' : 's'} En El Rango`}
      </p>
      <ScrollTable>
        <table className="min-w-full text-sm">
          <thead className="sticky top-0 z-10 bg-surface">
            <tr className="border-b border-line text-left">
              <th>
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('purchasedOn')}>
                  Fecha
                </button>
              </th>
              <th className="px-4 py-3 font-semibold">Productos</th>
              <th className="px-4 py-3 font-semibold">Pago</th>
              <th className="text-right">
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('total')}>
                  Total
                </button>
              </th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <TableSpinner colSpan={5} label="Cargando Compras..." />
            ) : sorted.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-muted">
                  {rows.length === 0
                    ? 'No hay compras. Registra la primera para que el catálogo tenga stock.'
                    : 'No hay compras en esas fechas.'}
                </td>
              </tr>
            ) : (
              sorted.map((document) => (
                <tr key={document.id} className="border-t border-line">
                  <td className="px-4 py-3">{formatDateOnly(document.purchasedOn)}</td>
                  <td className="px-4 py-3">
                    {document.lines.map((line) => `${line.productName} (${line.qty})`).join(', ')}
                  </td>
                  <td className="px-4 py-3">{PurchaseDocument.paymentLabel(document.paymentMethod)}</td>
                  <td className="px-4 py-3 text-right">{formatMoney(PurchaseDocument.total(document))}</td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex justify-end gap-3">
                      <Link to={`/inventario/compras/${document.id}`} className="font-semibold text-primary">
                        Ver
                      </Link>
                      <button
                        type="button"
                        className="text-danger"
                        disabled={deletingId === document.id}
                        onClick={() => void handleDelete(document.id)}
                      >
                        {deletingId === document.id ? 'Borrando...' : 'Borrar'}
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
