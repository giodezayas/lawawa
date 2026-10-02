import type { Product, StockMovement } from '../entities/product';

export type CreateProductInput = {
  name: string;
  salePrice: number;
  purchasePrice: number;
  replenishmentCost: number;
  minStock: number;
  countsForTax: boolean;
};

export type UpdateProductInput = {
  id: string;
  name: string;
  salePrice: number;
  purchasePrice: number;
  replenishmentCost: number;
  minStock: number;
  isActive: boolean;
  countsForTax: boolean;
};

export interface ProductRepository {
  listActive(): Promise<Product[]>;
  listAll(): Promise<Product[]>;
  getById(id: string): Promise<Product | null>;
  listMovements(productId: string): Promise<StockMovement[]>;
  create(input: CreateProductInput): Promise<Product>;
  update(input: UpdateProductInput): Promise<Product>;
  adjustStock(productId: string, qty: number): Promise<Product>;
  remove(id: string): Promise<void>;
}
