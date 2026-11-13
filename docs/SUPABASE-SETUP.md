# Configuración de Supabase para MazWaveTours

## Base de datos y permisos
En Supabase → SQL Editor, ejecuta el contenido completo de `supabase/schema.sql`. El script crea la tabla del catálogo, limita las escrituras al UUID administrador autorizado y configura el bucket público de imágenes con permisos de carga exclusivos del administrador.

## Catálogo
El catálogo completo incluye 24 experiencias con nombre, categoría, precio, capacidad, descripción, indicador de temporada e imagen. Si la tabla todavía no tiene datos, el primer inicio de sesión del administrador importa automáticamente el catálogo inicial. Los ajustes de marca, WhatsApp, eslogan y textos del hero también se guardan en la misma fila JSONB.

## Fotografías
En `/admin/`, cada experiencia incluye un control **Subir foto**. Acepta imágenes JPG, PNG, WebP, GIF o AVIF de hasta 8 MB. Las imágenes se almacenan en Supabase Storage, y su URL se guarda en el catálogo compartido para que aparezcan en el sitio público.

## Administrador
Crear el usuario desde Supabase → Authentication → Users. No habilitar registros públicos. El UUID autorizado está registrado en `public.app_admins` por el SQL.

## Publicación
Los cambios de texto y catálogo se guardan automáticamente en Supabase. El sitio público lee la misma fila al cargar; no se necesita un nuevo despliegue de GitHub Pages para modificar el contenido. Los cambios de código sí requieren el despliegue habitual.

Nunca colocar una secret/service_role key en el navegador. La publishable key se utiliza en el cliente.
