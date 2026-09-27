import {
  DomainError,
  InventoryErrorCodes,
  type Product,
  type ProductRepository,
  type StockMovement,
} from '@wawa/domain';
import { mapProduct } from '../mappers/product_mapper';
import { mapStockMovement } from '../mappers/stock_movement_mapper';
import type { AppSupabaseClient } from '../supabase/client';

export class ProductRepositoryImpl implements ProductRepository {
  constructor(private readonly client: AppSupabaseClient) {}

  async listActive(): Promise<Product[]> {
    const { data, error } = await this.client
      .from('product_catalog')
      .select('*')
      .eq('is_active', true)
      .order('name');

    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }

    return (data ?? []).map(mapProduct);
  }

  async listAll(): Promise<Product[]> {
    const { data, error } = await this.client.from('product_catalog').select('*').order('name');

    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }

    return (data ?? []).map(mapProduct);
  }

  async getById(id: string): Promise<Product | null> {
    const { data, error } = await this.client.from('product_catalog').select('*').eq('id', id).maybeSingle();

    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }

    return data ? mapProduct(data) : null;
  }

  async listMovements(productId: string): Promise<StockMovement[]> {
    const { data, error } = await this.client
      .from('stock_movements')
      .select('*')
      .eq('product_id', productId)
      .order('occurred_on', { ascending: false })
      .order('created_at', { ascending: false });

    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }

    return (data ?? []).map(mapStockMovement);
  }

  async create(input: {
    name: string;
    salePrice: number;
    purchasePrice: number;
    replenishmentCost: number;
    minStock: number;
  }): Promise<Product> {
    const { data, error } = await this.client
      .from('products')
      .insert({
        name: input.name,
        sale_price: input.salePrice,
        purchase_price: input.purchasePrice,
        replenishment_cost: input.replenishmentCost,
        min_stock: input.minStock,
      })
      .select('id')
      .single();

    if (error || !data) {
      if (error?.code === '23505') {
        throw new DomainError('Ese producto ya existe en el catálogo.', InventoryErrorCodes.duplicate);
      }
      throw new DomainError(error?.message ?? 'No se pudo guardar el producto.', InventoryErrorCodes.invalidInput);
    }

    return this.requireById(data.id);
  }

  async update(input: {
    id: string;
    name: string;
    salePrice: number;
    purchasePrice: number;
    replenishmentCost: number;
    minStock: number;
    isActive: boolean;
  }): Promise<Product> {
    const { error } = await this.client
      .from('products')
      .update({
        name: input.name,
        sale_price: input.salePrice,
        purchase_price: input.purchasePrice,
        replenishment_cost: input.replenishmentCost,
        min_stock: input.minStock,
        is_active: input.isActive,
      })
      .eq('id', input.id);

    if (error) {
      if (error.code === '23505') {
        throw new DomainError('Ese producto ya existe en el catálogo.', InventoryErrorCodes.duplicate);
      }
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }

    return this.requireById(input.id);
  }

  async adjustStock(productId: string, qty: number): Promise<Product> {
    const { error } = await this.client.rpc('adjust_product_stock', {
      p_id: productId,
      p_qty: qty,
    });

    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }

    return this.requireById(productId);
  }

  async remove(id: string): Promise<void> {
    const { error } = await this.client.rpc('delete_product', { p_id: id });
    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
  }

  private async requireById(id: string): Promise<Product> {
    const product = await this.getById(id);
    if (!product) {
      throw new DomainError('El producto se guardó, pero no se pudo leer.', InventoryErrorCodes.invalidInput);
    }
    return product;
  }
}
