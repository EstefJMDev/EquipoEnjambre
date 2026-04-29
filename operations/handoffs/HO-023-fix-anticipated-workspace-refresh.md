# Standard Handoff

document_id: HO-023
from_agent: Claude Code (executor de OD-007 §D.2)
to_agent: Desktop Tauri Shell Specialist
status: ready_for_review
phase: 2 (vigente)
date: 2026-04-29
cycle: Bugfix — refresh automático del `AnticipatedWorkspace` al recibir un sync del relay (R14)
opens: revisión por Desktop Tauri Shell Specialist + verificación end-to-end con dispositivo real (no mock)
depends_on: OD-007 §"Bloque D — D.2", risk-register §R14
unblocks: cierre de R14 una vez verificado en máquina con relay configurado y dispositivo Android emparejado

---

> **Resolución de numeración:** OD-007 §D.2.d especifica el handoff como
> `HO-020-fix-anticipated-workspace-refresh.md`, pero HO-020, HO-021 y HO-022
> ya están asignados (HO-020 = phase-2-ho-fw-pd-close, HO-021 =
> phase-3-ts-cr-002-001-kickoff, HO-022 = phase-3-p1-qa-criterio-18-kickoff).
> Este handoff toma **HO-023** por ser el siguiente número libre. La
> referencia simbólica de OD-007 §D.2.d se mantiene apuntando a este archivo.

---

## Objetivo

Notificar al Desktop Tauri Shell Specialist que se ha aplicado el fix del
bug R14 (workspace anticipado no se refresca con la app abierta) y solicitar
revisión + verificación end-to-end con dispositivo real.

El bug se materializa así: cuando el desktop tiene la app abierta y el relay
importa una captura nueva proveniente de Android, la pantalla no recalcula
clusters ni episodios. El usuario solo ve el cambio si cierra y vuelve a
abrir la app, o si hace una captura manual desde el formulario. El wow del
puente móvil → desktop **no dispara con la app ya abierta** — exactamente
el caso más relevante para el caso núcleo.

---

## Causa raíz

`App.tsx` solo llama a `initWorkspace()` desde el `useEffect` inicial,
guardado por `initialized.current`. No había ningún listener para "el relay
ha ingestado un evento nuevo", de forma que el frontend permanecía
desconectado del flujo de sincronización mientras estaba activo.

Por su parte, `drive_relay::run_relay_cycle` realizaba `process_android_event`
y emitía un ACK a Drive, pero no avisaba al frontend de que había llegado un
recurso nuevo.

---

## Cambios aplicados

### Backend Rust

`src-tauri/src/drive_relay.rs`:

- `process_android_event` cambia su firma de `Result<(), String>` a
  `Result<String, String>` y devuelve el `resource_uuid` derivado por
  `Uuid::new_v5(NAMESPACE_URL, domain || url)`. El UUID viaja como payload
  del evento Tauri para que el frontend pueda referenciarlo si lo necesita
  (hoy no lo usa, mañana sí).
- `run_relay_cycle` añade un parámetro `app_handle: Option<&AppHandle>`. Si
  está presente y `process_android_event` es exitoso, emite el evento Tauri
  `relay-event-imported` con el `resource_uuid` como payload.
- El parámetro es `Option<&AppHandle>` para preservar la testabilidad del
  ciclo desde código que no levante Tauri (consistente con la dirección de
  refactor que documenta el test ignored de D.1).
- Importa `tauri::{AppHandle, Emitter}`.

`src-tauri/src/lib.rs`:

- En el `setup` que spawnea el loop async del relay, pasa `Some(&handle)`
  como cuarto argumento a `run_relay_cycle`.

`src-tauri/tests/e2e_relay_roundtrip.rs`:

- El test `e2e_relay_data_roundtrip` actualiza la captura del retorno de
  `process_android_event` (ahora `Result<String, String>`).
- Añade un assert nuevo: `imported_uuid == expected_v5_uuid`. Pin-fija el
  contrato del payload del evento Tauri.

### Frontend TypeScript

`src/App.tsx`:

- Importa `listen` de `@tauri-apps/api/event`.
- El `useEffect` inicial ahora envuelve `detectPlatformAndInit` en un IIFE
  async, y tras inicializar registra un listener de `relay-event-imported`.
