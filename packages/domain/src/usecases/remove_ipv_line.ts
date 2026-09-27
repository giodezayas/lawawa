import type { IpvRepository } from '../repositories/ipv_repository';

export class RemoveIpvLineUseCase {
  constructor(private readonly ipvRepository: IpvRepository) {}

  execute(lineId: string): Promise<void> {
    return this.ipvRepository.removeLine(lineId);
  }
}
