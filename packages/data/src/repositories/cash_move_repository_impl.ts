import { DomainError, InventoryErrorCodes, type CashMove, type CashMoveRepository, type CreateCashMoveInput } from '@wawa/domain';
import { mapCashMove } from '../mappers/cash_move_mapper';
import type { AppSupabaseClient } from '../supabase/client';

export class CashMoveRepositoryImpl implements CashMoveRepository {
  constructor(private readonly client: AppSupabaseClient) {}

  async list(from: string, to: string): Promise<CashMove[]> {
    const { data, error } = await this.client
      .from('cash_moves')
      .select('*')
      .gte('occurred_on', from)
      .lte('occurred_on', to)
      .order('occurred_on', { ascending: false })
      .order('created_at', { ascending: false });

    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
    return (data ?? []).map(mapCashMove);
  }

  async create(input: CreateCashMoveInput): Promise<CashMove> {
    const { data, error } = await this.client
      .from('cash_moves')
      .insert({
        occurred_on: input.occurredOn,
        kind: input.kind,
        card: input.card,
        amount: input.amount,
        notes: input.notes,
        created_by: input.createdBy,
      })
      .select('*')
      .single();

    if (error || !data) {
      throw new DomainError(error?.message ?? 'No se pudo guardar el movimiento.', InventoryErrorCodes.invalidInput);
    }
    return mapCashMove(data);
  }

  async remove(id: string): Promise<void> {
    const { error } = await this.client.from('cash_moves').delete().eq('id', id);
    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
  }
}
