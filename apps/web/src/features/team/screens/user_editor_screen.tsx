import { DomainError, User, userRoles, type UserRole } from '@wawa/domain';
import { useEffect, useState, type FormEvent } from 'react';
import { Link, Navigate, useNavigate, useParams } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { useConfirm } from '../../../shared/ui/confirm_dialog';
import { PrimaryButton } from '../../../shared/ui/primary_button';
import { TextField } from '../../../shared/ui/text_field';

export function UserEditorScreen() {
  const { userId } = useParams();
  const isCreate = userId === undefined;
  const navigate = useNavigate();
  const { container, user } = useAuth();
  const confirm = useConfirm();
  const [email, setEmail] = useState('');
  const [fullName, setFullName] = useState('');
  const [role, setRole] = useState<UserRole>('trabajador');
  const [isActive, setIsActive] = useState(true);
  const [password, setPassword] = useState('');
  const [pageError, setPageError] = useState('');
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [ready, setReady] = useState(isCreate);

  useEffect(() => {
    if (!userId) {
      return;
    }
    void container.getUser
      .execute(userId)
      .then((row) => {
        setEmail(row.email);
        setFullName(row.fullName);
        setRole(row.role);
        setIsActive(row.isActive);
        setReady(true);
      })
      .catch((error) => {
        setPageError(error instanceof DomainError ? error.message : 'No se pudo abrir el usuario.');
      });
  }, [container, userId]);

  if (user && !User.canManageStaff(user)) {
    return <Navigate to="/" replace />;
  }

  const roleOptions = userRoles.filter((item) => item !== 'admin' || user?.role === 'admin');

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!user) {
      return;
    }
    setPageError('');
    setSaving(true);
    try {
      if (isCreate) {
        await container.createUser.execute(user, { email, password, fullName, role });
      } else if (userId) {
        await container.updateUser.execute(user, {
          id: userId,
          fullName,
          role,
          isActive,
          password: password.length > 0 ? password : undefined,
        });
      }
      navigate('/equipo/usuarios');
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo guardar el usuario.');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!user || !userId || user.id === userId || !(await confirm({ message: '¿Borrar este usuario?' }))) {
      return;
    }
    setDeleting(true);
    setPageError('');
    try {
      await container.deleteUser.execute(user, userId);
      navigate('/equipo/usuarios');
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo borrar el usuario.');
    } finally {
      setDeleting(false);
    }
  }

  if (!ready) {
    return pageError ? <p className="text-sm text-danger">{pageError}</p> : <p className="text-sm text-muted">Cargando Usuario...</p>;
  }

  return (
    <div className="mx-auto max-w-xl space-y-6">
      <div className="flex items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold">{isCreate ? 'Invitar Usuario' : 'Editar Usuario'}</h1>
          <p className="mt-1 text-sm text-muted">
            {isCreate ? 'Va a poder entrar con este correo y contraseña.' : 'Deja la contraseña vacía si no la cambias.'}
          </p>
        </div>
        <Link to="/equipo/usuarios" className="text-sm font-semibold text-primary">
          Volver A Usuarios
        </Link>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
      <form onSubmit={(event) => void handleSubmit(event)} className="space-y-4 rounded-3xl border border-line bg-surface p-5">
        {isCreate ? (
          <TextField
            id="email"
            label="Correo"
            type="email"
            required
            value={email}
            onChange={(event) => setEmail(event.target.value)}
          />
        ) : (
          <TextField id="email" label="Correo" value={email} readOnly />
        )}
        <TextField
          id="full-name"
          label="Nombre Completo"
          value={fullName}
          onChange={(event) => setFullName(event.target.value)}
        />
        <label className="block" htmlFor="role">
          <span className="mb-2 block text-sm font-medium text-ink">Rol *</span>
          <select
            id="role"
            required
            value={role}
            onChange={(event) => setRole(event.target.value as UserRole)}
            className="h-12 w-full rounded-2xl border border-line bg-white/80 px-4 text-sm outline-none ring-primary/20 transition focus:border-primary focus:ring-4"
          >
            {roleOptions.map((item) => (
              <option key={item} value={item}>
                {User.roleLabel(item)}
              </option>
            ))}
          </select>
        </label>
        {isCreate ? null : (
          <label className="flex items-center gap-3 text-sm">
            <input type="checkbox" checked={isActive} onChange={(event) => setIsActive(event.target.checked)} />
            Activo
          </label>
        )}
        <TextField
          id="password"
          label={isCreate ? 'Contraseña' : 'Nueva Contraseña'}
          type="password"
          required={isCreate}
          value={password}
          onChange={(event) => setPassword(event.target.value)}
        />
        <PrimaryButton type="submit" loading={saving} className="w-full">
          {isCreate ? 'Crear Usuario' : 'Guardar Cambios'}
        </PrimaryButton>
      </form>
      {isCreate || user?.id === userId ? null : (
        <button type="button" className="text-sm text-danger" disabled={deleting} onClick={() => void handleDelete()}>
          {deleting ? 'Borrando...' : 'Borrar Usuario'}
        </button>
      )}
    </div>
  );
}
