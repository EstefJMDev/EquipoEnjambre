# Delimitación Formal De FS Watcher — T-2-000

document_id: TS-2-000
task_id: T-2-000
owner_agent: Functional Analyst (redacta)
approver: Technical Architect (aprueba antes de cualquier implementación)
phase: 2
date: 2026-04-24
status: APROBADO — Technical Architect (AR-2-002, 2026-04-24)
referenced_backlog: operations/backlogs/backlog-phase-2.md (T-2-000)
referenced_decisions: D9, D1, D17, R12 WATCH ACTIVO
satisfies: Condición 1 del gate formal de Fase 1 (phase-gates.md)

---

## Propósito De Este Documento

Este documento responde las tres preguntas que D9 exige para autorizar cualquier
módulo de observación activa en desktop:

1. **¿Qué observa FS Watcher?** — directorios y extensiones de archivo
2. **¿Por cuánto tiempo observa?** — duración y condiciones de la observación
3. **¿Con qué controles de privacidad?** — consentimiento, revocación, visibilidad

Sin este documento aprobado por el Technical Architect, ninguna línea de código
de FS Watcher puede escribirse.

FS Watcher es el segundo caso de uso local de FlowWeaver en desktop (el primero
es el Bookmark Importer de bootstrap). No es una extensión del Share Intent ni
del Episode Detector. Es un detector de actividad de archivos locales que
alimenta al Episode Detector adaptado de Fase 1 con eventos de sesión —
distinto del Pattern Detector de Fase 2, que analiza patrones longitudinales.

---

## 1. Qué Observa FS Watcher

### Directorios observables

FS Watcher puede observar los siguientes directorios del usuario:

| Directorio | Candidato | Por defecto |
| --- | --- | --- |
| `~/Downloads` (carpeta de descargas del usuario) | ✅ sí | ❌ inactivo (requiere consentimiento) |
| `~/Desktop` (escritorio del usuario) | ✅ sí | ❌ inactivo (requiere consentimiento) |
| `~/Documents` | ❌ no (demasiado amplio, riesgo de privacidad) | — |
| Directorios del sistema (`/System`, `C:\Windows`, etc.) | ❌ prohibido | — |
| Directorios de red o montados remotamente | ❌ prohibido | — |
| Directorios ocultos (`.git`, `.ssh`, etc.) | ❌ prohibido | — |
| Directorios de otras apps (Dropbox, OneDrive raíz, etc.) | ❌ prohibido | — |

**Regla de selección:** el usuario elige activamente qué directorios observa
FS Watcher desde el Privacy Dashboard. Ningún directorio se activa por defecto.
La primera vez que el usuario activa FS Watcher, el Privacy Dashboard muestra
los dos candidatos con explicación de para qué se usa cada uno y solicita
confirmación por directorio.

**Directorio mínimo:** al menos `~/Downloads` debe estar disponible como opción.
Sin ningún directorio activo, FS Watcher no opera (y no debe operar).

### Extensiones de archivo en scope

FS Watcher observa solo archivos con estas extensiones:

| Grupo | Extensiones |
| --- | --- |
| Documentos | `.pdf`, `.docx`, `.doc`, `.txt`, `.md`, `.xlsx`, `.csv` |
| Imágenes | `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg` |
| Capturas de pantalla | `.png` (en `~/Desktop` o `~/Downloads` — mismo bucket que imágenes) |
| Video | `.mp4`, `.mov`, `.webm` |
| Archivos comprimidos | `.zip` |

Extensiones **explícitamente fuera de scope:**

| Grupo | Extensiones | Motivo |
| --- | --- | --- |
| Ejecutables | `.exe`, `.app`, `.dmg`, `.msi`, `.sh`, `.bat` | Riesgo de seguridad |
| Archivos de sistema | `.dll`, `.sys`, `.plist`, `.dylib` | No son recursos del usuario |
| Archivos de código | `.py`, `.js`, `.rs`, `.swift`, `.java`, etc. | Fuera del caso de uso |
| Credenciales | `.pem`, `.key`, `.p12`, `.env` | Riesgo de privacidad crítico |
| Cualquier extensión no listada | — | Regla de lista blanca: si no está incluido, no se observa |

