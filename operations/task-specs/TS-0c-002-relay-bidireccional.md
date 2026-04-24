# Especificación Operativa — T-0c-002

document_id: TS-0c-002
task_id: T-0c-002
phase: 0c
date: 2026-04-24
status: APROBADO — contrato de relay y clave de idempotencia definidos en AR-0c-001
owner_agent_android: Android Share Intent Specialist
owner_agent_desktop: Desktop Tauri Shell Specialist
referenced_decisions: D1, D6, D8, D9, D19, D20, D21
referenced_ar: AR-0c-001-phase-0c-contracts.md (sección A — idempotencia relay bidireccional)
referenced_ts: TS-0b-android-002-google-drive-sync.md (relay unidireccional Fase 0b — base de este módulo)
referenced_risk: R-0c-001 (XOR vs AES-256-GCM — debe resolverse en este módulo)
depends_on: T-0c-001 (backend Android con SQLite local + get_mobile_resources operativos)
blocks: T-0c-003 (criterio "recursos del desktop aparecen en galería"), gate de Fase 0c
nota_r12: el relay transporta raw_events entre dispositivos; no implementa ni invoca
          Episode Detector ni Pattern Detector en ninguno de los dos lados (R12 WATCH activo)

---

## Propósito en Fase 0c

T-0b-android-002 implementó el relay **unidireccional** Android → desktop. T-0c-002
extiende ese relay a **bidireccional**: el desktop también emite raw_events hacia
el móvil, y Android los descarga, clasifica con el Classifier local y persiste
en su SQLite.

El usuario que importa bookmarks en el desktop los verá aparecer en la galería
Android sin necesidad de capturarlos desde el móvil.

El relay sigue siendo asíncrono (WorkManager, 15 min). Sin sync en tiempo real.
Sin backend propio. Google Drive como transporte. D6 y D21 operativos.

---

## Declaración Explícita R12

**Este módulo no implementa ni invoca Episode Detector ni Pattern Detector.**

El relay transporta `raw_events` — eventos de captura individuales. No hay
agrupación temporal, no hay detección de patrones longitudinales, no hay
construcción de episodios en ninguno de los dos extremos del relay.

El Classifier que se aplica en el lado Android al recibir un raw_event del
desktop (para asignar categoría si el raw_event no la trae) es el mismo
Classifier determinístico de T-0c-001 (D8). No es Pattern Detector.

---

## Estructura del Relay en Fase 0c

La estructura de carpetas en Google Drive se extiende respecto a Fase 0b
añadiendo el namespace del desktop (AR-0c-001 sección A):

```
flowweaver-relay/
  ├── android-<device_id>/          ← escribe Android, lee Desktop
  │     ├── pending/
  │     │     └── <event_id>.json   ← raw_event pendiente de sync al desktop
  │     └── acked/
  │           └── <event_id>.json   ← marcado como procesado por el desktop
  └── desktop-<device_id>/          ← escribe Desktop, lee Android (NUEVO en 0c)
        ├── pending/
        │     └── <event_id>.json   ← raw_event pendiente de sync al Android
        └── acked/
              └── <event_id>.json   ← marcado como procesado por Android
```

**Regla de no-autoconsumo (AR-0c-001):**
- Android escribe en `android-<device_id>/` y lee de `desktop-<device_id>/`
- Desktop escribe en `desktop-<device_id>/` y lee de `android-<device_id>/`
- Ningún dispositivo procesa eventos de su propio namespace

---

## Clave de Idempotencia

**Clave: `(device_id, event_id)`**

Los namespaces separados en Drive garantizan que un `event_id` de Android
y el mismo `event_id` de desktop no colisionan — están en rutas distintas.
Dentro del mismo namespace, `event_id` es UUID v4 con probabilidad de colisión
negligible (2^122 por device_id).

Un evento no se procesa dos veces aunque el Worker lo descargue dos veces:
el receptor verifica si el `event_id` ya existe en su SQLite antes de INSERT.

---

## Lado Desktop — Desktop Tauri Shell Specialist

### Responsabilidad

El desktop emite raw_events hacia `desktop-<device_id>/pending/` cada vez que
el usuario importa bookmarks o añade una captura manual. También lee
`android-<device_id>/acked/` para limpiar los eventos ya procesados por Android
(comportamiento ya existente del relay de Fase 0b en la dirección inversa).

### Mecanismo de emisión

