import { Boxes, LayoutDashboard, LogOut, Package, Receipt, ShoppingCart, Users, Wallet } from 'lucide-react';
import { NavLink, Outlet } from 'react-router-dom';
import { User } from '@wawa/domain';
import { useAuth } from '../providers/auth_provider';

const navClass = ({ isActive }: { isActive: boolean }) =>
  `flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-medium ${
    isActive ? 'border-2 border-accent bg-white text-primary' : 'text-ink hover:bg-cream-dark'
  }`;

const mobileNavClass = ({ isActive }: { isActive: boolean }) =>
  `flex flex-1 flex-col items-center gap-1 py-2 text-[11px] font-medium ${
    isActive ? 'text-primary' : 'text-muted'
  }`;

export function AppShell() {
  const { user, signOut } = useAuth();
  const canManageStaff = user ? User.canManageStaff(user) : false;

  return (
    <div className="min-h-screen bg-white">
      <div className="flex min-h-screen">
        <aside className="hidden w-72 flex-col border-r border-line bg-white px-5 py-6 md:flex">
          <div className="mb-10">
            <p className="text-xs font-semibold uppercase tracking-[0.28em] text-primary">Interno</p>
            <h1 className="mt-2 text-2xl font-extrabold leading-none text-primary">La Wawa</h1>
            <p className="mt-1 text-sm text-muted">Gestión del negocio</p>
          </div>
          <nav className="flex flex-1 flex-col gap-1">
            <NavLink to="/" end className={navClass}>
              <LayoutDashboard size={18} />
              Inicio
            </NavLink>
            <p className="mt-5 px-4 pb-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-primary">
              Inventario
            </p>
            <NavLink to="/inventario/ipv" className={navClass}>
              <Boxes size={18} />
              IPV
            </NavLink>
            <NavLink to="/inventario/productos" className={navClass}>
              <Package size={18} />
              Productos
            </NavLink>
            <NavLink to="/inventario/compras" className={navClass}>
              <ShoppingCart size={18} />
              Compras
            </NavLink>
            <p className="mt-5 px-4 pb-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-primary">
              Finanzas
            </p>
            <NavLink to="/finanzas/resultados" className={navClass}>
              <Wallet size={18} />
              Resultados
            </NavLink>
            <NavLink to="/finanzas/gastos" className={navClass}>
              <Receipt size={18} />
              Gastos
            </NavLink>
            {canManageStaff ? (
              <>
                <p className="mt-5 px-4 pb-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-primary">
                  Equipo
                </p>
                <NavLink to="/equipo/usuarios" className={navClass}>
                  <Users size={18} />
                  Usuarios
                </NavLink>
              </>
            ) : null}
          </nav>
          {user ? (
            <div className="rounded-2xl border border-line p-4">
              <p className="truncate text-sm font-semibold">{User.displayName(user)}</p>
              <p className="text-xs text-primary">{User.roleLabel(user.role)}</p>
            </div>
          ) : null}
        </aside>
        <div className="flex min-w-0 flex-1 flex-col bg-white">
          <header className="flex items-center justify-between border-b border-line bg-white px-4 py-4 md:px-8">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.22em] text-primary md:hidden">La Wawa</p>
              <h2 className="text-lg font-bold">Panel Interno</h2>
            </div>
            <button
              type="button"
              onClick={() => void signOut()}
              className="btn-outline inline-flex items-center gap-2 rounded-full px-4 py-2 text-sm font-medium text-ink transition hover:text-primary"
            >
              <LogOut size={16} />
              Salir
            </button>
          </header>
          <main className="flex-1 bg-white px-4 py-6 pb-24 md:px-8 md:pb-6">
            <Outlet />
          </main>
        </div>
      </div>
      <nav className="fixed inset-x-0 bottom-0 z-10 border-t border-line bg-white md:hidden">
        <div className="flex">
          <NavLink to="/" end className={mobileNavClass}>
            <LayoutDashboard size={18} />
            Inicio
          </NavLink>
          <NavLink to="/inventario/ipv" className={mobileNavClass}>
            <Boxes size={18} />
            IPV
          </NavLink>
          <NavLink to="/finanzas/gastos" className={mobileNavClass}>
            <Receipt size={18} />
            Gastos
          </NavLink>
          <NavLink to="/finanzas/resultados" className={mobileNavClass}>
            <Wallet size={18} />
            Resultados
          </NavLink>
          <NavLink to="/inventario/productos" className={mobileNavClass}>
            <Package size={18} />
            Productos
          </NavLink>
          {canManageStaff ? (
            <NavLink to="/equipo/usuarios" className={mobileNavClass}>
              <Users size={18} />
              Usuarios
            </NavLink>
          ) : null}
        </div>
      </nav>
    </div>
  );
}
