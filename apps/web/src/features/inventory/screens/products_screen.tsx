import { DomainError, Product, formatMoney, toMoneyNumber } from '@wawa/domain';
import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { useConfirm } from '../../../shared/ui/confirm_dialog';
import { ScrollTable, TableSpinner } from '../../../shared/ui/list_table';
import { ExportButtons } from '../../../shared/ui/export_buttons';
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
  const [countsForTax, setCountsForTax] = useState(true);
  const [nameError, setNameError] = useState('');
  const [pageError, setPageError] = useState('');
  const [loading, setLoading] = useState(false);
  const [listLoading, setListLoading] = useState(true);
  const [query, setQuery] = useState('');
  const [deletingId, setDeletingId] = useState('');
  const [sortKey, setSortKey] = useState<SortKey>('name');
  const [sortAsc, setSortAsc] = useState(true);

  async function load() {
    setListLoading(true);
    try {
      setProducts(await container.listProducts.execute());
    } finally {
      setListLoading(false);
    }
  }

  useEffect(() => {
    void load().catch((error) => {
      setListLoading(false);
      setPageError(error instanceof DomainError ? error.message : 'No se pudo cargar el catálogo.');
    });
  }, [container]);

  const filtered = useMemo(() => {
    const needle = query.trim().toLowerCase();
    if (!needle) {
      return products;
    }
    return products.filter((product) => product.name.toLowerCase().includes(needle));
  }, [products, query]);

  const sorted = useMemo(() => {
    return filtered.slice().sort((left, right) => {
      const direction = sortAsc ? 1 : -1;
      if (sortKey === 'name') {
        return left.name.localeCompare(right.name) * direction;
      }
      return (left[sortKey] - right[sortKey]) * direction;
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
        countsForTax,
      });
      setName('');
      setSalePrice('');
      setPurchasePrice('');
      setReplenishmentCost('');
      setMinStock('');
      setCountsForTax(true);
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
        <label className="flex items-center gap-3 text-sm lg:mb-3">
          <input type="checkbox" checked={countsForTax} onChange={(event) => setCountsForTax(event.target.checked)} />
          Cuenta Para Impuestos
        </label>
        <PrimaryButton type="submit" loading={loading} className="w-full">
          Agregar Producto
        </PrimaryButton>
      </form>
      <TextField
        id="product-search"
        label="Buscar"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
      />
      <p className="text-sm text-muted">
        {listLoading
          ? 'Cargando Productos...'
          : `${sorted.length} Producto${sorted.length === 1 ? '' : 's'}`}
      </p>
      <ExportButtons
        title="Productos"
        fileName="productos"
        columns={['Producto', 'Precio De Venta', 'Última Compra', 'Costo De Reposición', 'Stock', 'Impuesto', 'Alerta']}
        rows={sorted.map((product) => [
          product.name,
          formatMoney(product.salePrice),
          product.lastPurchasePrice === null ? '' : formatMoney(product.lastPurchasePrice),
          formatMoney(product.replenishmentCost),
          String(product.stockQty),
          product.countsForTax ? 'Sí' : 'No',
          Product.isLowStock(product) ? 'Bajo Stock' : 'Ok',
        ])}
        disabled={listLoading || sorted.length === 0}
      />
      <ScrollTable>
        <table className="min-w-full text-sm">
          <thead className="sticky top-0 z-10 bg-surface">
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
              <th className="hidden px-4 py-3 font-semibold md:table-cell">Impuesto</th>
              <th className="hidden px-4 py-3 font-semibold md:table-cell">Alerta</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {listLoading ? (
              <TableSpinner colSpan={8} label="Cargando Productos..." />
            ) : sorted.length === 0 ? (
              <tr>
                <td colSpan={8} className="px-4 py-8 text-center text-muted">
                  {products.length === 0
                    ? 'Todavía no hay productos. Agrega el primero y luego cárgale una compra.'
                    : 'No hay productos con ese nombre.'}
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
                  <td className="hidden px-4 py-3 md:table-cell">{product.countsForTax ? 'Sí' : 'No'}</td>
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
      </ScrollTable>
    </div>
  );
}
