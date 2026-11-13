# Reservaciones y backend: plan de implementación

## Diagnóstico confirmado en el código actual

- El sitio es una aplicación estática: `index.html` y `admin.html`, con Tailwind por CDN y JavaScript en el navegador.
- El catálogo y el teléfono se inicializan desde datos incrustados en JavaScript.
- El formulario de reserva abre WhatsApp; no crea una reserva persistente ni consulta horarios.
- El panel administrativo compara una contraseña definida en el cliente y guarda cambios en `localStorage`. Esto no autentica usuarios ni sincroniza dispositivos.
- No se encontró `package.json`, framework de servidor ni backend existente en la raíz inspeccionada.

## Base preparada

La migración `supabase/migrations/202611140001_booking_foundation.sql` prepara:
- Perfiles vinculados a Supabase Auth y roles customer/staff/admin.
- Catálogo de embarcaciones centralizado.
- Solicitudes públicas de reserva con validación básica.
- Bloqueos de disponibilidad y reservas confirmadas.
- Restricción de base de datos que impide reservas confirmadas con periodos solapados para la misma embarcación.
- Row Level Security (RLS): el público solo puede consultar embarcaciones activas y enviar solicitudes; el personal autenticado administra datos operativos.

Las solicitudes públicas son solicitudes pendientes, no confirmaciones. La disponibilidad definitiva debe comprobarse en el servidor al convertir una solicitud en reserva. El esquema es una base inicial y requiere pruebas en un proyecto Supabase antes de producción.

## Pasos de integración pendientes

1. Crear/confirmar el proyecto Supabase y aplicar la migración.
2. Crear usuarios del equipo con Supabase Auth y asignar el primer rol admin desde una sesión SQL confiable, después de verificar el UUID.
3. Definir variables de entorno en el servicio de despliegue: URL del proyecto y clave publicable/anon. La clave `service_role` solo puede existir en servidor y nunca en HTML, JavaScript público ni Git.
4. Implementar endpoints/funciones de servidor para consultar disponibilidad y confirmar reservas dentro de una transacción; validar capacidad, horarios, duración, bloqueos y solapamientos.
5. Conectar el panel a Auth (sesión, cierre de sesión y recuperación), eliminar la contraseña fija y reemplazar localStorage como fuente de verdad.
6. Migrar el catálogo actual a la tabla `vessels` después de validar nombres, precios, capacidades, fotos y reglas comerciales.
7. Probar RLS con usuarios anónimos, clientes, staff y admin antes de habilitar reservas reales.

## Decisiones/datos que faltan

- Confirmación de Supabase como proveedor (propuesto por su Auth + Postgres + RLS).
- Proyecto/entorno de Supabase y URL pública; no compartir claves secretas en el repositorio o chat.
- Horarios de operación, duración de cada salida, margen entre salidas, días no laborables y política de anticipación.
- Reglas de depósitos, cancelaciones, reembolsos, impuestos y cuándo una solicitud se considera confirmada.
- Validación de la flota real: precios vigentes, capacidad autorizada, embarcaciones activas e imágenes con derechos.
- Quiénes serán administradores y personal autorizado.

## Límites de este cambio

No se desplegó nada, no se creó infraestructura externa, no se modificó `main` y no se añadió ninguna credencial. Esta entrega es el esquema inicial y el plan verificable; todavía no habilita reservas reales en el sitio.
