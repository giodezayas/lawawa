import type { PurchaseDocument } from '../entities/purchase';
import type { PurchaseRepository } from '../repositories/purchase_repository';

export class ListPurchasesUseCase {
  constructor(private readonly purchaseRepository: PurchaseRepository) {}

  execute(): Promise<PurchaseDocument[]> {
    return this.purchaseRepository.list();
  }
}
