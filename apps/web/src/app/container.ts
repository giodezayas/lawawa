import {
  AuthRepositoryImpl,
  DashboardRepositoryImpl,
  IpvRepositoryImpl,
  ProductRepositoryImpl,
  PurchaseRepositoryImpl,
  ExpenseRepositoryImpl,
  UserRepositoryImpl,
  createBrowserSupabaseClient,
  isSupabaseConfigured,
  type AppSupabaseClient,
} from '@wawa/data';
import {
  AdjustProductStockUseCase,
  CloseIpvUseCase,
  CloseBillingPeriodUseCase,
  CreateExpenseEntryUseCase,
  CreateIpvUseCase,
  CreateProductUseCase,
  CreatePurchaseUseCase,
  CreateUserUseCase,
  DeleteExpenseEntryUseCase,
  DeleteIpvUseCase,
  DeleteProductUseCase,
  DeletePurchaseUseCase,
  DeleteUserUseCase,
  GetCurrentUserUseCase,
  GetDashboardStatsUseCase,
  GetCashFlowUseCase,
  GetExpenseEntryUseCase,
  GetIpvUseCase,
  GetProductUseCase,
  GetPurchaseUseCase,
  GetPeriodReportUseCase,
  GetBillingPeriodUseCase,
  GetUserUseCase,
  ListExpenseEntriesUseCase,
  ListIpvsUseCase,
  ListProductMovementsUseCase,
  ListProductsUseCase,
  ListPurchasesUseCase,
  ListUsersUseCase,
  ObserveAuthStateUseCase,
  RemoveIpvLineUseCase,
  SignInUseCase,
  SignOutUseCase,
  SetBillingPeriodUseCase,
  UpdateExpenseEntryUseCase,
  UpdateIpvCollectionsUseCase,
  UpdateProductUseCase,
  UpdatePurchaseUseCase,
  UpdateUserUseCase,
  UpsertIpvLineUseCase,
} from '@wawa/domain';

export type AppContainer = {
  supabase: AppSupabaseClient;
  signIn: SignInUseCase;
  signOut: SignOutUseCase;
  getCurrentUser: GetCurrentUserUseCase;
  observeAuthState: ObserveAuthStateUseCase;
  getDashboardStats: GetDashboardStatsUseCase;
  listUsers: ListUsersUseCase;
  getUser: GetUserUseCase;
  createUser: CreateUserUseCase;
  updateUser: UpdateUserUseCase;
  deleteUser: DeleteUserUseCase;
  listProducts: ListProductsUseCase;
  getProduct: GetProductUseCase;
  listProductMovements: ListProductMovementsUseCase;
  createProduct: CreateProductUseCase;
  updateProduct: UpdateProductUseCase;
  adjustProductStock: AdjustProductStockUseCase;
  deleteProduct: DeleteProductUseCase;
  listPurchases: ListPurchasesUseCase;
  getPurchase: GetPurchaseUseCase;
  createPurchase: CreatePurchaseUseCase;
  updatePurchase: UpdatePurchaseUseCase;
  deletePurchase: DeletePurchaseUseCase;
  listIpvs: ListIpvsUseCase;
  getIpv: GetIpvUseCase;
  createIpv: CreateIpvUseCase;
  upsertIpvLine: UpsertIpvLineUseCase;
  removeIpvLine: RemoveIpvLineUseCase;
  closeIpv: CloseIpvUseCase;
  updateIpvCollections: UpdateIpvCollectionsUseCase;
  getCashFlow: GetCashFlowUseCase;
  deleteIpv: DeleteIpvUseCase;
  listExpenseEntries: ListExpenseEntriesUseCase;
  getExpenseEntry: GetExpenseEntryUseCase;
  createExpenseEntry: CreateExpenseEntryUseCase;
  updateExpenseEntry: UpdateExpenseEntryUseCase;
  deleteExpenseEntry: DeleteExpenseEntryUseCase;
  getPeriodReport: GetPeriodReportUseCase;
  getBillingPeriod: GetBillingPeriodUseCase;
  setBillingPeriod: SetBillingPeriodUseCase;
  closeBillingPeriod: CloseBillingPeriodUseCase;
};

