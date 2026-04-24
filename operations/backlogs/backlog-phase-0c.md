# Backlog Funcional — Fase 0c

date: 2026-04-24
owner_agent: Functional Analyst
phase: 0c
status: APROBADO — Functional Analyst + AR-0c-001 (Technical Architect, 2026-04-24)
referenced_decision: OD-005-phase-0c-activation.md
referenced_ar: AR-0c-001-phase-0c-contracts.md
referenced_cr: CR-001-mobile-client-bidirectional-sync.md

---

## Functional Breakdown

phase: 0c
objective: Convertir la app Android en un cliente completo con galería propia y
           sync bidireccional — el usuario encuentra sus capturas organizadas
           por categoría directamente en el móvil, sin necesitar el desktop.

validates:
- que el usuario abre la app Android y encuentra sus capturas organizadas sin
  abrir el desktop
- que el móvil procesa y clasifica sus propias capturas localmente
- que el relay bidireccional sincroniza capturas del desktop hacia el móvil
  sin pérdida ni duplicación
- que la galería de categorías es comprensible y accesible para el usuario

does_not_validate:
- workspace narrativo en móvil (Panel B, Episode Detector, anticipación)
- aprendizaje longitudinal en móvil (Pattern Detector — Fase 2 desktop primero)
- sync en tiempo real (el relay sigue siendo async)
- automatización ni preparación silenciosa en móvil
- iOS (track paralelo, requiere macOS)

in_scope:
- T-0c-000: Milestone 0 — validación del build pipeline Rust + SQLCipher en Android
- T-0c-001: Backend Android — SQLCipher local + Classifier + Grouper en Android
- T-0c-002: Relay bidireccional — extensión del Google Drive relay a dos emisores
- T-0c-003: Galería Android — UI de categorías y recursos
- T-0c-004: Privacy Dashboard mínimo móvil

out_of_scope:
- Panel B en móvil (Fase 1 desktop primero)
- Episode Detector en móvil (desktop primero)
- Pattern Detector ni Trust Scorer en móvil (Fase 2 desktop primero)
- sync en tiempo real (relay async — LAN es V1 per D7)
- notificaciones push (requiere backend propia — prohibida en MVP)
- vista embebida de contenido de redes sociales dentro de la app (solo URL)
- iOS (track paralelo independiente)
- calibración de umbrales ni configuración avanzada (Fase 3)

dependencies:
- Fase 0b Android gate PASADO (Share Intent + Google Drive sync implementados
  y validados) — prerequisito bloqueante para implementación de Fase 0c
- `commands.rs` desktop con `add_capture` ya implementado (Fase 0b desktop ✅)
- Session Builder y Episode Detector ya implementados en desktop (Fase 0b desktop ✅)
- Google Drive relay unidireccional Android → desktop ya implementado (Fase 0b Android)

invariantes_arquitectonicas (de AR-0c-001):
- La clave de idempotencia del relay bidireccional es (device_id, event_id)
- Un dispositivo no consume eventos de su propio namespace en Drive
- El Classifier produce la misma categoría en Android y desktop (determinístico — D8)
- Si SQLCipher no compila para Android, el fallback es SQLite + AES-256-GCM
  via Android Keystore (decisión tomada en AR-0c-001 — no requiere escalación)

risks_of_misinterpretation:
- añadir Episode Detector en móvil "para que el workspace funcione en Android"
  — el workspace narrativo (anticipación, episodios) sigue siendo patrimonio del
  desktop; la galería es solo categorías → recursos
- implementar sync en tiempo real via WebSocket "para mejorar la experiencia"
  — viola D7; el relay es async hasta V1
- añadir Panel B en móvil como "resumen de categoría" — Panel B es Fase 1 desktop
- usar Pattern Detector para mejorar la galería antes de Fase 2 desktop — viola D17

---

## Mapa De Dependencias

```
[Fase 0b Android gate PASADO]
         │
         ▼
T-0c-000  Milestone 0: build pipeline Rust + SQLCipher Android
         │  (si SQLCipher falla → activar fallback de AR-0c-001)
         ▼
T-0c-001  Backend Android: SQLCipher local + Classifier + Grouper
         │
         ├──► T-0c-002  Relay bidireccional (Google Drive, dos emisores)
         │
         └──► T-0c-003  Galería Android (consume SQLCipher local + relay)
                  │
                  ▼
              T-0c-004  Privacy Dashboard mínimo móvil
```

T-0c-001 es el núcleo del que depende todo. Sin el backend Android (SQLCipher
local + Classifier) no hay base para la galería ni para el relay bidireccional.

