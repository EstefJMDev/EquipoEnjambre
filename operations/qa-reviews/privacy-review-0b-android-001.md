# Revisión De Privacidad — Fase 0b Android

document_id: PRIVACY-REVIEW-0b-android-001
owner_agent: Privacy Guardian
phase: 0b
date: 2026-04-24
status: APROBADO CON OBSERVACIONES — sin correcciones bloqueantes; implementación autorizada
reviewed_items:
  - operations/task-specs/TS-0b-android-001-share-intent.md
  - operations/task-specs/TS-0b-android-002-google-drive-sync.md
reference_normativo:
  - Project-docs/decisions-log.md (D1, D6, D9)
  - operations/architecture-reviews/AR-0c-001-phase-0c-contracts.md

---

## Resultado Global

| TS | Estado de privacidad | Correcciones bloqueantes | Observaciones |
| --- | --- | --- | --- |
| TS-0b-android-001 (Share Intent) | COMPATIBLE con Nivel 1 | Ninguna | 2 (no bloqueantes) |
| TS-0b-android-002 (Google Drive Sync) | COMPATIBLE con Nivel 1 | Ninguna | 3 (no bloqueantes) |

**La implementación puede comenzar. Ninguna observación requiere corrección previa.**
Las observaciones deben incorporarse como criterios de aceptación adicionales
en la implementación — no en las TS (que quedan aprobadas tal como están).

---

## A. Revisión — TS-0b-android-001 (Android Share Intent)

### A.1 Inventario de datos capturados

| Dato | Capturado | Cifrado | Compatible D1 | Observación |
| --- | --- | --- | --- | --- |
| URL | Sí | Sí (AES-256-GCM) | ✅ | |
| Título (EXTRA_SUBJECT) | Sí | Sí (AES-256-GCM) | ✅ | |
| Dominio (derivado de URL) | Sí | No — en claro | ✅ D1 permite dominio en claro | |
| Categoría (del Classifier) | Sí | No — en claro | ✅ | |
| Contenido de la página | No | — | ✅ | Prohibición correcta |
| Historial de navegación | No | — | ✅ | |
| Identidad del usuario | No | — | ✅ | `device_id` es UUID opaco |
| Geolocalización | No | — | ✅ | No capturado en ningún campo |

**Veredicto: captura mínima y correcta. D1 operativo.**

### A.2 D9 — Captura explícita únicamente

El Share Intent se activa exclusivamente por acción del usuario (toca "Compartir"
y selecciona FlowWeaver). No hay:
- observer en background
- polling del clipboard
- acceso a historial del navegador
- detección pasiva de apps en uso

**D9: operativo. La captura es el mínimo necesario para el caso núcleo.**

### A.3 UX de confirmación — verificación de privacidad

La tarjeta de confirmación muestra: categoría + dominio + "Tu workspace del
escritorio estará listo."

**Compatible con D1**: categoría y dominio son campos en claro. El usuario es
el propietario de los datos — mostrarlos en la UI de confirmación no viola
ninguna restricción. La URL y el título no aparecen en la confirmación. Correcto.

**Observación A.1 (no bloqueante):** La tarjeta de confirmación muestra que el
dato "viajará al escritorio". El texto debe ser honesto sobre qué viaja y qué no:
el URL viaja cifrado, no el URL en claro. Se recomienda que la tarjeta no use
formulaciones que den a entender que FlowWeaver "sabe lo que estabas viendo"
(lo cual implicaría lectura de contenido). El texto actual "Tu workspace del
escritorio estará listo" es correcto y no exagera. Mantener ese tono.

**Observación A.2 (no bloqueante):** El botón "Deshacer" debe eliminar el
`raw_event` de la cola local **y también del SQLCipher** si ya fue procesado por
el Session Builder antes de que el usuario tocara Deshacer. La TS menciona "si
el sync ya envió el evento, emite un evento de borrado" — bien. Añadir: ese
evento de borrado también debe incluir una señal al desktop para que elimine la
captura si ya fue procesada. Incorporar en los criterios de aceptación de la
implementación.

---

## B. Revisión — TS-0b-android-002 (Google Drive Sync)

### B.1 Inventario de datos en Google Drive

| Dato en el archivo Drive | Cifrado | Compatible D1 | Observación |
| --- | --- | --- | --- |
| `event_id` (UUID) | No — en claro | ✅ opaco, no revela contenido | |
| `device_id` (UUID del dispositivo) | No — en claro | ✅ opaco, no linked a identidad | Ver Observación B.1 |
| `captured_at` (timestamp) | No — en claro | ✅ timestamp no revela contenido | Ver Observación B.2 |
| `domain` | No — en claro | ✅ D1 permite dominio en claro | |
| `category` | No — en claro | ✅ | |
| `url_encrypted` | Sí — AES-256-GCM | ✅ | |
| `title_encrypted` | Sí — AES-256-GCM | ✅ | |

**Veredicto: los campos sensibles viajan cifrados. Los campos en claro son
exactamente los que D1 permite. Compatible con Nivel 1.**

