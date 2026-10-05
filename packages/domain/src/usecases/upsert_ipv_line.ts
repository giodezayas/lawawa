import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import type { IpvLine } from '../entities/ipv';
import type { IpvLineDefaults, IpvRepository } from '../repositories/ipv_repository';

export class GetIpvLineDefaultsUseCase {
  constructor(private readonly ipvRepository: IpvRepository) {}

  execute(ipvId: string, productId: string): Promise<IpvLineDefaults> {
    if (!ipvId || !productId) {
      throw new DomainError('Elige un producto del catálogo.', InventoryErrorCodes.invalidInput);
    }
    return this.ipvRepository.lineDefaults(ipvId, productId);
  }
}

export class UpsertIpvLineUseCase {
  constructor(private readonly ipvRepository: IpvRepository) {}

  execute(input: {
    id?: string;
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
    if (!input.productId) {
      throw new DomainError('Elige un producto del catálogo.', InventoryErrorCodes.invalidInput);
    }

    const quantities = [input.openingQty, input.inboundQty, input.outboundQty, input.soldQty];
    if (quantities.some((value) => value < 0)) {
      throw new DomainError('Las cantidades no pueden ser negativas.', InventoryErrorCodes.invalidInput);
    }

    return this.ipvRepository.upsertLine(input);
  }
}
