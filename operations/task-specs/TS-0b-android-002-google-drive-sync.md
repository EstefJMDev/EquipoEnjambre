# Especificación Operativa — T-0b-android-002

owner_agent: Android Share Intent Specialist
document_id: TS-0b-android-002
task_id: T-0b-android-002
phase: 0b
date: 2026-04-24
status: DRAFT — pendiente de revisión por Technical Architect
referenced_decisions: D6, D1, D18, D19, D21
referenced_arch_note: operations/architecture-notes/arch-note-phase-0c-android-review.md
required_review: Technical Architect (protocolo relay, idempotencia, cifrado)
depends_on: TS-0b-android-001 (define el raw_event que este módulo transporta)
blocks: E2E testing de Fase 0b

---

## Propósito En Fase 0b

Este módulo implementa el lado Android del relay cifrado definido en D6. Es el
transporte que mueve los raw_events capturados por el Share Intent (T-0b-android-001)
desde el dispositivo Android hasta el desktop Windows, usando Google Drive como
relay intermediario.

En Fase 0b, el sync es **unidireccional: Android → desktop**. El desktop ya
tiene implementado el comando `add_capture` que lee estos eventos. La
bidireccionalidad (desktop → móvil) es una extensión de Fase 0c (D21).

El sync no bloquea la captura. El Share Intent encola el raw_event localmente
y este módulo lo envía de forma asíncrona en background. La experiencia del
usuario no depende de la disponibilidad de red en el momento de la captura.

---

## Emparejamiento Y Clave De Cifrado

Antes de que el sync pueda funcionar, el dispositivo Android y el desktop deben
compartir una clave simétrica AES-256 para el cifrado de los campos sensibles
(URL, título — D1).

### Flujo de emparejamiento (una sola vez al instalar)

```
Desktop genera clave AES-256 → la codifica en QR
Usuario escanea QR con Android → Android almacena la clave en Android Keystore
A partir de ahí: sync opera con esa clave sin intervención del usuario
```

Este mecanismo es el "fallback QR" de D18, reutilizado como mecanismo de
emparejamiento primario en Fase 0b. Es el más simple posible sin backend propio.

### Almacenamiento de la clave en Android

La clave se almacena en el **Android Keystore System** — el almacén seguro de
claves del sistema operativo. Nunca se escribe en `SharedPreferences` ni en disco
en claro. Sólo es accesible para la app de FlowWeaver.

### Fallback si el usuario no ha emparejado

Si el Share Intent se invoca antes de que el usuario haya emparejado:

1. La tarjeta de confirmación muestra: "Guardado localmente. Empareja tu
   escritorio para sincronizar."
2. El raw_event se encola cifrado con una clave provisional local.
3. Al emparejar, la cola se re-cifra con la clave real y se envía.

---

## Estructura Del Relay (Google Drive)

### Ruta de archivos en Google Drive

```
AppData de FlowWeaver en Google Drive (acceso privado — solo FlowWeaver puede leer)
  └── flowweaver-relay/
        └── android-<device_id>/
              ├── pending/
              │     ├── <event_id>.json    ← raw_event pendiente de sync
              │     └── ...
              └── acked/
                    ├── <event_id>.json    ← marcado como procesado por el desktop
                    └── ...
```

El directorio `android-<device_id>/` garantiza que los eventos de un dispositivo
no colisionan con los de otro. En Fase 0c, el desktop también tendrá su propio
directorio `desktop-<device_id>/` en el relay.

### Ciclo de vida de un evento

```
1. Share Intent → encola raw_event en pending/ (local)
2. WorkManager ejecuta sync → sube archivo a Drive: pending/<event_id>.json
3. Desktop polling detecta nuevo archivo → descarga → procesa → llama add_capture
4. Desktop mueve el archivo a acked/<event_id>.json (o lo elimina) como ACK
5. Android lee acked/ → limpia el evento de la cola local
```

### Formato del archivo en Drive

El archivo `<event_id>.json` en Drive contiene exactamente el raw_event definido
en TS-0b-android-001, sin modificaciones:

```json
{
  "event_id":        "uuid-v4",
  "device_id":       "android-<uuid>",
  "captured_at":     1714000000000,
  "domain":          "instagram.com",
  "category":        "entertainment",
  "url_encrypted":   "<bytes AES-256 base64>",
  "title_encrypted": "<bytes AES-256 base64>",
  "schema_version":  1
}
```

El archivo en Drive es legible en claro para Google (los bytes encrypted están
en base64, no cifrados a nivel de transporte). D6 define este relay como "cifrado"
en el sentido de que los campos sensibles (URL, título) están cifrados
**dentro del payload** — el transporte HTTPS de Google Drive añade cifrado
de capa de red adicionalmente.

---

## Implementación Android — WorkManager

### Por qué WorkManager

Android (Doze mode, API 23+) restricción de background: las apps sin WorkManager
pueden ser matadas antes de completar una llamada de red en background. WorkManager
garantiza que el sync se ejecuta aunque el usuario bloquee el teléfono o cambie
de app (dentro de las restricciones de batería del SO).

### Configuración del Worker

```kotlin
val syncConstraints = Constraints.Builder()
    .setRequiredNetworkType(NetworkType.CONNECTED)
    .build()

val syncRequest = PeriodicWorkRequestBuilder<DriveRelayWorker>(
    repeatInterval = 15,
    repeatIntervalTimeUnit = TimeUnit.MINUTES
).setConstraints(syncConstraints)
 .build()

WorkManager.getInstance(context).enqueueUniquePeriodicWork(
    "flowweaver_sync",
    ExistingPeriodicWorkPolicy.KEEP,
    syncRequest
)
```

