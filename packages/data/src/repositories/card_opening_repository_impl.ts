import { DomainError, InventoryErrorCodes, type CardOpening, type CardOpeningRepository, type UpsertCardOpeningInput } from '@wawa/domain';
import { mapCardOpening } from '../mappers/card_opening_mapper';
import type { AppSupabaseClient } from '../supabase/client';

export class CardOpeningRepositoryImpl implements CardOpeningRepository {
  constructor(private readonly client: AppSupabaseClient) {}

  async get(): Promise<CardOpening | null> {
    const { data, error } = await this.client.from('card_opening').select('*').limit(1).maybeSingle();
    if (error) {
      throw new DomainError(error.message, InventoryErrorCodes.invalidInput);
    }
    return data ? mapCardOpening(data) : null;
  }

  async upsert(input: UpsertCardOpeningInput): Promise<CardOpening> {
    const { data, error } = await this.client
      .from('card_opening')
      .upsert(
        {
          id: true,
          as_of: input.asOf,
          p_amount: input.pAmount,
          f_amount: input.fAmount,
          notes: input.notes,
          updated_by: input.updatedBy,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'id' },
      )
      .select('*')
      .single();

    if (error || !data) {
      throw new DomainError(error?.message ?? 'No se pudo guardar el saldo de las tarjetas.', InventoryErrorCodes.invalidInput);
    }
    return mapCardOpening(data);
  }
}
