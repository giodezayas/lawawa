import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import type { CashMove } from '../entities/cash_move';
import { cashMoveKinds, transferCards, type CashMoveKind } from '../entities/cash_move';
import type { CashMoveRepository, CreateCashMoveInput } from '../repositories/cash_move_repository';

export class ListCashMovesUseCase {
  constructor(private readonly repository: CashMoveRepository) {}

  execute(from: string, to: string): Promise<CashMove[]> {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to) || to < from) {
      throw new DomainError('El rango de fechas no es válido.', InventoryErrorCodes.invalidInput);
    }
    return this.repository.list(from, to);
  }
}

export class CreateCashMoveUseCase {
  constructor(private readonly repository: CashMoveRepository) {}

  execute(input: CreateCashMoveInput): Promise<CashMove> {
    if (!cashMoveKinds.includes(input.kind)) {
      throw new DomainError('El tipo de movimiento no es válido.', InventoryErrorCodes.invalidInput);
    }
    if (!transferCards.includes(input.card)) {
      throw new DomainError('Elige Tarjeta P o Tarjeta F.', InventoryErrorCodes.invalidInput);
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(input.occurredOn)) {
      throw new DomainError('La fecha no es válida.', InventoryErrorCodes.invalidInput);
    }
    if (!(input.amount > 0)) {
      throw new DomainError('El importe tiene que ser mayor que 0.', InventoryErrorCodes.invalidInput);
    }
    return this.repository.create(input);
  }
}

export class DeleteCashMoveUseCase {
  constructor(private readonly repository: CashMoveRepository) {}

  execute(id: string): Promise<void> {
    if (!id) {
      throw new DomainError('No encontramos ese movimiento.', InventoryErrorCodes.notFound);
    }
    return this.repository.remove(id);
  }
}