export function readWebSupabaseEnv() {
  return {
    url: import.meta.env.VITE_SUPABASE_URL ?? '',
    anonKey: import.meta.env.VITE_SUPABASE_ANON_KEY ?? '',
  };
}

export function isWebConfigured(): boolean {
  return isSupabaseConfigured(readWebSupabaseEnv());
}

export function createAppContainer(): AppContainer {
  const env = readWebSupabaseEnv();
  if (!isSupabaseConfigured(env)) {
    throw new Error('Supabase no está configurado.');
  }

  const supabase = createBrowserSupabaseClient(env);
  const authRepository = new AuthRepositoryImpl(supabase);
  const userRepository = new UserRepositoryImpl(supabase);
  const dashboardRepository = new DashboardRepositoryImpl(supabase);
  const productRepository = new ProductRepositoryImpl(supabase);
  const purchaseRepository = new PurchaseRepositoryImpl(supabase);
  const ipvRepository = new IpvRepositoryImpl(supabase);
  const expenseRepository = new ExpenseRepositoryImpl(supabase);

  return {
    supabase,
    signIn: new SignInUseCase(authRepository),
    signOut: new SignOutUseCase(authRepository),
    getCurrentUser: new GetCurrentUserUseCase(authRepository),
    observeAuthState: new ObserveAuthStateUseCase(authRepository),
    getDashboardStats: new GetDashboardStatsUseCase(dashboardRepository),
    listUsers: new ListUsersUseCase(userRepository),
    getUser: new GetUserUseCase(userRepository),
    createUser: new CreateUserUseCase(userRepository),
    updateUser: new UpdateUserUseCase(userRepository),
    deleteUser: new DeleteUserUseCase(userRepository),
    listProducts: new ListProductsUseCase(productRepository),
    getProduct: new GetProductUseCase(productRepository),
    listProductMovements: new ListProductMovementsUseCase(productRepository),
    createProduct: new CreateProductUseCase(productRepository),
    updateProduct: new UpdateProductUseCase(productRepository),
    adjustProductStock: new AdjustProductStockUseCase(productRepository),
    deleteProduct: new DeleteProductUseCase(productRepository),
    listPurchases: new ListPurchasesUseCase(purchaseRepository),
    getPurchase: new GetPurchaseUseCase(purchaseRepository),
    createPurchase: new CreatePurchaseUseCase(purchaseRepository),
    updatePurchase: new UpdatePurchaseUseCase(purchaseRepository),
    deletePurchase: new DeletePurchaseUseCase(purchaseRepository),
    listIpvs: new ListIpvsUseCase(ipvRepository),
    getIpv: new GetIpvUseCase(ipvRepository),
    createIpv: new CreateIpvUseCase(ipvRepository),
    upsertIpvLine: new UpsertIpvLineUseCase(ipvRepository),
    removeIpvLine: new RemoveIpvLineUseCase(ipvRepository),
    closeIpv: new CloseIpvUseCase(ipvRepository),
    updateIpvCollections: new UpdateIpvCollectionsUseCase(ipvRepository),
    getCashFlow: new GetCashFlowUseCase(ipvRepository),
    deleteIpv: new DeleteIpvUseCase(ipvRepository),
    listExpenseEntries: new ListExpenseEntriesUseCase(expenseRepository),
    getExpenseEntry: new GetExpenseEntryUseCase(expenseRepository),
    createExpenseEntry: new CreateExpenseEntryUseCase(expenseRepository),
    updateExpenseEntry: new UpdateExpenseEntryUseCase(expenseRepository),
    deleteExpenseEntry: new DeleteExpenseEntryUseCase(expenseRepository),
    getPeriodReport: new GetPeriodReportUseCase(expenseRepository),
    getBillingPeriod: new GetBillingPeriodUseCase(expenseRepository),
    setBillingPeriod: new SetBillingPeriodUseCase(expenseRepository),
    closeBillingPeriod: new CloseBillingPeriodUseCase(expenseRepository),
  };
}