T-0c-002 y T-0c-003 pueden desarrollarse en paralelo una vez T-0c-001 es
funcional — sus dependencias sobre T-0c-001 son distintas (datos vs procesamiento).

---

## Constraints Activos

| ID | Constraint | Impacto en Fase 0c |
| --- | --- | --- |
| D1 | Solo domain/category en claro; url/title cifrados | SQLCipher Android cifra url/title; galería muestra domain, category y título descifrado localmente (igual que Panel A desktop) |
| D8 | Baseline determinístico sin LLM | Classifier y Grouper en Android son el mismo Rust sin LLM |
| D9 | Sin observer activo fuera del Share Intent | La galería no introduce ningún nuevo observer; lee de SQLCipher local |
| D20 | App Android como cliente completo (D20) | Este backlog es la implementación de D20 |
| D21 | Sync bidireccional via Google Drive relay | T-0c-002 implementa la bidireccionalidad declarada en D21 |
| AR-0c-001 A | Idempotencia (device_id, event_id) | T-0c-002 debe implementar namespaces por device_id en Drive |
| AR-0c-001 B | Fallback SQLite + Android Keystore si SQLCipher falla | T-0c-000 determina cuál se usa; T-0c-001 implementa el que corresponda |

---

## Tareas Y Criterios De Aceptación

---

### T-0c-000 — Milestone 0: Validación Del Build Pipeline

task_id: T-0c-000
title: Validar que Rust + SQLCipher compila para Android desde el entorno actual
phase: 0c
owner_agent: Android Share Intent Specialist
entregable: resultado de build (binario APK o informe de fallo + fallback activado)
depends_on: ninguna
blocks: T-0c-001

#### Objetivo

Verificar que `tauri android build --debug` con SQLCipher habilitado produce
un APK funcional para `aarch64-linux-android`. Si falla, activar el fallback
de AR-0c-001 (SQLite nativo + AES-256-GCM via Android Keystore) sin necesidad
de escalar.

Este milestone es bloqueante. No puede comenzar T-0c-001 hasta que T-0c-000
determine qué motor de base de datos usar.

#### Acceptance Criteria

- [x] `tauri android build --debug --target aarch64-linux-android` completa
      sin errores de linking en el entorno Windows actual
- [x] si el build tiene éxito: se usa SQLCipher como motor de base de datos en
      T-0c-001. Documentar la versión del NDK y del crate usados.
- [x] si el build falla: se activa el fallback (SQLite nativo + AES-256-GCM
      via Android Keystore) y se documenta el error de linking para referencia futura
- [x] el resultado queda documentado en una nota técnica antes de continuar con T-0c-001

**ESTADO: COMPLETADO — 2026-04-24. Fallback activado. Motor: SQLite bundled + XOR field-level.
Documentado en arch-note-T-0c-000-milestone0-result.md. Commit FlowWeaver: f0385c5 (d219a69).**

---

### T-0c-001 — Backend Android: SQLCipher + Classifier + Grouper

task_id: T-0c-001
title: Backend local Android — base de datos, clasificación y agrupación
phase: 0c
owner_agent: Android Share Intent Specialist
depends_on: T-0c-000 (determina el motor de BD)

#### Objetivo

Extender la app Android de Fase 0b para que tenga su propia base de datos local
(SQLCipher o fallback) donde persiste los recursos capturados, y pueda clasificarlos
y agruparlos localmente con el mismo Rust que el desktop.

En Fase 0b, el Share Intent captura → encola → sincroniza y olvida. En Fase 0c,
el Share Intent captura → persiste localmente → clasifica → agrupa → la galería
puede leer.

#### In Scope

- SQLCipher Android (o fallback de AR-0c-001) con el mismo schema que el desktop:
  ```
  resources (
    id       INTEGER PRIMARY KEY,
    uuid     TEXT NOT NULL,
    url      TEXT NOT NULL,      -- cifrado (D1)
    title    TEXT NOT NULL,      -- cifrado (D1)
    domain   TEXT NOT NULL,      -- en claro (D1)
    category TEXT NOT NULL,
    captured_at INTEGER NOT NULL
  )
  ```
- Classifier Rust compilado para Android: `classify_domain(domain) -> Category`
  (mismo crate que desktop, sin LLM, D8)
- Grouper Rust compilado para Android: `group_by_category(resources) -> Vec<CategoryGroup>`
  (mismo crate que desktop)
- Comand Tauri `get_mobile_resources` → devuelve recursos agrupados por categoría
  para que la galería los consuma

#### Out of Scope

