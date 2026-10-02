import { DomainError, Product, StockMovement, formatDateOnly, toMoneyNumber } from '@wawa/domain';
import { useEffect, useState, type FormEvent } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { useConfirm } from '../../../shared/ui/confirm_dialog';
import { PrimaryButton } from '../../../shared/ui/primary_button';
import { TextField } from '../../../shared/ui/text_field';

export function ProductDetailScreen() {
  const { productId } = useParams();
  const navigate = useNavigate();
  const { container } = useAuth();
  const confirm = useConfirm();
  const [product, setProduct] = useState<Product | null>(null);
  const [movements, setMovements] = useState<StockMovement[]>([]);
  const [name, setName] = useState('');
  const [salePrice, setSalePrice] = useState('');
  const [purchasePrice, setPurchasePrice] = useState('');
  const [replenishmentCost, setReplenishmentCost] = useState('');
  const [minStock, setMinStock] = useState('');
  const [isActive, setIsActive] = useState(true);
  const [countsForTax, setCountsForTax] = useState(true);
  const [stockQty, setStockQty] = useState('');
  const [nameError, setNameError] = useState('');
  const [pageError, setPageError] = useState('');
  const [saving, setSaving] = useState(false);
  const [adjusting, setAdjusting] = useState(false);
  const [deleting, setDeleting] = useState(false);

  async function load(id: string) {
    const [row, history] = await Promise.all([
      container.getProduct.execute(id),
      container.listProductMovements.execute(id),
    ]);
    setProduct(row);
    setMovements(history);
    setName(row.name);
    setSalePrice(String(row.salePrice));
    setPurchasePrice(String(row.lastPurchasePrice ?? 0));
    setReplenishmentCost(String(row.replenishmentCost));
    setMinStock(String(row.minStock));
    setIsActive(row.isActive);
    setCountsForTax(row.countsForTax);
    setStockQty(String(row.stockQty));
  }

  useEffect(() => {
    if (!productId) {
      return;
    }
    void load(productId).catch((error) => {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo cargar el producto.');
    });
  }, [container, productId]);

  async function handleSave(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!product) {
      return;
    }
    setNameError('');
    setPageError('');
    if (name.trim().length === 0) {
      setNameError('El nombre del producto es obligatorio.');
      return;
    }
    setSaving(true);
    try {
      const updated = await container.updateProduct.execute({
        id: product.id,
        name,
        salePrice: toMoneyNumber(salePrice),
        purchasePrice: toMoneyNumber(purchasePrice),
        replenishmentCost: toMoneyNumber(replenishmentCost),
        minStock: toMoneyNumber(minStock),
        isActive,
        countsForTax,
      });
      setProduct(updated);
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo guardar el producto.');
    } finally {
      setSaving(false);
    }
  }

  async function handleAdjust(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!product) {
      return;
    }
    setPageError('');
    setAdjusting(true);
    try {
      await container.adjustProductStock.execute(product.id, toMoneyNumber(stockQty));
      await load(product.id);
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo ajustar el stock.');
    } finally {
      setAdjusting(false);
    }
  }

  async function handleDelete() {
    if (!product || !(await confirm({ message: '¿Borrar este producto? Se borran sus compras y líneas de IPV.' }))) {
      return;
    }
    setDeleting(true);
    setPageError('');
    try {
      await container.deleteProduct.execute(product.id);
      navigate('/inventario/productos');
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo borrar el producto.');
    } finally {
      setDeleting(false);
    }
  }

  if (!product) {
    return pageError ? <p className="text-sm text-danger">{pageError}</p> : <p className="text-sm text-muted">Cargando Producto...</p>;
  }

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold">{product.name}</h1>
          <p className="mt-1 text-sm text-muted">
            Stock {product.stockQty} · {Product.isLowStock(product) ? 'Bajo Stock' : 'Ok'}
          </p>
        </div>
        <Link to="/inventario/productos" className="text-sm font-semibold text-primary">
          Volver Al Catálogo
        </Link>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}

      <form
        onSubmit={(event) => void handleSave(event)}
        className="grid gap-4 rounded-3xl border border-line bg-surface p-5 md:grid-cols-2"
      >
        <TextField
          id="product-name"
          label="Nombre Del Producto"
          value={name}
          error={nameError}
          required
          onChange={(event) => setName(event.target.value)}
        />
        <TextField
          id="sale-price"
          label="Precio De Venta"
          inputMode="decimal"
          value={salePrice}
          onChange={(event) => setSalePrice(event.target.value)}
        />
        <TextField
          id="purchase-price"
          label="Precio De Compra"
          inputMode="decimal"
          value={purchasePrice}
          onChange={(event) => setPurchasePrice(event.target.value)}
        />
        <TextField
          id="replenishment-cost"
          label="Costo De Reposición"
          inputMode="decimal"
          value={replenishmentCost}
          onChange={(event) => setReplenishmentCost(event.target.value)}
        />
        <TextField
          id="min-stock"
          label="Stock Mínimo"
          inputMode="decimal"
          value={minStock}
          onChange={(event) => setMinStock(event.target.value)}
        />
        <label className="flex items-center gap-3 text-sm md:mt-8">
          <input type="checkbox" checked={isActive} onChange={(event) => setIsActive(event.target.checked)} />
          Activo En El Catálogo
        </label>
        <label className="flex items-start gap-3 text-sm md:mt-8">
          <input type="checkbox" checked={countsForTax} onChange={(event) => setCountsForTax(event.target.checked)} />
          <span>
            <span className="block">Cuenta Para Impuestos</span>
            <span className="mt-0.5 block text-muted">Si está apagado, su ganancia no entra al 25%.</span>
          </span>
        </label>
        <div className="md:col-span-2">
          <PrimaryButton type="submit" loading={saving}>
            Guardar Producto
          </PrimaryButton>
        </div>
      </form>

      <form
        onSubmit={(event) => void handleAdjust(event)}
        className="grid gap-4 rounded-3xl border border-line bg-surface p-5 md:grid-cols-[1fr_auto] md:items-end"
      >
        <TextField
          id="stock-qty"
          label="Stock Actual"
          inputMode="decimal"
          value={stockQty}
          onChange={(event) => setStockQty(event.target.value)}
        />
        <PrimaryButton type="submit" loading={adjusting} loadingLabel="Ajustando...">
          Ajustar Stock
        </PrimaryButton>
      </form>

      <div className="overflow-x-auto rounded-3xl border border-line bg-surface">
        <table className="min-w-full text-sm">
          <thead>
            <tr className="border-b border-line text-left">
              <th className="px-4 py-3 font-semibold">Fecha</th>
              <th className="px-4 py-3 font-semibold">Movimiento</th>
              <th className="px-4 py-3 text-right font-semibold">Cantidad</th>
            </tr>
          </thead>
          <tbody>
            {movements.length === 0 ? (
              <tr>
                <td colSpan={3} className="px-4 py-8 text-center text-muted">
                  Este producto todavía no tiene compras ni IPV.
                </td>
              </tr>
            ) : (
              movements.map((movement) => (
                <tr key={movement.id} className="border-t border-line">
                  <td className="px-4 py-3">{formatDateOnly(movement.occurredOn)}</td>
                  <td className="px-4 py-3">{StockMovement.kindLabel(movement.kind)}</td>
                  <td className="px-4 py-3 text-right">{movement.qty}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <button type="button" className="text-sm text-danger" disabled={deleting} onClick={() => void handleDelete()}>
        {deleting ? 'Borrando...' : 'Borrar Producto'}
      </button>
    </div>
  );
}
