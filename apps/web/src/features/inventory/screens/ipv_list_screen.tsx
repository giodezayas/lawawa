import { DomainError, IpvDocument, User, formatDateOnly, formatMoney } from '@wawa/domain';
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { useConfirm } from '../../../shared/ui/confirm_dialog';
import { DateRangeFields, TableSpinner, inDateRange } from '../../../shared/ui/list_table';
import { ExportButtons } from '../../../shared/ui/export_buttons';
import { moneyTone } from '../../../shared/ui/money_tone';

type SortKey = 'workDate' | 'status';

export function IpvListScreen() {
  const { container, user } = useAuth();
  const canEditClosed = user ? User.canManageStaff(user) : false;
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
    <div className="mx-auto max-w-6xl min-w-0 space-y-6 overflow-x-hidden">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold">IPV</h1>
          <p className="mt-1 text-sm text-muted">
            Un IPV por día. Al crearlo se cargan los productos con stock. Manager y admin pueden corregir uno cerrado.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <ExportButtons
            title="IPV"
            fileName="ipv"
            columns={['Fecha', 'Estado', 'Total Venta', 'Efectivo', 'Tarjeta P', 'Tarjeta F', 'Ganancia Bruta']}
            rows={sorted.map((document) => [
              formatDateOnly(document.workDate),
              IpvDocument.statusLabel(document.status),
              document.lines.length > 0 ? formatMoney(IpvDocument.saleTotal(document)) : '',
              formatMoney(document.cashCollected),
              formatMoney(document.transferPCollected),
              formatMoney(document.transferFCollected),
              document.lines.length > 0 ? formatMoney(IpvDocument.grossProfit(document)) : '',
            ])}
            disabled={loading || sorted.length === 0}
          />
          <Link
            to="/inventario/ipv/nuevo"
            className="page-cta btn-primary inline-flex h-12 items-center rounded-2xl px-5 text-sm font-semibold"
          >
            Crear IPV
          </Link>
        </div>
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
      <div className="max-h-[32rem] overflow-y-auto overflow-x-hidden rounded-3xl border border-line bg-surface">
        <table className="w-full table-fixed text-sm">
          <thead className="sticky top-0 z-10 bg-surface">
            <tr className="border-b border-line text-left">
              <th className="w-[12%]">
                <button type="button" className="px-2 py-3 font-semibold" onClick={() => toggleSort('workDate')}>
                  Fecha
                </button>
              </th>
              <th className="w-[10%]">
                <button type="button" className="px-2 py-3 font-semibold" onClick={() => toggleSort('status')}>
                  Estado
                </button>
              </th>
              <th className="w-[13%] px-2 py-3 text-right font-semibold">Venta</th>
              <th className="w-[12%] px-2 py-3 text-right font-semibold">Efectivo</th>
              <th className="w-[11%] px-2 py-3 text-right font-semibold">Tarjeta P</th>
              <th className="w-[11%] px-2 py-3 text-right font-semibold">Tarjeta F</th>
              <th className="w-[13%] px-2 py-3 text-right font-semibold">Ganancia</th>
              <th className="w-[18%] px-2 py-3" />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <TableSpinner colSpan={8} label="Cargando IPV..." />
            ) : sorted.length === 0 ? (
              <tr>
                <td colSpan={8} className="px-4 py-8 text-center text-muted">
                  {rows.length === 0 ? 'No hay IPV todavía. Crea el del día.' : 'No hay IPV en esas fechas.'}
                </td>
              </tr>
            ) : (
              sorted.map((document) => {
                const saleTotal = IpvDocument.saleTotal(document);
                const profit = IpvDocument.grossProfit(document);
                return (
                  <tr key={document.id} className="border-t border-line">
                    <td className="truncate px-2 py-3">{formatDateOnly(document.workDate)}</td>
                    <td className="truncate px-2 py-3">{IpvDocument.statusLabel(document.status)}</td>
                    <td className="px-2 py-3 text-right">
                      {document.lines.length > 0 ? formatMoney(saleTotal) : '—'}
                    </td>
                    <td className="px-2 py-3 text-right">{formatMoney(document.cashCollected)}</td>
                    <td className="px-2 py-3 text-right">{formatMoney(document.transferPCollected)}</td>
                    <td className="px-2 py-3 text-right">{formatMoney(document.transferFCollected)}</td>
                    <td className={`px-2 py-3 text-right ${document.lines.length > 0 ? moneyTone(profit) : ''}`}>
                      {document.lines.length > 0 ? formatMoney(profit) : '—'}
                    </td>
                    <td className="px-2 py-3 text-right">
                      <div className="flex flex-wrap justify-end gap-2">
                        <Link to={`/inventario/ipv/${document.id}`} className="font-semibold text-primary">
                          {IpvDocument.isOpen(document) || canEditClosed ? 'Continuar' : 'Ver'}
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
      </div>
    </div>
  );
}
