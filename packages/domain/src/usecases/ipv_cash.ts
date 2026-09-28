import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import type { CashFlow } from '../entities/cash_flow';
import type { IpvDocument } from '../entities/ipv';
import type { IpvRepository } from '../repositories/ipv_repository';

export class UpdateIpvCollectionsUseCase {
  constructor(private readonly ipvRepository: IpvRepository) {}

  execute(id: string, cashCollected: number, transferPCollected: number, transferFCollected: number): Promise<IpvDocument> {
    if (cashCollected < 0 || transferPCollected < 0 || transferFCollected < 0) {
      throw new DomainError('El efectivo y las transferencias no pueden ser negativos.', InventoryErrorCodes.invalidInput);
    }
    return this.ipvRepository.updateCollections(id, cashCollected, transferPCollected, transferFCollected);
  }
}

export class GetCashFlowUseCase {
  constructor(private readonly ipvRepository: IpvRepository) {}

  execute(from: string, to: string): Promise<CashFlow> {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to) || to < from) {
      throw new DomainError('El rango de fechas no es válido.', InventoryErrorCodes.invalidInput);
    }
    return this.ipvRepository.getCashFlow(from, to);
  }
}
