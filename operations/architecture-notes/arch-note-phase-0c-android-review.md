# Nota Técnica — Revisión Android Share Intent Specialist: Fase 0c

document_id: ARCH-NOTE-0c-001
owner_agent: Android Share Intent Specialist
phase: 0c
date: 2026-04-24
status: EMITIDO — requiere lectura por Technical Architect antes de backlog-phase-0c.md
references:
  - operations/change-requests/CR-001-mobile-client-bidirectional-sync.md
  - operations/orchestration-decisions/OD-005-phase-0c-activation.md
  - Project-docs/decisions-log.md (D1, D6, D8, D9, D19, D20, D21)

---

## Propósito

Esta nota revisa la propuesta de Fase 0c desde la perspectiva del especialista
Android. Identifica cuatro concerns técnicos que el CR-001 no resuelve, propone
mejoras concretas a la arquitectura aprobada, y señala dos items que el Technical
Architect debe resolver en AR-0c-001 antes de que el Functional Analyst escriba
el backlog.

Ninguna de estas mejoras revoca lo aprobado en OD-005. Son precisiones y extensiones.

---

## Resultado Global

| Área | Evaluación | Acción requerida |
| --- | --- | --- |
| Modelo de sync bidireccional (D21) | CONCERN CRÍTICO — event_id con dos emisores | Technical Architect resuelve en AR-0c-001 |
| Pipeline de procesamiento en Android | CONCERN TÉCNICO — build de SQLCipher + Rust para Android | Validar como milestone 0 de implementación |
| UX de captura post-share | MEJORA SIGNIFICATIVA | Incluir en backlog-phase-0c.md |
| Sync en background (Android OS) | CONCERN TÉCNICO — Doze mode | Incluir en backlog-phase-0c.md |
| Diseño de galería | MEJORA — título visible + "Recientes" | Incluir en backlog-phase-0c.md |
| Consistencia de clasificación entre dispositivos | ACLARACIÓN POSITIVA — no es problema | Declarar explícitamente en backlog |

---

## 1. Concern Crítico — event_id Con Dos Emisores (D21)

### El problema

El relay actual (Fase 0b) está diseñado asumiendo que el móvil es el único
emisor de `raw_events`. La idempotencia funciona así: si el relay recibe el
mismo `event_id` dos veces, lo descarta. `event_id` es un UUID generado en el
dispositivo emisor.

Con Fase 0c, el desktop también emite `raw_events` hacia el relay. El protocolo
actual no distingue de qué dispositivo proviene cada evento. Hay dos riesgos:

**Riesgo A — Colisión de event_id (improbable pero posible):**
UUID v4 tiene probabilidad de colisión negligible. No es el riesgo principal.

**Riesgo B — Deduplicación cruzada errónea (real):**
Si el relay usa `event_id` como única clave de idempotencia, y un evento del
desktop llega al relay con el mismo `event_id` que un evento previo del móvil
(colisión real o de lógica de negocio), el relay lo descartaría. Pero más
importante: el receptor (el otro dispositivo) no sabe si el evento que está
procesando es suyo o del otro dispositivo. Podría procesarlo dos veces si el
relay no gestiona bien las colas separadas.

### La solución

Añadir `device_id` al **envelope del relay** (no al payload cifrado — D1 no se
viola porque el `device_id` no revela contenido del usuario):

```
relay_envelope {
  device_id:  "android-<uuid-del-dispositivo>"  // o "desktop-<uuid>"
  event_id:   "<uuid-del-evento>"
  payload:    <bytes cifrados>
  timestamp:  <unix ms>
}
```

La clave de idempotencia pasa a ser `(device_id, event_id)`, no solo `event_id`.
El receptor descarta su propia `device_id` al consumir (un dispositivo no procesa
sus propios eventos de vuelta).

**Implicación en D21:** D21 declara "raw_events en ambas direcciones con
idempotencia". La solución propuesta es compatible con D21 pero lo precisa:
la idempotencia es por `(device_id, event_id)`. El Technical Architect debe
aprobar este contrato en AR-0c-001 antes de que el backlog lo concrete.

---

## 2. Concern Técnico — Build Pipeline: Rust + SQLCipher Para Android

### El problema

El mismo Rust que corre en desktop (Windows x86_64) necesita compilar para tres
targets Android:
- `aarch64-linux-android` (ARM64 — la mayoría de dispositivos modernos)
- `armv7-linux-androideabi` (ARM32 — dispositivos más antiguos)
- `x86_64-linux-android` (emulador)

SQLCipher en Rust (`sqlcipher` crate o `rusqlite` con feature `bundled-sqlcipher`)
añade dependencias de compilación nativas (OpenSSL o libtomcrypt). Compilar
SQLCipher para Android desde Windows requiere NDK correctamente configurado y
posiblemente cross-compilation flags adicionales.

