import { Database } from 'lucide-react';

export function SetupScreen() {
  return (
    <div className="grid min-h-screen place-items-center bg-white px-4">
      <div className="max-w-xl rounded-3xl border border-line bg-surface p-8 shadow-sm">
        <Database className="text-primary" size={28} />
        <h1 className="mt-4 text-2xl font-extrabold">Conecta Supabase para continuar</h1>
        <ol className="mt-4 list-decimal space-y-2 pl-5 text-sm text-muted">
          <li>Crea un proyecto gratis en supabase.com</li>
          <li>Copia la URL y la anon key</li>
          <li>
            Crea <code className="rounded bg-primary/5 px-1 text-primary">apps/web/.env</code> (Vite) y{' '}
            <code className="rounded bg-primary/5 px-1 text-primary">apps/mobile/.env</code> (Flutter)
          </li>
          <li>Ejecuta el SQL de <code className="rounded bg-primary/5 px-1 text-primary">supabase/migrations</code></li>
          <li>Invita al primer usuario desde Authentication → Users</li>
        </ol>
      </div>
    </div>
  );
}
