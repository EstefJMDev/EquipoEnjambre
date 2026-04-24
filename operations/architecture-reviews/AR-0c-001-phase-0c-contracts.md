# Revisión Arquitectónica — Contratos De Fase 0c

document_id: AR-0c-001
owner_agent: Technical Architect
phase: 0c
date: 2026-04-24
status: APROBADO — dos bloqueantes resueltos; backlog-phase-0c.md puede producirse
documents_reviewed:
  - operations/architecture-notes/arch-note-phase-0c-android-review.md
  - operations/task-specs/TS-0b-android-001-share-intent.md
  - operations/task-specs/TS-0b-android-002-google-drive-sync.md
  - operations/orchestration-decisions/OD-005-phase-0c-activation.md
  - Project-docs/decisions-log.md (D6, D20, D21)
reference_normativo:
  - Project-docs/decisions-log.md (D1, D6, D8, D9, D19, D20, D21)
precede_a: Functional Analyst → backlog-phase-0c.md

---

## Objetivo De Esta Revisión

ARCH-NOTE-0c-001 (Android Share Intent Specialist) identificó dos bloqueantes
que debían resolverse antes de que el Functional Analyst pudiera escribir el
backlog de Fase 0c:

1. **Bloqueante A**: contrato `(device_id, event_id)` como clave de idempotencia
   del relay con dos emisores (Android + desktop).
2. **Bloqueante B**: decisión de fallback si SQLCipher no compila para Android
   con el NDK disponible.

Esta AR los resuelve formalmente. Ambas decisiones pasan a ser parte del marco
normativo de Fase 0c y deben declararse en backlog-phase-0c.md.

---

## Resultado Global

| Bloqueante | Resolución | Estado |
| --- | --- | --- |
| A — Idempotencia relay bidireccional | RESUELTO — contrato `(device_id, event_id)` aprobado | ✅ |
| B — Fallback SQLCipher Android | RESUELTO — SQLite nativo + cifrado Android Keystore | ✅ |

Backlog de Fase 0c puede producirse. Ningún bloqueante permanece abierto.

---

## A. Decisión — Idempotencia Del Relay Con Dos Emisores

### Contexto

En Fase 0b, el relay tiene un único emisor (Android) y un único receptor
(desktop). La clave de idempotencia es `event_id` (UUID v4).

En Fase 0c (D21), el relay es bidireccional: Android y desktop emiten raw_events
en ambas direcciones. Con dos emisores, se requiere que la clave de idempotencia
incluya el origen del evento para evitar colisiones de procesamiento.

### Decisión

**La clave de idempotencia del relay en Fase 0c es `(device_id, event_id)`.**

Consecuencias técnicas:

1. **Estructura de carpetas en Google Drive (Fase 0c):**

```
flowweaver-relay/
  ├── android-<device_id>/
  │     ├── pending/
  │     │     └── <event_id>.json
  │     └── acked/
  │           └── <event_id>.json
  └── desktop-<device_id>/
        ├── pending/
        │     └── <event_id>.json
        └── acked/
              └── <event_id>.json
```

Cada dispositivo emite solo a su propio directorio. Cada dispositivo lee solo
del directorio del otro dispositivo. No hay colisión posible entre event_ids
de dispositivos distintos porque están en namespaces separados.

2. **Regla de no-autoconsumo:** un dispositivo no procesa eventos de su propio
   directorio. El Android lee solo `desktop-<device_id>/pending/`. El desktop
   lee solo `android-<device_id>/pending/`. Esta regla debe declararse como
   invariante en backlog-phase-0c.md.

3. **Compatibilidad con Fase 0b:** En Fase 0b, el directorio
   `android-<device_id>/pending/` es el único activo. La estructura de Fase 0c
   extiende Fase 0b sin romperla — el desktop de Fase 0b ya lee ese directorio.
   La extensión añade `desktop-<device_id>/` sin tocar lo existente.

4. **UUID v4 como event_id:** La probabilidad de colisión de UUID v4 dentro
   del mismo `device_id` es negligible (2^122). No se requiere mecanismo
   adicional de unicidad dentro del mismo dispositivo.

### Verificación de D21

