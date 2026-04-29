# Standard Handoff

document_id: HO-022
from_agent: Handoff Manager
to_agent: QA Auditor
status: ready_for_execution
phase: 3
date: 2026-04-28
cycle: Verificación funcional manual Windows — criterio #18 AR-2-007 (P-1)
opens: ejecución de los 3 escenarios funcionales de AR-2-007 §"Criterio #18"
  en Windows y emisión del HO de cierre al Orchestrator con resultados.
depends_on: AR-2-007 (aprobado 2026-04-28) — criterio #18 aceptado como
  funcionalmente diferido al QA Auditor bajo condición explícita declarada en
  AR-2-007 §"Criterio #18 — Verificación Manual Windows". HO-020 aprobado
  (2026-04-28) — D14 satisfecho, Fase 2 cerrada, Fase 3 activa.
unblocks: P-1 (prerequisito bloqueante de beta pública de Fase 3, declarado en
  backlog-phase-3.md §"in_scope"). La aprobación de los 3 escenarios cierra P-1
  y despeja el último prerequisito técnico antes de la apertura de beta.

---

## Objetivo

Ejecutar los **3 escenarios funcionales de verificación manual Windows**
declarados en AR-2-007 §"Criterio #18 — Verificación Manual Windows"
(actualizado 2026-04-28 para reflejar el comportamiento background-persistent
de D9 revisado) y reportar los resultados al Orchestrator mediante un HO de
cierre.

Los escenarios cubren el ciclo completo de FS Watcher en Windows:
activación con evento permitido, rechazo de extensión fuera de lista blanca,
y captura de eventos mientras la app está en background (D9 revisado:
background-persistent).

El cierre de este HO con los 3 escenarios PASS constituye el cierre formal
de **P-1** y desbloquea la apertura de beta pública de Fase 3.

---

## Contexto y origen de P-1

### Por qué existe P-1

La implementación de T-2-000 (FS Watcher) fue completada por el Desktop Tauri
Shell Specialist (HO-018, 2026-04-27) y aprobada arquitectónicamente por
Technical Architect en AR-2-007 (2026-04-28) con **17 de los 18 criterios de
cierre confirmados** línea por línea.

El criterio #18 — verificación funcional manual Windows de los 3 escenarios —
fue aceptado como **técnicamente autorizado pero funcionalmente diferido**:
los tests unitarios cubren la lógica interna, pero la integración real con el
OS (ReadDirectoryChangesW vía `notify v6`) requiere ejecución manual de la app
en Windows. AR-2-007 §"Criterio #18" declaró explícitamente:

> "La verificación funcional manual es operativa (confirma integración con el
> OS), no arquitectónica."

### Revisión de D9 y el escenario 3

El 2026-04-28, D9 fue revisado en decisions-log.md
(§"D9 revisión FS Watcher Desktop: Background-Persistent"). El modelo
anterior (foreground-only, HO-017 / HO-018) fue reemplazado por el modelo
background-persistent: el watcher arranca una única vez en el primer
`Focused(true)` y **permanece activo mientras el proceso esté vivo**.
`Focused(false)` ya no hace drop del handle ni purga del buffer.

Como consecuencia, el escenario 3 de HO-018 §"Verificación manual" quedó
obsoleto. AR-2-007 §"Criterio #18" define el **escenario 3 revisado**
(background-persistent): el evento creado mientras la app está minimizada
**DEBE estar presente** al restaurar el foco.

Este HO reproduce los escenarios 1 y 2 de HO-018 sin cambios y el escenario 3
revisado de AR-2-007, que son los tres escenarios canónicos que cierran P-1.

---

## Referencia normativa

- **AR-2-007 §"Criterio #18 — Verificación Manual Windows"** (actualizado
  2026-04-28): definición canónica de los 3 escenarios. Este HO los reproduce
  literalmente para ejecución.
- **backlog-phase-3.md §"in_scope" línea P-1**: declara P-1 como prerequisito
  bloqueante de beta pública heredado de Fase 2.
- **decisions-log.md §"D9 revisión FS Watcher Desktop: Background-Persistent"**
  (2026-04-28): revisión que invalida el escenario 3 original y exige el
  comportamiento background-persistent.
- **HO-018 §"Verificación manual"**: escenarios 1 y 2 sin cambios (base).
- **TS-2-000 §1**: lista blanca de extensiones (escenario 2).

---

## Setup necesario

### Requisitos previos

1. Repositorio FlowWeaver en rama `main` con el estado aprobado por AR-2-007
   (commit con `fs_watcher.rs` implementado — 684 líneas).
2. Entorno de desarrollo Windows operativo:
   - Rust 1.95.0 / Cargo 1.95.0 instalado.
   - Node.js 24.13.0 / npm 11.6.2 instalado.
   - Visual Studio Build Tools 2022 instalado.
3. Directorio `~/Downloads` del sistema Windows activo y accesible.
4. Consola del navegador (DevTools) disponible para invocar comandos Tauri.

### Arranque de la app

```bash
cargo tauri dev
```

