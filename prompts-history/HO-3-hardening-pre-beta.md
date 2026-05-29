# FlowWeaver — Fase 3 hardening pre-beta

## Contexto operativo

Eres Claude Code trabajando en `C:\Users\pinnovacion\Desktop\FlowWeaver`. El
orquestador (`EquipoEnjambre`) está en `C:\Users\pinnovacion\Desktop\EquipoEnjambre`.
El proxy (`flowweaver-proxy`) es un repo separado.

Estado: Fase 3 implementada (T-3-008 a T-3-012). El producto funciona end-to-end.
Esta tarea cierra una pasada de hardening sobre la implementación existente
**sin reescribir la arquitectura**. Respeta la lógica actual: solo hay que tapar
agujeros y alinear cosas que se han desincronizado durante el desarrollo.

## Decisiones que NO se tocan

- **D1**: `url` y `title` cifrados, nunca al frontend. Ningún cambio aquí amplía la superficie.
- **D4**: State Machine es la única autoridad de transición. No moverla.
- **D8**: Baseline determinístico sin LLM. La síntesis es opcional.
- **D9**: FS Watcher en modo **background-persistent** (revisada 2026-04-28).
  Cualquier comentario que aún diga "foreground-only" se actualiza al pasar.
- **D14**: Privacy Dashboard completo antes de beta. Estos cambios refuerzan
  el dashboard, no lo expanden.
- **D25**: `synthesis_engine` verifica `has_consent` antes del proxy. Innegociable.
- **R12**: `pattern_detector` ≠ `episode_detector` ≠ `fs_watcher` ≠ `state_machine`
  ≠ `trust_scorer`. No fusiones módulos.
- **Sin StrictMode**: incompatible con `listen()` async de Tauri. Descubierto durante
  Fase 3. **Documenta esto como decisión arquitectónica nueva** — ver tarea 9.
- **Sin `react-markdown`**: el renderer inline propio se queda. Lo que cambia es
  cómo se sanitiza la salida (tarea 1).

## Tareas

### 1. [CRÍTICO — seguridad] XSS en `renderMarkdown`

**Archivo**: `src/utils/renderMarkdown.ts`

**Problema**: la función aplica regex de Markdown sobre el texto del LLM y el
resultado va directo a `dangerouslySetInnerHTML`. No escapa entidades HTML. El
LLM puede emitir `<script>` o `<img onerror>`, sea por accidente, sea porque un
título malicioso (los títulos son input de usuario sin saneamiento) llega al
prompt y el modelo lo refleja en la respuesta. La consecuencia es ejecución de
JS en una WebView con acceso a la BD descifrada — rompe D1 de facto.

**Fix**: escapar entidades HTML del texto de entrada **antes** de aplicar los
reemplazos Markdown. No introduzcas `dompurify` ni `marked` ni `react-markdown`
(decisión existente). Implementa un escape mínimo:

```ts
function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function renderMarkdown(text: string): string {
  const escaped = escapeHtml(text);
  return escaped
    .replace(/^#### (.+)$/gm, '<h4>$1</h4>')
    .replace(/^### (.+)$/gm, '<h3>$1</h3>')
    .replace(/^## (.+)$/gm, '<h2>$1</h2>')
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\n/g, '<br/>');
}
```

**Test**: añade `src/utils/renderMarkdown.test.ts` con vitest. Casos:
- input `<script>alert(1)</script>` → no aparece `<script>` literal en el output.
- input `## Título <img onerror=x>` → renderiza `<h2>` pero el `<img>` queda escapado.
- input `**negrita**` → sigue funcionando.
- input `## Heading\n\nbody` → renderiza heading y body con `<br/>`.

Asegura que `npm run test` pasa.

### 2. [CRÍTICO — datos] Cómputo de mes incoherente con el proxy

**Archivos**:
- `src-tauri/src/commands.rs` (función `get_synthesis_usage`)
- `src/components/SynthesisSection.tsx`

