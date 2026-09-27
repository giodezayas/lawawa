import {
  DomainError,
  InventoryErrorCodes,
  type CreatePurchaseInput,
  type PurchaseDocument,
  type PurchaseRepository,
  type UpdatePurchaseInput,
} from '@wawa/domain';
import { mapPurchaseDocument } from '../mappers/purchase_mapper';
import type { AppSupabaseClient } from '../supabase/client';
import type { Database } from '../supabase/database.types';

type PurchaseRow = Database['public']['Tables']['purchase_documents']['Row'];
type LineRow = Database['public']['Tables']['purchase_lines']['Row'];

export class PurchaseRepositoryImpl implements PurchaseRepository {
  constructor(private readonly client: AppSupabaseClient) {}

  async list(): Promise<PurchaseDocument[]> {
    const { data, error } = await this.client
      .from('purchase_documents')
      .select('*')
      .order('purchased_on', { ascending: false });

    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }

    const documents = data ?? [];
    if (documents.length === 0) {
      return [];
    }

    const { data: lines, error: linesError } = await this.client
      .from('purchase_lines')
      .select('*')
      .in(
        'purchase_id',
        documents.map((row) => row.id),
      );

    if (linesError) {
      throw new DomainError(linesError.message, InventoryErrorCodes.invalidInput);
    }

    const productIds = [...new Set((lines ?? []).map((line) => line.product_id))];
    const names = new Map<string, string>();

    if (productIds.length > 0) {
      const { data: products, error: productsError } = await this.client
        .from('products')
        .select('id, name')
        .in('id', productIds);

      if (productsError) {
        throw new DomainError(productsError.message, InventoryErrorCodes.invalidInput);
      }

      for (const product of products ?? []) {
        names.set(product.id, product.name);
      }
    }

    const linesByPurchase = new Map<string, Array<{ row: LineRow; productName: string }>>();
    for (const line of lines ?? []) {
      const bucket = linesByPurchase.get(line.purchase_id) ?? [];
      bucket.push({ row: line, productName: names.get(line.product_id) ?? 'Producto' });
      linesByPurchase.set(line.purchase_id, bucket);
    }

    return documents.map((row) => mapPurchaseDocument(row, linesByPurchase.get(row.id) ?? []));
  }

  async getById(id: string): Promise<PurchaseDocument | null> {
    const { data, error } = await this.client.from('purchase_documents').select('*').eq('id', id).maybeSingle();

    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }

    if (!data) {
      return null;
    }

    return this.load(id, data);
  }

  async create(input: CreatePurchaseInput): Promise<PurchaseDocument> {
    const { data, error } = await this.client
      .from('purchase_documents')
      .insert({
        purchased_on: input.purchasedOn,
        payment_method: input.paymentMethod,
        created_by: input.createdBy,
      })
      .select('*')
      .single();

    if (error || !data) {
      throw new DomainError(error?.message ?? 'No se pudo crear la compra.', InventoryErrorCodes.invalidInput);
    }

    try {
      await this.replaceLines(data.id, input.lines);
    } catch (lineError) {
      await this.client.from('purchase_documents').delete().eq('id', data.id);
      throw lineError;
    }

    return this.requireById(data.id);
  }

  async update(input: UpdatePurchaseInput): Promise<PurchaseDocument> {
    const { error } = await this.client
      .from('purchase_documents')
      .update({ purchased_on: input.purchasedOn, payment_method: input.paymentMethod })
      .eq('id', input.id);

    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }

    const { error: clearError } = await this.client.from('purchase_lines').delete().eq('purchase_id', input.id);
    if (clearError) {
      throw new DomainError(clearError.message, InventoryErrorCodes.invalidInput);
    }

    await this.replaceLines(input.id, input.lines);
    return this.requireById(input.id);
  }

  async remove(id: string): Promise<void> {
    const { error } = await this.client.from('purchase_documents').delete().eq('id', id);
    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
  }

  private async replaceLines(
    purchaseId: string,
    lines: readonly { productId: string; qty: number; unitCost: number }[],
  ): Promise<void> {
    const { error } = await this.client.from('purchase_lines').insert(
      lines.map((line) => ({
        purchase_id: purchaseId,
        product_id: line.productId,
        qty: line.qty,
        unit_cost: line.unitCost,
      })),
    );

    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
  }

  private async requireById(id: string): Promise<PurchaseDocument> {
    const document = await this.getById(id);
    if (!document) {
      throw new DomainError('La compra se guardó, pero no se pudo leer.', InventoryErrorCodes.invalidInput);
    }
    return document;
  }

  private async load(id: string, row: PurchaseRow): Promise<PurchaseDocument> {
    const { data: lines, error: linesError } = await this.client
      .from('purchase_lines')
      .select('*')
      .eq('purchase_id', id);

    if (linesError) {
      throw new DomainError(linesError.message, InventoryErrorCodes.invalidInput);
    }

    const productIds = [...new Set((lines ?? []).map((line) => line.product_id))];
    const names = new Map<string, string>();

    if (productIds.length > 0) {
      const { data: products, error: productsError } = await this.client
        .from('products')
        .select('id, name')
        .in('id', productIds);

      if (productsError) {
        throw new DomainError(productsError.message, InventoryErrorCodes.invalidInput);
      }

      for (const product of products ?? []) {
        names.set(product.id, product.name);
      }
    }

    return mapPurchaseDocument(
      row,
      (lines ?? []).map((line) => ({ row: line, productName: names.get(line.product_id) ?? 'Producto' })),
    );
  }
}