Para capturar logs de debug del FS Watcher durante la ejecución (recomendado
para adjuntar en el HO de cierre):

```bash
RUST_LOG=debug cargo tauri dev
```

El output de `eprintln!("[fs_watcher] ...")` de `lib.rs` sirve como evidencia
de los eventos procesados por el backend. Se recomienda mantener la terminal
visible durante los escenarios para capturar el output relevante.

### Verificación de arranque

Antes de ejecutar los escenarios, confirmar que la app arranca sin errores y
que el FS Watcher responde:

```javascript
window.__TAURI_INTERNALS__.invoke('fs_watcher_get_status')
```

Resultado esperado: objeto con `runtime_state` (valor `"Suspended"` si no hay
directorios activos), `directories` con `Downloads` y `Desktop` en estado
inactivo, `events_in_current_session: 0`.

---

## Escenarios de verificación

### Escenario 1 — Activación y evento permitido

**Objetivo:** verificar que FS Watcher detecta un archivo de extensión
permitida en un directorio activado.

**Pasos:**

1. Arrancar la app con `cargo tauri dev`. App en primer plano.

2. Activar el directorio `Downloads` con confirmación explícita:

   ```javascript
   window.__TAURI_INTERNALS__.invoke('fs_watcher_activate_directory', { directory: 'Downloads', confirmed: true })
   ```

   Resultado esperado: `null` (sin error). El comando confirma activación.

3. Verificar el estado del watcher:

   ```javascript
   window.__TAURI_INTERNALS__.invoke('fs_watcher_get_status')
   ```

   Resultado esperado: `runtime_state: "Active"`, directorio `Downloads` con
   `active: true`.

4. Crear un archivo `.pdf` en `Downloads`:

   ```powershell
   echo "test" > "$env:USERPROFILE\Downloads\test-fwatcher-$(Get-Date -Format 'HHmmss').pdf"
   ```

5. Obtener los eventos de sesión:

   ```javascript
   window.__TAURI_INTERNALS__.invoke('fs_watcher_get_session_events')
   ```

**Resultado esperado:** el array contiene al menos un evento con:
- `directory: "Downloads"`
- `extension: "pdf"`
- `event_id`: UUID v4 válido (cadena de 36 caracteres con guiones)
- `detected_at`: timestamp Unix aproximado al momento de creación del archivo

**Criterio de PASS:** evento presente con los campos esperados.

---

### Escenario 2 — Extensión rechazada (fuera de lista blanca)

**Objetivo:** verificar que archivos con extensiones fuera de la lista blanca
de TS-2-000 §1 son ignorados silenciosamente.

**Pasos:**

1. Mismo setup que Escenario 1. Directorio `Downloads` activo.

2. Crear un archivo `.exe` en `Downloads`:

   ```powershell
   echo "test" > "$env:USERPROFILE\Downloads\test-fwatcher-blocked.exe"
   ```

3. Obtener los eventos de sesión:

   ```javascript
   window.__TAURI_INTERNALS__.invoke('fs_watcher_get_session_events')
   ```

**Resultado esperado:** el array **no contiene** ningún evento con
`extension: "exe"`. El buffer puede contener eventos previos del Escenario 1
(`.pdf`), pero ninguno con extensión `.exe`.

**Criterio de PASS:** evento `.exe` ausente. La lista blanca rechaza
silenciosamente la extensión sin error ni log de fallo visible para el usuario.

---

### Escenario 3 — Background-persistent: evento capturado con app minimizada

**Objetivo:** verificar que el watcher permanece activo mientras la app está
en background (D9 revisado, 2026-04-28) y captura eventos durante ese periodo.

Este escenario reemplaza el escenario 3 de HO-018 §"Verificación manual"
(que verificaba el comportamiento foreground-only, ya obsoleto). La fuente
canónica es AR-2-007 §"Criterio #18 — Escenario 3 revisado".

**Pasos:**

1. Mismo setup que Escenario 1, con `Downloads` activo y al menos un evento
   `.pdf` ya en el buffer (resultado del Escenario 1).

2. **Minimizar la app FlowWeaver** (perder el foco) — la app pasa a background.
   No cerrar la app; solo minimizarla o hacer clic en otra ventana.

3. Con la app en background, crear un archivo `.pdf` en `Downloads`:

   ```powershell
   echo "test" > "$env:USERPROFILE\Downloads\test-fwatcher-bg-$(Get-Date -Format 'HHmmss').pdf"
   ```

4. Esperar aproximadamente 2 segundos sin restaurar el foco.

5. **Restaurar la app FlowWeaver** (recuperar el foco) haciendo clic en la
   barra de tareas o en la ventana.

6. Obtener los eventos de sesión:

   ```javascript
   window.__TAURI_INTERNALS__.invoke('fs_watcher_get_session_events')
   ```

**Resultado esperado:** el evento del paso 3 **DEBE estar presente** en el
array. El buffer contiene tanto los eventos previos (Escenario 1) como el
nuevo evento creado durante el periodo en background.

