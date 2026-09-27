import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import type { Product } from '../entities/product';
import type { ProductRepository } from '../repositories/product_repository';

export class GetProductUseCase {
  constructor(private readonly productRepository: ProductRepository) {}

  async execute(id: string): Promise<Product> {
    const product = await this.productRepository.getById(id);
    if (!product) {
      throw new DomainError('No encontramos ese producto.', InventoryErrorCodes.notFound);
    }
    return product;
  }
}
