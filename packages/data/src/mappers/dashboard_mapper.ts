import { DashboardStats } from '@wawa/domain';
import type { Database } from '../supabase/database.types';

type StatsRow = Database['public']['Views']['dashboard_stats']['Row'];

export function mapDashboardStats(row: StatsRow): DashboardStats {
  return DashboardStats.create({
    productCount: Number(row.product_count),
    lowStockCount: Number(row.low_stock_count),
    stockUnits: Number(row.stock_units),
    ipvTodayCount: Number(row.ipv_today_count),
    ipvTodayStatus: row.ipv_today_status,
    saleToday: Number(row.sale_today),
    profitToday: Number(row.profit_today),
    saleMonth: Number(row.sale_month),
    profitMonth: Number(row.profit_month),
    purchaseToday: Number(row.purchase_today),
    activeUserCount: Number(row.active_user_count),
  });
}
