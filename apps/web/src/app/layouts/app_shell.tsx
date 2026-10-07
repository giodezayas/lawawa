import { BarChart3, Boxes, CreditCard, Landmark, LayoutDashboard, LogOut, Menu, Package, Receipt, ShoppingCart, Users, Wallet, X } from 'lucide-react';
import { useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { User } from '@wawa/domain';
import { useAuth } from '../providers/auth_provider';

const navClass = ({ isActive }: { isActive: boolean }) =>
  `flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-medium ${
    isActive ? 'border-2 border-accent bg-white text-primary' : 'text-ink hover:bg-cream-dark'
  }`;

function AppNav({ canManageStaff, onNavigate }: { canManageStaff: boolean; onNavigate?: () => void }) {
  return (
    <nav className="flex flex-1 flex-col gap-1">
      <NavLink to="/" end className={navClass} onClick={onNavigate}>
        <LayoutDashboard size={18} />
        Inicio
      </NavLink>
      <p className="mt-5 px-4 pb-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-primary">Inventario</p>
      <NavLink to="/inventario/ipv" className={navClass} onClick={onNavigate}>
        <Boxes size={18} />
        IPV
      </NavLink>
      <NavLink to="/inventario/productos" className={navClass} onClick={onNavigate}>
        <Package size={18} />
        Productos
      </NavLink>
      <NavLink to="/inventario/compras" className={navClass} onClick={onNavigate}>
        <ShoppingCart size={18} />
        Compras
      </NavLink>
      <p className="mt-5 px-4 pb-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-primary">Finanzas</p>
      <NavLink to="/finanzas/resultados" className={navClass} onClick={onNavigate}>
        <Wallet size={18} />
        Resultados
      </NavLink>
      <NavLink to="/finanzas/reportes" className={navClass} onClick={onNavigate}>
        <BarChart3 size={18} />
        Reportes
      </NavLink>
      <NavLink to="/finanzas/tarjetas" className={navClass} onClick={onNavigate}>
        <CreditCard size={18} />
        Tarjetas
      </NavLink>
      <NavLink to="/finanzas/gastos" className={navClass} onClick={onNavigate}>
        <Receipt size={18} />
        Gastos
      </NavLink>
      <NavLink to="/finanzas/impuestos" className={navClass} onClick={onNavigate}>
        <Landmark size={18} />
        Impuestos
      </NavLink>
      {canManageStaff ? (
        <>
          <p className="mt-5 px-4 pb-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-primary">Equipo</p>
          <NavLink to="/equipo/usuarios" className={navClass} onClick={onNavigate}>
            <Users size={18} />
            Usuarios
          </NavLink>
        </>
      ) : null}
    </nav>
  );
}

export function AppShell() {
  const { user, signOut } = useAuth();
  const location = useLocation();
  const canManageStaff = user ? User.canManageStaff(user) : false;
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    setMenuOpen(false);
  }, [location.pathname]);

  useEffect(() => {
    if (!menuOpen) {
      return;
    }
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setMenuOpen(false);
      }
    };
    document.body.style.overflow = 'hidden';
    window.addEventListener('keydown', onKey);
    return () => {
      document.body.style.overflow = '';
      window.removeEventListener('keydown', onKey);
    };
  }, [menuOpen]);

  const closeMenu = () => setMenuOpen(false);

  return (
    <div className="min-h-screen bg-white">
      <div className="flex min-h-screen">
        <aside className="hidden w-72 shrink-0 flex-col border-r border-line bg-white px-5 py-6 md:flex">
          <div className="mb-10">
            <p className="text-xs font-semibold uppercase tracking-[0.28em] text-primary">Interno</p>
            <h1 className="mt-2 text-2xl font-extrabold leading-none text-primary">La Wawa</h1>
            <p className="mt-1 text-sm text-muted">Gestión del negocio</p>
          </div>
          <AppNav canManageStaff={canManageStaff} />
          {user ? (
            <div className="mt-6 rounded-2xl border border-line p-4">
              <p className="truncate text-sm font-semibold">{User.displayName(user)}</p>
              <p className="text-xs text-primary">{User.roleLabel(user.role)}</p>
            </div>
          ) : null}
        </aside>
        <div className="flex min-w-0 flex-1 flex-col bg-white">
          <header className="sticky top-0 z-20 flex items-center justify-between gap-3 border-b border-line bg-white px-4 py-3 md:px-8 md:py-4">
            <div className="flex min-w-0 items-center gap-3">
              <button
                type="button"
                className="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl border-2 border-accent bg-white text-primary md:hidden"
                aria-label={menuOpen ? 'Cerrar Menú' : 'Abrir Menú'}
                aria-expanded={menuOpen}
                aria-controls="mobile-menu"
                onClick={() => setMenuOpen((open) => !open)}
              >
                {menuOpen ? <X size={22} /> : <Menu size={22} />}
              </button>
              <div className="min-w-0">
                <p className="text-xs font-semibold uppercase tracking-[0.22em] text-primary">La Wawa</p>
                <h2 className="truncate text-base font-bold md:text-lg">Panel Interno</h2>
              </div>
            </div>
            <button
              type="button"
              onClick={() => void signOut()}
              className="btn-outline inline-flex h-11 shrink-0 items-center gap-2 rounded-full px-3 text-sm font-medium md:px-4"
            >
              <LogOut size={16} />
              <span className="hidden sm:inline">Salir</span>
            </button>
          </header>
          <main className="flex-1 overflow-x-hidden bg-white px-4 py-5 md:px-8 md:py-6">
            <Outlet />
          </main>
        </div>
      </div>
      {menuOpen ? (
        <div className="fixed inset-0 z-40 md:hidden">
          <button type="button" className="absolute inset-0 bg-ink/40" aria-label="Cerrar Menú" onClick={closeMenu} />
          <aside
            id="mobile-menu"
            className="absolute inset-y-0 left-0 flex w-[min(20rem,88vw)] flex-col bg-white px-5 py-6 shadow-xl"
          >
            <div className="mb-8 flex items-start justify-between gap-3">
              <div>
                <p className="text-xs font-semibold uppercase tracking-[0.28em] text-primary">Interno</p>
                <p className="mt-2 text-2xl font-extrabold leading-none text-primary">La Wawa</p>
                <p className="mt-1 text-sm text-muted">Gestión del negocio</p>
              </div>
              <button
                type="button"
                className="inline-flex h-10 w-10 items-center justify-center rounded-2xl border-2 border-accent text-primary"
                aria-label="Cerrar Menú"
                onClick={closeMenu}
              >
                <X size={20} />
              </button>
            </div>
            <AppNav canManageStaff={canManageStaff} onNavigate={closeMenu} />
            {user ? (
              <div className="mt-6 rounded-2xl border border-line p-4">
                <p className="truncate text-sm font-semibold">{User.displayName(user)}</p>
                <p className="text-xs text-primary">{User.roleLabel(user.role)}</p>
              </div>
            ) : null}
          </aside>
        </div>
      ) : null}
    </div>
  );
}