D21 declara: "El relay transporta raw_events en ambas direcciones. No hay merge
de bases de datos ni fuente de verdad única."

El contrato aprobado es coherente con D21:
- Cada dispositivo procesa de forma independiente los eventos que recibe.
- No hay base de datos maestra. Cada SQLCipher es soberano.
- El relay es un canal de transporte, no un estado compartido.

**Bloqueante A: RESUELTO.**

---

## B. Decisión — Fallback Si SQLCipher No Compila Para Android

### Contexto

ARCH-NOTE-0c-001 identifica que compilar SQLCipher para Android (`aarch64-linux-android`)
requiere NDK correctamente configurado y puede fallar si el crate `bundled-sqlcipher`
no encuentra las dependencias nativas (OpenSSL, libtomcrypt).

El Milestone 0 de Fase 0c (validación del build pipeline) debe ejecutarse antes
de implementar la galería. Esta AR define qué ocurre si Milestone 0 falla.

### Decisión de fallback

Si `bundled-sqlcipher` no compila para Android con el NDK disponible:

**Fallback aprobado: SQLite nativo de Android + cifrado a nivel de directorio
via Android Keystore.**

Mecanismo del fallback:

1. **Motor de base de datos:** SQLite nativo compilado por defecto en Tauri 2
   Android (sin crate adicional). No requiere NDK especial.

2. **Cifrado de datos sensibles:** Los campos `url` y `title` se cifran con
   AES-256-GCM usando una clave del Android Keystore antes de insertarse en
   SQLite. El Keystore es el sistema seguro de claves del SO — equivalente
   funcional a la clave de cifrado de SQLCipher.

3. **Cifrado del archivo de base de datos:** Android 6+ garantiza cifrado de
   almacenamiento a nivel de SO en dispositivos con cifrado de disco activado
   (la mayoría de dispositivos modernos). El directorio privado de la app
   (`/data/data/<package>/databases/`) está protegido por el SO.

4. **Paridad funcional con SQLCipher desktop:** El fallback garantiza que los
   campos sensibles no están en claro en la base de datos. La diferencia es
   que SQLCipher cifra la base de datos completa como archivo; el fallback cifra
   campo a campo. El resultado de privacidad es equivalente desde la perspectiva
   de D1.

5. **Refactorización posterior:** Si SQLCipher Android se resuelve en una versión
   futura del NDK o del crate, la migración es directa (mismos campos, distinto
   motor de cifrado). No hay deuda de diseño.

### Condición de activación del fallback

El Milestone 0 ejecuta `tauri android build --debug --target aarch64-linux-android`
con SQLCipher habilitado. Si el build falla con error de linking o de dependencias
nativas, el implementador activa el fallback sin escalar — la decisión está
tomada aquí.

Si el build tiene éxito: SQLCipher nativo. Sin fallback.

**Bloqueante B: RESUELTO.**

---

## C. Revisión De Contratos De TS-0b-android-001 Y TS-0b-android-002

Esta AR aprovecha para verificar los contratos de las TS de Fase 0b Android,
que el Technical Architect debe revisar antes de implementación.

### C.1 TS-0b-android-001 — Android Share Intent

| Contrato | Verificación | Estado |
| --- | --- | --- |
| Pipeline captura en < 300ms | El Classifier Rust es O(1) por tabla hash de dominios | ✅ factible |
| `url_encrypted` + `title_encrypted` cifrados antes de cola local | Correcto — el cifrado ocurre en el pipeline, antes de tocar ningún almacenamiento | ✅ D1 conforme |
| `domain` y `category` en claro en el raw_event | Correcto — D1 define estos campos como en claro | ✅ |
| `device_id` fijo por dispositivo en Android Keystore | Correcto — debe generarse en el primer arranque y no regenerarse | ✅ |
| No observer activo fuera del Intent | Correcto — no hay polling, no hay FS Watcher, no hay Accessibility | ✅ D9 |
| No galería en Fase 0b | Correcto — "Ver en galería" está explícitamente ausente | ✅ scope 0b |
| Compatibilidad del raw_event con `add_capture` desktop | El payload es idéntico al que `add_capture` ya recibe. Sin cambios en desktop. | ✅ |

