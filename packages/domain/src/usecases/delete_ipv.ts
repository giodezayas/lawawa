import type { IpvRepository } from '../repositories/ipv_repository';

export class DeleteIpvUseCase {
  constructor(private readonly ipvRepository: IpvRepository) {}

  execute(id: string): Promise<void> {
    return this.ipvRepository.remove(id);
  }
}
