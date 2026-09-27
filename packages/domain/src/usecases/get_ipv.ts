import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import type { IpvDocument } from '../entities/ipv';
import type { IpvRepository } from '../repositories/ipv_repository';

export class GetIpvUseCase {
  constructor(private readonly ipvRepository: IpvRepository) {}

  async execute(id: string): Promise<IpvDocument> {
    const document = await this.ipvRepository.getById(id);
    if (!document) {
      throw new DomainError('No encontramos ese IPV.', InventoryErrorCodes.notFound);
    }
    return document;
  }
}
