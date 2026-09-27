import type { DashboardStats } from '../entities/dashboard_stats';
import type { DashboardRepository } from '../repositories/dashboard_repository';

export class GetDashboardStatsUseCase {
  constructor(private readonly dashboardRepository: DashboardRepository) {}

  execute(): Promise<DashboardStats> {
    return this.dashboardRepository.getStats();
  }
}
