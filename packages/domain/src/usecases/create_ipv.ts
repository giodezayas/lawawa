import { DomainError, InventoryErrorCodes } from '../errors/domain_error';
import type { IpvDocument } from '../entities/ipv';
import type { IpvRepository } from '../repositories/ipv_repository';

export class CreateIpvUseCase {
  constructor(private readonly ipvRepository: IpvRepository) {}

  execute(input: { workDate: string; createdBy: string }): Promise<IpvDocument> {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(input.workDate)) {
      throw new DomainError('La fecha del día no es válida.', InventoryErrorCodes.invalidInput);
    }

    return this.ipvRepository.create(input);
  }
}
