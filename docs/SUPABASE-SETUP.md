# Configuración de Supabase para MazWaveTours

## 1. Crear tabla y políticas
En Supabase → SQL Editor → New query, pega y ejecuta el contenido de `supabase/schema.sql`.

## 2. Crear usuario administrador
En Supabase → Authentication → Users → Add user, crea el usuario con el correo y contraseña que usarás en `/admin/`. No habilites registro público.

## 3. Primer inicio
Abre `https://sesgoestudio.github.io/MazWaveTours/admin/`, inicia sesión con ese usuario y pulsa Guardar y publicar para guardar el catálogo inicial.

## Funcionamiento
- El sitio público consulta `site_config` y muestra el catálogo central.
- El admin inicia sesión con Supabase Auth y guarda cambios en esa misma fila.
- Los cambios se guardan automáticamente después de editar, además del botón manual.
- La publishable key es pública por diseño; nunca uses una secret/service_role key en el navegador.

## Seguridad
RLS permite lectura pública del catálogo y escritura solo a usuarios autenticados. Como medida adicional recomendada, limita quién puede crear usuarios desde Supabase Dashboard y no habilites signups públicos.
