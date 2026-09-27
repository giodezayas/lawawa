import { useState, type FormEvent } from 'react';
import { useAuth } from '../../../app/providers/auth_provider';
import { PrimaryButton } from '../../../shared/ui/primary_button';
import { TextField } from '../../../shared/ui/text_field';

export function LoginScreen() {
  const { signIn, errorMessage } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setLoading(true);
    try {
      await signIn(email, password);
    } catch {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-white">
      <div className="mx-auto grid min-h-screen max-w-6xl items-center gap-10 px-4 py-10 md:grid-cols-2 md:px-8">
        <section>
          <p className="text-xs font-semibold uppercase tracking-[0.35em] text-primary">Uso Interno</p>
          <h1 className="mt-4 max-w-md text-3xl font-extrabold leading-tight sm:text-4xl md:text-6xl">
            La Wawa
            <span className="block text-primary">Gestión</span>
          </h1>
          <p className="mt-5 max-w-md text-base text-muted">
            Una sola base de datos para web y móvil. Inventario, ventas, equipo y reportes
            nacerán aquí, módulo por módulo.
          </p>
        </section>
        <section className="rounded-3xl border border-line bg-white p-6 shadow-sm md:p-8">
          <h2 className="text-xl font-bold">Entrar Al Sistema</h2>
          <p className="mt-1 text-sm text-muted">Solo personal invitado. No hay registro público.</p>
          <form className="mt-6 space-y-4" onSubmit={(event) => void handleSubmit(event)}>
            <TextField
              id="email"
              label="Correo"
              type="email"
              autoComplete="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              required
            />
            <TextField
              id="password"
              label="Contraseña"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
            />
            {errorMessage ? <p className="text-sm text-danger">{errorMessage}</p> : null}
            <PrimaryButton type="submit" loading={loading} loadingLabel="Entrando..." className="w-full">
              Iniciar Sesión
            </PrimaryButton>
          </form>
        </section>
      </div>
    </div>
  );
}