**Problema**: el desktop calcula `month_start = now - (now % (30 * 24 * 3600))`,
que es una ventana rolling de 30 días alineada al epoch (jueves 1970-01-01) sin
relación con mes calendario. El proxy usa **mes calendario UTC** (`yyyymm`).
Los contadores nunca coinciden.

**Decisión**: la fuente de verdad del consumo es **el proxy**, porque es quien
aplica el rate limit. El desktop solo refleja.

**Fix dividido en dos partes**:

**a) Backend — recalcular sobre mes calendario UTC** (provisional para que el
contador local sea coherente cuando no hay header todavía). Añade dependencia
directa `chrono = "0.4"` (ya está como transitiva en `Cargo.lock`). Sustituye:

```rust
// src-tauri/src/commands.rs en get_synthesis_usage
use chrono::{Datelike, TimeZone, Utc};

let now_dt = Utc::now();
let month_start_dt = Utc.with_ymd_and_hms(now_dt.year(), now_dt.month(), 1, 0, 0, 0)
    .single()
    .ok_or("invalid month start")?;
let month_start = month_start_dt.timestamp();
```

Mantén el resto de la query igual.

**b) Backend — exponer el contador del proxy** (cuando llega).
- En `synthesis_engine::fetch_from_proxy`, lee la response header
  `x-synthesis-remaining` antes de empezar a leer el stream y guárdalo en una
  variable accesible.
- Tras un `generate_synthesis` exitoso, persiste el último valor visto en
  `user_prefs` con clave `synthesis_remaining_last` y otra clave
  `synthesis_remaining_seen_at` (timestamp Unix).
- En `get_synthesis_usage`, si hay un valor reciente (<24h) en `user_prefs`,
  prefiérelo sobre el conteo local. Si no, devuelve el conteo local.

**Test**: añade `test_get_synthesis_usage_uses_calendar_month` que insertae
síntesis con timestamps en distintos puntos del mes y verifica que el contador
empieza en el día 1 a las 00:00 UTC.

### 3. [CRÍTICO — seguridad] PRAGMA key por interpolación

**Archivo**: `src-tauri/src/storage.rs`, función `Db::open` línea ~62-68.

**Problema**: `conn.execute_batch(&format!("PRAGMA key = '{key}';"))` interpola
la passphrase directamente en SQL. Hoy no es explotable porque la key viene de
`app_data_dir`, pero es la clase de defensa por casualidad que un auditor o
QA externo va a marcar.

**Fix**: usar `pragma_update` con binding correcto:

```rust
#[cfg(not(target_os = "android"))]
conn.pragma_update(None, "key", &key)?;
```

Verifica que `cargo test --lib` sigue pasando — el path bundled-sqlcipher
debe aceptar `pragma_update` sobre PRAGMA key sin issue.

### 4. [CRÍTICO — UX] Bug de regenerar síntesis (acumula contenido viejo)

**Archivo**: `src/components/SynthesisView.tsx`

**Problema**: `contentAccum` vive en el closure del `useEffect` de listeners.
Al pulsar "Regenerar", `handleGenerate()` resetea el state pero los listeners
y su `contentAccum` siguen activos. Llegan nuevos chunks y se concatenan al
contenido anterior. El usuario ve resumen 1 + resumen 2 pegados.

**Fix**: introducir un `generationId` que se incrementa en cada `handleGenerate`,
y mover `contentAccum` a un `useRef` que se reinicia en cada generación.
Patrón:

```tsx
const generationIdRef = useRef(0);
const contentAccumRef = useRef('');

const handleGenerate = useCallback(async () => {
  generationIdRef.current += 1;
  contentAccumRef.current = '';
  setState({ status: 'loading' });
  try {
    await invoke('generate_synthesis', { /* ... */ });
  } catch (e) {
    setState({ status: 'error', message: mapError(String(e)) });
  }
}, [/* ... */]);
```