- Período: 15 minutos (mínimo de WorkManager).
- Condición: red disponible (CONNECTED — WiFi o datos).
- Política: KEEP — si ya hay un Worker encolado, no lanza otro.
- El Worker también se dispara inmediatamente al encolar un nuevo raw_event
  (mediante `OneTimeWorkRequest` adicional).

### Lógica del DriveRelayWorker

```
DriveRelayWorker.doWork():
  1. leer cola local (archivos en directorio privado de la app)
  2. para cada raw_event en la cola:
     a. subir a Drive: pending/<event_id>.json
     b. marcar en cola local como "pendiente de ACK"
  3. leer carpeta Drive: acked/
     a. para cada event_id en acked/: eliminar de cola local
  4. si hay errores de red: WorkManager retries automáticamente (backoff exponencial)
  5. devolver Result.success() o Result.retry()
```

---

## Idempotencia

La idempotencia es garantizada por `event_id`:

- Si el Worker intenta subir un archivo que ya existe en `pending/<event_id>.json`
  en Drive (por un reintento): Drive sobreescribe con el mismo contenido —
  el resultado es idéntico.
- El desktop verifica `event_id` antes de llamar a `add_capture`. Si el evento
  ya fue procesado (existe en su SQLCipher), lo ignora.
- Clave de idempotencia en Drive: `<event_id>` (en Fase 0b, un solo emisor).
  En Fase 0c (D21), la clave pasa a ser `(device_id, event_id)`.

---

## Cifrado Del Payload

### Algoritmo

AES-256-GCM (autenticado). La misma clave AES-256 compartida en el emparejamiento.

### Por campo

| Campo | Cifrado | En Drive |
| --- | --- | --- |
| `event_id` | No (UUID opaco, no revela contenido) | En claro |
| `device_id` | No (identifica dispositivo, no contenido) | En claro |
| `captured_at` | No (timestamp, no revela URL) | En claro |
| `domain` | No (D1 — en claro, nivel de abstracción aceptado) | En claro |
| `category` | No (D1 — en claro) | En claro |
| `url_encrypted` | Sí — AES-256-GCM | Base64 del ciphertext + nonce |
| `title_encrypted` | Sí — AES-256-GCM | Base64 del ciphertext + nonce |

Cada campo cifrado incluye su propio nonce (12 bytes aleatorios prefijados al
ciphertext). Nunca se reutiliza el mismo nonce para el mismo campo.

---

## Qué NO Hace

| Elemento excluido | Primera fase permitida | Regla |
| --- | --- | --- |
| Sync bidireccional (recibir del desktop) | Fase 0c | D21 |
| Sync en tiempo real (WebSocket, push) | V1 (LAN) | D7 |
| Backend propio para relay | nunca en MVP | D6 prohibición explícita |
| iCloud como relay (Android) | — | iCloud no disponible en Android |
| Sync de base de datos SQLCipher | Fase 0c+ | 0b solo envía raw_events |
| Sincronizar metadata de las capturas hacia el móvil | Fase 0c | 0b es unidireccional |

---

## Criterios De Aceptación

- [ ] el Worker sube un raw_event a `pending/<event_id>.json` en Drive en < 5
      segundos desde que hay red disponible
- [ ] el Worker lee `acked/<event_id>.json` y elimina eventos ya procesados de
      la cola local
- [ ] WorkManager se activa correctamente bajo Doze mode (verificar en dispositivo
      físico con batería al 20%)
- [ ] si Drive no está disponible en el momento de la captura, el raw_event
      persiste en la cola local hasta que el Worker lo envía en el siguiente ciclo
- [ ] un mismo raw_event no se procesa dos veces en el desktop aunque el Worker
      lo suba dos veces (idempotencia por event_id)
- [ ] los campos `url_encrypted` y `title_encrypted` en el archivo de Drive
      no son decodificables sin la clave AES-256 (verificar con un cliente Drive
      externo — los bytes deben ser opaco base64)
- [ ] `domain` y `category` son legibles en claro en el archivo de Drive (D1 —
      estos campos no son sensibles a nivel de relay)
- [ ] el flujo E2E completo funciona:
      Android Share Intent → cola local → Worker sube a Drive →
      desktop descarga → desktop llama add_capture → Session Builder procesa →
      Episode Detector evalúa → Anticipated Workspace se actualiza
- [ ] el emparejamiento QR funciona: desktop genera QR → Android escanea → sync
      opera con la clave compartida sin errores de cifrado

---

## Riesgos

| Riesgo | Descripción | Mitigación |
| --- | --- | --- |
| Google Drive API cuotas | Límites de solicitudes por usuario | Los eventos son archivos pequeños (< 1 KB); volumen de uso en 0b es bajo |
| Doze mode mata el Worker | WorkManager garantiza ejecución pero puede retrasarla | Latencia aceptable en 0b: el desktop no necesita el evento en < 1 min |
| Nonce collision en AES-GCM | Si se reutiliza el nonce, el cifrado se rompe | Nonce aleatorio de 12 bytes por campo — probabilidad negligible |
| Desktop no hace ACK | El Worker reintenta indefinidamente | El Worker limpia eventos con más de 7 días sin ACK (timeout configurable) |
| QR de emparejamiento caducado | La sesión de QR expira antes de escanear | QR válido durante 5 minutos; si expira, el desktop genera uno nuevo |

---

## Handoff Esperado

1. Android Share Intent Specialist produce este documento.
2. Technical Architect verifica protocolo relay, idempotencia y cifrado.
3. Tras aprobación: implementación de T-0b-android-001 + T-0b-android-002 en secuencia.
4. QA Auditor verifica criterios de aceptación y E2E testing.
5. QA Auditor cierra el track Android de Fase 0b → gate de Fase 0b Android pasado.
6. Handoff Manager produce HO-007-phase-0b-android-close.md.