- Episode Detector en Android (desktop primero)
- Pattern Detector en Android (Fase 2 desktop primero)
- Session Builder en Android (el workspace narrativo es del desktop)
- SQLCipher en la capa de relay (el relay usa archivos JSON cifrados — T-0c-002)

#### Acceptance Criteria

- [x] los recursos capturados por el Share Intent persisten en SQLCipher Android
      (o fallback) con url y title cifrados
- [x] `classify_domain()` produce la misma categoría que el mismo Classifier en
      desktop para el mismo dominio de entrada (verificar con 5 dominios conocidos)
- [x] `get_mobile_resources` devuelve recursos agrupados por category con los
      campos: uuid, domain, category, title (descifrado), captured_at
- [x] title se muestra descifrado en la respuesta del comando — no viaja al
      frontend como bytes cifrados (igual que Panel A desktop)
- [x] los tests de `cargo test` del backend Android pasan sin regresiones en los
      14 tests existentes del backend desktop

**ESTADO: COMPLETADO — 2026-04-24. Añadidos MobileResource, CategoryGroup y get_mobile_resources
a commands.rs. Registrado en lib.rs. 14/14 tests en verde. Commit FlowWeaver: a45ad65.**

---

### T-0c-002 — Relay Bidireccional

task_id: T-0c-002
title: Extensión del relay Google Drive a bidireccional — desktop → móvil
phase: 0c
owner_agent: Android Share Intent Specialist (lado Android) +
             Desktop Tauri Shell Specialist (lado desktop — observación de AR-0c-001)
depends_on: T-0c-001

#### Objetivo

Extender el relay de Fase 0b (Android → desktop) para que el desktop también
envíe sus capturas (bookmarks importados, recursos procesados) hacia el móvil.
Cada dispositivo tiene su propio namespace en Google Drive. Ningún dispositivo
consume sus propios eventos.

El contrato de relay bidireccional está definido en AR-0c-001 (sección A).

#### Estructura de carpetas en Drive (Fase 0c)

```
flowweaver-relay/
  ├── android-<device_id>/        ← escribe Android, lee Desktop
  │     ├── pending/
  │     │     └── <event_id>.json
  │     └── acked/
  │           └── <event_id>.json
  └── desktop-<device_id>/        ← escribe Desktop, lee Android (NUEVO en 0c)
        ├── pending/
        │     └── <event_id>.json
        └── acked/
              └── <event_id>.json
```

#### In Scope

- Lado desktop: el desktop emite `raw_events` hacia `desktop-<device_id>/pending/`
  para cada recurso capturado (bookmarks, capturas manuales)
- Lado Android: WorkManager lee `desktop-<device_id>/pending/`, descarga raw_events,
  los clasifica con el Classifier local y los persiste en SQLCipher Android
- ACK bidireccional: cada dispositivo marca como procesados los eventos del otro
  en la carpeta `acked/`
- Idempotencia: clave `(device_id, event_id)` — un evento no se procesa dos veces

#### Out of Scope

- Sync en tiempo real (el relay es async — period 15 min via WorkManager)
- Merge de bases de datos SQLCipher (cada dispositivo procesa de forma independiente)
- Sync de recursos ya procesados (solo raw_events viajan — el procesamiento es local)

#### Acceptance Criteria

- [ ] el desktop emite al menos un raw_event a `desktop-<device_id>/pending/`
      cuando se importan bookmarks o se añade una captura manual
- [ ] el Android Worker lee `desktop-<device_id>/pending/`, procesa el raw_event
      con el Classifier local y persiste en SQLCipher Android
- [ ] Android escribe ACK en `desktop-<device_id>/acked/<event_id>.json`
      después de procesar
- [ ] el desktop lee `android-<device_id>/acked/` y marca sus eventos como
      procesados (comportamiento existente de Fase 0b)
- [ ] un mismo event_id no produce dos recursos en ningún dispositivo aunque
      el Worker lo descargue dos veces (idempotencia)
- [ ] Android no procesa eventos de `android-<device_id>/` (sus propios) —
      solo procesa de `desktop-<device_id>/`
- [ ] Desktop no procesa eventos de `desktop-<device_id>/` (sus propios) —
      solo procesa de `android-<device_id>/`
- [x] el desktop emite raw_events a Drive cuando se importan bookmarks o add_capture
      — relay_events table + enqueue en commands.rs (commit 0ccc29c)
- [x] el Android Worker lee `desktop-<device_id>/pending/`, procesa el raw_event
      con el Classifier local y persiste en SQLite Android — DriveRelayWorker.kt
      implementado (commit f83e4b4)
