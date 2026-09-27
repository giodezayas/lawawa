import { DomainError, IpvDocument, formatDateOnly, formatMoney } from '@wawa/domain';
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { useConfirm } from '../../../shared/ui/confirm_dialog';
import { DateRangeFields, ScrollTable, TableSpinner, inDateRange } from '../../../shared/ui/list_table';
import { moneyTone } from '../../../shared/ui/money_tone';

type SortKey = 'workDate' | 'status';

export function IpvListScreen() {
  const { container } = useAuth();
  const confirm = useConfirm();
  const [rows, setRows] = useState<Awaited<ReturnType<typeof container.listIpvs.execute>>>([]);
  const [pageError, setPageError] = useState('');
  const [loading, setLoading] = useState(true);
  const [fromDate, setFromDate] = useState('');
  const [toDate, setToDate] = useState('');
  const [sortKey, setSortKey] = useState<SortKey>('workDate');
  const [sortAsc, setSortAsc] = useState(false);
  const [deletingId, setDeletingId] = useState('');

  async function load() {
    setLoading(true);
    try {
      const period = await container.getBillingPeriod.execute();
      setRows(await container.listIpvs.execute());
      setFromDate((current) => current || period.from);
      setToDate((current) => current || period.to);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load().catch((error) => {
      setLoading(false);
      setPageError(error instanceof DomainError ? error.message : 'No se pudieron cargar los IPV.');
    });
  }, [container]);

  async function handleDelete(id: string) {
    if (!(await confirm({ message: '¿Borrar este IPV? El stock del catálogo se va a recalcular.' }))) {
      return;
    }
    setDeletingId(id);
    setPageError('');
    try {
      await container.deleteIpv.execute(id);
      await load();
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo borrar el IPV.');
    } finally {
      setDeletingId('');
    }
  }

  const filtered = useMemo(
    () => rows.filter((document) => inDateRange(document.workDate, fromDate, toDate)),
    [rows, fromDate, toDate],
  );

  const sorted = useMemo(() => {
    return filtered.slice().sort((left, right) => {
      const direction = sortAsc ? 1 : -1;
      return left[sortKey].localeCompare(right[sortKey]) * direction;
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
          <h1 className="text-2xl font-extrabold">IPV</h1>
          <p className="mt-1 text-sm text-muted">
            Un IPV por día. Al crearlo se cargan los productos con stock. Al cerrar ya no se edita.
          </p>
        </div>
        <Link
          to="/inventario/ipv/nuevo"
          className="page-cta btn-primary inline-flex h-12 items-center rounded-2xl px-5 text-sm font-semibold"
        >
          Crear IPV
        </Link>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
      <DateRangeFields
        fromId="ipv-from"
        toId="ipv-to"
        from={fromDate}
        to={toDate}
        onFrom={setFromDate}
        onTo={setToDate}
      />
      <p className="text-sm text-muted">
        {loading ? 'Cargando IPV...' : `${sorted.length} IPV En El Rango`}
      </p>
      <ScrollTable>
        <table className="min-w-full text-sm">
          <thead className="sticky top-0 z-10 bg-surface">
            <tr className="border-b border-line text-left">
              <th>
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('workDate')}>
                  Fecha
                </button>
              </th>
              <th>
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('status')}>
                  Estado
                </button>
              </th>
              <th className="px-4 py-3 text-right font-semibold">Total Venta</th>
              <th className="hidden px-4 py-3 text-right font-semibold md:table-cell">Efectivo</th>
              <th className="hidden px-4 py-3 text-right font-semibold md:table-cell">Transferencia</th>
              <th className="hidden px-4 py-3 text-right font-semibold md:table-cell">Ganancia Bruta</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <TableSpinner colSpan={7} label="Cargando IPV..." />
            ) : sorted.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-muted">
                  {rows.length === 0 ? 'No hay IPV todavía. Crea el del día.' : 'No hay IPV en esas fechas.'}
                </td>
              </tr>
            ) : (
              sorted.map((document) => {
                const saleTotal = IpvDocument.saleTotal(document);
                const profit = IpvDocument.grossProfit(document);
                return (
                  <tr key={document.id} className="border-t border-line">
                    <td className="px-4 py-3">{formatDateOnly(document.workDate)}</td>
                    <td className="px-4 py-3">{IpvDocument.statusLabel(document.status)}</td>
                    <td className="px-4 py-3 text-right">
                      {document.lines.length > 0 ? formatMoney(saleTotal) : '—'}
                    </td>
                    <td className="hidden px-4 py-3 text-right md:table-cell">{formatMoney(document.cashCollected)}</td>
                    <td className="hidden px-4 py-3 text-right md:table-cell">{formatMoney(document.transferCollected)}</td>
                    <td className={`hidden px-4 py-3 text-right md:table-cell ${document.lines.length > 0 ? moneyTone(profit) : ''}`}>
                      {document.lines.length > 0 ? formatMoney(profit) : '—'}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <div className="flex justify-end gap-3">
                        <Link to={`/inventario/ipv/${document.id}`} className="font-semibold text-primary">
                          {IpvDocument.isOpen(document) ? 'Continuar' : 'Ver'}
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
                );
              })
            )}
          </tbody>
        </table>
      </ScrollTable>
    </div>
  );
}
