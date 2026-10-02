import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import type { CashFlow } from '../entities/cash_flow';
import { IpvDocument } from '../entities/ipv';
import type { IpvRepository } from '../repositories/ipv_repository';

export class UpdateIpvCollectionsUseCase {
  constructor(private readonly ipvRepository: IpvRepository) {}

  async execute(id: string, transferPCollected: number, transferFCollected: number): Promise<IpvDocument> {
    if (transferPCollected < 0 || transferFCollected < 0) {
      throw new DomainError('Las transferencias no pueden ser negativas.', InventoryErrorCodes.invalidInput);
    }
    const document = await this.ipvRepository.getById(id);
    if (!document) {
      throw new DomainError('No encontramos ese IPV.', InventoryErrorCodes.notFound);
    }
    const cashCollected = IpvDocument.cashFromSale(
      IpvDocument.saleTotal(document),
      transferPCollected,
      transferFCollected,
    );
    if (cashCollected < 0) {
      throw new DomainError(
        'La transferencia no puede ser mayor que la venta del día.',
        InventoryErrorCodes.invalidInput,
      );
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