Los listeners siguen como están pero usan `contentAccumRef.current` en lugar
de la variable de closure. **Mantén** la lógica de filtrar por `anchorKey`.

### 5. [CRÍTICO — UX/coherencia] Listeners duplicados en `EpisodePanel.tsx`

**Archivo**: `src/components/EpisodePanel.tsx`

**Problema**: `EpisodeSynthesisButton.generate()` registra `listen()` dentro
del handler, sin `useEffect` ni cleanup atado al ciclo de vida del componente.
Si el usuario cancela, cambia de pestaña o reintenta, los listeners quedan
colgados. Y la lógica está duplicada respecto a `SynthesisView.tsx`.

**Fix**: extraer un hook compartido `useSynthesis(anchorKey)` que centraliza:
- Listeners `synthesis_chunk` / `synthesis_complete` / `synthesis_error` con
  cleanup en useEffect.
- `generationId` y `contentAccumRef` (mismo patrón que tarea 4).
- Estado `status` y `content`.
- Función `generate(payload)` que invoca `generate_synthesis` y resetea.

Estructura propuesta:

```
src/hooks/useSynthesis.ts   ← nuevo
```

```ts
export type SynthesisStatus =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'streaming'; content: string }
  | { status: 'complete'; content: string }
  | { status: 'error'; message: string };

export function useSynthesis(anchorKey: string) {
  // ...
  return { state, generate, reset };
}
```

Refactoriza **`SynthesisView.tsx` y `EpisodeSynthesisButton`** (en
`EpisodePanel.tsx`) para consumir este hook. La UI no cambia. Solo cambia
de dónde sale el estado.

**Importante**: el hook debe coexistir limpiamente con dos instancias en
pantalla (AnticipatedWorkspace usa una, EpisodePanel puede tener varias).
Por eso los listeners filtran por `event.payload.anchor_key === anchorKey`.

**Test**: si tienes setup de vitest + react-testing-library, añade un test
mínimo que monta y desmonta el hook y verifica que los listeners se limpian.
Si no hay setup, deja una nota TODO en el archivo y abre issue en backlog.

### 6. [SERIO — auditoría] `consent_log_store` con audit trail completo

**Archivo**: `src-tauri/src/consent_log_store.rs` y `commands.rs`.

**Problema**: el header del archivo dice "stub mínimo, completo en T-3-012".
Tú dices que T-3-012 está cerrada. La realidad es que falta:
- Columna `revoked_at` (NULL = activo, timestamp = revocado).
- `revoke_consent` borra la fila → se pierde quién consintió y cuándo.
- `has_consent` devuelve true por la mera existencia de fila.

**Fix**:

a) Migración de schema (idempotente):

```rust
pub(crate) fn ensure_schema(conn: &Connection) -> Result<(), rusqlite::Error> {
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS consent_log (
            id               INTEGER PRIMARY KEY,
            consent_type     TEXT NOT NULL,
            consent_version  TEXT NOT NULL,
            accepted_at      INTEGER NOT NULL,
            revoked_at       INTEGER
        );
        CREATE INDEX IF NOT EXISTS idx_consent_type
            ON consent_log(consent_type, consent_version);",
    )?;
    // Migración para BDs Fase 3 anteriores: añadir revoked_at si no existe.
    let _ = conn.execute_batch(
        "ALTER TABLE consent_log ADD COLUMN revoked_at INTEGER;"
    );
    Ok(())
}
```

b) `has_consent` exige `revoked_at IS NULL`:

```rust
let count: i64 = conn
    .query_row(
        "SELECT COUNT(*) FROM consent_log
         WHERE consent_type = ?1 AND consent_version = ?2 AND revoked_at IS NULL",
        rusqlite::params![consent_type, consent_version],
        |row| row.get(0),
    )
    .unwrap_or(0);
Ok(count > 0)
```

c) `revoke_consent` marca, no borra:

