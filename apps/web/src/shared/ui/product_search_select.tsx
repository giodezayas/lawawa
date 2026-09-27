import { useEffect, useMemo, useRef, useState } from 'react';
import type { Product } from '@wawa/domain';

type ProductSearchSelectProps = {
  products: readonly Product[];
  selectedId: string;
  onSelect: (product: Product) => void;
  disabled?: boolean;
};

export function ProductSearchSelect({
  products,
  selectedId,
  onSelect,
  disabled = false,
}: ProductSearchSelectProps) {
  const selected = products.find((product) => product.id === selectedId);
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState(selected?.name ?? '');
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) {
      setQuery(selected?.name ?? '');
    }
  }, [open, selected?.name]);

  useEffect(() => {
    function handleClick(event: MouseEvent) {
      if (!rootRef.current?.contains(event.target as Node)) {
        setOpen(false);
      }
    }

    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

  const filtered = useMemo(() => {
    const needle = query.trim().toLowerCase();
    const active = products.filter((product) => product.isActive);
    if (!needle) {
      return active;
    }
    return active.filter((product) => product.name.toLowerCase().includes(needle));
  }, [products, query]);

  return (
    <div ref={rootRef} className="relative">
      <label className="block" htmlFor="product-search">
        <span className="mb-2 block text-sm font-medium text-ink">Producto *</span>
        <input
          id="product-search"
          type="text"
          role="combobox"
          aria-expanded={open}
          aria-controls="product-options"
          disabled={disabled}
          value={query}
          placeholder="Buscar y elegir producto"
          autoComplete="off"
          onFocus={() => setOpen(true)}
          onChange={(event) => {
            setQuery(event.target.value);
            setOpen(true);
          }}
          className="h-12 w-full rounded-2xl border border-line bg-white px-4 text-sm outline-none focus:border-primary focus:ring-4 focus:ring-primary/20"
        />
      </label>
      {open ? (
        <ul
          id="product-options"
          role="listbox"
          className="absolute z-20 mt-1 max-h-56 w-full overflow-auto rounded-2xl border border-line bg-white py-1 shadow-lg"
        >
          {filtered.length === 0 ? (
            <li className="px-4 py-3 text-sm text-muted">No hay productos con ese nombre.</li>
          ) : (
            filtered.map((product) => (
              <li key={product.id}>
                <button
                  type="button"
                  role="option"
                  aria-selected={product.id === selectedId}
                  className={`w-full px-4 py-2 text-left text-sm hover:bg-primary/5 ${
                    product.id === selectedId ? 'bg-primary/10 font-semibold text-primary' : ''
                  }`}
                  onClick={() => {
                    onSelect(product);
                    setQuery(product.name);
                    setOpen(false);
                  }}
                >
                  {product.name}
                </button>
              </li>
            ))
          )}
        </ul>
      ) : null}
    </div>
  );
}