El handle del watcher se mantuvo activo durante la pérdida de foco y capturó
el evento del paso 3 sin necesidad de restaurar el foco para que el OS
entregara el evento.

**Criterio de PASS:** evento del paso 3 presente, con `extension: "pdf"` y
`detected_at` correspondiente al momento de creación durante el background.

---

## Comandos de referencia rápida

```javascript
// Activar directorio (escenarios 1 y 2)
window.__TAURI_INTERNALS__.invoke('fs_watcher_activate_directory', { directory: 'Downloads', confirmed: true })

// Obtener eventos de sesión
window.__TAURI_INTERNALS__.invoke('fs_watcher_get_session_events')

// Ver estado del watcher
window.__TAURI_INTERNALS__.invoke('fs_watcher_get_status')
```

```powershell
# Archivo PDF permitido (escenarios 1 y 3)
echo "test" > "$env:USERPROFILE\Downloads\test-fwatcher-$(Get-Date -Format 'HHmmss').pdf"

# Archivo EXE rechazado (escenario 2)
echo "test" > "$env:USERPROFILE\Downloads\test-fwatcher-blocked.exe"
```

---

## Cómo reportar logs y evidencia

El QA Auditor adjunta en el HO de cierre:

1. **Resultado de cada escenario:** PASS o FAIL, con el output literal de
   `fs_watcher_get_session_events()` que justifica la decisión (copiar/pegar
   el objeto JSON devuelto por la consola).

2. **Fragmento de log de debug relevante** (si se usó `RUST_LOG=debug`):
   líneas de `[fs_watcher]` de la terminal que muestran eventos detectados o
   descartados. No es obligatorio para PASS, pero es evidencia adicional de
   calidad y facilita diagnóstico si algún escenario falla.

3. **Estado del watcher antes y después** de cada escenario: resultado de
   `fs_watcher_get_status()` al inicio y al final del escenario.

4. **En caso de FAIL:** descripción del comportamiento observado, mensaje de
   error si lo hubo, y fragmento de log. El QA Auditor **no intenta corregir
   el comportamiento** — abre un issue de corrección al Desktop Tauri Shell
   Specialist y suspende el cierre de P-1 hasta que se resuelva y se
   re-ejecute el escenario.

---

## Criterios de cierre de este HO

| Escenario | Condición de PASS |
|---|---|
| 1 — Activación + evento permitido | Evento `.pdf` presente en buffer tras creación del archivo con `Downloads` activo |
| 2 — Extensión rechazada | Evento `.exe` ausente del buffer tras creación del archivo |
| 3 — Background-persistent | Evento `.pdf` presente en buffer tras creación durante background y restauración del foco |

**Los 3 escenarios PASS → P-1 cerrado → beta desbloqueada.**

Si algún escenario falla:

1. El QA Auditor documenta el fallo en el HO de cierre (HO-023 o siguiente
   número disponible) con el comportamiento observado y lo envía al
   Orchestrator.
2. El Orchestrator abre un issue de corrección al Desktop Tauri Shell Specialist.
3. Tras la corrección, el QA Auditor re-ejecuta únicamente el escenario
   fallido y confirma el nuevo resultado.
4. Solo cuando los 3 escenarios acumulan resultado PASS (en la misma o en
   distintas ejecuciones documentadas) se declara P-1 cerrado.

**P-1 no puede declararse cerrado con ningún escenario en estado FAIL ni
pendiente.**

---

## Solicitud al QA Auditor

Ejecutar los 3 escenarios en Windows según los pasos exactos de este HO y
emitir el **HO de cierre** (HO-023 o siguiente número disponible al momento
de emisión) dirigido al **Orchestrator** con:

- Resultado de cada escenario (PASS / FAIL).
- Evidencia de output de `fs_watcher_get_session_events()` por escenario.
- Fragmento de log de debug si se capturó (recomendado).
- Declaración explícita de si P-1 queda cerrado o si se requiere corrección.

El Orchestrator recepciona el HO de cierre, verifica la declaración de P-1, y
actualiza el estado del prerequisito en backlog-phase-3.md si procede.

---

## Firma

submitted_by: Handoff Manager
submission_date: 2026-04-28
notes: Este HO se emite tras la aprobación de HO-020 (D14 satisfecho, Fase 2
  cerrada) y la apertura de Fase 3. El criterio #18 de AR-2-007 quedó
  explícitamente diferido al QA Auditor por decisión del Technical Architect
  (AR-2-007 §"Criterio #18"). El escenario 3 reproduce el texto canónico de
  AR-2-007 §"Escenario 3 revisado" (background-persistent), que reemplaza el
  escenario 3 original de HO-018 (foreground-only, obsoleto tras D9 revisado
  el 2026-04-28). Los escenarios 1 y 2 son idénticos a HO-018 §"Verificación
  manual" escenarios 1 y 2. Los comandos Tauri reproducen literalmente las
  firmas certificadas en AR-2-007 y los comandos PowerShell son equivalentes
  funcionales de los documentados en HO-018.