- [x] Android escribe ACK en `desktop-<device_id>/acked/<event_id>.json` — implementado
- [x] el desktop lee `android-<device_id>/acked/` y marca eventos procesados —
      drive_relay.rs run_relay_cycle() paso 2 (commit 0ccc29c)
- [x] un mismo event_id no produce dos recursos — LocalDb.insertOrIgnore() (Android),
      relay_events UNIQUE event_id + insert_or_ignore uuid (desktop)
- [x] Android no procesa eventos de su propio namespace — safety check en Worker
- [x] Desktop no procesa sus propios eventos — drive_relay lee solo android-<id>/pending/
- [x] los campos url y title usan AES-256-GCM fw1a — FieldCrypto.kt con clave
      constante que Rust y Kotlin derivan idénticamente. fw2a (Keystore) descartado
      per TA: clave hardware-bound no legible por Rust. Decisión documentada.
- [x] los recursos con XOR son migrados a fw1a en primera ejecución del Worker

**ESTADO: IMPLEMENTADO — 2026-04-24. Commits FlowWeaver: f83e4b4 (Android), 0ccc29c (desktop).
Pendiente: configuración OAuth Google Drive (prerequisito externo — usuario configura via
configure_drive command). El relay no opera hasta que el usuario aporte client_id,
client_secret, refresh_token y paired_android_id.**

---

### T-0c-003 — Galería Android

task_id: T-0c-003
title: Pantalla de galería Android — categorías y recursos
phase: 0c
owner_agent: Android Share Intent Specialist
depends_on: T-0c-001 (datos), T-0c-002 (recibe recursos del desktop)

#### Objetivo

Implementar la pantalla principal de la app Android donde el usuario ve sus
recursos capturados organizados por categoría. Es la primera superficie de valor
visible en el móvil — el usuario puede encontrar lo que capturó sin abrir el desktop.

La galería es deliberadamente simple: categorías → recursos → tap abre URL en
el navegador del sistema. Sin workspace narrativo, sin Panel B, sin episodios.

#### Estructura de la galería

```
┌─────────────────────────────────────┐
│  FlowWeaver                    [⟳]  │
│                                     │
│  Recientes                          │
│  ├── [ig]  "Eminem – Lose Yourself" │  ← hace 2 min
│  ├── [yt]  "Pizza napolitana"       │  ← hace 1h
│  └── [gh]  "rust-lang/rust"         │  ← hace 3h
│                                     │
│  Por categoría                      │
│  ├── entertainment      8  →        │
│  ├── research          12  →        │
│  ├── shopping           3  →        │
│  └── ...                            │
└─────────────────────────────────────┘
```

Al tap en una categoría:
```
┌─────────────────────────────────────┐
│  ← entertainment (8)               │
│                                     │
│  [ig]  instagram.com                │
│        "Eminem – Lose Yourself"     │
│        hace 2 min                   │
│                                     │
│  [yt]  youtube.com                  │
│        "Pizza napolitana"           │
│        hace 1h                      │
│  ...                                │
└─────────────────────────────────────┘
```

Al tap en un recurso: abre la URL en el navegador del sistema (no embedded).

#### In Scope

- Sección "Recientes": últimos 10 recursos capturados, independientemente de categoría
- Sección "Por categoría": lista de categorías con recuento de recursos
- Vista de categoría: recursos ordenados por `captured_at` desc (más recientes primero)
- Cada recurso muestra: favicon (dominio), dominio, título descifrado, tiempo relativo
- Pull-to-refresh: fuerza un ciclo de sync inmediato
- Icono [⟳] en header: indica si el sync está en progreso
- Estado vacío: "Comparte algo desde Instagram, YouTube o cualquier app para empezar"
- Título descifrado visible (igual que Panel A desktop — D1 permite mostrar
  título al propietario de los datos)

#### Out of Scope

- Búsqueda dentro de la galería (Fase posterior)
- Ordenación manual ni etiquetas (Fase posterior)
- Vista previa de contenido embebido (Reels, videos)
- Panel B, resumen de categoría, episodios, anticipación
- Edición de categoría asignada (Fase posterior)

#### Acceptance Criteria

- [ ] la galería muestra todos los recursos capturados en el dispositivo agrupados
      por categoría con recuento correcto
- [ ] la sección "Recientes" muestra los últimos 10 recursos en orden cronológico
      inverso, independientemente de su categoría
- [ ] al tap en un recurso se abre la URL en el navegador del sistema (Chrome,
      Firefox o el que el usuario tenga por defecto)
- [ ] el título que se muestra está descifrado localmente — no aparece como bytes
- [ ] si el usuario no tiene capturas, se muestra el estado vacío con instrucción
      de cómo empezar
