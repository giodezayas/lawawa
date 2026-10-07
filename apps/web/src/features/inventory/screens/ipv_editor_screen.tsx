import {
  DomainError,
  IpvDocument,
  IpvLine,
  User,
  IPV_DAILY_SALARY,
  ipvDayCut,
  otherExpensesOnDate,
  formatDateOnly,
  formatMoney,
  todayIsoDate,
  toMoneyNumber,
  type Product,
  type ExpenseEntry,
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

type LineEdit = {
  inboundQty: string;
  outboundQty: string;
  soldQty: string;
  inboundAddsStock: boolean;
};

function lineEditFrom(line: IpvLine): LineEdit {
  return {
    inboundQty: String(line.inboundQty),
    outboundQty: String(line.outboundQty),
    soldQty: String(line.soldQty),
    inboundAddsStock: line.inboundAddsStock,
  };
}

function QtyInput({
  value,
  disabled,
  display,
  onChange,
}: {
  value: string;
  disabled: boolean;
  display?: string;
  onChange: (value: string) => void;
}) {
  if (disabled) {
    return <span className="block truncate text-right">{display ?? value}</span>;
  }
  return (
    <input
      inputMode="decimal"
      value={value}
      onChange={(event) => onChange(event.target.value)}
      className="h-8 w-full min-w-0 rounded-lg border border-line bg-white px-1 text-right text-xs outline-none focus:border-primary"
    />
  );
}

export function IpvEditorScreen() {
  const { ipvId } = useParams();
  const isCreate = ipvId === undefined;
  const navigate = useNavigate();
  const { container, user } = useAuth();
  const confirm = useConfirm();
  const [products, setProducts] = useState<Product[]>([]);
  const [dayExpenses, setDayExpenses] = useState<ExpenseEntry[]>([]);
  const [document, setDocument] = useState<IpvDocument | null>(null);
  const [workDate, setWorkDate] = useState(todayIsoDate());
  const [draft, setDraft] = useState<DraftLine>(emptyDraft);
  const [transferPCollected, setTransferPCollected] = useState('');
  const [transferFCollected, setTransferFCollected] = useState('');
  const [savingCollections, setSavingCollections] = useState(false);
  const [pageError, setPageError] = useState('');
  const [lineError, setLineError] = useState('');
  const [saving, setSaving] = useState(false);
  const [closing, setClosing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [lineDrafts, setLineDrafts] = useState<Record<string, LineEdit>>({});
  const [savingLineId, setSavingLineId] = useState('');
  const [deletingLineId, setDeletingLineId] = useState('');
  const [addingLine, setAddingLine] = useState(false);
  const [lineNotice, setLineNotice] = useState('');

  const canEditClosed = user ? User.canManageStaff(user) : false;
  const locked = document ? !IpvDocument.isOpen(document) && !canEditClosed : false;
  const isClosed = document ? !IpvDocument.isOpen(document) : false;

  function applyDocument(next: IpvDocument) {
    setDocument(next);
    setTransferPCollected(String(next.transferPCollected));
    setTransferFCollected(String(next.transferFCollected));
    setLineDrafts(Object.fromEntries(next.lines.map((line) => [line.id, lineEditFrom(line)])));
  }

  function showLineNotice(message: string) {
    setLineNotice(message);
    window.setTimeout(() => setLineNotice(''), 2000);
  }

  function patchSavedLine(saved: IpvLine) {
    setDocument((current) => {
      if (!current) {
        return current;
      }
      const exists = current.lines.some((line) => line.id === saved.id);
      const lines = exists
        ? current.lines.map((line) => (line.id === saved.id ? saved : line))
        : [...current.lines, saved];
      return IpvDocument.create({ ...current, lines });
    });
    setLineDrafts((current) => ({ ...current, [saved.id]: lineEditFrom(saved) }));
  }

  function dropLine(lineId: string) {
    setDocument((current) => {
      if (!current) {
        return current;
      }
      return IpvDocument.create({ ...current, lines: current.lines.filter((line) => line.id !== lineId) });
    });
    setLineDrafts((current) => {
      const next = { ...current };
      delete next[lineId];
      return next;
    });
  }

  useEffect(() => {
    void container.listProducts.execute().then(setProducts);
    void container.listExpenseEntries.execute().then(setDayExpenses);
  }, [container]);

  useEffect(() => {
    if (!ipvId) {
      return;
    }
    void container.getIpv
      .execute(ipvId)
      .then((next) => applyDocument(next))
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

  const cashCollected = IpvDocument.cashFromSale(
    totals.saleTotal,
    toMoneyNumber(transferPCollected),
    toMoneyNumber(transferFCollected),
  );

  const dayCut = useMemo(
    () =>
      ipvDayCut({
        saleTotal: totals.saleTotal,
        grossProfit: totals.profit,
        otherExpenses: otherExpensesOnDate(dayExpenses, document?.workDate ?? ''),
      }),
    [totals.saleTotal, totals.profit, document, dayExpenses],
  );

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
    const fromSack = product.name === 'Azúcar Por Libras';
    setDraft((current) => ({
      ...current,
      productId: product.id,
      productName: product.name,
      openingQty: String(fromSack ? 0 : product.stockQty),
      salePrice: String(product.salePrice),
      replenishmentCost: String(product.replenishmentCost),
      inboundAddsStock: fromSack ? false : current.inboundAddsStock,
    }));
    if (!document) {
      return;
    }
    void container.getIpvLineDefaults.execute(document.id, product.id).then((defaults) => {
      setDraft((current) => {
        if (current.productId !== product.id) {
          return current;
        }
        return {
          ...current,
          openingQty: String(defaults.openingQty),
          salePrice: String(defaults.salePrice),
          replenishmentCost: String(defaults.replenishmentCost),
          productName: defaults.productName || current.productName,
        };
      });
    });
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
    setAddingLine(true);
    try {
      const saved = await container.upsertIpvLine.execute({
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
      patchSavedLine(saved);
      setDraft(emptyDraft);
      showLineNotice('Producto agregado.');
    } catch (error) {
      setLineError(error instanceof DomainError ? error.message : 'No se pudo agregar la línea.');
    } finally {
      setAddingLine(false);
    }
  }

  async function removeLine(lineId: string) {
    if (!document || locked) {
      return;
    }
    if (!(await confirm({ message: '¿Quitar este producto del IPV?' }))) {
      return;
    }
    setPageError('');
    setDeletingLineId(lineId);
    try {
      await container.removeIpvLine.execute(lineId);
      dropLine(lineId);
      showLineNotice('Producto quitado.');
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo quitar el producto.');
    } finally {
      setDeletingLineId('');
    }
  }

  async function saveExistingLine(line: IpvLine) {
    if (!document || locked) {
      return;
    }
    const edit = lineDrafts[line.id] ?? lineEditFrom(line);
    setPageError('');
    setSavingLineId(line.id);
    try {
      const saved = await container.upsertIpvLine.execute({
        id: line.id,
        ipvId: document.id,
        productId: line.productId,
        productName: line.productName,
        openingQty: line.openingQty,
        inboundQty: toQty(edit.inboundQty),
        outboundQty: toQty(edit.outboundQty),
        soldQty: toQty(edit.soldQty),
        salePrice: line.salePrice,
        replenishmentCost: line.replenishmentCost,
        inboundAddsStock: edit.inboundAddsStock,
        sortOrder: line.sortOrder,
      });
      patchSavedLine(saved);
      showLineNotice('Producto guardado.');
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo guardar el producto.');
    } finally {
      setSavingLineId('');
    }
  }

  async function persistTransfers(ipvId: string) {
    return container.updateIpvCollections.execute(
      ipvId,
      toMoneyNumber(transferPCollected),
      toMoneyNumber(transferFCollected),
    );
  }

  async function saveCollections() {
    if (!document || locked) {
      return;
    }
    setPageError('');
    setSavingCollections(true);
    try {
      applyDocument(await persistTransfers(document.id));
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
      await persistTransfers(document.id);
      const closed = await container.closeIpv.execute(document.id, user.id);
      applyDocument(closed);
      setDayExpenses(await container.listExpenseEntries.execute());
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
            Un solo documento por día. Al crearlo el inicio de cada producto es el final del IPV anterior, y el precio y el costo salen del catálogo. Tú pones los vendidos.
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
    <div className="mx-auto min-w-0 max-w-full space-y-6 overflow-x-hidden">
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
              'Stock Final',
              'P. Venta',
              'Costo',
              'Total Venta',
              'Ganancia Bruta',
            ]}
            rows={document.lines.map((line) => [
              line.productName,
              String(line.openingQty),
              String(line.inboundQty),
              String(line.outboundQty),
              String(line.soldQty),
              String(line.closingQty),
              formatMoney(line.salePrice),
              formatMoney(line.replenishmentCost),
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
      {lineNotice ? <p className="text-sm text-primary">{lineNotice}</p> : null}

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

      <section className="space-y-3">
        <h2 className="text-sm font-semibold text-primary">Si Cobramos Hoy</h2>
        <p className="text-sm text-muted">
          Salario, la parte del día de los gastos (también los mensuales) e impuesto a reservar. Lo que queda se
          parte a la mitad entre los dos dueños.
        </p>
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          <article className="rounded-3xl border border-line bg-white px-5 py-4">
            <p className="text-sm font-medium text-primary">Salario</p>
            <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(dayCut.salary)}</p>
            <p className="mt-1 text-right text-xs text-muted">Se saca de la venta al cerrar</p>
          </article>
          <article className="rounded-3xl border border-line bg-white px-5 py-4">
            <p className="text-sm font-medium text-primary">Gastos A Reservar</p>
            <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(dayCut.otherExpenses)}</p>
            <p className="mt-1 text-right text-xs text-muted">Hoy, Semanales Y Mensuales Prorrateados</p>
          </article>
          <article className="rounded-3xl border border-line bg-white px-5 py-4">
            <p className="text-sm font-medium text-primary">Impuesto A Reservar</p>
            <p className="mt-1 text-right text-2xl font-extrabold text-danger">{formatMoney(dayCut.tax)}</p>
            <p className="mt-1 text-right text-xs text-muted">
              10% De La Venta (0114022) {formatMoney(dayCut.tribute0114022)}
            </p>
            <p className="mt-1 text-right text-xs text-muted">
              5% Menos $ 3,260.00 (0510122) {formatMoney(dayCut.tribute0510122)}
            </p>
          </article>
          <article className="rounded-3xl border border-line bg-white px-5 py-4">
            <p className="text-sm font-medium text-primary">Neta Del Día</p>
            <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(dayCut.net)}`}>
              {formatMoney(dayCut.net)}
            </p>
            <p className="mt-1 text-right text-xs text-muted">Ganancia Menos Salario, Gastos E Impuesto</p>
          </article>
          <article className="rounded-3xl border-2 border-accent bg-white px-5 py-4">
            <p className="text-sm font-medium text-primary">Cada Dueño</p>
            <p className={`mt-1 text-right text-2xl font-extrabold ${moneyTone(dayCut.ownerShare)}`}>
              {formatMoney(dayCut.ownerShare)}
            </p>
            <p className="mt-1 text-right text-xs text-muted">Mitad De La Neta</p>
          </article>
        </div>
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
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <div className="rounded-3xl border border-line bg-cream-dark px-4 py-3">
            <p className="text-sm font-medium text-ink">Efectivo</p>
            <p className={`mt-1 text-right text-xl font-extrabold ${moneyTone(cashCollected)}`}>
              {formatMoney(cashCollected)}
            </p>
            <p className="mt-1 text-right text-xs text-muted">Venta Menos Tarjetas</p>
          </div>
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
          Venta {formatMoney(totals.saleTotal)} · Recaudado {formatMoney(cashCollected + toMoneyNumber(transferPCollected) + toMoneyNumber(transferFCollected))}
          {' · '}
          Efectivo Luego Del Salario {formatMoney(IpvDocument.cashAfterSalary(cashCollected))}
          {' · '}
          Queda En Caja {formatMoney(IpvDocument.cashAfterSetAside(cashCollected, totals.profit))}
          {cashCollected < 0 ? (
            <span className="text-danger"> · La transferencia supera la venta</span>
          ) : null}
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
          <div className="grid grid-cols-2 gap-3">
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
              label="Vendidos *"
              inputMode="decimal"
              value={draft.soldQty}
              onChange={(event) => setDraft((current) => ({ ...current, soldQty: event.target.value }))}
            />
          </div>
          <p className="text-sm text-muted">
            Inicio {toQty(draft.openingQty)} · Precio {formatMoney(toQty(draft.salePrice))} · Costo{' '}
            {formatMoney(toQty(draft.replenishmentCost))} · Stock Final {preview.closingQty} · Total Venta{' '}
            {formatMoney(preview.saleTotal)} · Ganancia Bruta{' '}
            <span className={moneyTone(preview.grossProfit)}>{formatMoney(preview.grossProfit)}</span>
          </p>
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
                Márcalo si embolsas Azúcar 1 lb o 1 kg. Al cerrar se descuenta del saco. Azúcar Por Libras se rebaja con Vendidos.
              </span>
            </span>
          </label>
          {lineError ? <p className="text-sm text-danger">{lineError}</p> : null}
          <PrimaryButton type="submit" loading={addingLine} loadingLabel="Agregando...">
            Agregar Producto Al IPV
          </PrimaryButton>
        </form>
      )}

      {document.lines.length === 0 ? (
        <p className="rounded-3xl border border-line bg-surface px-4 py-8 text-center text-sm text-muted">
          No hay productos en este IPV. Puedes agregar uno del catálogo.
        </p>
      ) : (
        <div className="max-h-[36rem] overflow-y-auto overflow-x-hidden rounded-3xl border border-line bg-surface">
          <table className="w-full table-fixed text-xs">
            <thead className="sticky top-0 z-10 bg-surface">
              <tr className="border-b border-line text-left">
                <th className="w-[16%] px-2 py-2 font-semibold">Producto</th>
                <th className="w-[7%] px-1 py-2 text-right font-semibold">Inicio</th>
                <th className="w-[7%] px-1 py-2 text-right font-semibold">Entradas</th>
                <th className="w-[7%] px-1 py-2 text-right font-semibold">Salidas</th>
                <th className="w-[7%] px-1 py-2 text-right font-semibold">Vendidos</th>
                <th className="w-[7%] px-1 py-2 text-right font-semibold">Final</th>
                <th className="w-[8%] px-1 py-2 text-right font-semibold">P. Venta</th>
                <th className="w-[8%] px-1 py-2 text-right font-semibold">Costo</th>
                <th className="w-[8%] px-1 py-2 text-right font-semibold">Venta</th>
                <th className="w-[8%] px-1 py-2 text-right font-semibold">Ganancia</th>
                <th className="w-[5%] px-1 py-2 text-center font-semibold">Suma</th>
                <th className="w-[12%] px-2 py-2" />
              </tr>
            </thead>
            <tbody>
              {document.lines.map((line) => {
                const edit = lineDrafts[line.id] ?? lineEditFrom(line);
                const patch = (next: Partial<LineEdit>) =>
                  setLineDrafts((current) => ({ ...current, [line.id]: { ...edit, ...next } }));
                const live = IpvLine.compute({
                  openingQty: line.openingQty,
                  inboundQty: toQty(edit.inboundQty),
                  outboundQty: toQty(edit.outboundQty),
                  soldQty: toQty(edit.soldQty),
                  salePrice: line.salePrice,
                  replenishmentCost: line.replenishmentCost,
                });
                return (
                  <tr key={line.id} className="border-t border-line align-middle">
                    <td className="px-2 py-1">
                      <Link to={`/inventario/productos/${line.productId}`} className="block truncate font-semibold text-primary">
                        {line.productName}
                      </Link>
                      {line.productName === 'Azúcar Por Libras' ? (
                        <span className="block text-[10px] text-muted">Vendidos = lb del saco</span>
                      ) : null}
                    </td>
                    <td className="truncate px-1 py-1 text-right">{line.openingQty}</td>
                    <td className="px-1 py-1">
                      <QtyInput value={edit.inboundQty} disabled={locked} onChange={(value) => patch({ inboundQty: value })} />
                    </td>
                    <td className="px-1 py-1">
                      <QtyInput
                        value={edit.outboundQty}
                        disabled={locked}
                        onChange={(value) => patch({ outboundQty: value })}
                      />
                    </td>
                    <td className="px-1 py-1">
                      <QtyInput value={edit.soldQty} disabled={locked} onChange={(value) => patch({ soldQty: value })} />
                    </td>
                    <td className="truncate px-1 py-1 text-right">{live.closingQty}</td>
                    <td className="truncate px-1 py-1 text-right">{formatMoney(line.salePrice)}</td>
                    <td className="truncate px-1 py-1 text-right">{formatMoney(line.replenishmentCost)}</td>
                    <td className="truncate px-1 py-1 text-right">{formatMoney(live.saleTotal)}</td>
                    <td className={`truncate px-1 py-1 text-right ${moneyTone(live.grossProfit)}`}>
                      {formatMoney(live.grossProfit)}
                    </td>
                    <td className="px-1 py-1 text-center">
                      {locked ? (
                        edit.inboundAddsStock ? 'Sí' : 'No'
                      ) : (
                        <input
                          type="checkbox"
                          checked={edit.inboundAddsStock}
                          aria-label="Suma Al Inventario"
                          onChange={(event) => patch({ inboundAddsStock: event.target.checked })}
                        />
                      )}
                    </td>
                    <td className="px-2 py-1 text-right">
                      {locked ? null : (
                        <div className="flex flex-wrap justify-end gap-2">
                          <button
                            type="button"
                            className="font-semibold text-primary"
                            disabled={savingLineId === line.id || deletingLineId === line.id}
                            onClick={() => void saveExistingLine(line)}
                          >
                            {savingLineId === line.id ? 'Guardando...' : 'Guardar'}
                          </button>
                          <button
                            type="button"
                            className="text-danger"
                            disabled={savingLineId === line.id || deletingLineId === line.id}
                            onClick={() => void removeLine(line.id)}
                          >
                            {deletingLineId === line.id ? 'Borrando...' : 'Quitar'}
                          </button>
                        </div>
                      )}
                    </td>
                  </tr>
                );
              })}
              <tr className="border-t border-line bg-surface font-semibold">
                <td className="px-2 py-2" colSpan={8}>
                  Totales Del Turno
                </td>
                <td className="px-1 py-2 text-right">{formatMoney(totals.saleTotal)}</td>
                <td className={`px-1 py-2 text-right ${moneyTone(totals.profit)}`}>{formatMoney(totals.profit)}</td>
                <td colSpan={2} />
              </tr>
            </tbody>
          </table>
        </div>
      )}

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
        {isClosed ? null : (
          <p className="text-sm text-muted">Al cerrar se registra el salario de {formatMoney(IPV_DAILY_SALARY)} como gasto del día.</p>
        )}
        <button type="button" className="text-sm text-danger" disabled={deleting} onClick={() => void deleteIpv()}>
          {deleting ? 'Borrando...' : 'Borrar IPV'}
        </button>
      </div>
    </div>
  );
}