**Regla de lista blanca:** FS Watcher observa solo las extensiones explícitamente
listadas. Cualquier tipo de archivo no incluido se ignora silenciosamente.

### Qué registra de cada archivo

Cuando un archivo con extensión permitida aparece en un directorio observado:

| Campo | Almacenado | Cifrado | Justificación |
| --- | --- | --- | --- |
| Nombre del archivo | Sí | Sí (D1) | Puede revelar contenido |
| Ruta completa | Solo el directorio padre | No (en claro — nivel de abstracción D1) | El directorio es información de contexto, no de contenido |
| Extensión / tipo | Sí | No (en claro — es la categoría del evento) | |
| Timestamp de detección | Sí | No | |
| Tamaño del archivo | No | — | No aporta al caso de uso |
| Contenido del archivo | **Nunca** | — | D1 — prohibición permanente |
| Hash del archivo | No en Fase 2 | — | Fuera de scope |

---

## 2. Por Cuánto Tiempo Observa

### Duración de la observación

**FS Watcher observa únicamente mientras la app FlowWeaver está en primer plano.**

| Condición | FS Watcher |
| --- | --- |
| App FlowWeaver abierta y en foco | ACTIVO |
| App FlowWeaver minimizada | INACTIVO — suspende la observación |
| App FlowWeaver en background | INACTIVO — suspende la observación |
| App FlowWeaver cerrada | INACTIVO |
| Sistema en reposo / bloqueo de pantalla | INACTIVO |

No existe modo de observación en background bajo ninguna circunstancia. Esta
restricción es permanente en Fase 2 y no puede eliminarse sin un change request
formal que modifique D9.

### Qué ocurre al suspender la observación

Cuando la app pasa a background o se cierra:
- Los eventos de archivo en cola pero no procesados por el Episode Detector
  se descartan (no se guardan para la próxima sesión).
- El Episode Detector adaptado de Fase 1 cierra la sesión activa.
- No se registra ningún archivo adicional hasta que el usuario vuelva a poner
  la app en primer plano.

### Sesión de observación

Una sesión de FS Watcher es el período continuo en que la app está en primer
plano y el usuario tiene al menos un directorio activado. La sesión termina
cuando la app pierde el foco o se cierra.

---

## 3. Controles De Privacidad

### Consentimiento

| Control | Descripción |
| --- | --- |
| Activación por directorio | El usuario activa cada directorio individualmente desde el Privacy Dashboard. No hay "activar todo". |
| Confirmación explícita | Al activar un directorio por primera vez, el sistema muestra: "FlowWeaver observará [directorio] para detectar archivos mientras tengas la app abierta. Solo detecta el nombre y tipo de archivo — nunca el contenido." El usuario debe confirmar. |
| Sin activación por defecto | Ningún directorio se activa al instalar. El usuario elige activamente. |

### Revocación

| Control | Descripción |
| --- | --- |
| Desactivar por directorio | El usuario puede desactivar cualquier directorio desde el Privacy Dashboard en cualquier momento. La desactivación es inmediata. |
| Purga de eventos | Al desactivar un directorio, los eventos asociados a ese directorio pueden eliminarse desde el Privacy Dashboard (botón "Eliminar historial de [directorio]"). |
| Reset completo | El botón "Eliminar todos mis datos" del Privacy Dashboard elimina también el historial de eventos de FS Watcher. |

### Visibilidad en el Privacy Dashboard

El Privacy Dashboard de Fase 2 (T-2-004) debe incluir una sección de FS Watcher
con:

- Lista de directorios activos e inactivos
- Estado en tiempo real: activo / inactivo / suspendido
- Contador de eventos detectados en la sesión actual
- Contador de eventos detectados en las últimas 24 horas
- Botón "Dejar de observar [directorio]" por directorio
- Botón "Eliminar historial de [directorio]"
- Texto explicativo: "FlowWeaver detecta el nombre y tipo de archivo mientras
  tienes la app abierta. Nunca lee el contenido de tus archivos."

---

## 4. Separación Explícita: FS Watcher vs Pattern Detector (R12)

R12 WATCH ACTIVO se extiende a la distinción entre FS Watcher y Pattern Detector.
Esta distinción debe declararse explícitamente en el código, en la documentación
y en la UI.

