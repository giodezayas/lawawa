import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import type { IpvLine } from '../entities/ipv';
import type { IpvRepository } from '../repositories/ipv_repository';

export class UpsertIpvLineUseCase {
  constructor(private readonly ipvRepository: IpvRepository) {}

  execute(input: {
    ipvId: string;
    productId: string;
    productName: string;
    openingQty: number;
    inboundQty: number;
    outboundQty: number;
    soldQty: number;
    salePrice: number;
    replenishmentCost: number;
    inboundAddsStock: boolean;
    sortOrder: number;
  }): Promise<IpvLine> {
    if (!input.productId || input.productName.trim().length === 0) {
      throw new DomainError('Elige un producto del catálogo.', InventoryErrorCodes.invalidInput);
    }

    const quantities = [input.openingQty, input.inboundQty, input.outboundQty, input.soldQty];
    if (quantities.some((value) => value < 0)) {
      throw new DomainError('Las cantidades no pueden ser negativas.', InventoryErrorCodes.invalidInput);
    }

    return this.ipvRepository.upsertLine(input);
  }
}
