import { DomainError, Product, formatMoney, toMoneyNumber } from '@wawa/domain';
import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { useConfirm } from '../../../shared/ui/confirm_dialog';
import { PrimaryButton } from '../../../shared/ui/primary_button';
import { TextField } from '../../../shared/ui/text_field';

type SortKey = 'name' | 'salePrice' | 'replenishmentCost' | 'stockQty';

export function ProductsScreen() {
  const { container } = useAuth();
  const confirm = useConfirm();
  const [products, setProducts] = useState<Awaited<ReturnType<typeof container.listProducts.execute>>>([]);
  const [name, setName] = useState('');
  const [salePrice, setSalePrice] = useState('');
  const [purchasePrice, setPurchasePrice] = useState('');
  const [replenishmentCost, setReplenishmentCost] = useState('');
  const [minStock, setMinStock] = useState('');
  const [nameError, setNameError] = useState('');
  const [pageError, setPageError] = useState('');
  const [loading, setLoading] = useState(false);
  const [deletingId, setDeletingId] = useState('');
  const [sortKey, setSortKey] = useState<SortKey>('name');
  const [sortAsc, setSortAsc] = useState(true);

  async function load() {
    const rows = await container.listProducts.execute();
    setProducts(rows);
  }

  useEffect(() => {
    void load().catch((error) => {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo cargar el catálogo.');
    });
  }, [container]);

  const sorted = useMemo(() => {
    return products.slice().sort((left, right) => {
      const direction = sortAsc ? 1 : -1;
      if (sortKey === 'name') {
        return left.name.localeCompare(right.name) * direction;
      }
      return (left[sortKey] - right[sortKey]) * direction;
    });
  }, [products, sortKey, sortAsc]);

  function toggleSort(key: SortKey) {
    if (sortKey === key) {
      setSortAsc((value) => !value);
      return;
    }
    setSortKey(key);
    setSortAsc(true);
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setNameError('');
    setPageError('');
    if (name.trim().length === 0) {
      setNameError('El nombre del producto es obligatorio.');
      return;
    }

    setLoading(true);
    try {
      await container.createProduct.execute({
        name,
        salePrice: toMoneyNumber(salePrice),
        purchasePrice: toMoneyNumber(purchasePrice),
        replenishmentCost: toMoneyNumber(replenishmentCost),
        minStock: toMoneyNumber(minStock),
      });
      setName('');
      setSalePrice('');
      setPurchasePrice('');
      setReplenishmentCost('');
      setMinStock('');
      await load();
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo guardar el producto.');
    } finally {
      setLoading(false);
    }
  }

  async function handleDelete(productId: string, productName: string) {
    if (!(await confirm({ message: `¿Borrar ${productName}? Se borran sus compras y líneas de IPV.` }))) {
      return;
    }
    setDeletingId(productId);
    setPageError('');
    try {
      await container.deleteProduct.execute(productId);
      await load();
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo borrar el producto.');
    } finally {
      setDeletingId('');
    }
  }

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <div>
        <h1 className="text-2xl font-extrabold">Catálogo De Productos</h1>
        <p className="mt-1 text-sm text-muted">
          Precio de venta y costo se editan aquí. El stock empieza en 0 y sube con las compras.
        </p>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
      <form
        onSubmit={(event) => void handleSubmit(event)}
        className="grid gap-4 rounded-3xl border border-line bg-surface p-5 sm:grid-cols-2 lg:grid-cols-4 lg:items-end"
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
        <PrimaryButton type="submit" loading={loading} className="w-full">
          Agregar Producto
        </PrimaryButton>
      </form>
      <div className="overflow-x-auto rounded-3xl border border-line bg-surface">
        <table className="min-w-full text-sm">
          <thead>
            <tr className="border-b border-line text-left">
              <th>
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('name')}>
                  Producto
                </button>
              </th>
              <th className="text-right">
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('salePrice')}>
                  Precio De Venta
                </button>
              </th>
              <th className="hidden px-4 py-3 text-right font-semibold md:table-cell">Última Compra</th>
              <th className="hidden text-right md:table-cell">
                <button
                  type="button"
                  className="px-4 py-3 font-semibold"
                  onClick={() => toggleSort('replenishmentCost')}
                >
                  Costo De Reposición
                </button>
              </th>
              <th className="text-right">
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('stockQty')}>
                  Stock
                </button>
              </th>
              <th className="hidden px-4 py-3 font-semibold md:table-cell">Alerta</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {sorted.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-muted">
                  Todavía no hay productos. Agrega el primero y luego cárgale una compra.
                </td>
              </tr>
            ) : (
              sorted.map((product) => (
                <tr key={product.id} className="border-t border-line">
                  <td className="px-4 py-3">
                    <Link to={`/inventario/productos/${product.id}`} className="font-semibold text-primary">
                      {product.name}
                    </Link>
                  </td>
                  <td className="px-4 py-3 text-right">{formatMoney(product.salePrice)}</td>
                  <td className="hidden px-4 py-3 text-right md:table-cell">
                    {product.lastPurchasePrice === null ? '—' : formatMoney(product.lastPurchasePrice)}
                  </td>
                  <td className="hidden px-4 py-3 text-right md:table-cell">{formatMoney(product.replenishmentCost)}</td>
                  <td className="px-4 py-3 text-right">{product.stockQty}</td>
                  <td className="hidden px-4 py-3 md:table-cell">
                    {Product.isLowStock(product) ? (
                      <span className="font-semibold text-danger">Bajo Stock</span>
                    ) : (
                      <span className="text-muted">Ok</span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex justify-end gap-3">
                      <Link to={`/inventario/productos/${product.id}`} className="font-semibold text-primary">
                        Ver
                      </Link>
                      <button
                        type="button"
                        className="text-danger"
                        disabled={deletingId === product.id}
                        onClick={() => void handleDelete(product.id, product.name)}
                      >
                        {deletingId === product.id ? 'Borrando...' : 'Borrar'}
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
