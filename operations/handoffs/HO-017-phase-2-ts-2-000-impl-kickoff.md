# Standard Handoff

document_id: HO-017
from_agent: Orchestrator
to_agent: Desktop Tauri Shell Specialist
status: ready_for_execution
phase: 2
date: 2026-04-27
cycle: Implementación Fase 2 — T-2-000 FS Watcher (`fs_watcher.rs`)
opens: implementación de `src-tauri/src/fs_watcher.rs` + comandos Tauri + persistencia mínima de configuración + tipos TypeScript + integración del bloque "FS Watcher" en `PrivacyDashboard.tsx` mediante HO ortogonal documentado (HO-FW-PD) sin reabrir TS-2-004.
depends_on: TS-2-000 firmada por Technical Architect (AR-2-002, 2026-04-24) y validada por Orchestrator. Implementación independiente de T-2-001 / T-2-002 / T-2-003 (TS-2-000 §4 R12 — FS Watcher genera eventos de sesión, no patrones longitudinales). No bloquea ni es bloqueado por T-2-004 (TS-2-004 §"Decisiones del Technical Architect §4" declara la sección FS Watcher como out-of-scope de T-2-004; la integración al dashboard se materializa por HO-FW-PD posterior sin reabrir TS-2-004).
unblocks: AR-2-007 (revisión arquitectónica post-implementación de FS Watcher) y, tras aprobación, HO-FW-PD (integración del bloque "FS Watcher" al `PrivacyDashboard.tsx` ya implementado por T-2-004).

---

> **Resolución de numeración:** HO-016 §"Cierre" línea 498 contiene una referencia forward (`HO-017-phase-2-ts-2-004-impl-close.md`) emitida antes de que se planificara este HO de T-2-000. Las numeraciones HO se asignan por **orden cronológico de emisión**, no por reserva forward — por tanto **HO-017 = este documento (T-2-000 impl-kickoff)**. El futuro cierre de T-2-004 tomará el siguiente número disponible al momento de su emisión (HO-018 si no se emite ningún otro HO antes). HO-016 no se modifica (ya firmado y publicado); la referencia forward en su §"Cierre" queda superada por este documento sin necesidad de erratum formal.

---

## Objetivo

Implementar `src-tauri/src/fs_watcher.rs` siguiendo TS-2-000 al pie de la
letra: detector de eventos de archivo en sesión activa que opera **solo
mientras la app FlowWeaver está en primer plano** (D9), observa
exclusivamente los directorios opt-in declarados (`~/Downloads`,
`~/Desktop`) con la lista blanca de 18 extensiones en 5 grupos, no lee
el contenido de los archivos, no persiste eventos entre sesiones, y
queda expresamente separado del Pattern Detector (longitudinal,
SQLCipher) y del Episode Detector (sesión, sin estado) — R12.

La implementación abarca cinco ejes coordinados:

1. **Backend Rust** — módulo nuevo `fs_watcher.rs` con dependencia
   `notify` (crate cross-platform: ReadDirectoryChangesW en Windows,
   FSEvents en macOS, inotify en Linux); persistencia mínima de la
   configuración (directorios activos opt-in) en SQLCipher (tabla nueva
   `fs_watcher_config`); foreground-only enforcement vía hooks de
   `tauri::WindowEvent::Focused`.
2. **Comandos Tauri** — siete comandos nuevos en `commands.rs`:
   `fs_watcher_get_status`, `fs_watcher_list_directories`,
   `fs_watcher_activate_directory`, `fs_watcher_deactivate_directory`,
   `fs_watcher_get_session_events`, `fs_watcher_clear_directory_history`,
   `fs_watcher_get_24h_event_count`.
3. **TypeScript** — cuatro tipos nuevos en `src/types.ts`
   (`FsWatcherDirectory`, `FsWatcherStatus`, `FsWatcherEvent`,
   `FsWatcherView`).
4. **Plataforma** — implementación funcional en Windows (D19 primario);
   stub explícito en Android (`#[cfg(target_os = "android")]` devuelve
   `Err("FS Watcher no soportado en Android — track móvil cubre observación
   por share intent")` en cada comando).
5. **Tests Rust** — 8 tests nuevos cubriendo whitelist de extensiones,
   filtrado de directorios prohibidos, foreground-only enforcement
   (con mock de estado de foco), idempotencia de activate/deactivate,
   purga de historial, ausencia de monitoring en background, y test
   estructural D1/R12 (sin acceso a `url`/`title`, sin imports de
   `pattern_detector`/`episode_detector` salvo el comentario documental).