| Dimensión | FS Watcher | Pattern Detector |
| --- | --- | --- |
| Función | Detectar eventos de archivo en la sesión actual | Detectar patrones longitudinales en el historial de recursos |
| Escala temporal | Tiempo real (eventos mientras la app está abierta) | Días / semanas (historial en SQLCipher) |
| Input | Eventos del sistema de archivos (inotify / FSEvents / ReadDirectoryChangesW) | Registros de `resources` en SQLCipher (domain, category, captured_at) |
| Output | Evento de sesión: nombre de archivo, tipo, timestamp | DetectedPattern: firma longitudinal por domain/category |
| Persistencia | No persiste entre sesiones (eventos descartados al cerrar) | Persiste patrones detectados |
| Relación | FS Watcher genera eventos → Episode Detector adaptado (Fase 1) los evalúa | Pattern Detector lee historial de SQLCipher, independiente de FS Watcher |
| Módulo Rust | `fs_watcher.rs` (independiente) | `pattern_detector.rs` (independiente) |

**FS Watcher NO genera los patrones que detecta el Pattern Detector.** Los eventos
de FS Watcher son efímeros (sesión actual). Los patrones del Pattern Detector
son longitudinales (semanas de historial). Son módulos con propósitos distintos
que operan sobre fuentes y escalas temporales completamente diferentes.

El archivo `fs_watcher.rs` debe incluir en su comentario de cabecera:
```rust
// FS Watcher: detecta eventos de archivo en sesión activa.
// Distinto de pattern_detector.rs (patrones longitudinales) — R12.
// Opera solo mientras la app está en primer plano (D9).
```

---

## Criterios De Aceptación De Este Documento

- [x] el documento especifica al menos un directorio observable (`~/Downloads`)
      y los criterios de selección por el usuario (activación manual por directorio)
- [x] el documento especifica explícitamente que no hay monitoring en background
      (sección 2 — "únicamente mientras la app está en primer plano")
- [x] el documento especifica los controles de privacidad mínimos: consentimiento
      (confirmación por directorio), revocación (botón en Privacy Dashboard),
      visualización en Privacy Dashboard (sección 3)
- [x] el documento declara qué extensiones de archivo entran en scope (lista
      blanca de 18 extensiones en 5 grupos) y cuáles no (ejecutables, sistema,
      código, credenciales)
- [x] el documento declara explícitamente la separación entre FS Watcher
      (detección de sesión de archivos locales) y Pattern Detector (patrones
      longitudinales) — R12 (sección 4)
- [x] el documento es aprobado por el Technical Architect antes de que comience
      ninguna implementación de FS Watcher (AR-2-002, 2026-04-24 — sin correcciones)

---

## Riesgos De Interpretación

| Riesgo | Descripción | Contención |
| --- | --- | --- |
| Ampliar scope de directorios | Proponer añadir `~/Documents`, `~/Pictures` u otros sin CR | Este documento cierra el scope; cualquier directorio nuevo requiere actualizar este documento con aprobación TA |
| Background monitoring "opcional" | Proponer un modo "silencioso" de FS Watcher cuando la app está minimizada | D9 es absoluto en Fase 2: no hay monitoring sin app en primer plano |
| FS Watcher "genera patrones" | Describir FS Watcher como si produjera los inputs del Pattern Detector directamente | R12: FS Watcher → Episode Detector (adaptado). Pattern Detector lee SQLCipher, no los eventos de FS Watcher |
| Observar extensiones de código o credenciales | Alguien propone añadir `.py`, `.env`, `.pem` para capturar "contexto de trabajo" | Lista blanca es cerrada; requiere CR para modificarla |
| Leer el contenido del archivo | Cualquier propuesta de leer contenido para "mejorar la clasificación" | D1 permanente: nunca se lee el contenido |

---

## Handoff Esperado

1. Functional Analyst produce este documento (completado).
2. Technical Architect revisa y aprueba o devuelve con correcciones.
3. Si aprobado: Desktop Tauri Shell Specialist puede comenzar implementación
   de `fs_watcher.rs` como parte de Fase 1 (ya autorizada en OD-003).
4. Si hay correcciones: Functional Analyst revisa y vuelve a TA.

La implementación de FS Watcher está **bloqueada hasta aprobación del Technical
Architect** sobre este documento.