Un proceso `tauri::async_runtime::spawn` arranca al iniciar la app desktop
y opera en background. No bloquea la UI. No introduce observer activo de
ficheros del sistema (D9) — solo escribe en Drive.

```rust
// En lib.rs o commands.rs, al arrancar la app Tauri:
tauri::async_runtime::spawn(async move {
    loop {
        drive_relay::upload_pending_desktop_events(&device_id).await;
        drive_relay::read_android_acks(&device_id).await;
        tokio::time::sleep(Duration::from_secs(30)).await;
    }
});
```

Período: 30 segundos. La diferencia con Android (15 min) es intencional:
el desktop está normalmente conectado a red y el período más corto mejora
la latencia de aparición en la galería sin coste de batería.

### Formato del raw_event emitido por el desktop

Mismo schema que el raw_event de Android (TS-0b-android-001), para que
el receptor Android pueda procesarlo con el mismo Classifier:

```json
{
  "event_id":        "uuid-v4",
  "device_id":       "desktop-<uuid>",
  "captured_at":     1714000000000,
  "domain":          "github.com",
  "category":        "research",
  "url_encrypted":   "<bytes AES-256 base64>",
  "title_encrypted": "<bytes AES-256 base64>",
  "schema_version":  1
}
```

`category` viene del Classifier desktop. Android puede usarlo directamente
o reclasificar localmente — el Classifier es determinístico (D8), el resultado
es idéntico.

### Eventos que el desktop emite

- Bookmarks importados (bookmark importer de Fase 0a)
- Capturas manuales via `add_capture`
- No emite: sesiones, episodios, grupos — solo raw_events de recursos

### Cifrado del payload desktop

AES-256-GCM con la clave compartida en el emparejamiento QR (misma clave
que el relay de Fase 0b). Nonce aleatorio de 12 bytes por campo. D1 operativo.

---

## Lado Android — Android Share Intent Specialist

### Extensión del DriveRelayWorker

El `DriveRelayWorker` existente (T-0b-android-002) se extiende para también:

1. Leer `desktop-<device_id>/pending/` en Drive
2. Para cada raw_event descargado:
   a. Verificar idempotencia: si `event_id` ya existe en SQLite Android, ignorar
   b. Cifrar url y title con la clave del Keystore (AES-256-GCM — ver R-0c-001)
   c. INSERT en SQLite Android con el mismo schema de T-0c-001
   d. Escribir ACK en `desktop-<device_id>/acked/<event_id>.json`
3. Seguir enviando los propios raw_events del Share Intent a `android-<device_id>/pending/`

```
DriveRelayWorker.doWork() extendido:
  -- DIRECCIÓN EXISTENTE (Android → Desktop): sin cambios --
  1. subir cola local de capturas propias a android-<device_id>/pending/
  2. leer android-<device_id>/acked/ → limpiar cola local

  -- DIRECCIÓN NUEVA (Desktop → Android): nueva en 0c --
  3. leer desktop-<device_id>/pending/
     para cada raw_event:
       a. skip si event_id ya en SQLite (idempotencia)
       b. classify_domain(raw_event.domain) si category está en claro
       c. cifrar url y title con clave Keystore (AES-256-GCM)
       d. INSERT en SQLite Android
       e. escribir ACK en desktop-<device_id>/acked/<event_id>.json
```

### Resolución de R-0c-001 — AES-256-GCM via Android Keystore

**R-0c-001 debe resolverse en este módulo.**

AR-0c-001 pre-autorizó AES-256-GCM via Android Keystore como el cifrado
de campo estándar para el fallback de Android. T-0c-001 heredó el XOR de
`crypto.rs` como baseline provisional.

En T-0c-002, el Android Share Intent Specialist implementa AES-256-GCM
via Android Keystore para el cifrado de campo en SQLite Android:

```kotlin
// Generación de la clave en Android Keystore (una sola vez al instalar)
val keyGenerator = KeyGenerator.getInstance(
    KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore"
)
keyGenerator.init(
    KeyGenParameterSpec.Builder(
        "flowweaver_field_key",
        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
    )
    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
    .build()
)
val secretKey = keyGenerator.generateKey()
```

El upgrade AES-256-GCM se aplica a:
- los raw_events recibidos del desktop (este módulo, paso 3c)
- retroactivamente a los recursos ya en SQLite de T-0c-001 (migración en la
  primera ejecución del Worker con T-0c-002 activo)

