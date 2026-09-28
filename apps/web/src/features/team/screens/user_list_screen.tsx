import { DomainError, User } from '@wawa/domain';
import { useEffect, useMemo, useState } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { useConfirm } from '../../../shared/ui/confirm_dialog';
import { ScrollTable, TableSpinner } from '../../../shared/ui/list_table';
import { TextField } from '../../../shared/ui/text_field';

type SortKey = 'fullName' | 'username' | 'role';

export function UserListScreen() {
  const { container, user } = useAuth();
  const confirm = useConfirm();
  const [rows, setRows] = useState<User[]>([]);
  const [pageError, setPageError] = useState('');
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState('');
  const [sortKey, setSortKey] = useState<SortKey>('fullName');
  const [sortAsc, setSortAsc] = useState(true);
  const [deletingId, setDeletingId] = useState('');

  async function load() {
    if (!user) {
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      setRows(await container.listUsers.execute(user));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load().catch((error) => {
      setLoading(false);
      setPageError(error instanceof DomainError ? error.message : 'No se pudo cargar el equipo.');
    });
  }, [container, user]);

  const filtered = useMemo(() => {
    const needle = query.trim().toLowerCase();
    if (!needle) {
      return rows;
    }
    return rows.filter((row) => {
      return User.displayName(row).toLowerCase().includes(needle) || row.username.toLowerCase().includes(needle);
    });
  }, [rows, query]);

  const sorted = useMemo(() => {
    return filtered.slice().sort((left, right) => {
      const direction = sortAsc ? 1 : -1;
      if (sortKey === 'role') {
        return User.roleLabel(left.role).localeCompare(User.roleLabel(right.role)) * direction;
      }
      const leftValue = sortKey === 'fullName' ? User.displayName(left) : left.username;
      const rightValue = sortKey === 'fullName' ? User.displayName(right) : right.username;
      return leftValue.localeCompare(rightValue) * direction;
    });
  }, [filtered, sortKey, sortAsc]);

  function toggleSort(key: SortKey) {
    if (sortKey === key) {
      setSortAsc((value) => !value);
      return;
    }
    setSortKey(key);
    setSortAsc(true);
  }

  async function handleDelete(row: User) {
    if (!user || !(await confirm({ message: `¿Borrar a ${User.displayName(row)}?` }))) {
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
          <p className="mt-1 text-sm text-muted">Invita al equipo con un usuario y contraseña. No hay registro público.</p>
        </div>
        <Link
          to="/equipo/usuarios/nuevo"
          className="page-cta btn-primary inline-flex h-12 items-center rounded-2xl px-5 text-sm font-semibold"
        >
          Invitar Usuario
        </Link>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
      <TextField
        id="user-search"
        label="Buscar"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
      />
      <p className="text-sm text-muted">
        {loading ? 'Cargando Usuarios...' : `${sorted.length} Usuario${sorted.length === 1 ? '' : 's'}`}
      </p>
      <ScrollTable>
        <table className="min-w-full text-sm">
          <thead className="sticky top-0 z-10 bg-surface">
            <tr className="border-b border-line text-left">
              <th>
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('fullName')}>
                  Nombre
                </button>
              </th>
              <th>
                <button type="button" className="px-4 py-3 font-semibold" onClick={() => toggleSort('username')}>
                  Usuario
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
            {loading ? (
              <TableSpinner colSpan={5} label="Cargando Usuarios..." />
            ) : sorted.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-muted">
                  {rows.length === 0 ? 'No hay usuarios para mostrar.' : 'No hay usuarios con esa búsqueda.'}
                </td>
              </tr>
            ) : (
              sorted.map((row) => (
                <tr key={row.id} className="border-t border-line">
                  <td className="px-4 py-3">{User.displayName(row)}</td>
                  <td className="px-4 py-3">{row.username}</td>
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
      </ScrollTable>
    </div>
  );
}
