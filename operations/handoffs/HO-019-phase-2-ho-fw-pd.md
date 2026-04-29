# Standard Handoff

document_id: HO-019
alias: HO-FW-PD
from_agent: Orchestrator
to_agent: Desktop Tauri Shell Specialist
status: ready_for_execution
phase: 2
date: 2026-04-28
cycle: Integración FS Watcher al PrivacyDashboard — `FsWatcherSection.tsx`
opens: implementación de `src/components/FsWatcherSection.tsx` + composición en
  `PrivacyDashboard.tsx`. Este HO materializa la cláusula pendiente de D14
  (Privacy Dashboard completo antes de beta) y la decisión de TS-2-004
  §"Decisiones del Technical Architect §4" (sección FS Watcher out-of-scope de
  T-2-004, diferida a HO-FW-PD).
depends_on: AR-2-007 aprobado sin correcciones (2026-04-28) — certifica los
  siete comandos Tauri y los cinco tipos TypeScript del bloque T-2-000 como
  contrato estable. TS-2-000 §3 "Visibilidad en el Privacy Dashboard" es la
  spec autoritativa de los elementos visuales.
unblocks: gate de cierre de Fase 2. Tras aprobación del HO de cierre de este
  ciclo, D14 queda completamente satisfecho y Fase 2 cierra formalmente. El QA
  Auditor ejecuta en paralelo la verificación manual del criterio #18 de
  AR-2-007 (3 escenarios Windows).

---

## Objetivo

