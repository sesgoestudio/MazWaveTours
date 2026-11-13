# Publicación automática desde MazWaveTours Admin

## Qué hace

El panel puede publicar los cambios del catálogo y ajustes directamente en `index.html` de la rama `main` usando la API de GitHub. GitHub Pages inicia el despliegue al recibir el commit.

- Los cambios de precio, nombre, capacidad, categoría, descripción, imagen, temporada, altas y bajas se publican automáticamente después de una pausa de 2 segundos.
- Los cambios de marca y WhatsApp también se publican automáticamente.
- El botón **Guardar y publicar** permite forzar el guardado inmediato.
- No se necesita Supabase ni un servidor externo.

## Conexión inicial requerida

GitHub no permite que una página pública escriba en un repositorio sin autorización. El administrador necesita un Fine-grained Personal Access Token creado por el propietario del repositorio.

1. En GitHub, abre Settings → Developer settings → Personal access tokens → Fine-grained tokens.
2. Genera un token con expiración corta razonable.
3. En **Repository access**, selecciona **Only select repositories** y elige `sesgoestudio/MazWaveTours`.
4. En **Repository permissions**, asigna únicamente **Contents: Read and write**. Metadata queda con lectura automática.
5. Copia el token y pégalo en el panel Admin, en **Publicación automática en GitHub**, y pulsa **Conectar GitHub**.

El token no se incluye en archivos ni commits del repositorio. El panel lo mantiene en `sessionStorage` de esa pestaña y ofrece un botón para desconectarlo. Al cerrar la sesión del navegador, normalmente se elimina.

## Consideraciones de seguridad

Este es un puente directo sin backend: el token está disponible para JavaScript de la página mientras la sesión está conectada. Por eso:
- Utiliza un token fine-grained limitado exclusivamente a este repositorio y con vencimiento.
- No conectes GitHub en dispositivos compartidos.
- Desconecta el panel al terminar y revoca el token desde GitHub si sospechas exposición.
- El login actual del panel sigue siendo una barrera visual del lado del cliente; no es autenticación real y no protege contra alguien que inspeccione el código.

Para una solución más robusta a largo plazo, se recomienda un backend pequeño o GitHub App con OAuth y almacenamiento de secretos del lado servidor. Eso requiere alojar un servicio y configurar sus secretos fuera del repositorio.

## Publicación y disponibilidad

El panel actualiza el archivo `index.html` de `main` mediante un commit. GitHub Pages publica después de completar su workflow. La confirmación de commit no significa que la página ya se haya actualizado; el despliegue puede tardar un poco.

El flujo solo sincroniza los datos del catálogo y ajustes que contiene `defaultData`. No cambia el diseño ni publica imágenes locales: las imágenes deben usar URLs públicas accesibles.
