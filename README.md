# SIMSAT — Diario de aprendizaje y seguimiento

Bitácora del escalamiento SIMSAT-ANP: piloto Laguna de Términos → cobertura
de las 232 Áreas Naturales Protegidas. App estática (sin backend) que corre
en el navegador y guarda los datos en `localStorage`.

## Estructura

```
index.html          → la app (antes "Diario SIMSAT.dc.html")
support.js           → runtime que renderiza index.html (no editar a mano)
anp-catalog.js        → catálogo de las 232 ANP (generado desde el CSV)
scripts/
  ANP232.csv           → fuente de verdad del catálogo de ANP
  build_catalog.py     → regenera anp-catalog.js a partir del CSV
```

## Probarlo en tu máquina

`index.html` carga `anp-catalog.js` con `import()` dinámico, lo cual **no
funciona abriendo el archivo directamente con doble clic** (`file://`) por
restricciones de CORS del navegador en módulos ES. Necesitas un servidor
local muy simple:

```bash
cd simsat-diario
python3 -m http.server 8000
# abre http://localhost:8000 en tu navegador
```

(También sirve `npx serve` si tienes Node instalado.)

## Publicarlo en GitHub

1. **Crear el repositorio en GitHub** (desde github.com → "New repository").
   Nómbralo por ejemplo `simsat-diario`. No lo inicialices con README (ya
   tienes uno).

2. **Inicializar git localmente** (en la carpeta del proyecto):
   ```bash
   git init
   git add .
   git commit -m "Diario SIMSAT: primera versión"
   git branch -M main
   git remote add origin https://github.com/TU_USUARIO/simsat-diario.git
   git push -u origin main
   ```
   Si te pide login, lo más simple es generar un *Personal Access Token* en
   GitHub (Settings → Developer settings → Personal access tokens) y usarlo
   como contraseña, o configurar SSH.

3. **Activar GitHub Pages** para tener una URL pública:
   - En el repo → Settings → Pages
   - Source: "Deploy from a branch" → Branch: `main` / carpeta `/ (root)`
   - Guarda. En 1-2 minutos tendrás la app en
     `https://TU_USUARIO.github.io/simsat-diario/`

Como Pages sirve por `https://`, el `import()` dinámico funciona sin
problema ahí (a diferencia de abrir el archivo local sin servidor).

## Cómo seguir actualizando conforme agregas anotaciones

Importante: los datos que capturas en la app (fases, ANP registradas,
tareas, decisiones) se guardan en el `localStorage` **de tu navegador**, no
en el repositorio. Git no los versiona automáticamente. Flujo recomendado:

1. Trabaja normalmente en la app (local o en la URL de GitHub Pages).
2. De vez en cuando (por ejemplo cada semana, o después de una sesión de
   trabajo importante) da clic en **"Exportar respaldo"**. Descarga un
   `simsat-diario-respaldo-YYYY-MM-DD.json`.
3. Mueve ese archivo a una carpeta `respaldos/` del repo y haz commit:
   ```bash
   mkdir -p respaldos
   mv ~/Downloads/simsat-diario-respaldo-*.json respaldos/
   git add respaldos/
   git commit -m "Respaldo diario SIMSAT $(date +%Y-%m-%d)"
   git push
   ```
   Esto te da un historial versionado real de tu bitácora en git (puedes ver
   diffs entre respaldos, volver a una fecha anterior, etc.), y es también
   cómo llevas tus datos a otra computadora o navegador: abres la app ahí y
   usas **"Importar respaldo"** con el JSON más reciente.
4. Si cambia el código de la app (por ejemplo, otro ajuste como el que se
   hizo hoy al buscador de ANP), simplemente edita `index.html`, prueba
   localmente con el servidor de arriba, y:
   ```bash
   git add index.html
   git commit -m "Ajuste: dropdown de ANP con lista completa"
   git push
   ```
   GitHub Pages se actualiza solo un par de minutos después de cada push.

## Actualizar el catálogo de ANP

Si el CSV oficial de ANP cambia (nuevo decreto, recategorización, corrección
de nombre), no edites `anp-catalog.js` a mano:

```bash
cp NuevoANP232.csv scripts/ANP232.csv   # reemplaza el CSV
python3 scripts/build_catalog.py         # regenera anp-catalog.js
git add scripts/ANP232.csv anp-catalog.js
git commit -m "Actualiza catálogo de ANP"
git push
```

## Cambios de esta versión

