import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import { paymentMethods, type PaymentMethod, type PurchaseDocument } from '../entities/purchase';
import type { PurchaseRepository } from '../repositories/purchase_repository';

export class CreatePurchaseUseCase {
  constructor(private readonly purchaseRepository: PurchaseRepository) {}

  execute(input: {
    purchasedOn: string;
    paymentMethod: PaymentMethod;
    createdBy: string;
    lines: readonly { productId: string; qty: number; unitCost: number }[];
  }): Promise<PurchaseDocument> {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(input.purchasedOn) || !paymentMethods.includes(input.paymentMethod)) {
      throw new DomainError('La fecha de compra no es válida.', InventoryErrorCodes.invalidInput);
    }

    if (input.lines.length === 0) {
      throw new DomainError('Agrega al menos un producto a la compra.', InventoryErrorCodes.invalidInput);
    }

    for (const line of input.lines) {
      if (!line.productId || line.qty <= 0 || line.unitCost < 0) {
        throw new DomainError('Cada línea necesita producto, cantidad y costo.', InventoryErrorCodes.invalidInput);
      }
    }

    return this.purchaseRepository.create(input);
  }
}