### B.2 Narrativa verificable — coherencia con la promesa del producto

La promesa del producto es "procesamiento local, datos mínimos, cifrado fuerte".

Verificación del relay:
- ✅ URL y título viajan cifrados — la promesa se cumple en el transporte
- ✅ Google Drive es el relay, no el procesador — la lógica está en los dispositivos
- ✅ Google no tiene la clave AES-256 — no puede descifrar los campos sensibles
- ✅ No hay backend propio — D6 respetado

La narrativa "verificable por diseño" se mantiene: un usuario técnico puede
auditar que el payload en Drive tiene campos opaco en `url_encrypted` y
`title_encrypted` y confirmar que no están en claro.

### B.3 Observaciones (no bloqueantes)

**Observación B.1 — `device_id` en la ruta de Drive:**
La estructura `android-<device_id>/pending/` expone el `device_id` como parte
de la ruta del directorio en Google Drive. Un tercero con acceso a esa cuenta
de Drive podría ver cuántos dispositivos usa el usuario y cuántas capturas hace
cada uno (por número de archivos).

Sin embargo: (a) el `device_id` es un UUID opaco que no revela identidad; (b)
acceder a Drive de un usuario requiere sus credenciales; (c) D1 no prohíbe
metadatos de dispositivo en el relay. **Compatible con Nivel 1. Documentar
esta realidad en el Privacy Dashboard** ("tus capturas se almacenan temporalmente
en tu Google Drive personal cifradas") para que la promesa sea honesta.

**Observación B.2 — `captured_at` en claro revela patrones de uso:**
El timestamp en claro permite inferir a qué hora y con qué frecuencia el usuario
captura recursos, sin revelar qué capturó. Este es un metadato de comportamiento,
no de contenido. D1 no cifra timestamps — es el nivel de abstracción aceptado.

En Fase 2, cuando el Pattern Detector analice patrones temporales, este dato
ya estará en el historial. No hay nueva exposición: el `captured_at` ya existe
en el `resources` de SQLCipher desktop. **Compatible con Nivel 1. Sin acción
requerida en Fase 0b.**

**Observación B.3 — Clave provisional antes del emparejamiento:**
La TS menciona que si el usuario captura antes de emparejar, el evento se cifra
con una "clave provisional local". El Privacy Guardian exige que en la
implementación se garantice:

1. La clave provisional se genera y almacena en Android Keystore (no en
   `SharedPreferences` ni en disco en claro).
2. Al emparejar, los eventos pendientes cifrados con la clave provisional se
   re-cifran con la clave real antes de enviarse a Drive.
3. La clave provisional se destruye del Keystore tras el re-cifrado (no se
   reutiliza ni se conserva).

Este flujo no está completamente especificado en TS-0b-android-002. Añadir
como criterio de aceptación de la implementación. No bloquea la TS tal como
está escrita.

---

## C. Verificación De La Promesa Verificable

¿Puede un usuario técnico auditar que FlowWeaver cumple su promesa de privacidad
en el flow de captura Android?

| Afirmación de la promesa | Auditable | Cómo |
| --- | --- | --- |
| "Solo veo el dominio, no la URL completa" | ✅ | El archivo en Drive muestra `domain` en claro y `url_encrypted` como bytes opacos |
| "La URL viaja cifrada, Google no la ve" | ✅ | AES-256-GCM con clave en Android Keystore — Google solo ve bytes opacos |
| "Solo capturo lo que el usuario comparte activamente" | ✅ | Share Intent = acción explícita; no hay proceso en background |
| "No leo el contenido de las páginas" | ✅ | Solo `EXTRA_TEXT` (URL) y `EXTRA_SUBJECT` (título) del Intent |

**La narrativa verificable se mantiene.**

---

## D. Criterios De Aceptación Adicionales Para La Implementación

Estos criterios no están en las TS pero deben verificarse en la QA review:

1. La tarjeta de confirmación no usa lenguaje que implique lectura de contenido
   de la URL (ej: no "Hemos analizado tu Reel" sino "Guardado como entertainment").
2. "Deshacer" envía señal de borrado al desktop si el evento ya fue sincronizado.
3. La clave provisional antes del emparejamiento se almacena en Android Keystore,
   se destruye tras el re-cifrado, y nunca aparece en disco ni en SharedPreferences.
4. El Privacy Dashboard mínimo (ya implementado en desktop) incluye referencia
   al relay de Drive: "tus capturas se almacenan temporalmente cifradas en tu
   Google Drive personal".

---

## E. Veredicto Final

reviewed_scope: TS-0b-android-001 + TS-0b-android-002
privacy_status: COMPATIBLE con Nivel 1 (D1)
data_risk: BAJO — ningún dato sensible expuesto en claro fuera del dispositivo
required_fix: Ninguna corrección bloqueante
escalate_required: No
next_agent: Android Share Intent Specialist → implementación de T-0b-android-001 y T-0b-android-002
