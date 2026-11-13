# Flujo de solicitudes por WhatsApp

## Decisión de producto

MazWaveTours funcionará inicialmente sin base de datos, servicios externos ni cuentas adicionales. El sitio no confirmará reservas automáticamente: enviará una solicitud prellenada al WhatsApp comercial y el equipo confirmará disponibilidad, precio y condiciones directamente con el cliente.

## Experiencia del cliente

1. El cliente elige una embarcación o experiencia en el catálogo.
2. Completa nombre, fecha tentativa, número de personas y comentarios.
3. El sitio valida los datos básicos y abre WhatsApp con un mensaje preparado.
4. El cliente revisa y envía el mensaje desde su propia cuenta.
5. El equipo responde y confirma manualmente disponibilidad y condiciones.

## Cambios implementados

- Validación del nombre y número de personas.
- La fecha no puede seleccionarse en el pasado; puede dejarse pendiente.
- Número de WhatsApp validado antes de construir el enlace.
- Mensaje incluye experiencia, datos del cliente y aviso de que la disponibilidad debe confirmarse.
- La navegación usa el enlace oficial `https://wa.me/` para abrir WhatsApp o WhatsApp Web.
- No se guardan datos personales en una base de datos ni se simula una reserva confirmada.

## Configuración

El número de WhatsApp se toma de `db.phone` en `index.html` y del panel administrativo actual. Debe conservarse en formato internacional, solo dígitos y con código de país (México: 52). El valor existente es `526693285696`; verificar que siga siendo el número comercial correcto antes de publicar.

## Límites conocidos

- No existe calendario compartido ni bloqueo automático de horarios.
- Dos clientes podrían solicitar la misma fecha; el equipo debe revisar y confirmar manualmente.
- El mensaje no se envía solo: el cliente debe pulsar enviar en WhatsApp.
- El panel administrativo existente sigue siendo local al navegador y su contraseña del lado del cliente no es seguridad real. No usarlo para datos sensibles.
- No se requiere Supabase, servidor, claves API ni despliegue de infraestructura.
