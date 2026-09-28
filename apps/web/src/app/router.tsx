import { Navigate, Outlet, RouterProvider, createBrowserRouter } from 'react-router-dom';
import { AppShell } from './layouts/app_shell';
import { useAuth } from './providers/auth_provider';
import { LoginScreen } from '../features/auth/screens/login_screen';
import { DashboardScreen } from '../features/dashboard/screens/dashboard_screen';
import { IpvEditorScreen } from '../features/inventory/screens/ipv_editor_screen';
import { IpvListScreen } from '../features/inventory/screens/ipv_list_screen';
import { ProductDetailScreen } from '../features/inventory/screens/product_detail_screen';
import { ProductsScreen } from '../features/inventory/screens/products_screen';
import { PurchaseEditorScreen } from '../features/inventory/screens/purchase_editor_screen';
import { PurchaseListScreen } from '../features/inventory/screens/purchase_list_screen';
import { UserEditorScreen } from '../features/team/screens/user_editor_screen';
import { UserListScreen } from '../features/team/screens/user_list_screen';
import { ExpenseEditorScreen } from '../features/finance/screens/expense_editor_screen';
import { ExpenseListScreen } from '../features/finance/screens/expense_list_screen';
import { ResultsScreen } from '../features/finance/screens/results_screen';
import { ReportsScreen } from '../features/finance/screens/reports_screen';
import { CardsScreen } from '../features/finance/screens/cards_screen';
import { LoadingState } from '../shared/ui/loading_state';

function GuestRoute() {
  const { status } = useAuth();

  if (status === 'booting') {
    return <LoadingState label="Preparando acceso..." />;
  }

  if (status === 'authenticated') {
    return <Navigate to="/" replace />;
  }

  return <Outlet />;
}

function ProtectedRoute() {
  const { status } = useAuth();

  if (status === 'booting') {
    return <LoadingState label="Cargando tu sesión..." />;
  }

  if (status === 'anonymous') {
    return <Navigate to="/login" replace />;
  }

  return <Outlet />;
}

const router = createBrowserRouter([
  {
    element: <GuestRoute />,
    children: [{ path: '/login', element: <LoginScreen /> }],
  },
  {
    element: <ProtectedRoute />,
    children: [
      {
        element: <AppShell />,
        children: [
          { path: '/', element: <DashboardScreen /> },
          { path: '/inventario/ipv', element: <IpvListScreen /> },
          { path: '/inventario/ipv/nuevo', element: <IpvEditorScreen /> },
          { path: '/inventario/ipv/:ipvId', element: <IpvEditorScreen /> },
          { path: '/inventario/productos', element: <ProductsScreen /> },
          { path: '/inventario/productos/:productId', element: <ProductDetailScreen /> },
          { path: '/inventario/compras', element: <PurchaseListScreen /> },
          { path: '/inventario/compras/nueva', element: <PurchaseEditorScreen /> },
          { path: '/inventario/compras/:purchaseId', element: <PurchaseEditorScreen /> },
          { path: '/equipo/usuarios', element: <UserListScreen /> },
          { path: '/equipo/usuarios/nuevo', element: <UserEditorScreen /> },
          { path: '/equipo/usuarios/:userId', element: <UserEditorScreen /> },
          { path: '/finanzas/resultados', element: <ResultsScreen /> },
          { path: '/finanzas/reportes', element: <ReportsScreen /> },
          { path: '/finanzas/tarjetas', element: <CardsScreen /> },
          { path: '/finanzas/gastos', element: <ExpenseListScreen /> },
          { path: '/finanzas/gastos/nuevo', element: <ExpenseEditorScreen /> },
          { path: '/finanzas/gastos/:expenseId', element: <ExpenseEditorScreen /> },
        ],
      },
    ],
  },
  { path: '*', element: <Navigate to="/" replace /> },
]);

export function AppRouter() {
  return <RouterProvider router={router} />;
}