- El buscador de "Registrar ANP" ahora funciona como una lista desplegable
  real: al dar clic en el campo (sin escribir nada) se despliegan las 232
  ANP; al escribir, filtra en tiempo real.
- La búsqueda ahora ignora acentos (p. ej. escribir "canon" encuentra
  "Cañón...").
- Tecla `Esc` cierra el desplegable.
- Se agregó `scripts/build_catalog.py` para regenerar el catálogo desde el
  CSV sin edición manual, evitando desincronización entre ambos archivos.

## Sincronización entre dispositivos (Supabase)

La app ahora puede sincronizar tu bitácora entre computadoras/navegadores
usando un PIN compartido, sin exportar/importar JSON a mano. Cómo se
protege sin usar el sistema de login real de Supabase:

- La tabla `diario_sync` tiene RLS activado **sin ninguna policy**, así que
  nadie puede leer/escribir la tabla directamente con la anon key (que de
  todas formas es pública, queda visible en el código del sitio — así
  funciona Supabase siempre).
- El único acceso es a través de dos funciones (`get_diario` / `save_diario`)
  que reciben tu PIN como parámetro, lo comparan contra un hash (bcrypt vía
  `pgcrypto`, nunca se guarda en texto plano) y solo entonces leen o
  actualizan la fila. Sin el PIN correcto, las funciones rechazan la
  llamada.
- Por eso importa que el PIN sea una frase razonablemente larga (10+
  caracteres), no un PIN de 4 dígitos: es la única barrera real.

### Paso a paso

1. **Crear el proyecto en Supabase** (dashboard → "New project"). Elige
   nombre, región y una contraseña de base de datos (esa contraseña es
   distinta de tu PIN de la app; solo la necesitarías para conectarte por
   `psql`, guárdala por si acaso pero no la vas a usar en el día a día).

2. **Ejecutar el SQL de configuración**: abre `scripts/supabase_setup.sql`
   de este repo, reemplaza `'CAMBIA_ESTE_PIN'` por tu PIN/passphrase real,
   y pega todo el contenido en Supabase → SQL Editor → Run.

3. **Copiar tus credenciales**: en Supabase → Project Settings → API,
   copia el **Project URL** y la key **anon public**.

4. **Pegarlas en el código**: en `index.html`, busca (cerca del inicio del
   `<script type="text/x-dc" data-dc-script>`):
   ```js
   const SUPABASE_URL = "https://TU-PROYECTO.supabase.co";
   const SUPABASE_ANON_KEY = "TU_ANON_PUBLIC_KEY_AQUI";
   ```
   y reemplaza ambos valores por los tuyos.

5. **Commit y push**:
   ```bash
   git add index.html
   git commit -m "Activa sincronización con Supabase"
   git push
   ```
   Espera 1-2 minutos a que GitHub Pages actualice.

6. **Conectar en cada dispositivo**: abre la app, en la barra
   "Sincronización" (arriba, debajo de las pestañas) escribe tu PIN y da
   clic en **Conectar**. El PIN se recuerda en ese navegador (via
   `localStorage`), así que solo lo tecleas una vez por dispositivo. Repite
   en tu otra computadora con el mismo PIN.

### Cómo funciona el sync

- Cada vez que agregas/editas algo, la app guarda local (como siempre) y
  además sube una copia a Supabase en segundo plano.
- Al conectar (o al abrir la app si ya estaba conectada), compara la fecha
  del último guardado local vs. la remota: si la remota es más nueva (la
  actualizaste desde otro dispositivo), adopta esa versión; si la local es
  más nueva o igual, sube la local. Es decir: siempre gana el más reciente.
- Si trabajas offline, tus cambios se quedan en local y se suben la próxima
  vez que haya conexión y des clic en "Sincronizar ahora" (o simplemente
  agregues algo nuevo).
- Si un día quieres cambiar el PIN, corre en el SQL Editor:
  ```sql
  update diario_sync set pin_hash = crypt('TU_PIN_NUEVO', gen_salt('bf')) where id = 'floi-simsat';
  ```
  y vuelve a conectar en cada dispositivo con el PIN nuevo.

**Nota:** esto sigue siendo un mecanismo simple pensado para un solo
usuario (tú). No reemplaza un sistema de autenticación real si algún día
esto se vuelve una herramienta multiusuario — para eso sí valdría la pena
migrar a Supabase Auth (email+contraseña o magic link) con RLS basada en
`auth.uid()`.

