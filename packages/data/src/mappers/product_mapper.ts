import { Product } from '@wawa/domain';
import type { Database } from '../supabase/database.types';

type CatalogRow = Database['public']['Views']['product_catalog']['Row'];

export function mapProduct(row: CatalogRow): Product {
  return Product.create({
    id: row.id,
    name: row.name,
    salePrice: Number(row.sale_price),
    replenishmentCost: Number(row.replenishment_cost),
    lastPurchasePrice: Number(row.last_purchase_price ?? 0),
    minStock: Number(row.min_stock),
    stockQty: Number(row.stock_qty),
    isActive: row.is_active,
    countsForTax: row.counts_for_tax !== false,
  });
}