```rust
pub(crate) fn revoke_consent(
    conn: &Connection,
    consent_type: &str,
    now_unix: i64,
) -> Result<(), rusqlite::Error> {
    conn.execute(
        "UPDATE consent_log SET revoked_at = ?1
         WHERE consent_type = ?2 AND revoked_at IS NULL",
        rusqlite::params![now_unix, consent_type],
    )?;
    Ok(())
}
```

d) Quita el header obsoleto del archivo. Sustitúyelo por:

```
// consent_log_store.rs — Fase 3 (T-3-012)
// Audit trail de consentimientos. revoked_at preserva quién consintió y cuándo,
// incluso tras revocación. has_consent solo cuenta filas activas.
```

e) Expone command `revoke_synthesis_consent` en `commands.rs`:

```rust
#[tauri::command]
pub fn revoke_synthesis_consent(state: State<'_, DbState>) -> Result<(), String> {
    let now_unix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .map_err(|e| e.to_string())?;
    let db = state.0.lock().map_err(|e| e.to_string())?;
    let conn = db.conn();
    consent_log_store::ensure_schema(conn).map_err(|e| e.to_string())?;
    consent_log_store::revoke_consent(conn, "synthesis", now_unix)
        .map_err(|e| e.to_string())?;
    Ok(())
}
```

Regístralo en `lib.rs` `invoke_handler`.

**Test**: añade `test_revoke_keeps_audit_trail` que graba consent, revoca, y
verifica:
- `has_consent` devuelve `false`.
- `SELECT COUNT(*) FROM consent_log` devuelve 1 (no se borró).
- La fila tiene `revoked_at IS NOT NULL`.

### 7. [SERIO — UX] Flujo consent + token unificado

**Archivos**:
- `src/components/SynthesisSection.tsx`
- `src/components/SynthesisOnboarding.tsx`

**Problema**: hoy el usuario puede acabar en estados híbridos:
- Token grabado, consent ausente → al primer "Generar" aparece consent modal.
- Consent grabado (vía modal en episodio), sin token → "Generar" falla con `NoToken`.
- Al desactivar (`clear_synthesis_token`), el consent **no se revoca** → audit
  trail dice "sigue consintiendo" aunque ya no haya token.

**Fix**: un único toggle "Síntesis activa" en `SynthesisSection` con flujo serial:

a) **Activar**:
1. Mostrar consent modal (`SynthesisConsentModal`) — texto exacto PG-003.
2. Si el usuario acepta → invocar `record_synthesis_consent`.
3. Mostrar `SynthesisOnboarding` para el token.
4. Si el usuario introduce token → invocar `set_synthesis_token`.
5. Refresh.

Si el usuario cancela en el paso 1 o 3, no se persiste nada del paso anterior
(o se revoca lo recién grabado para no dejar estados a medio camino). Lo más
sencillo: encadenar las dos modales y solo grabar consent **al pulsar "Activar"
en el onboarding del token**, no al cerrar el primer modal. Es decir,
`SynthesisConsentModal.onAccept` simplemente abre el onboarding; el
`record_synthesis_consent` se ejecuta dentro de `SynthesisOnboarding.handleActivate`
**antes** de `set_synthesis_token`. Si falla cualquiera de los dos, nada se
persiste — usa una transacción mental, no rollback real.

b) **Desactivar**:
1. Confirm dialog (mantén el actual).
2. Si confirmado → invocar `clear_synthesis_token` **y** `revoke_synthesis_consent`
   en orden. Ambos son idempotentes.
3. Refresh.

c) **Estados que sigue mostrando `SynthesisSection`** (siguen siendo los que
ya hay):
- "Síntesis activa" toggle.
- Contador "X de 5 síntesis usadas este mes" (con el fix de tarea 2).
- Texto explicativo (PG-002 / PG-005).

