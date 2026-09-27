import { DomainError, PurchaseDocument, billingPeriodContaining, formatMoney, paymentMethods, todayIsoDate, toMoneyNumber, type CashFlow, type PaymentMethod, type Product } from '@wawa/domain';
import { useEffect, useState, type FormEvent } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { CashFlowSummary } from '../../../shared/ui/cash_flow_summary';
import { PrimaryButton } from '../../../shared/ui/primary_button';
import { ProductSearchSelect } from '../../../shared/ui/product_search_select';
import { TextField } from '../../../shared/ui/text_field';

type DraftLine = {
  productId: string;
  productName: string;
  qty: string;
  unitCost: string;
};

export function PurchaseEditorScreen() {
  const { purchaseId } = useParams();
  const isCreate = purchaseId === undefined;
  const { container, user } = useAuth();
  const navigate = useNavigate();
  const [products, setProducts] = useState<Product[]>([]);
  const [purchasedOn, setPurchasedOn] = useState(todayIsoDate());
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>('cash');
  const [flow, setFlow] = useState<CashFlow | null>(null);
  const [draft, setDraft] = useState<DraftLine>({ productId: '', productName: '', qty: '', unitCost: '' });
  const [lines, setLines] = useState<DraftLine[]>([]);
  const [pageError, setPageError] = useState('');
  const [lineError, setLineError] = useState('');
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [ready, setReady] = useState(isCreate);

  useEffect(() => {
    void container.listProducts.execute().then(setProducts);
    void (async () => {
      const startDay = await container.getBillingStartDay.execute();
      const period = billingPeriodContaining(todayIsoDate(), startDay);
      setFlow(await container.getCashFlow.execute(period.from, period.to));
    })().catch(() => undefined);
  }, [container]);

  useEffect(() => {
    if (!purchaseId) {
      return;
    }
    void container.getPurchase
      .execute(purchaseId)
      .then((document) => {
        setPurchasedOn(document.purchasedOn);
        setPaymentMethod(document.paymentMethod);
        setLines(
          document.lines.map((line) => ({
            productId: line.productId,
            productName: line.productName,
            qty: String(line.qty),
            unitCost: String(line.unitCost),
          })),
        );
        setReady(true);
      })
      .catch((error) => {
        setPageError(error instanceof DomainError ? error.message : 'No se pudo abrir la compra.');
      });
  }, [container, purchaseId]);

  function selectProduct(product: Product) {
    setDraft((current) => ({
      ...current,
      productId: product.id,
      productName: product.name,
      unitCost: current.unitCost || (product.lastPurchasePrice !== null ? String(product.lastPurchasePrice) : ''),
    }));
  }

  function addLine() {
    setLineError('');
    if (!draft.productId) {
      setLineError('Elige un producto del catálogo.');
      return;
    }
    const qty = toMoneyNumber(draft.qty);
    const unitCost = toMoneyNumber(draft.unitCost);
    if (qty <= 0) {
      setLineError('La cantidad debe ser mayor que 0.');
      return;
    }
    setLines((current) => [...current, { ...draft, qty: String(qty), unitCost: String(unitCost) }]);
    setDraft({ productId: '', productName: '', qty: '', unitCost: '' });
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!user) {
      return;
    }
    setPageError('');
    if (lines.length === 0) {
      setPageError('Agrega al menos un producto a la compra.');
      return;
    }
    const payload = {
      purchasedOn,
      paymentMethod,
      lines: lines.map((line) => ({
        productId: line.productId,
        qty: toMoneyNumber(line.qty),
        unitCost: toMoneyNumber(line.unitCost),
      })),
    };
    setSaving(true);
    try {
      if (purchaseId) {
        await container.updatePurchase.execute({ id: purchaseId, ...payload });
      } else {
        await container.createPurchase.execute({ ...payload, createdBy: user.id });
      }
      navigate('/inventario/compras');
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo guardar la compra.');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!purchaseId || !window.confirm('¿Borrar esta compra? El stock se va a recalcular.')) {
      return;
    }
    setDeleting(true);
    setPageError('');
    try {
      await container.deletePurchase.execute(purchaseId);
      navigate('/inventario/compras');
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo borrar la compra.');
    } finally {
      setDeleting(false);
    }
  }

  if (!ready) {
    return pageError ? <p className="text-sm text-danger">{pageError}</p> : <p className="text-sm text-muted">Cargando Compra...</p>;
  }

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <div className="flex items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold">{isCreate ? 'Registrar Compra' : 'Editar Compra'}</h1>
          <p className="mt-1 text-sm text-muted">Esta compra suma al stock del catálogo.</p>
        </div>
        <Link to="/inventario/compras" className="text-sm font-semibold text-primary">
          Volver A Compras
        </Link>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
      {flow ? <CashFlowSummary flow={flow} title="Caja Del Período" /> : null}
      <form onSubmit={(event) => void handleSubmit(event)} className="space-y-4">
        <div className="rounded-3xl border border-line bg-surface p-5">
          <TextField
            id="purchased-on"
            label="Fecha"
            type="date"
            required
            value={purchasedOn}
            onChange={(event) => setPurchasedOn(event.target.value)}
          />
          <label className="mt-4 block" htmlFor="payment-method">
            <span className="mb-2 block text-sm font-medium text-ink">Pago *</span>
            <select
              id="payment-method"
              required
              value={paymentMethod}
              onChange={(event) => setPaymentMethod(event.target.value as PaymentMethod)}
              className="h-12 w-full rounded-2xl border border-line bg-white px-4 text-sm outline-none ring-primary/15 transition focus:border-primary focus:ring-4"
            >
              {paymentMethods.map((method) => (
                <option key={method} value={method}>
                  {PurchaseDocument.paymentLabel(method)}
                </option>
              ))}
            </select>
          </label>
        </div>
        <div className="space-y-4 rounded-3xl border border-line bg-surface p-5">
          <ProductSearchSelect products={products} selectedId={draft.productId} onSelect={selectProduct} />
          <div className="grid gap-3 md:grid-cols-2">
            <TextField
              id="qty"
              label="Cantidad"
              inputMode="decimal"
              value={draft.qty}
              onChange={(event) => setDraft((current) => ({ ...current, qty: event.target.value }))}
            />
            <TextField
              id="unit-cost"
              label="Precio De Compra"
              inputMode="decimal"
              value={draft.unitCost}
              onChange={(event) => setDraft((current) => ({ ...current, unitCost: event.target.value }))}
            />
          </div>
          {lineError ? <p className="text-sm text-danger">{lineError}</p> : null}
          <button
            type="button"
            onClick={addLine}
            className="btn-outline h-12 rounded-2xl px-5 text-sm font-semibold"
          >
            Agregar A La Compra
          </button>
        </div>
        <div className="overflow-x-auto rounded-3xl border border-line bg-surface">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="border-b border-line text-left">
                <th className="px-4 py-3 font-semibold">Producto</th>
                <th className="px-4 py-3 text-right font-semibold">Cantidad</th>
                <th className="px-4 py-3 text-right font-semibold">Precio De Compra</th>
                <th className="px-4 py-3 text-right font-semibold">Total</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody>
              {lines.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-4 py-6 text-center text-muted">
                    Agrega productos a esta compra.
                  </td>
                </tr>
              ) : (
                lines.map((line, index) => (
                  <tr key={`${line.productId}-${index}`} className="border-t border-line">
                    <td className="px-4 py-3">
                      <Link to={`/inventario/productos/${line.productId}`} className="font-semibold text-primary">
                        {line.productName}
                      </Link>
                    </td>
                    <td className="px-4 py-3 text-right">{line.qty}</td>
                    <td className="px-4 py-3 text-right">{formatMoney(toMoneyNumber(line.unitCost))}</td>
                    <td className="px-4 py-3 text-right">
                      {formatMoney(toMoneyNumber(line.qty) * toMoneyNumber(line.unitCost))}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <button
                        type="button"
                        className="text-danger"
                        onClick={() => setLines((current) => current.filter((_, itemIndex) => itemIndex !== index))}
                      >
                        Quitar
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
        <div className="flex flex-wrap items-center gap-4">
          <PrimaryButton type="submit" loading={saving}>
            {isCreate ? 'Guardar Compra' : 'Guardar Cambios'}
          </PrimaryButton>
          {isCreate ? null : (
            <button type="button" className="text-sm text-danger" disabled={deleting} onClick={() => void handleDelete()}>
              {deleting ? 'Borrando...' : 'Borrar Compra'}
            </button>
          )}
        </div>
      </form>
    </div>
  );
}
