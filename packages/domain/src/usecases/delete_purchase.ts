import type { PurchaseRepository } from '../repositories/purchase_repository';

export class DeletePurchaseUseCase {
  constructor(private readonly purchaseRepository: PurchaseRepository) {}

  execute(id: string): Promise<void> {
    return this.purchaseRepository.remove(id);
  }
}