La función `encrypt_field(text: String): ByteArray` en `crypto.rs` Android
se reemplaza por la llamada al Keystore.

---

## Ciclo de Vida Completo de un Evento Desktop → Android

```
Desktop importa bookmark
       ↓
Desktop Classifier asigna category
       ↓
Desktop cifra url y title con AES-256-GCM (clave compartida QR)
       ↓
Background process desktop sube desktop-<device_id>/pending/<event_id>.json
       ↓
DriveRelayWorker Android lee desktop-<device_id>/pending/
       ↓
Android verifica idempotencia (event_id no en SQLite)
       ↓
Android cifra url y title con clave Android Keystore AES-256-GCM
       ↓
Android INSERT en SQLite local
       ↓
Android escribe desktop-<device_id>/acked/<event_id>.json
       ↓
get_mobile_resources → galería muestra el recurso del desktop
```

---

## Qué NO Hace Este Módulo

| Elemento excluido | Regla |
| --- | --- |
| Sync en tiempo real (WebSocket, push) | D7 / OD-005 |
| Merge de bases de datos SQLite | D21 — cada dispositivo procesa de forma independiente |
| Episode Detector en el relay | R12 WATCH — el relay transporta raw_events, no episodios |
| Pattern Detector en el relay | D17 / OD-005 — Fase 2 desktop primero |
| Sync de sesiones o episodios del desktop | OD-005 — solo raw_events viajan |
| Panel B en Android | OD-005 prohibición explícita |
| Autoconsumo de eventos propios | AR-0c-001 — regla de no-autoconsumo |

---

## Criterios de Aceptación

Los mismos que el backlog-phase-0c.md más las condiciones de implementación
de esta TS:

- [ ] el desktop emite al menos un raw_event a `desktop-<device_id>/pending/`
      cuando se importan bookmarks o se añade una captura manual
- [ ] el Android Worker lee `desktop-<device_id>/pending/`, procesa el raw_event
      con el Classifier local y persiste en SQLite Android
- [ ] Android escribe ACK en `desktop-<device_id>/acked/<event_id>.json`
      después de procesar
- [ ] el desktop lee `android-<device_id>/acked/` y marca sus eventos como
      procesados (comportamiento existente de Fase 0b)
- [ ] un mismo event_id no produce dos recursos en Android aunque el Worker
      lo descargue dos veces (idempotencia)
- [ ] Android no procesa eventos de `android-<device_id>/` (sus propios)
- [ ] Desktop no procesa eventos de `desktop-<device_id>/` (sus propios)
- [ ] los campos url y title de los recursos insertados en SQLite Android desde
      el relay usan AES-256-GCM via Android Keystore (R-0c-001 resuelto)
- [ ] los recursos ya insertados por T-0c-001 con XOR son migrados a AES-256-GCM
      en la primera ejecución del Worker con T-0c-002 activo
- [ ] 14/14 tests Rust existentes siguen en verde tras la extensión del Worker
- [ ] `tsc --noEmit` limpio si hay cambios en tipos TypeScript del desktop

---

## Riesgos

| Riesgo | Mitigación |
| --- | --- |
| R-0c-001 (XOR → AES-256-GCM) | Resuelto en este módulo — upgrade y migración obligatorios |
| Colisión de event_id entre dispositivos | Imposible por namespaces separados en Drive |
| Desktop emite eventos duplicados (restart de la app) | Idempotencia en el receptor Android: skip si event_id ya existe |
| Worker Android descarga eventos del desktop antes de que el desktop haya hecho ACK de los propios de Android | Las dos direcciones del relay son independientes en el Worker — no hay bloqueo cruzado |
| Migración XOR → AES-256-GCM falla para un recurso ya existente | Estrategia: best-effort + log; los recursos que no se puedan migrar se re-capturan en el próximo ciclo del Share Intent |

---

## Trazabilidad

| Documento | Estado |
| --- | --- |
| AR-0c-001 sección A — contrato relay bidireccional | APROBADO |
| TS-0b-android-002 — relay unidireccional (base) | REFERENCIA |
| QA-REVIEW-0c-001 — O-001 (AES-256-GCM pendiente) | HEREDADO — resuelto en esta TS |
| HO-007 — T-0c-002 abierta | REFERENCIA |
| TS-0c-002 (este documento) | APROBADO — AR-0c-001 cubre el contrato |
