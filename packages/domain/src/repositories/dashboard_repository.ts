import type { DashboardStats } from '../entities/dashboard_stats';

export interface DashboardRepository {
  getStats(): Promise<DashboardStats>;
}