d) Mantener `check_synthesis_consent` y los modales activos en
`AnticipatedWorkspace.tsx` y `EpisodePanel.tsx` como **defensa en profundidad**.
Si por algún motivo el toggle del Privacy Dashboard fue saltado (ej. consent
revocado mientras hay token), el modal sigue apareciendo al pulsar "Generar".

**Importante**: cuando la activación se hace ahora desde `SynthesisOnboarding`,
**borra** el flujo paralelo donde el modal de consent en
`AnticipatedWorkspace.tsx` graba consent sin token. El modal de
`AnticipatedWorkspace` y `EpisodePanel` debe **redirigir al usuario al
Privacy Dashboard** si no hay token (porque ahora la activación canónica
está allí). Texto: "Para activar la síntesis, ve al Panel de Privacidad
(🔒) y activa el toggle."

### 8. [SERIO — UX] Síntesis pasadas no son visibles

**Archivos**:
- `src-tauri/src/commands.rs` (nuevo command).
- `src-tauri/src/lib.rs` (registro).
- `src/hooks/useSynthesis.ts` (consumir al montar).

**Problema**: `syntheses_store::get_by_anchor` y `list_recent` existen y están
testeados, pero ningún command los expone. El usuario genera síntesis, la BD
las guarda cifradas, y nunca más se ven. Inconsistente con D27 (sync entre
dispositivos) y con el principio "cifras lo que vas a usar".

**Fix**:

a) Nuevo command `get_synthesis_for_anchor`:

```rust
#[derive(Debug, Serialize)]
pub struct StoredSynthesisView {
    pub anchor_key:    String,
    pub category:      String,
    pub synthesis_type: String,
    pub content:       String,  // descifrado en backend, igual que titles
    pub generated_at:  i64,
}

#[tauri::command]
pub fn get_synthesis_for_anchor(
    anchor_key: String,
    state: State<'_, DbState>,
    app: tauri::AppHandle,
) -> Result<Option<StoredSynthesisView>, String> {
    let db = state.0.lock().map_err(|e| e.to_string())?;
    let conn = db.conn();
    syntheses_store::ensure_schema(conn).map_err(|e| e.to_string())?;
    let entry = match syntheses_store::get_by_anchor(conn, &anchor_key)
        .map_err(|e| e.to_string())? {
        None => return Ok(None),
        Some(e) => e,
    };
    let key = db_key(&app);
    let content = crypto::decrypt_any(&entry.content_encrypted, &key)
        .ok_or("decrypt failed")?;
    Ok(Some(StoredSynthesisView {
        anchor_key:     entry.anchor_key,
        category:       entry.category,
        synthesis_type: entry.synthesis_type,
        content,
        generated_at:   entry.generated_at,
    }))
}
```

Justificación de exponer `content` descifrado: **el contenido de la síntesis
no es `url` ni `title`**. Es texto generado a partir de inputs que el usuario
ya consintió enviar al proxy. D1 protege url/title; D25 cubre el ciclo de
síntesis. Exponerlo al frontend para mostrar es coherente con cómo
`titles` (descifrado en `session_builder`) ya se expone.

b) Registrar en `lib.rs`.

c) En `useSynthesis(anchorKey)`, al montar:
1. Invocar `get_synthesis_for_anchor`.
2. Si devuelve `Some`, setear estado a `complete` con el contenido y la
   `generated_at`.
3. Si `None`, queda en `idle`.

d) UI: añadir un indicador `"Generada el {fecha}"` en el footer cuando viene
de BD (no de stream actual). Y mostrar el botón "Regenerar" que ya existe.

**Test**: `test_get_synthesis_for_anchor_round_trip` que persiste cifrado y
recupera descifrado.

### 9. [SERIO — gobernanza] Documentar decisión "Sin StrictMode"

**Archivo**: `EquipoEnjambre/Project-docs/decisions-log.md`

