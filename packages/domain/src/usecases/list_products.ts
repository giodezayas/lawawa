import type { Product } from '../entities/product';
import type { ProductRepository } from '../repositories/product_repository';

export class ListProductsUseCase {
  constructor(private readonly productRepository: ProductRepository) {}

  execute(): Promise<Product[]> {
    return this.productRepository.listAll();
  }
}
