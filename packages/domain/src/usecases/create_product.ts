import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import type { Product } from '../entities/product';
import type { ProductRepository } from '../repositories/product_repository';

export class CreateProductUseCase {
  constructor(private readonly productRepository: ProductRepository) {}

  execute(input: {
    name: string;
    salePrice: number;
    purchasePrice: number;
    replenishmentCost: number;
    minStock: number;
    countsForTax?: boolean;
  }): Promise<Product> {
    const name = input.name.trim();
    if (name.length === 0) {
      throw new DomainError('El nombre del producto es obligatorio.', InventoryErrorCodes.invalidInput);
    }

    if (
      input.salePrice < 0 ||
      input.purchasePrice < 0 ||
      input.replenishmentCost < 0 ||
      input.minStock < 0
    ) {
      throw new DomainError('El precio y el mínimo no pueden ser negativos.', InventoryErrorCodes.invalidInput);
    }

    return this.productRepository.create({
      name,
      salePrice: input.salePrice,
      purchasePrice: input.purchasePrice,
      replenishmentCost: input.replenishmentCost,
      minStock: input.minStock,
      countsForTax: input.countsForTax !== false,
    });
  }
}