**Problema**: la eliminación de `<StrictMode>` se decidió durante el debug de
listeners SSE duplicados (race condition irresoluble en `useEffect` async de
Tauri). No está en el log de decisiones. Si Claude Code u otro agente
refactoriza el frontend en el futuro y vuelve a meter StrictMode, no tendrá
referencia.

**Fix**: añade entrada D32 en `decisions-log.md`:

```
| D32 | React StrictMode descartado en frontend Tauri | useEffect bajo StrictMode
ejecuta dos veces en dev. Combinado con `listen()` async de @tauri-apps/api/event,
produce listeners duplicados que no se pueden recolectar de forma fiable. La
primera invocación devuelve la promise pero la cleanup ejecuta antes de que la
segunda termine de registrar. Decisión: `src/main.tsx` no envuelve `<App/>` en
`<React.StrictMode>`. Cualquier refactor de `App.tsx` o de componentes con
listeners Tauri debe preservar esta condición. Las warnings que StrictMode
detectaría se ejercitan vía test manual y eslint. | 2026-05-XX (fecha real
del commit) |
```

Y al final del archivo, en la sección de "Decisiones cerradas recientemente",
añade la entrada correspondiente.

### 10. [SERIO — coherencia documental] Comentarios obsoletos sobre D9 foreground-only

**Archivo**: `src-tauri/src/fs_watcher.rs`

**Problema**: el header del módulo (líneas ~4 y ~16) dice "Foreground-only"
y "D9 absoluto". D9 fue revisada el 2026-04-28 a background-persistent. El
código en `lib.rs` ya implementa background-persistent; solo el comentario
está mal.

**Fix**: actualizar el header. Reemplaza:

```
// Opera solo mientras la app está en primer plano (D9).
```

por:

```
// Opera en modo background-persistent: una vez arrancado por foco inicial,
// sigue activo mientras haya directorios activos, también si la app pierde
// foco (D9 revisada 2026-04-28). Solo se detiene al cerrar la app o al
// desactivar todos los directorios.
```

Y en la tabla de comparación:

```
// | Foreground-only | Sí (D9 absoluto)    | ...
```

por:

```
// | Background      | Persistente (D9 rev) | ...
```

### 11. [SERIO — proxy] Endurecer prompt `noticias.txt`

**Archivo**: `flowweaver-proxy-main/src/prompts/v1/noticias.txt`

**Problema**: el prompt actual invita al modelo a usar lo que conoce hasta
su fecha de cutoff. Cualquier título posterior al cutoff produce
alucinaciones con tono autoritativo. Categoría `noticias` es la más expuesta
y la más sensible reputacionalmente.

**Fix**: reescribir el prompt para limitar al modelo a lo que aparece
literalmente en los títulos:

```
Eres un asistente que organiza titulares de noticias guardados por el usuario.
El usuario ha guardado estos titulares:
Títulos: {titles}
Dominios: {domains}

NORMAS:
- No describas eventos. No expliques el contexto. No conjeturas sobre lo que
  pasó. Trabaja solo con lo que dicen literalmente los titulares.
- Si no reconoces un titular, no lo expliques. Lístalo.
- No menciones fechas de eventos.

Genera un resumen en español con este formato Markdown exacto:

## Temas detectados

[Agrupa los titulares por tema general en 1-3 categorías. Para cada categoría,
indica cuántos titulares la componen y enuméralos. No expliques los temas.]

## Fuentes consultadas

[Lista de dominios distintos y cuántos titulares hay de cada uno.]

## Sugerencia

[Una frase: "Tienes N titulares sobre {tema} de los últimos días — puede que
quieras ponerte al día." Sin más contenido.]
```

Después del cambio, despliega el proxy (`wrangler deploy`) en una rama o
preview environment, no en producción directamente. **No lo despliegues a
producción sin que yo lo apruebe.**

### 12. [MEDIO — proxy] Código de error `INVALID_BODY`

**Archivos**:
- `flowweaver-proxy-main/src/index.ts`
- `flowweaver-proxy-main/src/types.ts`

