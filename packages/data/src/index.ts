export {
  createBrowserSupabaseClient,
  createNativeSupabaseClient,
  isSupabaseConfigured,
} from './supabase/client';
export type {
  AppSupabaseClient,
  NativeAuthStorage,
  SupabaseConfig,
} from './supabase/client';
export type { Database } from './supabase/database.types';
export { AuthRepositoryImpl } from './repositories/auth_repository_impl';
export { UserRepositoryImpl } from './repositories/user_repository_impl';
export { DashboardRepositoryImpl } from './repositories/dashboard_repository_impl';
export { ProductRepositoryImpl } from './repositories/product_repository_impl';
export { IpvRepositoryImpl } from './repositories/ipv_repository_impl';
export { PurchaseRepositoryImpl } from './repositories/purchase_repository_impl';
export { ExpenseRepositoryImpl } from './repositories/expense_repository_impl';
export { CashMoveRepositoryImpl } from './repositories/cash_move_repository_impl';
export { mapProfileToUser } from './mappers/user_mapper';
export { mapDashboardStats } from './mappers/dashboard_mapper';
export { mapProduct } from './mappers/product_mapper';
export { mapIpvDocument, mapIpvLine } from './mappers/ipv_mapper';
export { mapPurchaseDocument } from './mappers/purchase_mapper';
export { mapStockMovement } from './mappers/stock_movement_mapper';
export { mapExpenseCategory, mapExpenseEntry } from './mappers/expense_mapper';
export { mapPeriodReport } from './mappers/period_report_mapper';
export { mapCashFlow } from './mappers/cash_flow_mapper';
