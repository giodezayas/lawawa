import {
  DomainError,
  IpvDocument,
  IpvLine,
  User,
  formatDateOnly,
  formatMoney,
  todayIsoDate,
  toMoneyNumber,
  type Product,
} from '@wawa/domain';
import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { useConfirm } from '../../../shared/ui/confirm_dialog';
import { PrimaryButton } from '../../../shared/ui/primary_button';
import { ProductSearchSelect } from '../../../shared/ui/product_search_select';
import { TextField } from '../../../shared/ui/text_field';
import { moneyTone } from '../../../shared/ui/money_tone';
import { ExportButtons } from '../../../shared/ui/export_buttons';

type DraftLine = {
  productId: string;
  productName: string;
  openingQty: string;
  inboundQty: string;
  outboundQty: string;
  soldQty: string;
  salePrice: string;
  replenishmentCost: string;
  inboundAddsStock: boolean;
};

const emptyDraft: DraftLine = {
  productId: '',
  productName: '',
  openingQty: '',
  inboundQty: '',
  outboundQty: '',
  soldQty: '',
  salePrice: '',
  replenishmentCost: '',
  inboundAddsStock: false,
};

function toQty(value: string): number {
  const parsed = Number.parseFloat(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function IpvEditorScreen() {
  const { ipvId } = useParams();
  const isCreate = ipvId === undefined;
  const navigate = useNavigate();
  const { container, user } = useAuth();
  const confirm = useConfirm();
  const [products, setProducts] = useState<Product[]>([]);
  const [document, setDocument] = useState<IpvDocument | null>(null);
  const [workDate, setWorkDate] = useState(todayIsoDate());
  const [draft, setDraft] = useState<DraftLine>(emptyDraft);
  const [cashCollected, setCashCollected] = useState('');
  const [transferPCollected, setTransferPCollected] = useState('');
  const [transferFCollected, setTransferFCollected] = useState('');
  const [savingCollections, setSavingCollections] = useState(false);
  const [pageError, setPageError] = useState('');
  const [lineError, setLineError] = useState('');
  const [saving, setSaving] = useState(false);
  const [closing, setClosing] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const canEditClosed = user ? User.canManageStaff(user) : false;
  const locked = document ? !IpvDocument.isOpen(document) && !canEditClosed : false;
  const isClosed = document ? !IpvDocument.isOpen(document) : false;

  useEffect(() => {
    void container.listProducts.execute().then(setProducts);
  }, [container]);

  useEffect(() => {
    if (!ipvId) {
      return;
    }
    void container.getIpv
      .execute(ipvId)
      .then((next) => {
        setDocument(next);
        setCashCollected(String(next.cashCollected));
        setTransferPCollected(String(next.transferPCollected));
        setTransferFCollected(String(next.transferFCollected));
      })
      .catch((error) => {
        setPageError(error instanceof DomainError ? error.message : 'No se pudo abrir el IPV.');
      });
  }, [container, ipvId]);

  const totals = useMemo(() => {
    const lines = document?.lines ?? [];
    const saleTotal = lines.reduce((sum, line) => sum + line.saleTotal, 0);
    const profit = lines.reduce((sum, line) => sum + line.grossProfit, 0);
    return {
      products: lines.length,
      soldQty: lines.reduce((sum, line) => sum + line.soldQty, 0),
      saleTotal,
      profit,
      cost: saleTotal - profit,
    };
  }, [document]);

  const preview = IpvLine.compute({
    openingQty: toQty(draft.openingQty),
    inboundQty: toQty(draft.inboundQty),
    outboundQty: toQty(draft.outboundQty),
    soldQty: toQty(draft.soldQty),
    salePrice: toQty(draft.salePrice),
    replenishmentCost: toQty(draft.replenishmentCost),
  });

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!user) {
      return;
    }
    setPageError('');
    setSaving(true);
    try {
      const created = await container.createIpv.execute({
        workDate,
        createdBy: user.id,
      });
      navigate(`/inventario/ipv/${created.id}`, { replace: true });
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo crear el IPV.');
    } finally {
      setSaving(false);
    }
  }

  function selectProduct(product: Product) {
    setDraft((current) => ({
      ...current,
      productId: product.id,
      productName: product.name,
      openingQty: current.openingQty || String(product.stockQty),
      salePrice: current.salePrice || String(product.salePrice),
      replenishmentCost: current.replenishmentCost || String(product.replenishmentCost),
    }));
  }

  async function addLine(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!document || locked) {
      return;
    }
    setLineError('');
    if (!draft.productId) {
      setLineError('Elige un producto del catálogo.');
      return;
    }

    try {
      await container.upsertIpvLine.execute({
        ipvId: document.id,
        productId: draft.productId,
        productName: draft.productName,
        openingQty: toQty(draft.openingQty),
        inboundQty: toQty(draft.inboundQty),
        outboundQty: toQty(draft.outboundQty),
        soldQty: toQty(draft.soldQty),
        salePrice: toQty(draft.salePrice),
        replenishmentCost: toQty(draft.replenishmentCost),
        inboundAddsStock: draft.inboundAddsStock,
        sortOrder: document.lines.length,
      });
      const next = await container.getIpv.execute(document.id);
      setDocument(next);
      setDraft(emptyDraft);
    } catch (error) {
      setLineError(error instanceof DomainError ? error.message : 'No se pudo agregar la línea.');
    }
  }

  async function removeLine(lineId: string) {
    if (!document || locked) {
      return;
    }
    if (!(await confirm({ message: '¿Quitar este producto del IPV?' }))) {
      return;
    }
    await container.removeIpvLine.execute(lineId);
    setDocument(await container.getIpv.execute(document.id));
  }

  async function saveCollections() {
    if (!document || locked) {
      return;
    }
    setPageError('');
    setSavingCollections(true);
    try {
      const next = await container.updateIpvCollections.execute(
        document.id,
        toMoneyNumber(cashCollected),
        toMoneyNumber(transferPCollected),
        toMoneyNumber(transferFCollected),
      );
      setDocument(next);
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo guardar la caja.');
    } finally {
      setSavingCollections(false);
    }
  }

  async function closeIpv() {
    if (!document || !user) {
      return;
    }
    setPageError('');
    setClosing(true);
    try {
      await container.updateIpvCollections.execute(
        document.id,
        toMoneyNumber(cashCollected),
        toMoneyNumber(transferPCollected),
        toMoneyNumber(transferFCollected),
      );
      const closed = await container.closeIpv.execute(document.id, user.id);
      setDocument(closed);
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo cerrar el IPV.');
    } finally {
      setClosing(false);
    }
  }

  async function deleteIpv() {
    if (!document || !(await confirm({ message: '¿Borrar este IPV?' }))) {
      return;
    }
    setDeleting(true);
    setPageError('');
    try {
      await container.deleteIpv.execute(document.id);
      navigate('/inventario/ipv');
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo borrar el IPV.');
    } finally {
      setDeleting(false);
    }
  }

  if (isCreate) {
    return (
      <div className="mx-auto max-w-xl space-y-6">
        <div>
          <h1 className="text-2xl font-extrabold">Crear IPV</h1>
          <p className="mt-1 text-sm text-muted">
            Un solo documento por día. Al crearlo se cargan solos los productos con stock.
          </p>
        </div>
        {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
        <form onSubmit={(event) => void handleCreate(event)} className="space-y-4 rounded-3xl border border-line bg-surface p-5">
          <TextField
            id="work-date"
            label="Fecha"
            type="date"
            required
            value={workDate}
            onChange={(event) => setWorkDate(event.target.value)}
          />
          <PrimaryButton type="submit" loading={saving} className="w-full">
            Crear IPV
          </PrimaryButton>
        </form>
      </div>
    );
  }

  if (!document) {
    return pageError ? <p className="text-sm text-danger">{pageError}</p> : <p className="text-sm text-muted">Cargando IPV...</p>;
  }

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm text-muted">
            {formatDateOnly(document.workDate)}
          </p>
          <h1 className="text-2xl font-extrabold">IPV {IpvDocument.statusLabel(document.status)}</h1>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <ExportButtons
            title={`IPV ${formatDateOnly(document.workDate)}`}
            fileName={`ipv_${document.workDate}`}
            columns={[
              'Producto',
              'Inicio',
              'Entradas',
              'Salidas',
              'Vendidos',
              'P. Venta',
              'Costo',
              'Stock Final',
              'Total Venta',
              'Ganancia Bruta',
            ]}
            rows={document.lines.map((line) => [
              line.productName,
              String(line.openingQty),
              String(line.inboundQty),
              String(line.outboundQty),
              String(line.soldQty),
              formatMoney(line.salePrice),
              formatMoney(line.replenishmentCost),
              String(line.closingQty),
              formatMoney(line.saleTotal),
              formatMoney(line.grossProfit),
            ])}
            disabled={document.lines.length === 0}
          />
          <Link to="/inventario/ipv" className="text-sm font-semibold text-primary">
            Volver A La Lista
          </Link>
        </div>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}

      <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <article className="rounded-3xl border border-line bg-white px-5 py-4">
          <p className="text-sm font-medium text-primary">Productos En El IPV</p>
          <p className="mt-1 text-2xl font-extrabold">{totals.products}</p>
        </article>
        <article className="rounded-3xl border border-line bg-white px-5 py-4">
          <p className="text-sm font-medium text-primary">Unidades Vendidas</p>
          <p className="mt-1 text-2xl font-extrabold">{totals.soldQty}</p>
        </article>
        <article className="rounded-3xl border border-line bg-white px-5 py-4">
          <p className="text-sm font-medium text-primary">Total De Venta</p>
          <p className="mt-1 text-right text-2xl font-extrabold">{formatMoney(totals.saleTotal)}</p>
        </article>
        <article className="rounded-3xl border border-line bg-white px-5 py-4">
          <p className="text-sm font-medium text-primary">Ganancia Bruta</p>
          <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(totals.profit)}`}>
            {formatMoney(totals.profit)}
          </p>
          <p className="mt-1 text-right text-xs text-muted">Costo De Lo Vendido {formatMoney(totals.cost)}</p>
        </article>
      </section>

      <form
        onSubmit={(event) => {
          event.preventDefault();
          void saveCollections();
        }}
        className="space-y-4 rounded-3xl border border-line bg-surface p-5"
      >
        <div className="flex flex-wrap items-end justify-between gap-2">
          <h2 className="text-sm font-semibold text-primary">Recaudo Del Día</h2>
          <Link to="/finanzas/tarjetas" className="text-sm font-semibold text-primary">
            Ver Tarjetas
          </Link>
        </div>
        <div className="grid gap-3 sm:grid-cols-3">
          <TextField
            id="cash-collected"
            label="Efectivo"
            inputMode="decimal"
            value={cashCollected}
            disabled={locked}
            onChange={(event) => setCashCollected(event.target.value)}
          />
          <div className="rounded-3xl border-2 border-accent bg-white p-3">
            <TextField
              id="transfer-p-collected"
              label="Tarjeta P"
              inputMode="decimal"
              value={transferPCollected}
              disabled={locked}
              onChange={(event) => setTransferPCollected(event.target.value)}
            />
          </div>
          <div className="rounded-3xl border-2 border-accent bg-white p-3">
            <TextField
              id="transfer-f-collected"
              label="Tarjeta F"
              inputMode="decimal"
              value={transferFCollected}
              disabled={locked}
              onChange={(event) => setTransferFCollected(event.target.value)}
            />
          </div>
        </div>
        <p className="text-sm text-muted">
          Venta {formatMoney(totals.saleTotal)} · Recaudado{' '}
          {formatMoney(
            toMoneyNumber(cashCollected) + toMoneyNumber(transferPCollected) + toMoneyNumber(transferFCollected),
          )}{' '}
          · Diferencia{' '}
          <span
            className={moneyTone(
              toMoneyNumber(cashCollected) +
                toMoneyNumber(transferPCollected) +
                toMoneyNumber(transferFCollected) -
                totals.saleTotal,
            )}
          >
            {formatMoney(
              toMoneyNumber(cashCollected) +
                toMoneyNumber(transferPCollected) +
                toMoneyNumber(transferFCollected) -
                totals.saleTotal,
            )}
          </span>
        </p>
        {locked ? null : (
          <PrimaryButton type="submit" loading={savingCollections}>
            Guardar Caja
          </PrimaryButton>
        )}
      </form>

      {locked ? null : (
        <form onSubmit={(event) => void addLine(event)} className="space-y-4 rounded-3xl border border-line bg-surface p-5">
          <ProductSearchSelect
            products={products.filter((product) => !document.lines.some((line) => line.productId === product.id))}
            selectedId={draft.productId}
            onSelect={selectProduct}
          />
          <div className="grid gap-3 md:grid-cols-3 lg:grid-cols-6">
            <TextField
              id="opening"
              label="Inicio De Turno"
              inputMode="decimal"
              value={draft.openingQty}
              onChange={(event) => setDraft((current) => ({ ...current, openingQty: event.target.value }))}
            />
            <TextField
              id="inbound"
              label="Entradas"
              inputMode="decimal"
              value={draft.inboundQty}
              onChange={(event) => setDraft((current) => ({ ...current, inboundQty: event.target.value }))}
            />
            <TextField
              id="outbound"
              label="Salidas"
              inputMode="decimal"
              value={draft.outboundQty}
              onChange={(event) => setDraft((current) => ({ ...current, outboundQty: event.target.value }))}
            />
            <TextField
              id="sold"
              label="Vendidos"
              inputMode="decimal"
              value={draft.soldQty}
              onChange={(event) => setDraft((current) => ({ ...current, soldQty: event.target.value }))}
            />
            <TextField
              id="sale-price"
              label="Precio De Venta"
              inputMode="decimal"
              value={draft.salePrice}
              onChange={(event) => setDraft((current) => ({ ...current, salePrice: event.target.value }))}
            />
            <TextField
              id="cost"
              label="Costo De Reposición"
              inputMode="decimal"
              value={draft.replenishmentCost}
              onChange={(event) => setDraft((current) => ({ ...current, replenishmentCost: event.target.value }))}
            />
          </div>
          <label className="flex items-start gap-3 text-sm">
            <input
              type="checkbox"
              checked={draft.inboundAddsStock}
              onChange={(event) =>
                setDraft((current) => ({ ...current, inboundAddsStock: event.target.checked }))
              }
              className="mt-1"
            />
            <span>
              <span className="font-medium">Suma Al Inventario</span>
              <span className="mt-0.5 block text-muted">
                Márcalo si embolsas acá. Al cerrar el IPV se descuenta del saco (1 lb o 2.2 lb por kg).
              </span>
            </span>
          </label>
          <p className="text-sm text-muted">
            Stock Final {preview.closingQty} · Total Venta {formatMoney(preview.saleTotal)} · Ganancia
            Bruta <span className={moneyTone(preview.grossProfit)}>{formatMoney(preview.grossProfit)}</span>
          </p>
          {lineError ? <p className="text-sm text-danger">{lineError}</p> : null}
          <PrimaryButton type="submit">Agregar Producto Al IPV</PrimaryButton>
        </form>
      )}

      <div className="overflow-x-auto rounded-3xl border border-line bg-surface">
        <table className="min-w-full text-sm">
          <thead>
            <tr className="border-b border-line text-left">
              <th className="px-3 py-3 font-semibold">Producto</th>
              <th className="px-3 py-3 text-right font-semibold">Inicio</th>
              <th className="px-3 py-3 text-right font-semibold">Entradas</th>
              <th className="px-3 py-3 text-right font-semibold">Salidas</th>
              <th className="px-3 py-3 text-right font-semibold">Vendidos</th>
              <th className="px-3 py-3 text-right font-semibold">P. Venta</th>
              <th className="px-3 py-3 text-right font-semibold">Costo</th>
              <th className="px-3 py-3 text-right font-semibold">Stock Final</th>
              <th className="px-3 py-3 text-right font-semibold">Total Venta</th>
              <th className="px-3 py-3 text-right font-semibold">Ganancia Bruta</th>
              {locked ? null : <th className="px-3 py-3" />}
            </tr>
          </thead>
          <tbody>
            {document.lines.length === 0 ? (
              <tr>
                <td colSpan={locked ? 10 : 11} className="px-4 py-8 text-center text-muted">
                  No hay productos en este IPV. Puedes agregar uno del catálogo.
                </td>
              </tr>
            ) : (
              document.lines.map((line) => (
                <tr key={line.id} className="border-t border-line">
                  <td className="px-3 py-3">
                    <Link to={`/inventario/productos/${line.productId}`} className="font-semibold text-primary">
                      {line.productName}
                    </Link>
                  </td>
                  <td className="px-3 py-3 text-right">{line.openingQty}</td>
                  <td className="px-3 py-3 text-right">{line.inboundQty}</td>
                  <td className="px-3 py-3 text-right">{line.outboundQty}</td>
                  <td className="px-3 py-3 text-right">{line.soldQty}</td>
                  <td className="px-3 py-3 text-right">{formatMoney(line.salePrice)}</td>
                  <td className="px-3 py-3 text-right">{formatMoney(line.replenishmentCost)}</td>
                  <td className="px-3 py-3 text-right">{line.closingQty}</td>
                  <td className="px-3 py-3 text-right">{formatMoney(line.saleTotal)}</td>
                  <td className={`px-3 py-3 text-right ${moneyTone(line.grossProfit)}`}>
                    {formatMoney(line.grossProfit)}
                  </td>
                  {locked ? null : (
                    <td className="px-3 py-3 text-right">
                      <button type="button" className="text-danger" onClick={() => void removeLine(line.id)}>
                        Quitar
                      </button>
                    </td>
                  )}
                </tr>
              ))
            )}
          </tbody>
          <tfoot>
            <tr className="border-t border-line font-semibold">
              <td className="px-3 py-3" colSpan={8}>
                Totales Del Turno
              </td>
              <td className="px-3 py-3 text-right">{formatMoney(totals.saleTotal)}</td>
              <td className={`px-3 py-3 text-right ${moneyTone(totals.profit)}`}>{formatMoney(totals.profit)}</td>
              {locked ? null : <td />}
            </tr>
          </tfoot>
        </table>
      </div>

      <div className="flex flex-wrap items-center gap-4">
        {isClosed ? (
          <p className="text-sm text-muted">
            {canEditClosed
              ? 'Este IPV está cerrado. Como manager o admin puedes corregir recaudo y productos; el stock se actualiza.'
              : 'Este IPV está cerrado. El stock del catálogo queda igual al stock final de cada producto.'}
          </p>
        ) : (
          <PrimaryButton type="button" loading={closing} loadingLabel="Cerrando..." onClick={() => void closeIpv()}>
            Cerrar IPV
          </PrimaryButton>
        )}
        <button type="button" className="text-sm text-danger" disabled={deleting} onClick={() => void deleteIpv()}>
          {deleting ? 'Borrando...' : 'Borrar IPV'}
        </button>
      </div>
    </div>
  );
}