Tauri 2 gestiona parte de esto, pero el `bundled-sqlcipher` puede dar problemas
en targets Android si el NDK no está en el PATH correcto o si la versión de
Android Studio / NDK no es compatible.

### La solución

**Milestone 0 de Fase 0c (antes de cualquier implementación de galería o sync):**
Verificar que el build pipeline compila correctamente el binario Tauri 2 para
Android con SQLCipher activo. Criterio: `tauri android build --debug` completa
sin errores de linking para el target `aarch64-linux-android`.

Este milestone es bloqueante. Si SQLCipher no compila para Android con el NDK
disponible, la arquitectura de Fase 0c requiere un fallback (ej: SQLite sin
cifrado en Android con cifrado a nivel de archivo del sistema operativo, que
Android 6+ garantiza). El Technical Architect decide el fallback si aplica.

**Declarar en backlog-phase-0c.md como T-0c-000** (análoga a T-2-000 para FS
Watcher): validación técnica del build pipeline antes de implementación.

---

## 3. Mejora Significativa — UX de Captura Post-Share

### El problema actual

El flujo actual de Share Intent termina con un toast genérico: "Guardado". El
usuario no sabe en qué categoría quedó clasificado el recurso ni puede ir
directamente a verlo en la galería.

Esto crea rozamiento: el usuario comparte un Reel, ve "Guardado", y no sabe
si FlowWeaver lo entendió bien. Si va a la galería, tiene que buscar.

### La mejora

Al completar el Share Intent, en lugar del toast genérico, mostrar:

```
┌─────────────────────────────────────┐
│  ✓  Guardado en FlowWeaver          │
│                                     │
│  entertainment  ·  instagram.com    │
│                                     │
│  [Ver en galería]      [Deshacer]   │
└─────────────────────────────────────┘
```

- La categoría asignada es feedback inmediato de que el sistema entendió el recurso
- "Ver en galería" abre la app en la categoría correspondiente
- "Deshacer" elimina el recurso recién guardado (ventana de 10 segundos)

**Por qué importa:** este feedback cierra el loop cognitivo del usuario. Si la
categoría es incorrecta, el usuario lo sabe inmediatamente y puede corregirlo
(en el Privacy Dashboard). Sin este feedback, los errores de clasificación son
invisibles hasta que el usuario abre la galería — si es que la abre.

**Implementación:** el Share Intent ya corre el Classifier antes de persistir.
El resultado de clasificación ya está disponible en ese momento. Solo es cuestión
de mostrarlo en lugar de descartarlo.

---

## 4. Concern Técnico — Sync En Background: Doze Mode De Android

### El problema

Android, a partir de Android 6 (Doze mode) y con restricciones crecientes en
versiones posteriores, limita agresivamente el trabajo en background. Una app
que no está en primer plano NO puede:
- abrir conexiones de red arbitrariamente
- ejecutar Workers sin declarar explícitamente las restricciones de red

Si el relay de Fase 0b en Android no usa WorkManager, el sync puede fallar
silenciosamente cuando la app está en background.

### La solución

El sync de raw_events con Google Drive en Android debe usar **WorkManager** con:
```
Constraints.Builder()
  .setRequiredNetworkType(NetworkType.CONNECTED)
  .build()
```

Esto garantiza que:
- El sync se ejecuta cuando hay red, aunque la app esté en background
- Android no mata el Worker por Doze (WorkManager tiene garantía de ejecución)
- El ACK y los reintentos funcionan aunque el usuario no tenga la app abierta

**Cadencia recomendada:** `PeriodicWorkRequest` con período de 15 minutos
(mínimo de WorkManager). Cuando el usuario abre la app, se fuerza un sync
inmediato además del periódico.

**Implicación en el contrato:** D21 dice "relay async". WorkManager es async
y cumple D21. Pero debe declararse explícitamente en el backlog para que el
implementador no use `Thread` o `Coroutine` directamente (que Doze puede matar).

---

## 5. Mejora — Diseño De Galería: Título Visible Y Sección "Recientes"

### Sobre el título en la galería (D1)

D1 almacena el título cifrado en SQLCipher. Pero D1 no prohíbe mostrar el
título en la UI al usuario propietario de los datos — igual que Panel A en
desktop muestra el título descifrado localmente.

**La galería móvil puede y debe mostrar el título descifrado del recurso.**
El usuario necesita ver qué guardó, no solo el dominio. "instagram.com" solo
no le permite distinguir un Reel de Eminem de uno de cocina.

