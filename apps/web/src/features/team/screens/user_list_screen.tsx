import { DomainError, User } from '@wawa/domain';
import { useEffect, useMemo, useState } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';

type SortKey = 'fullName' | 'email' | 'role';

export function UserListScreen() {
  const { container, user } = useAuth();
  const [rows, setRows] = useState<User[]>([]);
  const [pageError, setPageError] = useState('');
  const [sortKey, setSortKey] = useState<SortKey>('fullName');
  const [sortAsc, setSortAsc] = useState(true);
  const [deletingId, setDeletingId] = useState('');

  async function load() {
    if (!user) {
      return;
    }
    setRows(await container.listUsers.execute(user));
  }

  useEffect(() => {
    void load().catch((error) => {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo cargar el equipo.');
    });
  }, [container, user]);

  const sorted = useMemo(() => {
    return rows.slice().sort((left, right) => {
      const direction = sortAsc ? 1 : -1;
      if (sortKey === 'role') {
        return User.roleLabel(left.role).localeCompare(User.roleLabel(right.role)) * direction;
      }
      const leftValue = sortKey === 'fullName' ? User.displayName(left) : left.email;
      const rightValue = sortKey === 'fullName' ? User.displayName(right) : right.email;
      return leftValue.localeCompare(rightValue) * direction;
    });
  }, [rows, sortKey, sortAsc]);

  function toggleSort(key: SortKey) {
    if (sortKey === key) {
      setSortAsc((value) => !value);
      return;
    }
    setSortKey(key);
    setSortAsc(true);
  }

  async function handleDelete(row: User) {
    if (!user || !window.confirm(`¿Borrar a ${User.displayName(row)}?`)) {
      return;
    }
    setDeletingId(row.id);
    setPageError('');
    try {
      await container.deleteUser.execute(user, row.id);
      await load();
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo borrar el usuario.');
    } finally {
      setDeletingId('');
    }
  }

  if (user && !User.canManageStaff(user)) {
    return <Navigate to="/" replace />;
  }

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold">Usuarios</h1>
          <p className="mt-1 text-sm text-muted">Invita al equipo. No hay registro público.</p>
        </div>
        <Link
          to="/equipo/usuarios/nuevo"
          className="btn-primary inline-flex h-12 items-center rounded-2xl px-5 text-sm font-semibold"
        >
          Invitar Usuario
        </Link>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
      <div className="overflow-x-auto rounded-3xl border border-line bg-surface">
        <table className="min-w-full text-sm">
          <thead>
            <tr className="border-b border-line text-left">
              <th>
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('fullName')}>
                  Nombre
                </button>
              </th>
              <th>
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('email')}>
                  Correo
                </button>
              </th>
              <th>
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('role')}>
                  Rol
                </button>
              </th>
              <th className="px-4 py-3 font-semibold">Estado</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {sorted.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-muted">
                  No hay usuarios para mostrar.
                </td>
              </tr>
            ) : (
              sorted.map((row) => (
                <tr key={row.id} className="border-t border-line">
                  <td className="px-4 py-3">{User.displayName(row)}</td>
                  <td className="px-4 py-3">{row.email}</td>
                  <td className="px-4 py-3">{User.roleLabel(row.role)}</td>
                  <td className="px-4 py-3">{row.isActive ? 'Activo' : 'Inactivo'}</td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex justify-end gap-3">
                      <Link to={`/equipo/usuarios/${row.id}`} className="font-semibold text-primary">
                        Ver
                      </Link>
                      {user && user.id !== row.id ? (
                        <button
                          type="button"
                          className="text-danger"
                          disabled={deletingId === row.id}
                          onClick={() => void handleDelete(row)}
                        >
                          {deletingId === row.id ? 'Borrando...' : 'Borrar'}
                        </button>
                      ) : null}
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
