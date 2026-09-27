import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import type { Product } from '../entities/product';
import type { ProductRepository } from '../repositories/product_repository';

export class AdjustProductStockUseCase {
  constructor(private readonly productRepository: ProductRepository) {}

  execute(productId: string, qty: number): Promise<Product> {
    if (qty < 0) {
      throw new DomainError('El stock no puede ser negativo.', InventoryErrorCodes.invalidInput);
    }
    return this.productRepository.adjustStock(productId, qty);
  }
}
