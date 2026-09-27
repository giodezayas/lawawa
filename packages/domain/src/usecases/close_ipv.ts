import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import { IpvDocument } from '../entities/ipv';
import type { IpvRepository } from '../repositories/ipv_repository';

export class CloseIpvUseCase {
  constructor(private readonly ipvRepository: IpvRepository) {}

  async execute(id: string, closedBy: string): Promise<IpvDocument> {
    const document = await this.ipvRepository.getById(id);
    if (!document) {
      throw new DomainError('No encontramos ese IPV.', InventoryErrorCodes.notFound);
    }

    if (!IpvDocument.isOpen(document)) {
      throw new DomainError('Este IPV ya está cerrado.', InventoryErrorCodes.closed);
    }

    if (document.lines.length === 0) {
      throw new DomainError('Agrega al menos un producto antes de cerrar.', InventoryErrorCodes.invalidInput);
    }

    return this.ipvRepository.close(id, closedBy);
  }
}
