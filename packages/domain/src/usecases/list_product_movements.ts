import type { StockMovement } from '../entities/product';
import type { ProductRepository } from '../repositories/product_repository';

export class ListProductMovementsUseCase {
  constructor(private readonly productRepository: ProductRepository) {}

  execute(productId: string): Promise<StockMovement[]> {
    return this.productRepository.listMovements(productId);
  }
}