**TS-0b-android-001: APROBADO sin correcciones.**

### C.2 TS-0b-android-002 — Google Drive Sync

| Contrato | Verificación | Estado |
| --- | --- | --- |
| WorkManager con `NETWORK_CONNECTED` | Correcto — garantiza ejecución bajo Doze mode | ✅ |
| Idempotencia por `event_id` (Fase 0b, emisor único) | Correcto para Fase 0b | ✅ |
| Extensión a `(device_id, event_id)` en Fase 0c | Declarado en la TS — coherente con decisión A de esta AR | ✅ |
| Estructura de carpetas `android-<device_id>/pending/` | Coherente con el namespace de dispositivo aprobado en A | ✅ |
| Cifrado AES-256-GCM con nonce por campo | Correcto — nonce aleatorio de 12 bytes previene reutilización | ✅ D1 |
| Google Drive no como backend propio | El relay usa Drive como transporte de archivos, no como servicio de lógica | ✅ D6 |
| QR como mecanismo de emparejamiento | Correcto — D18 lo define como escape y mecanismo de pairing | ✅ |
| Timeout de 7 días para eventos sin ACK | Razonable — evita que la cola crezca indefinidamente | ✅ |

**Observación en TS-0b-android-002**: El desktop debe también implementar la
lectura de `android-<device_id>/pending/` y el write de `acked/<event_id>`.
Esta responsabilidad cae en el Desktop Tauri Shell Specialist como parte del
completado de Fase 0b Android. El comando `add_capture` ya existe; lo que falta
es el polling de Drive y el ACK. El Technical Architect recomienda que esto se
implemente como un proceso `tauri::async_runtime::spawn` que se activa al
arrancar la app desktop y revisa Drive cada 30 segundos.

**TS-0b-android-002: APROBADO con observación (side implementado en desktop).**

---

## D. Invariantes De Fase 0c Derivadas De Esta AR

El Functional Analyst debe declarar estas invariantes en backlog-phase-0c.md:

1. La clave de idempotencia del relay en Fase 0c es `(device_id, event_id)`.
   Los eventos se organizan en namespaces por dispositivo en Google Drive.
2. Un dispositivo no consume eventos de su propio namespace — solo del namespace
   del otro dispositivo.
3. Si SQLCipher no compila para Android, el fallback aprobado es SQLite nativo
   + cifrado de campos con AES-256-GCM via Android Keystore. Esta decisión no
   requiere escalación — está tomada en esta AR.
4. El Classifier Rust es el mismo en Android y desktop. La clasificación
   de un mismo dominio produce la misma categoría en ambos dispositivos (D8).
5. La galería de Fase 0c lee de SQLCipher Android (o del fallback). No depende
   de datos del desktop para mostrar capturas propias del móvil.

---

## E. Siguiente Agente Responsable

**Functional Analyst** → producir backlog-phase-0c.md tomando:
- Esta AR (decisiones A y B + invariantes de la sección D)
- `operations/orchestration-decisions/OD-005-phase-0c-activation.md`
- `operations/architecture-notes/arch-note-phase-0c-android-review.md`
- `Project-docs/decisions-log.md` (D20, D21)
- `Project-docs/scope-boundaries.md` (scope de Fase 0c)
- `Project-docs/phase-definition.md` (hipótesis de Fase 0c)

La implementación de Fase 0c no puede comenzar hasta que Fase 0b Android
pase su gate (TS-0b-android-001 + TS-0b-android-002 implementados y validados
por QA).

---

## F. Trazabilidad

| Acción | Archivo | Estado |
| --- | --- | --- |
| Bloqueante A resuelto | AR-0c-001 (esta AR) | COMPLETADO |
| Bloqueante B resuelto | AR-0c-001 (esta AR) | COMPLETADO |
| TS-0b-android-001 revisada | TS-0b-android-001-share-intent.md | APROBADO |
| TS-0b-android-002 revisada | TS-0b-android-002-google-drive-sync.md | APROBADO con observación desktop |
| backlog-phase-0c.md | Functional Analyst — pendiente | PENDIENTE |
