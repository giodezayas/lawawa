import {
  DomainError,
  InventoryErrorCodes,
  type DashboardRepository,
  type DashboardStats,
} from '@wawa/domain';
import { mapDashboardStats } from '../mappers/dashboard_mapper';
import type { AppSupabaseClient } from '../supabase/client';

export class DashboardRepositoryImpl implements DashboardRepository {
  constructor(private readonly client: AppSupabaseClient) {}

  async getStats(): Promise<DashboardStats> {
    const { data, error } = await this.client.from('dashboard_stats').select('*').maybeSingle();

    if (error || !data) {
      throw new DomainError(error?.message ?? 'No se pudieron cargar las estadísticas.', InventoryErrorCodes.invalidInput);
    }

    return mapDashboardStats(data);
  }
}
