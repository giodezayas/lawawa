import {
  DomainError,
  InventoryErrorCodes,
  type CreateIpvInput,
  type IpvDocument,
  type IpvLine,
  type IpvRepository,
  type UpsertIpvLineInput,
} from '@wawa/domain';
import { mapCashFlow } from '../mappers/cash_flow_mapper';
import { mapIpvDocument, mapIpvLine } from '../mappers/ipv_mapper';
import type { AppSupabaseClient } from '../supabase/client';

export class IpvRepositoryImpl implements IpvRepository {
  constructor(private readonly client: AppSupabaseClient) {}

  async list(): Promise<IpvDocument[]> {
    const { data, error } = await this.client
      .from('ipv_documents')
      .select('*')
      .order('work_date', { ascending: false });

    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }

    const { data: lines, error: linesError } = await this.client.from('ipv_lines').select('*');
    if (linesError) {
      throw new DomainError(linesError.message, InventoryErrorCodes.invalidInput);
    }

    const linesByIpv = new Map<string, NonNullable<typeof lines>>();
    for (const line of lines ?? []) {
      const bucket = linesByIpv.get(line.ipv_id) ?? [];
      bucket.push(line);
      linesByIpv.set(line.ipv_id, bucket);
    }

    return (data ?? []).map((row) => mapIpvDocument(row, linesByIpv.get(row.id) ?? []));
  }

  async getById(id: string): Promise<IpvDocument | null> {
    const { data, error } = await this.client.from('ipv_documents').select('*').eq('id', id).maybeSingle();

    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }

    if (!data) {
      return null;
    }

    const { data: lines, error: linesError } = await this.client
      .from('ipv_lines')
      .select('*')
      .eq('ipv_id', id)
      .order('sort_order');

    if (linesError) {
      throw new DomainError(linesError.message, InventoryErrorCodes.invalidInput);
    }

    return mapIpvDocument(data, lines ?? []);
  }

  async create(input: CreateIpvInput): Promise<IpvDocument> {
    const { data, error } = await this.client
      .from('ipv_documents')
      .insert({
        work_date: input.workDate,
        shift: 'manana',
        created_by: input.createdBy,
      })
      .select('*')
      .single();

    if (error || !data) {
      if (error?.code === '23505') {
        throw new DomainError('Ya existe un IPV para ese día.', InventoryErrorCodes.duplicate);
      }
      throw new DomainError(error?.message ?? 'No se pudo crear el IPV.', InventoryErrorCodes.invalidInput);
    }

    await this.seedStockedCatalogLines(data.id);
    const seeded = await this.getById(data.id);
    return seeded ?? mapIpvDocument(data);
  }

  private async seedStockedCatalogLines(ipvId: string): Promise<void> {
    const { data: catalog, error } = await this.client
      .from('product_catalog')
      .select('id, name, sale_price, replenishment_cost, stock_qty')
      .eq('is_active', true)
      .gt('stock_qty', 0)
      .order('name');

    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }

    if (!catalog || catalog.length === 0) {
      return;
    }

    const { error: insertError } = await this.client.from('ipv_lines').insert(
      catalog.map((product, index) => ({
        ipv_id: ipvId,
        product_id: product.id,
        product_name: product.name,
        opening_qty: product.stock_qty,
        inbound_qty: 0,
        outbound_qty: 0,
        sold_qty: 0,
        sale_price: product.sale_price,
        replenishment_cost: product.replenishment_cost,
        inbound_adds_stock: false,
        sort_order: index,
      })),
    );

    if (insertError) {
      throw new DomainError(insertError.message, InventoryErrorCodes.invalidInput);
    }
  }

  async upsertLine(input: UpsertIpvLineInput): Promise<IpvLine> {
    const { data: existing, error: existingError } = await this.client
      .from('ipv_lines')
      .select('id')
      .eq('ipv_id', input.ipvId)
      .eq('product_id', input.productId)
      .maybeSingle();

    if (existingError) {
      throw new DomainError(existingError.message, InventoryErrorCodes.invalidInput);
    }

    const payload = {
      opening_qty: input.openingQty,
      inbound_qty: input.inboundQty,
      outbound_qty: input.outboundQty,
      sold_qty: input.soldQty,
      sale_price: input.salePrice,
      replenishment_cost: input.replenishmentCost,
      inbound_adds_stock: input.inboundAddsStock,
      sort_order: input.sortOrder,
    };

    const query = existing
      ? this.client.from('ipv_lines').update(payload).eq('id', existing.id)
      : this.client.from('ipv_lines').insert({
          ipv_id: input.ipvId,
          product_id: input.productId,
          product_name: input.productName,
          ...payload,
        });

    const { data, error } = await query.select('*').single();

    if (error || !data) {
      if (error?.message.includes('cerrado')) {
        throw new DomainError('Este IPV ya está cerrado y no se puede editar.', InventoryErrorCodes.closed);
      }
      throw new DomainError(error?.message ?? 'No se pudo guardar la línea.', InventoryErrorCodes.invalidInput);
    }

    return mapIpvLine(data);
  }

  async removeLine(lineId: string): Promise<void> {
    const { error } = await this.client.from('ipv_lines').delete().eq('id', lineId);
    if (error) {
      if (error.message.includes('cerrado')) {
        throw new DomainError('Este IPV ya está cerrado y no se puede editar.', InventoryErrorCodes.closed);
      }
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
  }

  async close(id: string, _closedBy: string): Promise<IpvDocument> {
    const { error } = await this.client.rpc('close_ipv', { p_id: id });

    if (error) {
      if (error.message.includes('cerrado')) {
        throw new DomainError('Este IPV ya está cerrado y no se puede editar.', InventoryErrorCodes.closed);
      }
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }

    const document = await this.getById(id);
    if (!document) {
      throw new DomainError('No encontramos ese IPV.', InventoryErrorCodes.notFound);
    }
    return document;
  }

  async updateCollections(id: string, cashCollected: number, transferCollected: number): Promise<IpvDocument> {
    const { data, error } = await this.client
      .from('ipv_documents')
      .update({ cash_collected: cashCollected, transfer_collected: transferCollected })
      .eq('id', id)
      .eq('status', 'open')
      .select('*')
      .maybeSingle();

    if (error) {
      if (error.message.includes('cerrado')) {
        throw new DomainError('Este IPV ya está cerrado y no se puede editar.', InventoryErrorCodes.closed);
      }
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }

    if (!data) {
      const existing = await this.getById(id);
      if (!existing) {
        throw new DomainError('No encontramos ese IPV.', InventoryErrorCodes.notFound);
      }
      throw new DomainError('Este IPV ya está cerrado y no se puede editar.', InventoryErrorCodes.closed);
    }

    const { data: lines, error: linesError } = await this.client
      .from('ipv_lines')
      .select('*')
      .eq('ipv_id', id)
      .order('sort_order');
    if (linesError) {
      throw new DomainError(linesError.message, InventoryErrorCodes.invalidInput);
    }
    return mapIpvDocument(data, lines ?? []);
  }

  async getCashFlow(from: string, to: string) {
    const { data, error } = await this.client.rpc('cash_flow_report', { p_from: from, p_to: to });
    if (error || data === null) {
      throw new DomainError(error?.message ?? 'No se pudo armar la caja.', InventoryErrorCodes.invalidInput);
    }
    return mapCashFlow(data);
  }

  async remove(id: string): Promise<void> {
    const { error } = await this.client.rpc('delete_ipv', { p_id: id });
    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
  }
}
