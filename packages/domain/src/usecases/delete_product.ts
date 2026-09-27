import type { ProductRepository } from '../repositories/product_repository';

export class DeleteProductUseCase {
  constructor(private readonly productRepository: ProductRepository) {}

  execute(id: string): Promise<void> {
    return this.productRepository.remove(id);
  }
}