Propuesta de item en la galería:
```
entertainment
  ├── [ig] instagram.com  ·  "Eminem - Lose Yourself (Live)"    hace 2h
  ├── [yt] youtube.com    ·  "Cómo hacer pizza napolitana"       hace 3h
  └── [tt] tiktok.com     ·  "Brushstroke techniques for oil"   ayer
```

El título se muestra truncado a ~40 caracteres. Se descifra solo en el proceso
local — no sale del dispositivo. Esto es Privacy Level 1 correcto.

### Sección "Recientes" en la galería

La galería propuesta en CR-001 es "categorías → recursos". Mejora: añadir una
sección "Recientes" fija al inicio que muestra los últimos 10 recursos capturados
independientemente de su categoría.

**Por qué:** el principal momento de uso de la galería es inmediatamente después
de capturar. El usuario quiere ver "lo que acabo de guardar" — no buscar su
categoría primero. Con "Recientes" arriba, encuentra el recurso en un tap.

```
[Recientes]
  ├── instagram.com  ·  "Eminem - Lose Yourself"   hace 2min  ← lo que acabo de compartir
  ├── youtube.com    ·  "Pizza napolitana"          hace 1h
  └── ...

[Por categoría]
  ├── entertainment  (8)
  ├── research       (12)
  └── ...
```

---

## 6. Aclaración Positiva — Consistencia De Clasificación Entre Dispositivos

### La preocupación inicial

Si el desktop y el móvil corren el mismo Classifier + Grouper sobre el mismo
`raw_event`, ¿producirán el mismo resultado? ¿Pueden clasificar diferente?

### La aclaración

**No: no hay riesgo de inconsistencia.** El Classifier es determinístico (D8).
El mismo input produce el mismo output con el mismo código. Como el móvil y el
desktop corren el mismo binario Rust (mismo código fuente compilado), la
clasificación de cualquier evento es idéntica en ambos dispositivos.

**Esto también significa:** si el desktop captura un bookmark y lo envía como
`raw_event` al relay → el móvil lo recibe → corre su Classifier → obtiene
exactamente la misma categoría que el desktop asignó. No hay divergencia.

**Declarar explícitamente en backlog-phase-0c.md** como invariante de arquitectura:
"La clasificación es determinística e idéntica en móvil y desktop para el mismo
input. El relay de raw_events bidireccional no introduce inconsistencia."

---

## Resumen De Acciones Requeridas

### Para el Technical Architect (antes de backlog-phase-0c.md)

| Item | Urgencia | Decisión requerida |
| --- | --- | --- |
| event_id + device_id en relay envelope | BLOQUEANTE | Aprobar contrato `(device_id, event_id)` como clave de idempotencia en AR-0c-001 |
| Fallback si SQLCipher no compila para Android | BLOQUEANTE | Definir alternativa técnica si el build pipeline falla (SQLite + Android file encryption) |

### Para el Functional Analyst (al redactar backlog-phase-0c.md)

| Item | Tipo | Prioridad |
| --- | --- | --- |
| T-0c-000: Milestone 0 — validar build pipeline Rust+SQLCipher en Android | Pre-implementación | PRIMER PASO |
| UX post-share: feedback de categoría + "Ver en galería" + "Deshacer" | Implementación | ALTA |
| WorkManager para sync en background | Implementación | ALTA |
| Galería: mostrar título descifrado + sección "Recientes" | Implementación | MEDIA |
| Invariante de consistencia determinística declarada en cada TS | Documental | MEDIA |

### Para el Privacy Guardian (revisión de la galería)

Verificar que mostrar el título descifrado en la galería móvil no introduce
vectores de privacidad nuevos respecto a lo ya aprobado en Panel A desktop.
El título se descifra localmente y no sale del dispositivo — el mismo modelo
que D1 ya permite.

---

## Invariantes Arquitectónicas Propuestas Para Fase 0c

Estas invariantes deben declararse en el backlog y verificarse en AR-0c-001:

1. La clave de idempotencia del relay es `(device_id, event_id)`, no solo `event_id`.
2. Un dispositivo nunca procesa sus propios raw_events de vuelta desde el relay.
3. El Classifier en Android es el mismo Rust determinístico del desktop — misma output, mismo input.
4. La galería móvil muestra títulos descifrados localmente; no los transmite fuera del dispositivo.
5. El sync en background usa WorkManager con constraint `NETWORK_CONNECTED`.
6. SQLCipher compila para target Android antes de que comience ninguna implementación de galería (T-0c-000 es bloqueante).
7. La galería no introduce observación activa — es una vista de lo que ya está en SQLCipher (D9 operativo).
8. El "Deshacer" de la UX post-share elimina el recurso de SQLCipher local; si ya sincronizó, emite un evento de borrado al relay.