**Problema**: cuando el JSON viene malformado, el proxy devuelve
`SYNTHESIS_TYPE_UNKNOWN`. Es engañoso.

**Fix**:

a) En `types.ts`, añade `INVALID_BODY` al union de `SynthesisError.error`.

b) En `index.ts`, sustituye:

```ts
} catch {
  return jsonError(400, "SYNTHESIS_TYPE_UNKNOWN");
}
```

por:

```ts
} catch {
  return jsonError(400, "INVALID_BODY");
}
```

c) No hace falta cambiar el cliente Rust: el manejo en `SynthesisError` ya
agrupa cualquier 400 fuera del enum como `Http(...)` genérico, y el frontend
ya muestra un mensaje genérico. Si quieres mensaje específico, añade caso en
`mapError` del frontend (`'INVALID_BODY' → 'Petición malformada — recarga
y reintenta.'`). Opcional.

### 13. [MEDIO — coherencia] `synthesis_tokens.token_hash` mal nombrada

**Archivo**: `src-tauri/src/synthesis_tokens.rs`

**Problema**: la columna se llama `token_hash` pero contiene ciphertext AES
(reversible). Confunde al lector.

**Fix**: migración de schema. **Cuidado**: cambiar nombre de columna en
SQLite requiere `ALTER TABLE ... RENAME COLUMN` (disponible desde SQLite
3.25+; SQLCipher bundled lo soporta).

```rust
pub(crate) fn ensure_schema(conn: &Connection) -> Result<(), rusqlite::Error> {
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS synthesis_tokens (
            id              INTEGER PRIMARY KEY CHECK (id = 1),
            token_encrypted TEXT NOT NULL,
            set_at          INTEGER NOT NULL
        );",
    )?;
    // Migración Fase 3 → 3.1: rename token_hash → token_encrypted si existe.
    let column_exists: bool = conn
        .query_row(
            "SELECT 1 FROM pragma_table_info('synthesis_tokens') WHERE name = 'token_hash'",
            [],
            |_| Ok(true),
        )
        .unwrap_or(false);
    if column_exists {
        conn.execute_batch(
            "ALTER TABLE synthesis_tokens RENAME COLUMN token_hash TO token_encrypted;"
        )?;
    }
    Ok(())
}
```

Actualiza las queries en el mismo archivo (`set_token`, `get_token`) para
usar `token_encrypted`.

**Test**: `test_token_hash_to_token_encrypted_migration` que crea la tabla
con el schema viejo, ejecuta `ensure_schema`, y verifica que la columna
ahora se llama `token_encrypted` y los datos siguen.

### 14. [MEDIO — coherencia] Mapping de categorías duplicado

**Archivos**:
- `src/components/AnticipatedWorkspace.tsx`
- `src/components/EpisodePanel.tsx`

**Problema**: `SYNTHESIS_CATEGORY_MAP` está declarado en los dos componentes
con el mismo contenido. Va a aparecer también en mobile cuando D27 entre.

**Fix**: extraer a `src/utils/synthesisCategory.ts`:

```ts
export const SYNTHESIS_CATEGORY_MAP: Record<string, string> = {
  cocina:           'cocina',
  recetas:          'cocina',
  gastronomia:      'cocina',
  entretenimiento:  'entretenimiento',
  cine:             'entretenimiento',
  musica:           'entretenimiento',
  juegos:           'entretenimiento',
  noticias:         'noticias',
  actualidad:       'noticias',
  tecnologia:       'tecnologia',
  programacion:     'tecnologia',
  desarrollo:       'tecnologia',
};

export function mapCategoryToSynthesisType(category: string): string {
  return SYNTHESIS_CATEGORY_MAP[category.toLowerCase()] ?? 'noticias';
}

export function canSynthesize(category: string): boolean {
  return category.toLowerCase() in SYNTHESIS_CATEGORY_MAP;
}
```