Crear el subcomponente `src/components/FsWatcherSection.tsx` y añadirlo al
`PrivacyDashboard.tsx` existente. El subcomponente muestra los siete elementos
de transparencia declarados en TS-2-000 §3 ("Visibilidad en el Privacy
Dashboard") consumiendo exclusivamente los siete comandos Tauri certificados
por AR-2-007. No se crea ni modifica ningún archivo backend (Rust, SQLCipher,
Cargo.toml). No se reabre TS-2-004.

La implementación abarca dos ejes:

1. **`FsWatcherSection.tsx` (nuevo)** — subcomponente React que invoca
   `fs_watcher_get_status` al montarse y lo refresca cada 4 segundos mientras
   el panel esté abierto. Oculto en Android (`runtime_state === 'Unsupported'`
   — D19). Muestra estado en tiempo real, contadores, lista de directorios con
   botones de control, y texto explicativo literal de TS-2-000 §3.
2. **`PrivacyDashboard.tsx` (modificación mínima)** — añadir
   `import { FsWatcherSection } from './FsWatcherSection';` y componer
   `<FsWatcherSection />` entre `<TrustStateSection />` y
   `<PrivacyDashboardNeverSeen />`.

---

## Inputs

Lectura obligatoria antes de cualquier edición:

### Spec autoritativa
- **TS-2-000 §3 "Visibilidad en el Privacy Dashboard":** los siete elementos
  declarados literalmente son el único contrato visual de este HO. Se reproducen
  en §"Entregables" abajo.

### Contratos certificados por AR-2-007 (no modificar)
- **Siete comandos Tauri** (en `commands.rs` — solo consumir, nunca editar):
  - `fs_watcher_get_status` → `Result<FsWatcherStatus, String>`
  - `fs_watcher_list_directories` → `Result<FsWatcherDirectory[], String>`
  - `fs_watcher_activate_directory({ directory, confirmed })` → `Result<void, String>`
  - `fs_watcher_deactivate_directory({ directory })` → `Result<void, String>`
  - `fs_watcher_get_session_events` → `Result<FsWatcherEvent[], String>`
  - `fs_watcher_clear_directory_history({ directory })` → `Result<void, String>`
  - `fs_watcher_get_24h_event_count` → `Result<number, String>`

- **Cinco tipos TypeScript** (`src/types.ts` líneas 131-161 — no modificar):
  ```typescript
  type CandidateDirectory = 'Downloads' | 'Desktop';
  type FsWatcherRuntimeState = 'Active' | 'Suspended' | 'Unsupported';
  interface FsWatcherDirectory { directory, absolute_path, active, activated_at }
  interface FsWatcherEvent { event_id, directory, extension, detected_at }
  interface FsWatcherStatus { runtime_state, directories, events_in_current_session, events_last_24h }
  ```

### Código existente a no modificar
- `src-tauri/src/fs_watcher.rs` — cerrado por AR-2-007.
- `src-tauri/src/commands.rs` (sección FS Watcher) — cerrado por AR-2-007.
- `src/types.ts` (bloque T-2-000) — cerrado por AR-2-007.
- `src/components/PrivacyDashboard.tsx` — solo las dos ediciones declaradas en
  §"Entregables · 2" (import + composición). Nada más.

### Código de referencia (leer antes de editar)
- `src/components/PrivacyDashboard.tsx` — estructura actual (líneas 1-121):
  tiene cabecera, sección de recursos con categorías/dominios, botón de purga
  global, `<PatternsSection />`, `<TrustStateSection />`,
  `<PrivacyDashboardNeverSeen />`. La sección FS Watcher va entre
  `<TrustStateSection />` y `<PrivacyDashboardNeverSeen />`.
- `src/components/TrustStateSection.tsx` — patrón de subcomponente con polling
  y estado local: referencia de estilo a seguir.

---

## Entregables Esperados

### 1. Nuevo archivo `src/components/FsWatcherSection.tsx`

Shape contractual exacto (implementar literalmente; se puede enriquecer el JSX
interno siempre que la lógica y los contratos de privacidad sean los declarados
aquí):

```tsx
import { useState, useEffect } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { CandidateDirectory, FsWatcherStatus } from '../types';

export function FsWatcherSection() {
  const [status, setStatus] = useState<FsWatcherStatus | null>(null);

  useEffect(() => {
    let alive = true;
    const load = () => {
      invoke<FsWatcherStatus>('fs_watcher_get_status')
        .then(s => { if (alive) setStatus(s); })
        .catch(() => {}); // Unsupported en Android → silencioso
    };
    load();
    const id = setInterval(load, 4000); // polling cada 4 s (< 5 s — criterio #5)
    return () => { alive = false; clearInterval(id); };
  }, []);

  // D19: oculto en Android (runtime_state === 'Unsupported')
  if (!status || status.runtime_state === 'Unsupported') return null;

  async function handleActivate(dir: CandidateDirectory) {
    // TS-2-000 §3 "Confirmación explícita" — texto literal del spec.
    const ok = confirm(
      `FlowWeaver observará ${dir} para detectar archivos mientras tengas la app abierta. ` +
      `Solo detecta el nombre y tipo de archivo — nunca el contenido.`
    );
    if (!ok) return;
    await invoke('fs_watcher_activate_directory', { directory: dir, confirmed: true })
      .catch(() => {});
    invoke<FsWatcherStatus>('fs_watcher_get_status').then(setStatus).catch(() => {});
  }

  async function handleDeactivate(dir: CandidateDirectory) {
    await invoke('fs_watcher_deactivate_directory', { directory: dir }).catch(() => {});
    invoke<FsWatcherStatus>('fs_watcher_get_status').then(setStatus).catch(() => {});
  }

  async function handleClearHistory(dir: CandidateDirectory) {
    await invoke('fs_watcher_clear_directory_history', { directory: dir }).catch(() => {});
    invoke<FsWatcherStatus>('fs_watcher_get_status').then(setStatus).catch(() => {});
  }

  return (
    <section
      aria-labelledby="pd-fs-watcher"
      className="privacy-dashboard__section"
    >
      <h4 id="pd-fs-watcher" className="privacy-dashboard__section-title">
        Observación de archivos locales
      </h4>

      {/* Texto explicativo literal — TS-2-000 §3 */}
      <p className="privacy-dashboard__fs-description">
        FlowWeaver detecta el nombre y tipo de archivo mientras tienes la app
        abierta. Nunca lee el contenido de tus archivos.
      </p>

      {/* Estado en tiempo real */}
      <p className="privacy-dashboard__fs-state">
        Estado:{' '}
        <span className={`privacy-dashboard__fs-badge privacy-dashboard__fs-badge--${status.runtime_state.toLowerCase()}`}>
          {status.runtime_state === 'Active' ? 'Activo' : 'Suspendido'}
        </span>
      </p>

      {/* Contadores — visibles solo cuando hay sesión activa */}
      {status.runtime_state === 'Active' && (
        <p className="privacy-dashboard__fs-counters">
          <span>{status.events_in_current_session} archivos en esta sesión</span>
          {' · '}
          <span>{status.events_last_24h} en las últimas 24 h</span>
        </p>
      )}

      {/* Lista de directorios */}
      <ul className="privacy-dashboard__fs-dirs">
        {status.directories.map(dir => (
          <li key={dir.directory} className="privacy-dashboard__fs-dir">
            <span className="privacy-dashboard__fs-dir-name">
              {dir.directory}
            </span>
            <span className="privacy-dashboard__fs-dir-status">
              {dir.active ? 'Activo' : 'Inactivo'}
            </span>
            <span className="privacy-dashboard__fs-dir-actions">
              {dir.active ? (
                <>
                  <button
                    className="privacy-dashboard__fs-btn"
                    onClick={() => handleDeactivate(dir.directory)}
                  >
                    Dejar de observar
                  </button>
                  <button
                    className="privacy-dashboard__fs-btn privacy-dashboard__fs-btn--danger"
                    onClick={() => handleClearHistory(dir.directory)}
                  >
                    Eliminar historial
                  </button>
                </>
              ) : (
                <button
                  className="privacy-dashboard__fs-btn"
                  onClick={() => handleActivate(dir.directory)}
                >
                  Activar
                </button>
              )}
            </span>
          </li>
        ))}
      </ul>
    </section>
  );
}
```

**Notas de implementación:**

a. **D1 absoluto:** no acceder a `file_name_encrypted` (no está en el shape
   TypeScript de `FsWatcherEvent`). No renderizar url, title, ni ruta completa
   de ningún archivo. Los contadores son enteros; los nombres de directorio
   (`CandidateDirectory`) son etiquetas legibles ('Downloads', 'Desktop') que
   TS-2-000 §1 autoriza en claro.

b. **Polling interval ≤ 5 s:** el `setInterval` de 4 s es el valor
   recomendado. Si hay razones de UX para ajustarlo, puede ser entre 2 s y
   5 s. No más de 5 s (criterio #5).

c. **`invoke` silencioso en catch:** en Android la invocación devuelve
   `Err(UnsupportedPlatform)` y el componente retorna `null` antes de
   renderizar. El catch en el polling (`catch(() => {})`) previene errores de
   consola en Android sin necesidad de detectar la plataforma explícitamente.

d. **Texto de confirmación exacto:** el mensaje del `confirm()` en
   `handleActivate` debe reproducir el texto literal de TS-2-000 §3
   "Confirmación explícita": `"FlowWeaver observará [directorio] para detectar
   archivos mientras tengas la app abierta. Solo detecta el nombre y tipo de
   archivo — nunca el contenido."` La variable `dir` sustituye `[directorio]`.

e. **CSS:** añadir clases BEM prefijadas `privacy-dashboard__fs-*` coherentes
   con el sistema de clases existente en `PrivacyDashboard.tsx`. Las clases
   pueden declararse inline (style prop) o en el CSS existente del componente
   — lo que minimice el delta de archivos. No crear un archivo CSS nuevo.

f. **Un solo `useEffect` con cleanup:** el retorno del `useEffect` limpia el
   intervalo y la bandera `alive` para evitar state updates en componente
   desmontado. Patrón idéntico a `TrustStateSection.tsx` si lo usa.

### 2. Modificación `src/components/PrivacyDashboard.tsx`

Exactamente dos cambios, nada más:

**Cambio A — Import (añadir tras los imports existentes):**
```tsx
import { FsWatcherSection } from './FsWatcherSection';
```

**Cambio B — Composición (entre `<TrustStateSection />` y
`<PrivacyDashboardNeverSeen />`):**
```tsx
<TrustStateSection />
<FsWatcherSection />          {/* ← nuevo */}
<PrivacyDashboardNeverSeen />
```

No se modifica ninguna otra línea de `PrivacyDashboard.tsx`. El resto del
componente (cabecera, sección de recursos, botón de purga global,
`<PatternsSection />`, lógica de stats) queda intacto.

---

## Verificación Final

```bash
npx tsc --noEmit
```
- Salida limpia, sin errores ni warnings.

Verificación visual manual Windows (antes de cerrar el HO):
1. Abrir FlowWeaver (`cargo tauri dev`). Abrir el Privacy Dashboard.
2. La sección "Observación de archivos locales" aparece con estado "Suspendido"
   y ambos directorios inactivos.
3. Activar "Downloads": aparece el diálogo de confirmación con el texto exacto
   de TS-2-000 §3. Confirmar → directorio pasa a "Activo".
4. El estado global cambia a "Activo". Los contadores se actualizan al crear
   un `.pdf` en Downloads (≤ 4 s de latencia por polling).
5. Clic en "Dejar de observar" → directorio vuelve a "Inactivo".
6. Clic en "Eliminar historial" con directorio activo → buffer limpiado, contadores en 0.
7. El texto "Nunca lee el contenido de tus archivos." es visible en el panel.

---

## Criterios De Cierre

El HO de cierre debe reportar cada uno con referencia verificable:

1. `src/components/FsWatcherSection.tsx` existe y exporta `FsWatcherSection`.
2. `PrivacyDashboard.tsx` importa `FsWatcherSection` y lo compone entre
   `<TrustStateSection />` y `<PrivacyDashboardNeverSeen />`.
3. El componente devuelve `null` cuando `status === null` o
   `status.runtime_state === 'Unsupported'` (D19 — Android oculto).
4. `fs_watcher_get_status` se invoca al montar el componente (carga inicial).
5. `fs_watcher_get_status` se refresca en intervalo ≤ 5 s con cleanup en
   desmontaje (sin memory leaks).
6. La lista de directorios muestra nombre y estado (activo/inactivo) para
   cada entrada de `status.directories`.
7. Botón "Activar" visible cuando `dir.active === false`. Invoca el diálogo
   de confirmación con texto exacto de TS-2-000 §3 antes de llamar
   `fs_watcher_activate_directory({ directory: dir, confirmed: true })`.
8. Botón "Dejar de observar" visible cuando `dir.active === true`. Invoca
   `fs_watcher_deactivate_directory({ directory: dir })`.
9. Botón "Eliminar historial" visible cuando `dir.active === true`. Invoca
   `fs_watcher_clear_directory_history({ directory: dir })`.
10. Contadores `events_in_current_session` y `events_last_24h` visibles
    cuando `runtime_state === 'Active'`.
11. Texto explicativo literal presente en el JSX: "FlowWeaver detecta el
    nombre y tipo de archivo mientras tienes la app abierta. Nunca lee el
    contenido de tus archivos."
12. `npx tsc --noEmit` limpio tras ambas ediciones.
13. **D1:** ningún acceso a `file_name_encrypted`; ningún render de `url`,
    `title`, ruta completa de archivo. Auditable por inspección del JSX.
14. Verificación visual manual Windows: los 6 pasos de §"Verificación Final"
    demostrados (o delegados al QA Auditor antes del gate de cierre de Fase 2).

---

## Restricciones

### D1 — sin url/title en claro (transversal absoluto)
Los únicos datos que el componente puede renderizar son: el nombre del
directorio (`CandidateDirectory` = 'Downloads' o 'Desktop'), su estado
(active: bool), `activated_at` formateado si se desea mostrar, y los
contadores enteros. Ningún campo de `FsWatcherEvent` puede renderizarse
excepto `extension` y `detected_at` — y solo si HO-FW-PD decidiera mostrar
un listado de eventos (fuera de scope de este HO). `file_name_encrypted`
es `Vec<u8>` en Rust y no existe en el tipo TypeScript de `FsWatcherEvent`
— no hay forma de acceder a él desde el frontend.

### D9 — foreground-only (transitivo a la UI)
El componente no intenta "activar" el watcher por su cuenta. Solo consume el
estado desde `fs_watcher_get_status`. El hook backend `WindowEvent::Focused`
gestiona el ciclo de vida del watcher. La UI refleja ese estado, no lo controla
directamente.

### D14 — Privacy Dashboard completo
Este HO es el último entregable que satisface D14. Tras aprobación del HO de
cierre, D14 queda completamente satisfecho: el usuario tiene visibilidad y
control completo sobre los dos mecanismos de observación de Fase 2 (Share
Intent desde el móvil + FS Watcher en desktop) y sobre los patrones y el
estado de confianza. Ningún mecanismo de observación de Fase 2 queda sin
representación en el Privacy Dashboard.

### D19 — Windows + Android primario
La sección no se muestra en Android (`runtime_state === 'Unsupported'`). El
componente no necesita detectar la plataforma explícitamente — el backend
devuelve `Unsupported` y el componente retorna `null`. El `catch(() => {})`
en el polling es suficiente para absorber el `Err(UnsupportedPlatform)` sin
errores de consola.

### Sin reabrir contratos cerrados
- `fs_watcher.rs` — cerrado por AR-2-007. Sin modificaciones.
- `commands.rs` (sección FS Watcher) — cerrado por AR-2-007. Sin modificaciones.
- `src/types.ts` (bloque T-2-000) — cerrado por AR-2-007. Sin modificaciones.
- `TS-2-004` — cerrado por HO-016 y AR-2-006. La adición de
  `<FsWatcherSection />` en `PrivacyDashboard.tsx` no reabre TS-2-004 —
  está autorizada explícitamente por TS-2-004 §"Decisiones del Technical
  Architect §4".

---

## Cierre

Tras completar los 14 criterios, el Desktop Tauri Shell Specialist emite el
**HO de cierre de HO-FW-PD** (HO-020 o siguiente número disponible) al
Orchestrator reportando:
- Estado de `npx tsc --noEmit`.
- Confirmación línea-por-línea de los 14 criterios.
- Estado de la verificación visual manual Windows (completada o delegada al
  QA Auditor con los 6 pasos documentados).

Tras aprobación del HO de cierre:
- **D14 queda completamente satisfecho.**
- El QA Auditor completa el criterio #18 de AR-2-007 (3 escenarios Windows de
  FS Watcher) si no se completaron durante este ciclo.
- **Fase 2 cierra formalmente.** El Orchestrator emite el PIR de Fase 2 y la
  OD de apertura de Fase 3.

---

## Firma

### Visados completados — autorización formal de implementación

#### 1. Technical Architect — contratos y scope ✅

**Visado por:** Technical Architect
**Fecha:** 2026-04-28
**Resultado:** APROBADO sin correcciones.

Los contratos de los siete comandos Tauri y los cinco tipos TypeScript están
certificados en AR-2-007 y no requieren modificación. La implementación es
puramente frontend (nuevo componente React + dos líneas en `PrivacyDashboard.tsx`).
La posición de `<FsWatcherSection />` entre `<TrustStateSection />` y
`<PrivacyDashboardNeverSeen />` es coherente con el flujo del panel (primero
datos, luego patrones, luego confianza, luego archivos locales, luego
primer uso). El patrón `useEffect` + `setInterval` + cleanup es el correcto
para polling en Tauri v2 con React. Sin nuevas decisiones arquitectónicas
necesarias.

#### 2. Privacy Guardian — D1 y texto de consentimiento ✅

**Visado por:** Privacy Guardian
**Fecha:** 2026-04-28
**Resultado:** APROBADO sin correcciones.

D1 cumplido estructuralmente: `FsWatcherEvent.file_name_encrypted` no existe
en el shape TypeScript (excluido deliberadamente en AR-2-006/AR-2-007), por
lo que el frontend no puede acceder a él. Los únicos datos renderizados son
nombres de directorio ('Downloads'/'Desktop'), estado booleano, contadores
enteros, y extensiones — todos autorizados por D1 en claro. El texto de
confirmación de activación reproduce el literal de TS-2-000 §3. El texto
explicativo "Nunca lee el contenido de tus archivos." es visible en la UI.
La sección oculta en Android (D19) no expone ningún dato en plataformas no
soportadas.

#### 3. Functional Analyst — cobertura de TS-2-000 §3 ✅

**Visado por:** Functional Analyst
**Fecha:** 2026-04-28
**Resultado:** APROBADO sin correcciones.

Mapeo TS-2-000 §3 → HO-019:

| Elemento TS-2-000 §3 | Entregable HO-019 |
|---|---|
| Lista de directorios activos e inactivos | `status.directories.map(dir => ...)` con estado por fila |
| Estado en tiempo real: activo / suspendido | Badge `runtime_state` con polling 4 s |
| Contador eventos sesión actual | `status.events_in_current_session` visible cuando Active |
| Contador eventos últimas 24h | `status.events_last_24h` visible cuando Active |
| Botón "Dejar de observar [directorio]" | `handleDeactivate` vía `fs_watcher_deactivate_directory` |
| Botón "Eliminar historial de [directorio]" | `handleClearHistory` vía `fs_watcher_clear_directory_history` |
| Texto explicativo literal | Párrafo en JSX con el texto exacto de TS-2-000 §3 |
| Confirmación al activar por primera vez | `confirm()` con texto literal de TS-2-000 §3 antes de `activate_directory` |

Cobertura completa. Ningún elemento de TS-2-000 §3 omitido.

#### 4. QA Auditor — plan de verificación ✅

**Visado por:** QA Auditor
**Fecha:** 2026-04-28
**Resultado:** APROBADO sin correcciones.

Los 14 criterios de cierre cubren los riesgos relevantes:
- Criterio #3 (D19 — null en Unsupported): previene renders vacíos en Android.
- Criterio #5 (cleanup del interval): previene memory leaks y errores tras
  desmontaje.
- Criterio #7 (confirmación antes de activate): blinda TS-2-000 §3
  "Confirmación explícita" en la UI.
- Criterio #13 (D1 — inspección JSX): auditable sin ejecución.
- Criterio #14 (verificación visual manual Windows): los 6 pasos cubren el
  ciclo completo end-to-end incluyendo el flujo de activación con confirmación.

No hay tests Rust nuevos en este HO (sin código backend). `npx tsc --noEmit`
(criterio #12) es la única verificación automatizada necesaria para código
TypeScript/React sin lógica de negocio compleja.

#### 5. Orchestrator — validación final + autorización ✅

**Visado por:** Orchestrator
**Fecha:** 2026-04-28
**Resultado:** APROBADO. Status: `ready_for_execution`.

Visados 1-4 completos. AR-2-007 aprobado (2026-04-28). Todos los contratos
backend certificados. Scope estrictamente acotado a dos archivos frontend.
D14 se satisface completamente con este HO. Fase 2 cierra formalmente tras
el HO de cierre de este ciclo. El Desktop Tauri Shell Specialist queda
formalmente autorizado a implementar `FsWatcherSection.tsx` siguiendo este
HO al pie de la letra.

submitted_by: Orchestrator
submission_date: 2026-04-28
notes: Alias HO-FW-PD referenciado en TS-2-004 §"Decisiones del Technical
  Architect §4", HO-017, HO-018 y AR-2-007. Este documento toma el número
  HO-019 por orden cronológico de emisión.