- En cada evento, el listener recarga `get_clusters` y `get_episodes` en
  paralelo, actualiza `clusters` y `episodes`, y transiciona `phase` de
  `"empty"` a `"ready"` si hay clusters nuevos. Usa el callback de
  `setPhase` (`(cur) => ...`) para no capturar el valor obsoleto del
  cierre — la regla explícita de OD-007 §D.2.b.
- El listener silencia errores: el siguiente sync intentará de nuevo. No
  recursión, no relisten en fallo, no bucles.
- `useEffect` cleanup llama a `unlisten?.()` cuando el componente se
  desmonta o el efecto se vuelve a ejecutar.
- El registro del listener está envuelto en try/catch para que la
  ausencia de Tauri (p.ej. en el rendering Android cuando se cargue la
  app más adelante) no rompa el flujo de inicialización.

---

## Verificaciones automáticas

- `cargo test --test e2e_relay_roundtrip` → **passed** (1 ok, 1 ignored).
- `npx tsc --noEmit` → **passed** (sin output).
- Compilación del crate completa con un único warning preexistente
  (`tauri_plugin_shell::Shell::open` deprecated en `commands.rs:482`) no
  introducido por este cambio.

---

## Verificación pendiente (manual, no ejecutable en esta sesión)

El siguiente test manual es bloqueante para cerrar R14 pero requiere:
- entorno con Drive configurado (`configure_drive` con OAuth válido)
- dispositivo Android emparejado activo

**Procedimiento:**

1. Levantar `tauri dev` en desktop con un usuario que tenga Drive ya
   configurado vía `configure_drive`.
2. Esperar a que el desktop entre en estado `"empty"` o `"ready"` con la
   ventana visible.
3. Desde el dispositivo Android emparejado, capturar un recurso nuevo
   (Share Intent → URL → enqueue al relay Drive).
4. Esperar al ACK (≤ 30s + propagación Drive).
5. Sin tocar la app desktop, observar que `AnticipatedWorkspace` aparece
   o se actualiza con el nuevo recurso, y que `phase` transiciona de
   `"empty"` a `"ready"` si era el primer recurso.

**Criterio de paso:** la actualización es automática, sin recargar ni
hacer captura manual desde el formulario.

**Criterio de fallo:** si el listener no dispara, revisar (en este orden):
- el `app_handle.emit` se ejecuta en `drive_relay.rs` (añadir log temporal)
- el listener registra correctamente (`@tauri-apps/api/event` está en
  `package.json`)
- el evento `relay-event-imported` no es swallowed por algún plugin

---

## Anti-objetivos / cuidados

- el listener **no** llama a `import_bookmarks`. Ese flujo es solo del
  arranque y no aplica al sync incremental.
- el listener **no** muta el formulario de captura ni el estado `error`.
  Permanecen estables; solo se recargan `clusters` y `episodes`.
- el listener **no** entra en bucle si la recarga falla — silencia
  excepciones del lado del invoke; el siguiente sync reintentará.
- el evento `relay-event-imported` se emite **solo** cuando hay un
  recurso recién importado (rama `if !already`). Redeliveries del mismo
  `event_id` no disparan refrescos espurios.
- D1 respetado: el payload del evento es solo el `resource_uuid` (string
  de v5). No viaja `url` ni `title`.

---

## Riesgos residuales

- **R14 sigue ABIERTO** hasta que el test manual confirme el comportamiento
  end-to-end con dispositivo real. El fix pasa los checks automáticos pero
  R14 era un bug de comportamiento percibido, no de invariante de tipos.
- **R15 no se modifica** por este HO. La latencia del relay no se mide;
  cuando se mida, el refresh tiene que estar dentro del presupuesto del
  P50 declarado en `product-spec.md` §17.

---

## Próximo agente

Desktop Tauri Shell Specialist, para:

1. Revisar la edición de `App.tsx` (cleanup del listener, callback de
   `setPhase`, ausencia de bucles).
2. Revisar la edición de `drive_relay.rs` (lugar de emisión del evento,
   flujo del `Option<&AppHandle>`, no-emisión en redeliveries).
3. Ejecutar el procedimiento manual descrito arriba con dispositivo real.
4. Cerrar R14 si pasa, abrir nueva observación si falla.

---

## Referencia cruzada

- OD-007 §"Bloque D — D.2"
- risk-register §R14 (estado ABIERTO antes y después de este HO; la
  verificación manual es el siguiente paso para mover a CERRADO)
- QA-REVIEW-E2E-RELAY-001 (D.1 baseline test) — comparte el contrato wire
  que aquí se extiende con el evento Tauri
