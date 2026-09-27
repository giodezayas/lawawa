import type { IpvDocument } from '../entities/ipv';
import type { IpvRepository } from '../repositories/ipv_repository';

export class ListIpvsUseCase {
  constructor(private readonly ipvRepository: IpvRepository) {}

  execute(): Promise<IpvDocument[]> {
    return this.ipvRepository.list();
  }
}
