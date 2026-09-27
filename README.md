# La Wawa · Gestión

Sistema interno (no público) con **una sola base de datos en Supabase**.

| Cliente | Stack | Carpeta |
| --- | --- | --- |
| Web | React + Vite + Clean Architecture | `apps/web` |
| App | Flutter + Riverpod + feature-first | `apps/mobile` |
| Dominio/datos web | TypeScript compartido | `packages/domain`, `packages/data` |
| Base de datos | Supabase (Postgres + Auth + RLS) | `supabase` |

## ¿Se puede hacer gratis con Supabase?

Sí, para uso interno al arrancar. El plan gratuito cubre Auth, Postgres y Row Level Security. Límites a vigilar más adelante: filas, storage y ancho de banda. No hace falta un servidor propio al inicio: web y Flutter hablan con el mismo proyecto.

El registro público está desactivado (`enable_signup = false`). El personal se invita desde el dashboard de Authentication.

## Arranque

1. Crea un proyecto en [supabase.com](https://supabase.com).
2. Copia URL y `anon key`.
3. Copia `.env.example` a `apps/web/.env` y `apps/mobile/.env`.
4. En el SQL Editor de Supabase ejecuta `supabase/migrations/20260911190000_init.sql`.
5. Authentication → Users → invita el primer usuario.
6. En SQL, marca al dueño:

```sql
update public.profiles
set role = 'owner', full_name = 'Tu nombre'
where email = 'tu-correo@negocio.com';
```

### Web

```bash
npm install
npm run dev:web
```

### Flutter

```bash
cd apps/mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define-from-file=.env
```

## Cómo se organiza el código

- Entidades inmutables (`freezed` en Flutter, objetos congelados en TypeScript).
- Casos de uso con una sola responsabilidad.
- Repositorios en dominio; implementaciones en data contra Supabase.
- UI en `presentation` / `features`.

Cuando indiques el primer módulo (inventario, caja, proveedores, etc.), se suma en las tres capas y en la misma base.
