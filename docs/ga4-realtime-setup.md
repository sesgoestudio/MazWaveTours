# Conectar Google Analytics 4 al administrador

El panel usa la propiedad GA4 **565034925** y consulta la API de tiempo real. La credencial privada se guarda únicamente como secreto de Supabase; nunca se publica en GitHub ni en el navegador.

## 1. Google Cloud

1. Abre https://console.cloud.google.com/ y selecciona o crea un proyecto.
2. En **APIs y servicios → Biblioteca**, habilita **Google Analytics Data API**.
3. En **IAM y administración → Cuentas de servicio**, crea una cuenta de servicio.
4. Genera una clave JSON y descárgala. No subas ese archivo al repositorio ni lo compartas en el chat.
5. Copia el correo de la cuenta de servicio (termina en `.iam.gserviceaccount.com`).

## 2. Dar acceso de lectura en GA4

1. Abre https://analytics.google.com/ y selecciona la propiedad **565034925**.
2. En **Administrador → Gestión de accesos a la propiedad**, agrega el correo de la cuenta de servicio.
3. Asígnale el rol **Lector**.

## 3. Guardar secretos en Supabase

En el proyecto https://supabase.com/dashboard/project/vwtthqywcuzjvzzbzzps/settings/functions agrega estos secretos en **Edge Functions → Secrets**:

- `GA4_PROPERTY_ID` = `565034925`
- `GA4_SERVICE_ACCOUNT_JSON` = el contenido completo del archivo JSON descargado (como valor secreto de una sola línea).

No agregues `private_key` al HTML, JavaScript público, SQL o GitHub.

## 4. Desplegar la función

Desde la raíz del repositorio, con Supabase CLI instalado y vinculado al proyecto:

```bash
supabase link --project-ref vwtthqywcuzjvzzbzzps
supabase functions deploy ga4-realtime
```

La función queda protegida por sesión y además comprueba `is_mazwave_admin()` antes de consultar Google. No requiere cambios SQL si el esquema actual conserva esa función y el usuario administrador ya está registrado en `app_admins`.

## 5. Comprobación

Inicia sesión en https://mazwavetours.com/admin.html. La tarjeta **Visitantes en tiempo real** debe mostrar usuarios activos y páginas consultadas; actualiza cada 30 segundos.

Si aparece “Pendiente de configuración”, revisa que la función esté desplegada, que los dos secretos estén guardados y que la cuenta de servicio tenga rol Lector en la propiedad GA4.

**Nota:** GA4 reporta usuarios activos dentro de su ventana de tiempo real de aproximadamente 30 minutos. El listado muestra páginas con actividad dentro de esa ventana, no una identificación individual de visitantes ni un conteo exacto de personas en cada segundo.