Importa donde haga falta y borra las definiciones duplicadas.

### 15. [MEDIO — UX] Filtro de "puede sintetizar" en `EpisodePanel`

**Archivo**: `src/components/EpisodePanel.tsx`

**Problema**: el comentario dice "Botón síntesis en Broad 100% con categoría
válida". El código actual filtra por `ep.coherence === 1.0 && canSynthesize(category)`,
que también pilla Precise con coherence=1.0 (raro pero posible). Ambigüedad
entre el comentario y el código.

**Decisión a tomar**: ¿quieres mostrar síntesis solo en Broad, o en cualquier
episodio con coherencia alta (Precise ≥ 0.9, Broad = 1.0)?

**Recomendación**: mostrarlo cuando la coherencia sea alta sin importar el
mode, pero subir el umbral para precisión. Sustituye:

```tsx
{ep.coherence === 1.0 && canSynthesize(category) && (
```

por:

```tsx
{ep.coherence >= 0.9 && canSynthesize(category) && (
```

Y actualiza el comentario en consecuencia. Si prefieres mantener "solo Broad",
usa `ep.mode === 'Broad' && canSynthesize(category)` y déjalo explícito.
Documenta tu elección en el commit.

## Verificaciones finales

Cuando termines, ejecuta y captura output:

1. `cargo test --lib` desde `src-tauri/` → 0 fallos. Sigue siendo ≥105 tests
   (más los nuevos que añadiste).
2. `npx tsc --noEmit` desde la raíz → EXIT=0.
3. `npm run test` (vitest) → todos pasan.
4. `npm run tauri dev` → arranca, el flujo completo funciona:
   - Activar síntesis desde Privacy Dashboard (consent + token en serie).
   - Generar síntesis de un episodio cocina.
   - Reabrir la app → la síntesis sigue visible (tarea 8).
   - Pulsar "Regenerar" → el contenido se reinicia, no se concatena (tarea 4).
   - Desactivar síntesis → token y consent desaparecen (tarea 7).

## Lo que NO debes hacer

- No reintroduzcas StrictMode.
- No añadas `react-markdown` ni `dompurify` ni librerías de Markdown — el
  renderer inline propio cubre el caso.
- No toques `crypto.rs`, `state_machine.rs`, `pattern_detector.rs`,
  `episode_detector.rs`, `session_builder.rs`, `trust_scorer.rs`,
  `fs_watcher.rs` (excepto el comentario de header en tarea 10).
- No despliegues el proxy a producción (tarea 11) sin aprobación explícita
  del Orchestrator.
- No implementes D27 (sync de syntheses) en esta tarea. Es de fase posterior.
- No cambies el shape del payload del proxy (los 5 campos D25 son
  innegociables: `category`, `titles`, `domains`, `synthesis_type`,
  `language` + `prompt_version` opcional).

## Entregables

1. Commits por tarea (no un único commit gigante). Mensaje de commit en cada
   uno con el ID de la tarea: `[T-3-hardening-1] Escape HTML en renderMarkdown`.
2. Resumen final con: tests añadidos, tests modificados, archivos tocados
   por tarea, y el output de las cuatro verificaciones finales.
3. Si encuentras un caso que el prompt no cubre y exige decisión, **para y
   pregunta**. No improvises decisiones de privacidad o de schema sin
   confirmación.

## Orden sugerido de ejecución

Tareas 1, 3, 13 son independientes y rápidas — empieza por ahí para acumular
verde.
Después tarea 6 (consent_log_store) porque la 7 depende de su API.
Después 4 y 5 juntas (comparten el patrón useRef/generationId/hook).
Después 2 (mes calendario + header del proxy).
Después 7 (flujo unificado consent+token), 8 (síntesis pasadas).
Después 9, 10, 11, 12, 14, 15 — son rápidas y sueltas.

Cualquier cosa que se te queme, frena y reporta antes de seguir.