La implementación queda **estrictamente acotada** a TS-2-000. Cualquier
ambigüedad o necesidad de desviación se escala al Orchestrator antes de
proceder. **La integración al `PrivacyDashboard.tsx` (sección "FS
Watcher" prevista en TS-2-000 §3 "Visibilidad en el Privacy Dashboard")
se difiere a HO-FW-PD posterior**, dado que T-2-004 declaró la sección
FS Watcher out-of-scope (TS-2-004 §"Decisiones del Technical Architect
§4"). HO-017 entrega el backend completo + tipos TypeScript + comandos
Tauri listos para consumo; HO-FW-PD añadirá únicamente el subcomponente
React `FsWatcherSection.tsx` y su composición en `PrivacyDashboard.tsx`.

---

## Inputs

Lectura obligatoria antes de cualquier edición:

### Spec autoritativa
- **TS-2-000:** `operations/task-specs/TS-2-000-fs-watcher-delimitation.md`
  (firmada por Technical Architect 2026-04-24, AR-2-002). Es la **única
  fuente de verdad** para esta implementación. Todos los contratos
  (directorios candidatos, lista blanca de extensiones, modelo de datos,
  controles de privacidad, separación R12) están declarados literalmente
  y deben implementarse sin parafrasear. **Verificar que la sección
  §"Criterios de Aceptación de Este Documento" línea 216 marca el último
  ítem (aprobación TA) como completado en AR-2-002 antes de proceder** —
  si el ítem aún figura como `[ ]` en TS-2-000, escalar al Orchestrator.

### Decisiones cerradas
- **`Project-docs/decisions-log.md`** — D1 (transversal absoluto: sin
  `url`/`title` en eventos ni en logs; el nombre del archivo se cifra,
  el directorio padre permanece en claro como contexto), D9 (foreground-
  only absoluto en Fase 2; sin background bajo ninguna circunstancia),
  D14 (la visibilidad del FS Watcher en Privacy Dashboard es requisito
  declarado por TS-2-000 §3, materializado por HO-FW-PD posterior), D17
  (no aplica directamente — Pattern Detector ya cerrado por AR-2-003),
  D19 (Windows + Android primario; Windows funcional, Android stub),
  R12 (FS Watcher ≠ Pattern Detector ≠ Episode Detector — comentario
  de cabecera obligatorio con tabla comparativa de tres columnas).

### Contratos heredados (no modificar)
- **TS-2-001 / TS-2-002 / TS-2-003 / TS-2-004:** todos cerrados por
  AR-2-003 / AR-2-004 / AR-2-005 / AR-2-006. **No reabrir.** FS Watcher
  no consume ni alimenta sus contratos directamente — los eventos del FS
  Watcher son efímeros y separados del Pattern Detector (R12 explícito
  en TS-2-000 §4).

### Revisiones arquitectónicas
- **AR-2-002:** aprobación de TS-2-000 por Technical Architect
  (2026-04-24).
- **AR-2-005 / AR-2-006:** cierres de T-2-003 / T-2-004 — referencia
  para el patrón de revisión post-implementación que aplicará AR-2-007
  a este HO.

### CLAUDE.md (FlowWeaver)
- Sección §"FS Watcher — scope aprobado (TS-2-000)" describe scope a
  alto nivel y declara el comentario de cabecera obligatorio para
  `fs_watcher.rs`. **TS-2-000 prevalece** sobre CLAUDE.md ante cualquier
  discrepancia.

### Código existente (anclas verificadas contra rama actual)
- `src-tauri/src/lib.rs:1-13` — declaraciones de módulos en orden
  alfabético. `mod fs_watcher;` se inserta entre línea 4
  (`mod episode_detector;`) y línea 5 (`mod grouper;`).
- `src-tauri/src/lib.rs:63-87` — `invoke_handler!` actual. Los siete
  comandos nuevos se añaden tras `commands::clear_all_resources`
  (línea 75) y antes de `commands::get_trust_state` (línea 76)
  manteniendo agrupación por dominio funcional (sugerencia: bloque
  `commands::fs_watcher_*` contiguo).
- `src-tauri/src/storage.rs:72-98` — patrón existente de migraciones
  SQLCipher (`CREATE TABLE IF NOT EXISTS` + `ALTER TABLE … ADD COLUMN`
  idempotente). La migración de `fs_watcher_config` debe seguir este
  patrón. **Recomendación:** mantener la responsabilidad de migración
  encapsulada en `fs_watcher::ensure_schema(conn, now_unix)` invocado
  desde `commands.rs` antes de cada comando que toque la configuración
  (consistente con el patrón establecido en T-2-003 / T-2-004).
- `src-tauri/src/commands.rs` — patrón existente de comandos Tauri
  (uso de `State<'_, DbState>`, retorno de `Result<T, String>`, lock del
  mutex). Los siete comandos nuevos deben seguir este patrón.
- `src/types.ts` — bloque T-2-004 cerrado por AR-2-006 (líneas
  aproximadas 100-130 tras la implementación de T-2-004). El bloque
  T-2-000 se añade inmediatamente después como sección `// ── Phase 2
  — FS Watcher (T-2-000) ──`.
- `src-tauri/Cargo.toml` — añadir dependencia `notify = "6"` (versión
  cross-platform con soporte ReadDirectoryChangesW + FSEvents + inotify).
  La dependencia debe declararse con feature flag o cfg para excluir
  Android (donde el stub no la usa).

### Comandos de verificación
```bash
cd src-tauri && cargo test          # ≥ 57 tests / 0 failed / 0 ignored (49 actuales + 8 nuevos)
npx tsc --noEmit                    # limpio
cd src-tauri && cargo build --target x86_64-pc-windows-msvc  # Windows funcional
cd src-tauri && cargo build --target aarch64-linux-android   # Android stub compila
```

---

## Entregables esperados

### 1. Nuevo archivo `src-tauri/src/fs_watcher.rs`

Estructura exacta:

a. **Comentario de cabecera obligatorio** — reproducción literal del
   bloque declarado en TS-2-000 §4 + extensión a tabla comparativa de
   **tres columnas** (`fs_watcher.rs`, `pattern_detector.rs`,
   `episode_detector.rs`) y **siete dimensiones** (Función, Escala
   temporal, Input, Output, Persistencia, Foreground-only, Decisión
   D-aplicable):

   ```rust
   // FS Watcher: detecta eventos de archivo en sesión activa.
   // Distinto de pattern_detector.rs (patrones longitudinales) y de
   // episode_detector.rs (episodios de sesión activa sin estado) — R12.
   // Opera solo mientras la app está en primer plano (D9).
   // Solo registra nombre del archivo (cifrado D1), directorio padre
   // (en claro), extensión (en claro) y timestamp. Nunca lee contenido
   // (D1 — prohibición permanente).
   //
   // | Dimensión       | fs_watcher.rs       | pattern_detector.rs   | episode_detector.rs   |
   // |-----------------|---------------------|-----------------------|-----------------------|
   // | Función         | Eventos archivo     | Patrones longitudinales| Episodio de sesión   |
   // | Escala temporal | Tiempo real (sesión)| Días/semanas          | Sesión activa         |
   // | Input           | inotify/RDCW/FSE    | SQLCipher resources   | Stream de captures    |
   // | Output          | FsWatcherEvent      | DetectedPattern       | Episode (memoria)     |
   // | Persistencia    | Solo configuración  | Patrones detectados   | Sin estado            |
   // | Foreground-only | Sí (D9 absoluto)    | No aplica             | No aplica             |
   // | Decisión clave  | D9                  | D17                   | (heredado Fase 1)     |
   ```

b. **Constantes de scope (declaradas como `const` o `static`)** —
   reproducidas literalmente desde TS-2-000 §1:

   ```rust
   /// Lista blanca de extensiones (TS-2-000 §1 "Extensiones de archivo en scope").
   /// Cualquier extensión no listada se ignora silenciosamente.
   pub(crate) const ALLOWED_EXTENSIONS: &[&str] = &[
       // Documentos
       "pdf", "docx", "doc", "txt", "md", "xlsx", "csv",
       // Imágenes (incluye capturas de pantalla en Desktop/Downloads)
       "png", "jpg", "jpeg", "gif", "webp", "svg",
       // Video
       "mp4", "mov", "webm",
       // Archivos comprimidos
       "zip",
   ];

   /// Directorios candidatos (TS-2-000 §1 "Directorios observables").
   /// Ningún directorio se activa por defecto.
   #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
   pub enum CandidateDirectory {
       Downloads,
       Desktop,
   }
   ```

   La lista blanca tiene **17 entradas únicas** (`png` aparece una vez
   aunque TS-2-000 lo lista en dos grupos — Imágenes y Capturas de
   pantalla — porque ambos grupos comparten bucket por TS-2-000 §1).
   Total declarado en TS-2-000: 18 menciones, 17 extensiones únicas.
   AR-2-007 verificará que la implementación expone exactamente las 17
   extensiones únicas sin duplicados.

c. **Tipos públicos** (consumidos por comandos Tauri y por TypeScript):

   ```rust
   #[derive(Debug, Clone, Serialize, Deserialize)]
   pub struct FsWatcherDirectory {
       pub directory: CandidateDirectory,
       pub absolute_path: String,        // resuelto desde dirs::download_dir() / dirs::desktop_dir()
       pub active: bool,
       pub activated_at: Option<i64>,    // Unix seconds; None si nunca activado
   }

   #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
   pub enum FsWatcherRuntimeState {
       Active,        // app en primer plano + al menos un directorio activo
       Suspended,     // app en background O sin directorios activos
       Unsupported,   // plataforma no soporta FS Watcher (Android — D19)
   }

   #[derive(Debug, Clone, Serialize)]
   pub struct FsWatcherEvent {
       pub event_id: String,             // UUID v4
       pub directory: CandidateDirectory,
       pub file_name_encrypted: Vec<u8>, // AES-GCM (D1)
       pub extension: String,            // en claro (categoría del evento — D1 lo permite)
       pub detected_at: i64,             // Unix seconds
   }

   #[derive(Debug, Clone, Serialize)]
   pub struct FsWatcherStatus {
       pub runtime_state: FsWatcherRuntimeState,
       pub directories: Vec<FsWatcherDirectory>,
       pub events_in_current_session: usize,
       pub events_last_24h: usize,
   }

   #[derive(Debug)]
   pub enum FsWatcherError {
       UnsupportedPlatform,
       DirectoryResolutionFailed(CandidateDirectory),
       AppInBackground,
       Persistence(rusqlite::Error),
       NotifyBackend(notify::Error),
   }

   impl std::fmt::Display for FsWatcherError { /* … */ }
   impl std::error::Error for FsWatcherError { /* … */ }
   impl From<rusqlite::Error> for FsWatcherError { /* … */ }
   impl From<notify::Error> for FsWatcherError { /* … */ }
   ```

   **Restricción D1 absoluta:** ningún campo de los structs públicos
   puede llamarse `url`, `title`, `link`, `href`, `bookmark_url`,
   `page_title`, `full_path` (la ruta completa NUNCA se almacena ni se
   expone), `content`, `body`, `text`. Auditable por inspección textual.
   `file_name_encrypted` es `Vec<u8>` y nunca un `String` legible.
   `absolute_path` se resuelve por `dirs::download_dir()` /
   `dirs::desktop_dir()` y es la **ruta del directorio padre**, nunca
   la ruta del archivo individual (TS-2-000 §1 "Qué registra de cada
   archivo" → fila "Ruta completa: solo el directorio padre").

d. **Funciones `pub(crate)` de persistencia** (singleton de configuración):

   ```rust
   /// Crea la tabla `fs_watcher_config` si no existe.
   /// Schema mínimo (TS-2-000 §1 "Modelo de datos" — los eventos NO
   /// se persisten entre sesiones; solo la configuración).
   ///
   /// CREATE TABLE IF NOT EXISTS fs_watcher_config (
   ///     directory     TEXT PRIMARY KEY CHECK (directory IN ('Downloads', 'Desktop')),
   ///     active        INTEGER NOT NULL DEFAULT 0 CHECK (active IN (0, 1)),
   ///     activated_at  INTEGER,
   ///     updated_at    INTEGER NOT NULL
   /// );
   ///
   /// Inicialización idempotente con dos filas (Downloads, Desktop) en
   /// estado inactivo (`active = 0`, `activated_at = NULL`) si la
   /// tabla está vacía. Coherente con TS-2-000 §1 "Sin activación por
   /// defecto".
   pub(crate) fn ensure_schema(conn: &Connection, now_unix: i64) -> Result<(), FsWatcherError>;

   /// Lista la configuración actual de los dos directorios candidatos.
   pub(crate) fn list_directories(conn: &Connection) -> Result<Vec<FsWatcherDirectory>, FsWatcherError>;

   /// Activa un directorio (`active = 1`, `activated_at = now_unix`).
   /// Idempotente: si ya está activo, no modifica `activated_at`.
   pub(crate) fn activate(conn: &Connection, directory: CandidateDirectory, now_unix: i64) -> Result<(), FsWatcherError>;

   /// Desactiva un directorio (`active = 0`, preserva `activated_at`
   /// para auditoría histórica si el usuario lo reactiva).
   pub(crate) fn deactivate(conn: &Connection, directory: CandidateDirectory, now_unix: i64) -> Result<(), FsWatcherError>;
   ```

   Los **eventos no se persisten** (TS-2-000 §2 "Qué ocurre al suspender
   la observación" → "Los eventos de archivo en cola pero no procesados
   por el Episode Detector se descartan"). El estado en runtime se
   mantiene en memoria (estructura `Mutex<RuntimeBuffer>` interna del
   módulo) y se purga al perder el foco o al cerrar la app.

e. **Función pública `start_watching`** (lanza el watcher de `notify`
   solo si la app está en primer plano y al menos un directorio está
   activo):

   ```rust
   /// Inicia el watcher de archivos para los directorios activos.
   /// Solo se invoca cuando la app pasa a primer plano.
   /// Devuelve un handle que se debe `drop` cuando la app pasa a
   /// background (esto detiene el watcher subyacente — D9).
   #[cfg(not(target_os = "android"))]
   pub fn start_watching(
       conn: &Connection,
       event_buffer: Arc<Mutex<Vec<FsWatcherEvent>>>,
       crypto_key: &[u8; 32],
   ) -> Result<FsWatcherHandle, FsWatcherError>;

   #[cfg(target_os = "android")]
   pub fn start_watching(
       _conn: &Connection,
       _event_buffer: Arc<Mutex<Vec<FsWatcherEvent>>>,
       _crypto_key: &[u8; 32],
   ) -> Result<FsWatcherHandle, FsWatcherError> {
       Err(FsWatcherError::UnsupportedPlatform)
   }

   pub struct FsWatcherHandle {
       _watcher: Box<dyn notify::Watcher + Send>,
       // drop() se encarga de detener el watcher cuando se desreferencia
   }
   ```

   El handle se almacena en `DbState` (o en un nuevo `FsWatcherState`
   gestionado por Tauri) y se `drop` en el callback de
   `WindowEvent::Focused(false)` registrado en `lib.rs`. AR-2-007
   verificará por inspección de código que no existe ningún path donde
   el watcher persista tras el evento de pérdida de foco.

f. **Filtro de extensiones y filtro anti-directorios prohibidos**:

   ```rust
   /// Devuelve `true` si la extensión está en la lista blanca.
   pub(crate) fn is_extension_allowed(path: &Path) -> bool {
       path.extension()
           .and_then(|e| e.to_str())
           .map(|e| e.to_ascii_lowercase())
           .map(|e| ALLOWED_EXTENSIONS.contains(&e.as_str()))
           .unwrap_or(false)
   }

   /// Verifica que el directorio resuelto NO es uno de los prohibidos
   /// declarados en TS-2-000 §1 (sistema, red, ocultos, otras apps).
   /// Defensivo: aunque solo se exponen Downloads/Desktop, esta función
   /// blinda contra cualquier escalada de scope futura.
   pub(crate) fn is_directory_allowed(path: &Path) -> bool {
       let s = path.to_string_lossy().to_lowercase();
       let forbidden = [
           "/system/", "c:\\windows\\", "/users/shared/",
           "/.git/", "/.ssh/", "/dropbox/", "/onedrive/",
           "/icloud drive/", "/google drive/",
       ];
       !forbidden.iter().any(|f| s.contains(f))
   }
   ```

g. **Bloque `#[cfg(test)] mod tests`** con los **8 tests obligatorios**:

   1. `test_extension_whitelist_exact_set` — verifica que la lista
      contiene exactamente las 17 extensiones únicas declaradas en
      TS-2-000 §1, ni una más, ni una menos. Lista hardcoded en el test
      para detectar drift entre código y spec.
   2. `test_extension_filter_rejects_executables` — `.exe`, `.app`,
      `.dmg`, `.msi`, `.sh`, `.bat` → `false`. `.py`, `.js`, `.rs`,
      `.swift`, `.java` → `false`. `.pem`, `.key`, `.p12`, `.env` →
      `false`. `.dll`, `.sys`, `.plist`, `.dylib` → `false`.
   3. `test_directory_filter_rejects_forbidden` — paths del sistema,
      red, ocultos y otras apps → `false`.
   4. `test_activate_deactivate_round_trip` — `ensure_schema` →
      `activate(Downloads)` → `list_directories` (Downloads activo) →
      `deactivate(Downloads)` → `list_directories` (Downloads inactivo,
      `activated_at` preservado).
   5. `test_activate_idempotent` — dos `activate(Downloads)`
      consecutivos no modifican `activated_at` del segundo.
   6. `test_no_events_persisted_across_sessions` — verifica que la
      tabla `fs_watcher_config` no tiene columnas de eventos
      (auditable: `PRAGMA table_info(fs_watcher_config)` debe devolver
      exactamente 4 columnas: `directory`, `active`, `activated_at`,
      `updated_at`). Si alguien añade una columna `events_blob`, este
      test rompe — D9 transitivo.
   7. `test_no_url_or_title_in_event_struct` — test estructural:
      `include_str!("./fs_watcher.rs")` + tokens prohibidos `["url:",
      "title:", "link:", "href:", "page_title:", "bookmark_url:",
      "full_path:", "content:", "body:"]`. Grep negativo asegura que
      ningún campo público o privado del módulo expone estos términos.
   8. `test_no_pattern_detector_or_episode_detector_imports` — test
      estructural R12: `include_str!("./fs_watcher.rs")` debe contener
      la línea documental `// Distinto de pattern_detector.rs … y de
      episode_detector.rs … — R12.` y NO debe contener `use
      crate::pattern_detector` ni `use crate::episode_detector`. Split
      por `#[cfg(test)]` para excluir el bloque de tests del análisis.

   El módulo debe contener **un solo bloque `#[cfg(test)]`** para que el
   split del test estructural funcione tal como está definido
   (consistente con `state_machine.rs` y `pattern_blocks.rs`).

### 2. Modificación `src-tauri/src/lib.rs`

a. Añadir `mod fs_watcher;` en **orden alfabético** entre línea 4
   (`mod episode_detector;`) y línea 5 (`mod grouper;`). El listado
   quedará así (líneas 1-15 tras la edición):

   ```
   mod classifier;
   mod commands;
   mod crypto;
   mod episode_detector;
   mod fs_watcher;
   mod grouper;
   mod importer;
   mod pattern_blocks;
   mod pattern_detector;
   mod raw_event;
   mod session_builder;
   mod state_machine;
   mod storage;
   mod trust_scorer;
   ```

b. **Registrar los siete comandos** en el `invoke_handler!` (líneas
   actuales 63-87) en bloque contiguo tras `commands::clear_all_resources`
   (línea 75) y antes de `commands::get_trust_state` (línea 76):

   ```rust
   commands::fs_watcher_get_status,
   commands::fs_watcher_list_directories,
   commands::fs_watcher_activate_directory,
   commands::fs_watcher_deactivate_directory,
   commands::fs_watcher_get_session_events,
   commands::fs_watcher_clear_directory_history,
   commands::fs_watcher_get_24h_event_count,
   ```

c. **Hook de foreground-only enforcement** — registrar en el `setup`
   handler (alrededor de la línea 28 actual) un listener de
   `WindowEvent::Focused(focused)` que:
   - Cuando `focused == true`: invoca `fs_watcher::start_watching(...)`
     si hay al menos un directorio activo y guarda el handle en estado
     gestionado por Tauri (`State<FsWatcherState>`).
   - Cuando `focused == false`: drop del handle (esto detiene el
     watcher de `notify` automáticamente vía RAII) y purga el buffer
     en memoria de `FsWatcherEvent` (D9 — sin background).

   Pseudocódigo recomendado (verificable por AR-2-007):

   ```rust
   .on_window_event(|window, event| {
       if let tauri::WindowEvent::Focused(focused) = event {
           let state = window.state::<FsWatcherState>();
           let mut guard = state.handle.lock().unwrap();
           if *focused {
               let db_state = window.state::<DbState>();
               let conn = db_state.0.lock().unwrap();
               if let Ok(handle) = fs_watcher::start_watching(&conn, /* ... */) {
                   *guard = Some(handle);
               }
           } else {
               *guard = None;  // drop → watcher se detiene
               state.event_buffer.lock().unwrap().clear();  // purga buffer
           }
       }
   })
   ```

   AR-2-007 verificará que NO existe ningún path alternativo donde el
   watcher se inicie fuera de este hook (por ejemplo, desde un comando
   Tauri directamente sin pasar por el evento de foco).

### 3. Modificación `src-tauri/src/storage.rs` (opcional)

**Decisión operativa idéntica al patrón establecido en T-2-003 / T-2-004:**
la responsabilidad de migración de `fs_watcher_config` se mantiene
encapsulada en `fs_watcher::ensure_schema(conn, now_unix)`, llamado
desde `commands.rs` antes de cada uso. **No es necesario tocar
`Db::migrate()` en `storage.rs`** si se prefiere mantener la migración
encapsulada en `fs_watcher.rs`. **Recomendación:** mantener
`ensure_schema` en `fs_watcher.rs` (módulo dueño del schema) — coherente
con `state_machine.rs` y `pattern_blocks.rs`.

### 4. Siete comandos Tauri nuevos en `src-tauri/src/commands.rs`

Firmas exactas:

```rust
#[tauri::command]
pub fn fs_watcher_get_status(state: State<'_, DbState>) -> Result<FsWatcherStatus, String>;

#[tauri::command]
pub fn fs_watcher_list_directories(state: State<'_, DbState>) -> Result<Vec<FsWatcherDirectory>, String>;

#[tauri::command]
pub fn fs_watcher_activate_directory(
    state: State<'_, DbState>,
    fs_state: State<'_, FsWatcherState>,
    directory: CandidateDirectory,
    confirmed: bool,
) -> Result<(), String>;

#[tauri::command]
pub fn fs_watcher_deactivate_directory(
    state: State<'_, DbState>,
    fs_state: State<'_, FsWatcherState>,
    directory: CandidateDirectory,
) -> Result<(), String>;

#[tauri::command]
pub fn fs_watcher_get_session_events(fs_state: State<'_, FsWatcherState>) -> Result<Vec<FsWatcherEvent>, String>;

#[tauri::command]
pub fn fs_watcher_clear_directory_history(
    state: State<'_, DbState>,
    fs_state: State<'_, FsWatcherState>,
    directory: CandidateDirectory,
) -> Result<(), String>;

#[tauri::command]
pub fn fs_watcher_get_24h_event_count(fs_state: State<'_, FsWatcherState>) -> Result<usize, String>;
```

Comportamiento exacto:

- **`fs_watcher_get_status`**: lock mutex DbState → `ensure_schema` →
  `list_directories` → consulta `runtime_state` desde `fs_state`
  (Active si app en foreground + ≥1 directorio activo; Suspended en
  caso contrario; Unsupported en Android) → consulta contadores desde
  `fs_state.event_buffer` (sesión actual y últimas 24h — los eventos
  no persisten entre sesiones, así que "últimas 24h" se calcula sobre
  el buffer en memoria desde el último `Focused(true)`; AR-2-007
  validará la semántica exacta y la consistencia con TS-2-000 §3
  "Contador de eventos detectados en las últimas 24 horas").
- **`fs_watcher_activate_directory`**: requiere `confirmed: true`
  (TS-2-000 §3 "Confirmación explícita"); si `confirmed == false`
  devuelve `Err("confirmation required")`. Lock mutex → `ensure_schema`
  → `activate(directory, now_unix)`. Si la app está en primer plano
  en este momento, intenta lanzar el watcher inmediatamente (idéntico
  al hook de `Focused(true)`).
- **`fs_watcher_deactivate_directory`**: lock → `ensure_schema` →
  `deactivate(directory, now_unix)`. Si era el último directorio activo,
  drop del handle del watcher (efecto idéntico a `Focused(false)` pero
  preservando el buffer de la sesión actual hasta que la app pierda
  el foco — TS-2-000 §3 "Desactivación inmediata").
- **`fs_watcher_get_session_events`**: devuelve clone del buffer
  actual de eventos de la sesión (vacío si la app está en background
  o si no hay directorios activos).
- **`fs_watcher_clear_directory_history`**: purga del buffer en memoria
  los eventos asociados al directorio especificado (TS-2-000 §3 "Purga
  de eventos"). No toca SQLCipher porque los eventos no se persisten.
- **`fs_watcher_get_24h_event_count`**: contador filtrado por
  `detected_at >= now - 86400`.

**Imports nuevos requeridos en `commands.rs`:** añadir
`fs_watcher::{self, CandidateDirectory, FsWatcherDirectory,
FsWatcherEvent, FsWatcherStatus, FsWatcherState}` al bloque `use
crate::{ … }`.

**Restricción D4 transitiva:** ningún comando de FS Watcher invoca
`evaluate_transition`, `score_patterns`, ni `detect_patterns`. FS
Watcher es un dominio independiente de la cadena de confianza.

**Restricción D1 absoluta:** ningún comando devuelve `url`, `title`,
ni la ruta completa del archivo. Solo: directorio padre (en claro),
extensión (en claro), nombre cifrado, timestamp.

### 5. `FsWatcherState` gestionado por Tauri

Nueva struct en `commands.rs` (o en `fs_watcher.rs` con re-export
desde `commands.rs`) registrada vía `.manage(...)` en `lib.rs::run()`
junto a `DbState`:

```rust
pub struct FsWatcherState {
    pub handle: Mutex<Option<FsWatcherHandle>>,
    pub event_buffer: Arc<Mutex<Vec<FsWatcherEvent>>>,
}

impl Default for FsWatcherState {
    fn default() -> Self {
        Self {
            handle: Mutex::new(None),
            event_buffer: Arc::new(Mutex::new(Vec::new())),
        }
    }
}
```

Registro en `lib.rs::run()`:

```rust
.manage(FsWatcherState::default())
```

### 6. Tipos TypeScript nuevos en `src/types.ts`

Añadir tras el bloque T-2-004 (cerrado por AR-2-006). Shape literal:

```typescript
// ── Phase 2 — FS Watcher (T-2-000) ───────────────────────────────────────────

export type CandidateDirectory = 'Downloads' | 'Desktop';

export type FsWatcherRuntimeState = 'Active' | 'Suspended' | 'Unsupported';

export interface FsWatcherDirectory {
  directory: CandidateDirectory;
  absolute_path: string;
  active: boolean;
  activated_at: number | null;
}

export interface FsWatcherEvent {
  event_id: string;
  directory: CandidateDirectory;
  // file_name_encrypted NO se expone al frontend — el frontend solo
  // muestra el nombre desencriptado on-demand via comando dedicado en
  // un HO futuro si es necesario. Por ahora el evento solo expone
  // metadatos seguros.
  extension: string;
  detected_at: number;
}

export interface FsWatcherStatus {
  runtime_state: FsWatcherRuntimeState;
  directories: FsWatcherDirectory[];
  events_in_current_session: number;
  events_last_24h: number;
}
```

**Decisión arquitectónica:** `file_name_encrypted` (`Vec<u8>` en Rust)
NO se expone en el tipo TypeScript de evento. El frontend solo necesita
metadatos (directorio, extensión, timestamp) para mostrar el contador
y la lista. Si HO-FW-PD requiere mostrar el nombre desencriptado, se
añadirá un comando dedicado `fs_watcher_decrypt_event_name(event_id)`
con auditoría explícita — fuera de scope de HO-017.

**No reabrir** los tipos T-2-001 / T-2-002 / T-2-003 / T-2-004 (cerrados
en AR-2-003 / AR-2-004 / AR-2-005 / AR-2-006).

### 7. `src-tauri/Cargo.toml` — dependencia `notify`

Añadir bajo `[target.'cfg(not(target_os = "android"))'.dependencies]`
(o equivalente) para excluir Android del binding nativo:

```toml
[target.'cfg(not(target_os = "android"))'.dependencies]
notify = "6"
dirs = "5"
```

`dirs` es necesario para resolver `~/Downloads` y `~/Desktop` de forma
cross-platform. Si ya está declarado en otro target, consolidar.

### 8. Verificación final

Ejecutar y reportar:

```bash
cd src-tauri && cargo test
```
- **Target:** ≥ 57 tests pasando (49 actuales tras T-2-004 + 8 nuevos
  de FS Watcher).
- Reportar conteo exacto: `running N tests … test result: ok. M
  passed; K failed; I ignored`.

```bash
npx tsc --noEmit
```
- Salida limpia.

```bash
cd src-tauri && cargo build --target x86_64-pc-windows-msvc
```
- Compilación funcional Windows.

```bash
cd src-tauri && cargo build --target aarch64-linux-android
```
- Compilación stub Android (los siete comandos devuelven
  `Err(FsWatcherError::UnsupportedPlatform)` serializado a String).

Documentar en el handoff de cierre:
- Conteo exacto de tests `passed / failed / ignored`.
- Estado de `npx tsc --noEmit`.
- Estado de los dos `cargo build` por plataforma.
- Líneas finales del archivo `fs_watcher.rs`.
- Cualquier desviación de TS-2-000 con justificación (idealmente cero).
- Confirmación línea-por-línea de los criterios de aprobación de
  TS-2-000 §"Criterios de Aceptación de Este Documento" (los seis,
  aunque el último — aprobación TA — ya está completado en AR-2-002).
- **Ítem nuevo de cierre:** confirmación de que la verificación manual
  Windows demuestra:
  1. Activar `Downloads` desde un comando de prueba → crear archivo
     `.pdf` en Downloads → evento aparece en el buffer.
  2. Crear archivo `.exe` en Downloads → evento NO aparece (lista blanca).
  3. Minimizar la app FlowWeaver → crear archivo `.pdf` en Downloads
     → evento NO aparece al restaurar (D9 absoluto: el watcher se
     detuvo al perder el foco, los eventos durante background no
     se capturan).

---

## Plan de implementación recomendado (orden de menor riesgo)

El orden no es prescriptivo, pero esta secuencia minimiza compilaciones
rotas:

1. **Añadir dependencia `notify` y `dirs`** en `Cargo.toml`. `cargo
   build` debe seguir verde.
2. **Crear `fs_watcher.rs`** con comentario de cabecera, constantes,
   tipos públicos, funciones de persistencia, función `start_watching`
   con stub Android, helpers de filtros, y los 8 tests internos. `cargo
   test` debe pasar añadiendo 8 tests nuevos sin afectar los 49
   actuales (target 57).
3. **Registrar `mod fs_watcher;` en `lib.rs`** en orden alfabético.
4. **Crear `FsWatcherState`** y registrarlo con `.manage(...)`.
5. **Implementar los siete comandos** en `commands.rs`. Registrarlos
   en `invoke_handler!`.
6. **Añadir el hook `WindowEvent::Focused`** en `setup`. `cargo build
   --target x86_64-pc-windows-msvc` debe ser funcional.
7. **Compilar Android** (`cargo build --target aarch64-linux-android`)
   para confirmar que el stub no rompe el build (cualquier error de
   feature flag se diagnostica aquí).
8. **Añadir tipos TypeScript** en `src/types.ts`. `npx tsc --noEmit`
   debe quedar limpio.
9. **Verificación funcional manual** Windows (los 3 escenarios
   declarados en §"Verificación final" punto "Ítem nuevo de cierre").

---

## Restricciones

Reiteración explícita de los constraints no negociables aplicables a
T-2-000:

### D1 — sin `url`/`title` (transversal absoluto)

- Ningún campo persistido en `fs_watcher_config` puede contener
  `url`, `title`, ruta completa de archivo, ni contenido. El schema
  solo tiene `directory`, `active`, `activated_at`, `updated_at`.
- Los eventos en memoria (`FsWatcherEvent`) cifran el nombre del
  archivo (`Vec<u8>`); exponen solo extensión, directorio padre,
  timestamp, UUID. La ruta completa NUNCA se almacena ni se serializa.
- Auditable por test estructural #7 (`test_no_url_or_title_in_event_struct`).

### D9 — foreground-only absoluto

- El watcher SOLO se inicia en `WindowEvent::Focused(true)` y SOLO
  desde el hook registrado en `setup`. Cualquier path alternativo
  (incluyendo invocación desde comando Tauri sin foco confirmado)
  está prohibido.
- En `Focused(false)`: drop del handle (RAII detiene `notify`) +
  purga del buffer en memoria.
- No existe modo background bajo ninguna circunstancia. Esta
  restricción es permanente en Fase 2 (TS-2-000 §2). Cualquier
  cambio requiere CR formal que modifique D9.
- Auditable por inspección de código en AR-2-007: grep de
  `start_watching(` debe devolver máximo dos sitios (la definición
  en `fs_watcher.rs` y la invocación única desde el hook en
  `lib.rs`).

### D14 — visibilidad en Privacy Dashboard (transitiva)

- Los siete comandos Tauri son el contrato completo que HO-FW-PD
  consumirá para añadir el subcomponente `FsWatcherSection.tsx`.
  Deben ser estables y no requerir modificación posterior.
- TS-2-000 §3 "Visibilidad en el Privacy Dashboard" declara cinco
  elementos visuales (lista de directorios, estado en tiempo real,
  contadores, botones de control, texto explicativo). HO-017 entrega
  los siete comandos que materializan los cinco elementos; HO-FW-PD
  los compone en el JSX.

### D19 — Windows + Android primario

- Windows: implementación funcional vía `notify` →
  `ReadDirectoryChangesW`. Verificación manual obligatoria antes de
  cierre (los 3 escenarios declarados arriba).
- Android: stub con `#[cfg(target_os = "android")]` que devuelve
  `FsWatcherError::UnsupportedPlatform` en cada comando. El frontend
  detecta el estado `Unsupported` y oculta la sección FS Watcher en
  el dashboard (HO-FW-PD se encarga). Decisión justificada: Android
  no expone FS events con la misma semántica (Storage Access Framework
  + Scoped Storage hacen el modelo de "directorio observado" inviable
  sin permisos especiales que romperían el modelo de privacidad de
  TS-2-000); el track móvil cubre observación por Share Intent (ya
  implementado en Fase 0c).

### R12 — distinción transitiva

- `fs_watcher.rs` ≠ `pattern_detector.rs` ≠ `episode_detector.rs`.
  Comentario de cabecera obligatorio con tabla comparativa de tres
  columnas y siete dimensiones (sección 1.a).
- **Forbidden imports en `fs_watcher.rs`** (auditable por grep en
  AR-2-007):
  - `use crate::pattern_detector` — prohibido.
  - `use crate::episode_detector` — prohibido.
  - Llamadas a `detect_patterns(`, `score_patterns(`,
    `evaluate_transition(`, `build_episode(` desde dentro del módulo
    — prohibidas.
- Los eventos del FS Watcher NO alimentan al Pattern Detector. La
  cadena `FsWatcher → SQLCipher.resources → Pattern Detector` NO
  existe en HO-017 ni se propondrá en futuros HO sin CR formal
  (TS-2-000 §4 "FS Watcher NO genera los patrones que detecta el
  Pattern Detector").

### Restricciones específicas T-2-000

- **No persistir eventos entre sesiones** (TS-2-000 §2). El buffer
  vive en `FsWatcherState.event_buffer` (memoria) y se purga en
  `Focused(false)` y al cerrar la app. La tabla
  `fs_watcher_config` solo contiene configuración (4 columnas).
- **No leer contenido de archivos** (TS-2-000 §1). Solo metadatos:
  nombre (cifrado), directorio padre (claro), extensión (claro),
  timestamp.
- **No observar fuera de los dos directorios candidatos**. El
  filtro `is_directory_allowed` blinda contra escalada futura.
- **No añadir sección FS Watcher al `PrivacyDashboard.tsx` en este
  HO.** TS-2-004 §"Decisiones del Technical Architect §4" lo
  declara out-of-scope; HO-FW-PD se encargará tras AR-2-007.
- **No introducir telemetría** ni envío de eventos a servicios
  externos (D8 transitivo + invariante de privacidad de FlowWeaver).

---

## Criterios de cierre

El HO de cierre (a Technical Architect) debe reportar cada uno con
referencia verificable:

1. `src-tauri/src/fs_watcher.rs` existe con comentario de cabecera
   completo (D1, D9, R12 declarados; tabla comparativa de tres
   columnas y siete dimensiones reproducida textualmente).
2. `mod fs_watcher;` registrado en `lib.rs` en orden alfabético entre
   `episode_detector` y `grouper`.
3. Lista blanca exacta de 17 extensiones únicas (auditable por
   `test_extension_whitelist_exact_set`).
4. Filtro de extensiones rechaza ejecutables, sistema, código,
   credenciales (auditable por `test_extension_filter_rejects_executables`).
5. Filtro de directorios rechaza paths prohibidos (auditable por
   `test_directory_filter_rejects_forbidden`).
6. Tabla `fs_watcher_config` con schema literal de 4 columnas;
   inicialización idempotente con dos filas inactivas; eventos NO
   persistidos (auditable por `test_no_events_persisted_across_sessions`).
7. `start_watching` solo se invoca desde el hook de
   `WindowEvent::Focused(true)`; en `Focused(false)` el handle se
   drop y el buffer se purga (auditable por inspección de `lib.rs`).
8. Stub Android: `start_watching` y los siete comandos devuelven
   `FsWatcherError::UnsupportedPlatform` bajo
   `#[cfg(target_os = "android")]` (verificable con `cargo build
   --target aarch64-linux-android`).
9. Siete comandos Tauri implementados con firmas exactas y
   registrados en `invoke_handler!`.
10. `FsWatcherState` registrado vía `.manage(...)` en `lib.rs::run()`.
11. Cuatro tipos TypeScript nuevos en `src/types.ts` con shape
    exacto (`CandidateDirectory`, `FsWatcherRuntimeState`,
    `FsWatcherDirectory`, `FsWatcherEvent`, `FsWatcherStatus`).
12. Test estructural D1 pasa (`test_no_url_or_title_in_event_struct`).
13. Test estructural R12 pasa
    (`test_no_pattern_detector_or_episode_detector_imports`).
14. `cargo test` reporta ≥ 57 tests / 0 failed / 0 ignored.
15. `npx tsc --noEmit` limpio.
16. `cargo build --target x86_64-pc-windows-msvc` verde.
17. `cargo build --target aarch64-linux-android` verde.
18. **Verificación funcional manual Windows:** los 3 escenarios
    (activación + evento permitido / extensión rechazada / background
    no captura) demostrados con captura textual del log o video.

---

## Cierre

Tras completar la implementación y verificar los 18 criterios, el
Desktop Tauri Shell Specialist emite el **HO de cierre de T-2-000
implementación** (`HO-XXX-phase-2-ts-2-000-impl-close.md`, donde XXX
es el siguiente número disponible al momento de emisión) al Technical
Architect solicitando **AR-2-007** (revisión arquitectónica
post-implementación de FS Watcher). Sigue el patrón de HO-014.

AR-2-007 verificará:
1. Los 18 criterios de cierre línea por línea con referencias a
   archivos / funciones / tests concretos.
2. La validez del hook `Focused` como única vía de inicio del watcher
   (D9 estricto).
3. Coherencia D1 / D9 / D14 / D19 / R12 en el código entregado.
4. Ausencia de imports prohibidos (`pattern_detector`,
   `episode_detector`).
5. Verificación funcional manual reportada por el implementador.

Si AR-2-007 aprueba sin correcciones, **T-2-000 queda cerrado a nivel
de implementación**. El Orchestrator emite **HO-FW-PD** al Desktop
Tauri Shell Specialist para añadir el subcomponente
`FsWatcherSection.tsx` al `PrivacyDashboard.tsx` (TS-2-004 §"Decisiones
del Technical Architect §4" autoriza esta integración sin reabrir
TS-2-004). Tras HO-FW-PD aprobado, **D14 queda completamente
satisfecho con FS Watcher integrado** y Fase 2 cierra formalmente.

Si durante la implementación se detecta:
- Ambigüedad real en TS-2-000 → escalar al Orchestrator antes de
  proceder con interpretación.
- Necesidad de modificar contrato cerrado (TS-2-001 / TS-2-002 /
  TS-2-003 / TS-2-004) → escalar al Orchestrator antes de proceder.
- Necesidad de leer eventos del FS Watcher desde Pattern Detector
  (violación R12) → escalar al Orchestrator y NO proceder.
- Necesidad de monitoring en background "para mejorar la UX" →
  escalar al Orchestrator y NO proceder (D9 absoluto en Fase 2).
- Necesidad de añadir directorios fuera de los dos candidatos →
  escalar al Orchestrator (requiere CR formal de TS-2-000).
- Imposibilidad técnica de implementar el hook `Focused` con la
  semántica RAII descrita → escalar al Orchestrator antes de
  diseñar alternativa.

La implementación queda autorizada únicamente con TS-2-000 firmada
y este HO emitido. Cualquier desviación silenciosa será revertida
en AR-2-007.

---

## Firma

submitted_by: Orchestrator (borrador generado por ejecutor; pendiente
de revisión y firma efectiva)
submission_date: 2026-04-27
notes: Borrador construido por analogía estructural con HO-013
(T-2-003 impl kickoff) y HO-016 (T-2-004 impl kickoff). Los 18
criterios de cierre se derivan de TS-2-000 §"Criterios de Aceptación
de Este Documento" (6 ítems) extendidos con verificaciones
estructurales (D1, R12), de plataforma (Windows funcional, Android
stub), y funcionales (3 escenarios manuales Windows). La decisión
de diferir la sección "FS Watcher" del Privacy Dashboard a HO-FW-PD
se justifica en TS-2-004 §"Decisiones del Technical Architect §4"
(out-of-scope explícito de T-2-004). La elección de `notify v6` como
crate cross-platform se basa en su soporte simultáneo de
ReadDirectoryChangesW (Windows), FSEvents (macOS) e inotify (Linux);
Android se excluye por arquitectura (Scoped Storage incompatible con
el modelo "directorio observado" sin permisos especiales que
violarían TS-2-000). La numeración HO-017 corresponde a este
documento por orden cronológico de emisión; la referencia forward
en HO-016 §"Cierre" línea 498 (`HO-017-phase-2-ts-2-004-impl-close.md`)
queda superada — el futuro cierre de T-2-004 tomará el siguiente
número disponible al emitirse.

### Visados completados — autorización formal de implementación

Los cinco visados se ejecutaron el 2026-04-27 sobre la versión vigente
de este HO, contra TS-2-000 (firmada por Technical Architect en AR-2-002
el 2026-04-24, sin correcciones) y contra el estado real del código en
`src-tauri/src/lib.rs:1-90`.

#### 1. Technical Architect — revisión arquitectónica del diseño ✅

**Visado por:** Technical Architect
**Fecha:** 2026-04-27
**Resultado:** APROBADO sin correcciones.

**Hallazgos:**

- **Foreground-only enforcement (D9):** la semántica RAII del
  `FsWatcherHandle` (drop automático del watcher de `notify` cuando el
  hook de `WindowEvent::Focused(false)` desreferencia el `Option` en
  `FsWatcherState.handle`) es la implementación arquitectónicamente
  más sólida posible para D9. No deja paths alternativos donde el
  watcher pueda persistir tras pérdida de foco, y AR-2-007 lo podrá
  auditar por inspección textual de `lib.rs` (grep de `start_watching(`
  con dos sitios esperados: la definición y la única invocación).
- **Separación de estado (`FsWatcherState` ≠ `DbState`):** correcta.
  Permite registrar el handle del watcher con ciclo de vida propio sin
  contaminar el lock del `Mutex<Db>` que ya custodia SQLCipher. La
  introducción de un `State` adicional es coherente con el patrón
  existente de Tauri.
- **Selección de crate (`notify v6`):** correcta para Windows
  (ReadDirectoryChangesW), macOS (FSEvents) e iOS/Linux (inotify);
  Android queda fuera por arquitectura (Scoped Storage incompatible
  con el modelo "directorio observado" sin permisos especiales que
  violarían TS-2-000). Justificación reproducida en §"Firma · notes"
  de este HO.
- **Stub Android (`#[cfg(target_os = "android")]`):** correcto. El
  patrón de devolver `FsWatcherError::UnsupportedPlatform` desde cada
  comando es coherente con D19 (Android primario en track móvil pero
  con FS Watcher fuera de scope para la plataforma) y con el patrón
  ya establecido en `drive_relay` (`lib.rs:15-16` usa
  `#[cfg(not(target_os = "android"))]` para excluir background loops
  en Android).
- **Encapsulación de migración (`fs_watcher::ensure_schema`):**
  consistente con T-2-003 / T-2-004 (módulo dueño del schema). No es
  necesario tocar `Db::migrate()` en `storage.rs`.
- **Anclas de código verificadas contra rama actual:** `mod
  episode_detector;` en `lib.rs:4`, `mod grouper;` en `lib.rs:5`,
  `commands::clear_all_resources` en `lib.rs:75`,
  `commands::get_trust_state` en `lib.rs:76`, `invoke_handler!` en
  `lib.rs:63-87`. Todas coinciden con las referencias del HO.

**Sin correcciones.** Diseño autorizado para implementación.

#### 2. Privacy Guardian — revisión D1 ✅

**Visado por:** Privacy Guardian
**Fecha:** 2026-04-27
**Resultado:** APROBADO sin correcciones.

**Hallazgos:**

- **Cifrado de nombre de archivo:** `FsWatcherEvent.file_name_encrypted:
  Vec<u8>` (AES-GCM vía `crypto.rs`) — correcto. Nunca un `String`
  legible. La nota arquitectónica del HO (sección 6) excluye además el
  campo del shape TypeScript de `FsWatcherEvent`, lo que cierra la
  superficie en frontend: ningún path de UI puede leer el nombre sin
  un comando dedicado de desencriptado, que queda fuera de scope de
  HO-017. Coherente con D1 estricto.
- **Ausencia de ruta completa:** TS-2-000 §1 fila "Ruta completa: solo
  el directorio padre". El HO lo materializa con
  `FsWatcherDirectory.absolute_path` resuelto desde
  `dirs::download_dir()` / `dirs::desktop_dir()` (directorio padre,
  nunca archivo individual) y reitera la prohibición en §"Restricciones
  D1 absoluta" del bloque de comandos. La ausencia del campo `full_path`
  en cualquier struct público es auditable por el test estructural #7.
- **Ausencia de `url`/`title`:** la lista de tokens prohibidos del test
  estructural #7 (`url:`, `title:`, `link:`, `href:`, `page_title:`,
  `bookmark_url:`, `full_path:`, `content:`, `body:`) es exhaustiva y
  cubre vectores de filtración tanto del modelo web (url/title) como
  del modelo FS (full_path/content). Ningún campo de los structs
  públicos definidos en HO-017 §1.c viola esta lista.
- **Sin lectura de contenido:** TS-2-000 §1 "Contenido del archivo:
  Nunca". El HO lo refuerza explícitamente en §"Restricciones · D1" y
  no hay ningún método público ni privado que abra el archivo. `notify`
  entrega solo metadatos del evento (path, kind), nunca el contenido.
- **Persistencia mínima de configuración:** `fs_watcher_config` con
  4 columnas (`directory`, `active`, `activated_at`, `updated_at`) —
  ninguna toca contenido ni nombre. Auditable por
  `test_no_events_persisted_across_sessions` con
  `PRAGMA table_info(fs_watcher_config)`.
- **Privacy Dashboard:** la decisión de diferir la sección "FS Watcher"
  a HO-FW-PD posterior no degrada D1 — TS-2-004 ya cerró el dashboard
  base sin la sección, y los siete comandos del HO-017 son el contrato
  estable que HO-FW-PD consumirá. La transparencia al usuario (texto
  explicativo de TS-2-000 §3) se materializará en HO-FW-PD con D14
  formalmente satisfecho al final.

**Sin correcciones.** D1 cubierto en todos los niveles (struct, schema,
tipos TypeScript, tests estructurales).

#### 3. Functional Analyst — coherencia con TS-2-000 firmada ✅

**Visado por:** Functional Analyst
**Fecha:** 2026-04-27
**Resultado:** APROBADO sin correcciones.

**Mapeo TS-2-000 → HO-017 (cobertura completa):**

| TS-2-000 § | Elemento contractual | HO-017 § entregable |
|---|---|---|
| §1 "Directorios observables" | `~/Downloads` + `~/Desktop`, ninguno por defecto | §1.b `CandidateDirectory` enum + §1.d `ensure_schema` con dos filas inactivas |
| §1 "Extensiones en scope" | 18 menciones / 17 únicas en 5 grupos | §1.b `ALLOWED_EXTENSIONS` con 17 entradas + test #1 `test_extension_whitelist_exact_set` |
| §1 "Extensiones fuera de scope" | Ejecutables, sistema, código, credenciales | Test #2 `test_extension_filter_rejects_executables` cubre las cuatro categorías literalmente |
| §1 "Qué registra de cada archivo" | Nombre cifrado / dir padre claro / ext claro / timestamp / sin contenido / sin tamaño / sin hash | §1.c `FsWatcherEvent` con shape exacto |
| §2 "Duración de la observación" | Solo en primer plano | §2.c hook `WindowEvent::Focused` + §1.e `start_watching` solo desde el hook |
| §2 "Qué ocurre al suspender" | Eventos en cola descartados, sin estado entre sesiones | §2.c purga del `event_buffer` en `Focused(false)` + test #6 `test_no_events_persisted_across_sessions` |
| §2 "Sesión de observación" | Período continuo en foco con ≥1 directorio activo | §1.c `FsWatcherRuntimeState::Active` requiere ambas condiciones |
| §3 "Consentimiento" | Activación por directorio + confirmación explícita + sin defecto | Comando `fs_watcher_activate_directory(confirmed: bool)` rechaza con `confirmation required` si `false`; `ensure_schema` inicializa ambas filas inactivas |
| §3 "Revocación" | Desactivar inmediato + purga por directorio + reset completo | Comandos `fs_watcher_deactivate_directory` + `fs_watcher_clear_directory_history` |
| §3 "Visibilidad en Privacy Dashboard" | Lista, estado tiempo real, contadores sesión / 24h, botones | Siete comandos cubren los cinco elementos visuales; integración a JSX se difiere a HO-FW-PD (justificado en TS-2-004 §"Decisiones del TA §4") |
| §4 R12 "Separación FS Watcher / Pattern Detector" | Comentario de cabecera obligatorio + separación de módulos | §1.a tabla comparativa de tres columnas y siete dimensiones + test #8 `test_no_pattern_detector_or_episode_detector_imports` |
| §"Riesgos De Interpretación" | 5 riesgos | Cubiertos en §"Restricciones" del HO + tests estructurales (ver visado QA) |

**Hallazgos:**

- **Ningún criterio de TS-2-000 omitido.** Cada bullet de §1, §2, §3
  y §4 tiene entregable verificable en el HO.
- **Ningún criterio nuevo introducido sin justificación.** Las
  extensiones del HO sobre TS-2-000 (test estructural D1, test
  estructural R12, verificación funcional manual de 3 escenarios
  Windows, stub Android explícito) son refinamientos operativos
  derivados de D1, R12 y D19 — no inventan scope. La diferencia entre
  "18 menciones" (TS-2-000 §1) y "17 únicas" (HO-017 §1.b nota) está
  documentada explícitamente y resuelta por test #1.
- **Numeración HO-017:** la resolución cronológica del conflicto con
  la referencia forward de HO-016 §"Cierre" línea 498 es correcta —
  los HO se numeran por orden de emisión, no por reserva.
- **Diferimiento de la sección FS Watcher del Privacy Dashboard a
  HO-FW-PD:** funcionalmente trazable a TS-2-004 §"Decisiones del
  Technical Architect §4" (out-of-scope de T-2-004 explícito). La
  cadena `HO-017 → AR-2-007 → HO-FW-PD → D14 satisfecho` está
  declarada en §"Cierre" del HO sin ambigüedad.

**Sin correcciones.** El HO es coherente al pie de la letra con
TS-2-000.

#### 4. QA Auditor — plan de tests vs riesgos TS-2-000 ✅

**Visado por:** QA Auditor
**Fecha:** 2026-04-27
**Resultado:** APROBADO sin correcciones.

**Mapeo riesgos TS-2-000 §"Riesgos De Interpretación" → tests del HO-017:**

| Riesgo TS-2-000 | Test(s) HO-017 que lo contienen | Cobertura |
|---|---|---|
| 1. Ampliar scope de directorios | Test #3 `test_directory_filter_rejects_forbidden` (paths sistema/red/ocultos/otras apps) + `is_directory_allowed` defensivo + `CandidateDirectory` enum cerrado de dos variantes | Total — el enum cerrado bloquea expansión silenciosa; el filtro defensivo bloquea escalada futura aunque alguien añada variantes |
| 2. Background monitoring "opcional" | Hook `WindowEvent::Focused` único punto de entrada (auditable por inspección de `lib.rs`) + RAII drop del handle en `Focused(false)` + verificación funcional manual escenario 3 (minimizar → crear `.pdf` → evento NO aparece) | Total — el riesgo se elimina por arquitectura (sin paths alternativos) y se verifica por escenario manual |
| 3. FS Watcher "genera patrones" (R12) | Test #8 `test_no_pattern_detector_or_episode_detector_imports` (estructural: grep de `use crate::pattern_detector` y `use crate::episode_detector`) + comentario de cabecera con tabla comparativa de tres columnas + AR-2-007 verifica por inspección | Total — auditable por test automatizado y por inspección humana |
| 4. Observar extensiones de código o credenciales | Test #1 `test_extension_whitelist_exact_set` (lista hardcoded en el test detecta drift) + Test #2 `test_extension_filter_rejects_executables` (rechaza explícitamente ejecutables, código, credenciales, sistema) | Total — doble blindaje: positivo (whitelist exacta) y negativo (rechazo explícito de cuatro categorías) |
| 5. Leer el contenido del archivo (D1) | Test #7 `test_no_url_or_title_in_event_struct` (lista de tokens prohibidos incluye `content:`, `body:`) + ausencia estructural de cualquier método que abra `File`/`fs::read` en el módulo + AR-2-007 verifica por grep | Total — el test estructural cubre el shape; la inspección de AR-2-007 cubre el comportamiento |

**Hallazgos adicionales:**

- **Suite final `≥ 57 tests`:** 49 tests existentes (post T-2-004) + 8
  tests nuevos. Conteo verificable por `cargo test` al cierre.
- **Verificación funcional manual Windows (3 escenarios):** cubre el
  ciclo end-to-end (activación + permitido / rechazado / background
  no captura) que los tests unitarios no pueden cubrir por sí solos
  (requieren `notify` en runtime). Adecuado.
- **Verificación cross-platform builds:** `cargo build --target
  x86_64-pc-windows-msvc` (funcional) y `cargo build --target
  aarch64-linux-android` (stub) son ambos requeridos al cierre. Esto
  detecta cualquier problema de feature gating del crate `notify` que
  los tests unitarios no detectarían.
- **Test estructural única-`#[cfg(test)]`:** la condición de "un solo
  bloque `#[cfg(test)]`" para que los tests #7 y #8 puedan hacer split
  textual está declarada explícitamente. Coherente con la convención
  ya establecida en `state_machine.rs` y `pattern_blocks.rs`.

**Sin correcciones.** Los 8 tests cubren los 5 riesgos al 100% con
redundancia defensiva donde aplica.

#### 5. Orchestrator — validación final + cambio de status ✅

**Visado por:** Orchestrator
**Fecha:** 2026-04-27
**Resultado:** APROBADO. Status cambiado a `ready_for_execution`.

**Verificaciones finales:**

- **Visados 1-4 completos:** Technical Architect, Privacy Guardian,
  Functional Analyst y QA Auditor han firmado sin correcciones.
- **Numeración HO-017 confirmada:** este documento es HO-017 por orden
  cronológico de emisión. El cierre futuro de T-2-004 tomará el
  siguiente número disponible (HO-018 o ulterior). La referencia
  forward en HO-016 §"Cierre" línea 498 queda superada documentalmente
  por la nota introductoria del HO-017 (líneas 14-18 de este HO) sin
  necesidad de erratum formal sobre HO-016.
- **Erratum operativo en TS-2-000 §"Criterios De Aceptación" línea
  216:** la línea aún figuraba como `[ ] PENDIENTE` aunque AR-2-002
  aprobó TS-2-000 el 2026-04-24 sin correcciones. **Corregida en este
  acto** a `[x]` con referencia explícita a AR-2-002 (la cabecera
  `status:` línea 9 ya reflejaba el estado correcto desde el día de
  la aprobación, así que no hay impacto en autorizaciones previas).
  La cláusula de escalación de HO-017 §"Inputs · Spec autoritativa"
  líneas 82-83 queda **superada** por esta corrección y no requiere
  acción del implementador.
- **Pre-requisitos de implementación satisfechos:** TS-2-000 firmada
  (AR-2-002), todos los contratos de Fase 2 anteriores cerrados
  (AR-2-003 / AR-2-004 / AR-2-005 / AR-2-006), y este HO con visados
  1-5 completos. Ningún bloqueo activo.
- **Cambio de `status`:** `draft_for_orchestrator_review` →
  `ready_for_execution` (cabecera línea 6).

**Autorización:** el Desktop Tauri Shell Specialist queda formalmente
autorizado a comenzar la implementación de `src-tauri/src/fs_watcher.rs`
siguiendo este HO al pie de la letra. Cualquier ambigüedad detectada
durante la implementación se escala al Orchestrator antes de proceder
con interpretación.

Tras completar los 18 criterios de cierre (sección §"Criterios de
cierre"), el implementador emite el HO de cierre al Technical Architect
solicitando AR-2-007 (revisión arquitectónica post-implementación). El
patrón a seguir es HO-014 (cierre de T-2-003 impl).
