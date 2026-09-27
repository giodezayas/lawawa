import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import type { PurchaseDocument } from '../entities/purchase';
import type { PurchaseRepository } from '../repositories/purchase_repository';

export class GetPurchaseUseCase {
  constructor(private readonly purchaseRepository: PurchaseRepository) {}

  async execute(id: string): Promise<PurchaseDocument> {
    const document = await this.purchaseRepository.getById(id);
    if (!document) {
      throw new DomainError('No encontramos esa compra.', InventoryErrorCodes.notFound);
    }
    return document;
  }
}
