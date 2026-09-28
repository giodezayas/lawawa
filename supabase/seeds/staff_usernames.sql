-- Cuatro accesos por nombre de usuario (sin correo). Contraseña inicial: Wawa2026
-- Ejecutar en el SQL Editor si el migration ya corrió y hay que recrear/resetear.

select public.ensure_staff_login('adrian', 'Wawa2026', 'Adrian Pelegrino', 'admin');
select public.ensure_staff_login('lorena', 'Wawa2026', 'Lorena Mondouy', 'manager');
select public.ensure_staff_login('mayren', 'Wawa2026', 'Mayren Angel', 'manager');
select public.ensure_staff_login('abraham', 'Wawa2026', 'Abraham De Zayas', 'trabajador');
