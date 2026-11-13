# Publicación segura de MazWaveTours

El administrador publica mediante un Cloudflare Worker. El token de GitHub y la contraseña administrativa viven únicamente como secretos del Worker; nunca se incluyen en JavaScript público.

## Configuración necesaria (una sola vez)

1. En Cloudflare, abre **Workers & Pages** y crea un Worker llamado `mazwave-publisher`.
2. Copia el contenido de `worker/mazwave-publisher.js` en el editor del Worker y pulsa **Deploy**.
3. En **Settings → Variables and Secrets**, agrega estos secretos (tipo Secret):
   - `GITHUB_TOKEN`: un fine-grained GitHub token con acceso únicamente al repositorio `sesgoestudio/MazWaveTours` y permiso **Contents: Read and write**. Usa un token nuevo; no reutilices el que se compartió anteriormente.
   - `ADMIN_PASSWORD`: crea una contraseña nueva, larga y exclusiva para el panel.
4. Copia la URL que Cloudflare asignó al Worker.
5. En `admin.html`, cambia `PUBLISHER_URL` por esa URL (sin barra final) y guarda el archivo en GitHub.
6. Abre `https://sesgoestudio.github.io/MazWaveTours/admin/`, inicia sesión con la contraseña que guardaste como `ADMIN_PASSWORD` y pulsa **Guardar y publicar**.

El Worker solo acepta peticiones desde el dominio oficial de GitHub Pages y escribe el catálogo en `index.html` de la rama `main`. GitHub Pages publica el commit automáticamente.

**Importante:** revoca cualquier token que se haya pegado en conversaciones o chats y crea uno nuevo. No lo pegues en el administrador ni en el chat.