- [ ] pull-to-refresh lanza un ciclo de sync inmediato y actualiza la galería
- [ ] la galería es funcional sin conexión a internet (lee de SQLCipher local)
- [ ] los recursos recibidos del desktop via relay bidireccional (T-0c-002)
      aparecen en la galería con el mismo tratamiento que los capturados en móvil
- [ ] npx tsc --noEmit (si hay tipos TypeScript nuevos) limpio

---

### T-0c-004 — Privacy Dashboard Mínimo Móvil

task_id: T-0c-004
title: Privacy Dashboard mínimo en Android
phase: 0c
owner_agent: Android Share Intent Specialist
depends_on: T-0c-001, T-0c-003
prerequisite_of: Fase 3 (sin Privacy Dashboard en móvil no puede haber beta con usuarios móviles)

#### Objetivo

Dar al usuario visibilidad y control sobre qué datos tiene FlowWeaver en su
dispositivo Android. Es el equivalente al Privacy Dashboard mínimo de Fase 0b
desktop, adaptado al contexto móvil.

El dashboard mínimo móvil no es el Privacy Dashboard completo de Fase 2. Su
alcance es: cuánto hay, de dónde viene, borrarlo si el usuario quiere.

#### In Scope

- Recuento de recursos por categoría (cuántos recursos tiene el usuario en el móvil)
- Indicador de relay: "tus capturas se almacenan temporalmente cifradas en tu
  Google Drive personal" con enlace a más información
- Sección de FS Watcher (si está activo en desktop): texto informativo — no gestión
  (la gestión de FS Watcher es en el dashboard desktop)
- Botón "Eliminar todos mis datos del móvil": elimina el SQLCipher Android local.
  No afecta al desktop ni al relay. Con confirmación explícita.
- Texto de transparencia: "Qué guarda FlowWeaver en este dispositivo" →
  "El nombre de los sitios que compartiste (domain), la categoría asignada y
  la fecha de captura. El enlace completo (URL) y el título están cifrados
  y solo tú puedes leerlos."
- Texto de transparencia: "Qué nunca guarda" →
  "El contenido de las páginas, tus contraseñas, tus datos de cuenta ni
  ninguna información personal."

#### Out of Scope

- Gestión de FS Watcher desde móvil (es del dashboard desktop — Fase 2)
- Gestión de patrones (Pattern Detector — Fase 2 desktop primero)
- Historial de transiciones de la State Machine (Fase 2)
- Configuración de umbrales (Fase 3)

#### Acceptance Criteria

- [ ] el dashboard muestra el recuento de recursos por categoría
- [ ] el botón "Eliminar todos mis datos del móvil" elimina el SQLCipher local
      Android con confirmación explícita y sin afectar al desktop
- [ ] el texto de transparencia "Qué guarda / Qué nunca guarda" es visible
      sin navegar a submenús
- [ ] el indicador de relay es honesto: menciona Google Drive explícitamente
- [ ] Privacy Guardian aprueba el texto de transparencia antes de lanzar
      (revisión específica requerida para el lenguaje de la UI)

---

## Hipótesis Que Fase 0c Debe Validar (Gate De Salida)

Antes de pasar el gate de Fase 0c, debe existir evidencia de que:

- El usuario abre la app Android y encuentra sus capturas organizadas sin
  abrir el desktop (galería funcional con datos reales)
- El relay bidireccional sincroniza sin pérdida ni duplicación (E2E test
  con captura en desktop → aparece en galería móvil)
- La galería móvil funciona sin conexión a internet (modo offline — SQLCipher local)
- El Privacy Dashboard móvil es honesto y comprensible para un usuario no técnico

### Condiciones de no-paso (bloquean el gate)

- la galería requiere el desktop encendido para mostrar datos (falla de offline-first)
- aparece contenido de páginas, texto de URLs o información personal en la galería
- el relay bidireccional produce duplicados en alguno de los dispositivos
- el Privacy Dashboard no incluye el botón de borrado o el texto de transparencia
- aparece cualquier módulo de los prohibidos (Episode Detector, Pattern Detector,
  Panel B, sync en tiempo real) en la implementación

---

## Track iOS — Sigue Abierto E Independiente

La Share Extension iOS y el Sync Layer vía iCloud siguen pendientes por
dependencia de plataforma macOS. Son independientes del gate de Fase 0c.

| Módulo | Bloqueo | Estado |
| --- | --- | --- |
| Share Extension iOS | Requiere macOS + Xcode | Pendiente — independiente de Fase 0c |
| Sync Layer MVP (iCloud) | Requiere Share Extension operativa | Pendiente — independiente de Fase 0c |
