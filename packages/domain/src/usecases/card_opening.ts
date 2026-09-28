import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import type { CardOpening } from '../entities/card_opening';
import type { CardOpeningRepository, UpsertCardOpeningInput } from '../repositories/card_opening_repository';

export class GetCardOpeningUseCase {
  constructor(private readonly repository: CardOpeningRepository) {}

  execute(): Promise<CardOpening | null> {
    return this.repository.get();
  }
}

export class UpsertCardOpeningUseCase {
  constructor(private readonly repository: CardOpeningRepository) {}

  execute(input: UpsertCardOpeningInput): Promise<CardOpening> {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(input.asOf)) {
      throw new DomainError('La fecha no es válida.', InventoryErrorCodes.invalidInput);
    }
    if (input.pAmount < 0 || input.fAmount < 0) {
      throw new DomainError('El saldo de las tarjetas no puede ser negativo.', InventoryErrorCodes.invalidInput);
    }
    return this.repository.upsert(input);
  }
}
