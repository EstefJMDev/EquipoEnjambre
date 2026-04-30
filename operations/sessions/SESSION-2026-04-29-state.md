# SESSION 2026-04-29 — Estado al cierre

date: 2026-04-29
session_type: OAuth Drive setup + validación E2E del puente
status_at_close: BLOQUEADO — bridge bidireccional ROTO (4 bugs arquitecturales + 1 bug de build detectados)

---

## Resumen ejecutivo

**El relay Android↔Desktop nunca ha funcionado end-to-end. Diagnóstico revela 4 bugs arquitecturales y 1 bug de build. Detectado por primera vez en sesión 2026-04-29 al hacer primera validación E2E real con OAuth funcionando.**

Las TS-0c-002 (relay bidireccional) y TS-0c-001 (backend Android) pasaron sus respectivas QA-reviews porque **cada lado se testó aislado**. No existe ni existió en el repo un test de integración cross-language (Rust desktop ↔ Kotlin Android) que hubiera detectado los Bugs #1/#2/#3. Esto es deuda crítica de testing — ver sección "Implicación de QA".

---

## Lo completado hoy

1. Aplicación de OD-007 documental (commits subidos a EquipoEnjambre + FlowWeaver, hashes `7e9fc37` y `2a70673`).
2. R14-mobile fix en código fuente — `MobileGallery.tsx` listener `visibilitychange`.
3. Safe-area fixes en código fuente — `App.css` + `index.html` `viewport-fit=cover`.
4. R16-fix + R16-hardening en código Android — `DriveRelayWorker.kt` con `ensureValidAccessToken()` + sealed class `TokenResult { Valid | RetryLater | Unrecoverable }`.
5. OAuth setup E2E: `client_id`, `client_secret`, `refresh_token` y `access_token` obtenidos. `drive_config.json` cifrado escrito en desktop, prefs Drive escritas en Android via `run-as`.
6. Bug del `^&` en `tmp_oauth_flow.js` diagnosticado y corregido — `replace(/&/g, '^&')` en `exec(start)` corrompía la URL al pasarla al navegador. Fix: no autoabrir browser, copia/pega manual. ~2h perdidas persiguiendo configuración Google Cloud cuando el problema era el script.
7. Tauri dev desktop relanzado — running con `drive_config.json` activo.
8. APK debug con R16 + R16-hardening instalado — pero **bundle JS desfasado** (NO incluye fixes R14-mobile ni safe-area).

---

## REPORTE A+B+C ÍNTEGRO

### Verificación A — Drive REST API

Llamada a `https://www.googleapis.com/drive/v3/files?spaces=appDataFolder` con access_token actual.

Total: **37 archivos** en `appDataFolder`.

Breakdown:

| Tipo | Esperado | Actual | Conclusión |
|---|---|---|---|
| `fw-android-<paired_id>-pending-*.json` (Android emite, Desktop lee) | ≥3 | **0** | ❌ Android no usa el naming convention esperado |
| `fw-android-<paired_id>-acked-*.json` (Desktop ACK al Android) | ≥1 | **0** | ❌ Desktop nunca lee del Android (no encuentra) |
| `fw-desktop-<id>-pending-*.json` (Desktop emite, Android lee) | variable | **13** ✅ | ✅ Desktop sí sube con naming correcto |
| `fw-desktop-<id>-acked-*.json` (Android ACK al Desktop) | ≥1 si Android leyó alguno | **0** | ❌ Android falla al procesar y nunca ACKa |
| Archivos huérfanos `<uuid>.json` puros (sin prefijo `fw-`) | 0 | **24** | 🚨 Son del Android — sube con nombre incorrecto sin prefijo |

Identificadores conocidos:
- `paired_android_id` = `android-53d34ffd-0e6d-484b-8eda-b55af7a4116c`
- `desktop_device_id` = `desktop-cf1e1e75-adae-5b90-8400-aaca0a732b50`

Los 4 UUIDs únicos del Android (subidos múltiples veces): `f431cd63`, `bf90596c`, `4db8deb9`, `4efd7506`.

### Verificación B — Logcat Android

`adb logcat -d -t 5000` filtrado por `DriveRelayWorker | ShareIntentActivity | FlowWeaver | WM-WorkerWrapper`.

Hallazgos:

1. ✅ Worker SE EJECUTA: `WM-WorkerWrapper: Worker result SUCCESS for Work [id=51e73937-2b73-4ac9-8236-73cf6c8f5568]` y `[id=fd6d6523-c3d7-4333-bbd5-95f05e36a21d]`.
2. ✅ Worker sube 4 eventos Android: `Uploaded Android event f431cd63`, `bf90596c`, `4db8deb9`, `4efd7506` — pero con nombre incorrecto (ver bug #1).
3. ✅ Worker descarga los `fw-desktop-*-pending-*.json` correctamente.
4. 🚨 **TODOS los 13 eventos descartados** con el mismo error:
   ```
   W/DriveRelayWorker: AES-GCM decrypt failed for desktop field: error:1e000065:Cipher functions:OPENSSL_internal:BAD_DECRYPT
   W/DriveRelayWorker: Cannot decrypt url for event <event_id> — pairing key mismatch? Skipping.
   ```
   13/13 descartados (ver bug #2).
5. ✅ Sin errores HTTP 4xx/5xx de Google API.

### Verificación C — BD desktop relay_events

⏸️ **NO EJECUTADA por falta de autorización explícita.** La BD es SQLCipher en `%LOCALAPPDATA%\flowweaver\resources.db` con clave determinística `fw-C:\Users\pinnovacion\AppData\Local\flowweaver` (hardcoded en `lib.rs:setup_db`, no secreta — pero seguí la regla "pídeme la key si hace falta, NO leas en frío"). Pendiente para próxima sesión.

---

## Los 4 bugs detectados — detalle técnico

### Bug #1 — Naming flat Drive AppData (afecta Android → Desktop)

**Causa raíz:** Drive AppData es **plano** (no jerárquico). El código del Worker construye el path con namespace pero al subir solo conserva el último segmento.

**Código afectado:**
- Archivo: `FlowWeaver/src-tauri/gen/android/app/src/main/java/com/flowweaver/app/DriveRelayWorker.kt`
- `uploadPendingAndroidEvents` (~línea 155):
  ```kotlin
  val remotePath = "$RELAY_ROOT/android-$deviceId/pending/$eventId.json"
  driveUploadOrUpdate(token, remotePath, eventJson)
  ```
- `driveUploadOrUpdate` (~líneas 455-457):
  ```kotlin
  val parts   = remotePath.split("/")
  val fileName = parts.last()  // ← solo "<event_id>.json", se pierde el namespace
  ```
- `driveListFiles` (~línea 508):
  ```kotlin
  val prefix = remotePath.split("/").last()  // → "pending"
  val q = "name contains '$prefix/' and trashed = false"  // busca 'pending/' literal — nunca matchea
  ```

**Qué impide:** Android sube `<event_id>.json` puro al root del AppData (24 archivos huérfanos en Drive). Desktop busca `fw-android-<paired>-pending-` con prefix flat — nunca encuentra. Sync Android → Desktop **completamente bloqueada**.

### Bug #2 — Crypto key derivation mismatch (afecta Desktop → Android)

**Causa raíz:** misma `shared_key_hex` en ambos lados pero **interpretación diferente** al derivar la clave AES.

**Código afectado:**
- Desktop `FlowWeaver/src-tauri/src/crypto.rs:97-102`:
  ```rust
  fn derive_key_aes(passphrase: &str) -> [u8; 32] {
      let mut h = Sha256::new();
      h.update(passphrase.as_bytes());
      h.finalize().into()
  }
  ```
  → toma el `shared_key_hex` como STRING ASCII de 64 chars y le aplica SHA-256 → 32 bytes derivados.
- Android `FlowWeaver/src-tauri/gen/android/app/src/main/java/com/flowweaver/app/DriveRelayWorker.kt:362-363`:
  ```kotlin
  val keyBytes = keyHex.hexToByteArray() ?: return null  // 32 bytes from 64 hex chars
  val secretKey = SecretKeySpec(keyBytes, "AES")
  ```
  → toma el `pairing_shared_key` como hex y decodifica a los 32 bytes literales que el hex representa.

**Qué impide:** dos claves AES distintas al cifrar/descifrar la misma carga útil. BAD_DECRYPT garantizado. Sync Desktop → Android **completamente bloqueada**. Visible en los 13/13 fallos del logcat.

**Decisión arquitectural pendiente:** ¿alinear a SHA-256(string) o a hex_decode literal? **Hay 13 eventos desktop ya en Drive cifrados con SHA-256(string)**, así que mantener desktop SHA-256 evita reescribir esa cola. Se decide alinear Android a SHA-256(string).

### Bug #3 — Android cifra upload con field key local, NO con pairing key

**Causa raíz:** ShareIntentActivity solo conoce la field key local Android (`FIELD_KEY_PASSPHRASE`, ligada al Keystore Android `fw2a`) y la usa para cifrar lo que sube a Drive, en lugar de la `pairing_shared_key` que sí podría ser descifrada por el desktop.

**Código afectado:**
- Archivo: `FlowWeaver/src-tauri/gen/android/app/src/main/java/com/flowweaver/app/ShareIntentActivity.kt`
- Líneas 90-92:
  ```kotlin
  val fieldKey       = FieldCrypto.deriveKey(FieldCrypto.FIELD_KEY_PASSPHRASE)
  val urlEncrypted   = FieldCrypto.encrypt(rawText, fieldKey)
  val titleEncrypted = FieldCrypto.encrypt(titleRaw, fieldKey)
  ```
- Líneas 96-106 (construcción del raw_event JSON que se sube):
  ```kotlin
  val rawEvent = JSONObject().apply {
      ...
      put("url_encrypted",   urlEncrypted)   // ← cifrado con field_key local Android
      put("title_encrypted", titleEncrypted) // ← cifrado con field_key local Android
      ...
  }
  ```

**Qué impide:** aunque arregláramos Bug #1 y Bug #2, el desktop NO podría descifrar lo del Android porque no tiene la `FIELD_KEY_PASSPHRASE` Android (ligada al Keystore Android, no compartible). El payload Android va cifrado con clave que solo Android conoce.

**Solución requerida:** ShareIntentActivity debe leer `pairing_shared_key` de SharedPreferences y usarla para cifrar el payload de tránsito, separadamente del cifrado local con field key Keystore que se mantiene para storage en LocalDb.

### Bug #4 — APK con bundle JS desfasado (independiente del relay)

**Causa raíz:** `tauri android build --debug` reusó assets cacheados de `src-tauri/gen/android/app/src/main/assets/` y no regeneró desde el `dist/` actualizado.

**Estado observado:**
- `dist/index.html` (12:44): `viewport-fit=cover` ✅
- `dist/assets/index-HeRMfNc0.js` (12:44): contiene `visibilitychange` x2 + `relay-event-imported` x1 ✅
- APK file local `app-universal-debug.apk` (12:44): bundle JS `index-x1gF9dye.js` SIN los fixes ❌
- APK instalado en tablet: mismo bundle viejo ❌

**Qué impide:** sin estos fixes en runtime:
- Galería mobile no se autorefresca tras un share (R14-mobile no funciona).
- UI tapada por status bar / gesture bar (safe-area no aplica).

**Solución requerida:** `cargo clean` + `rm -rf dist src-tauri/gen/android/app/src/main/assets/` + `npm run build` + `npx tauri android build --debug` (regeneración limpia desde cero).

---

## Implicación de QA — deuda crítica de testing

**Hecho:** los 3 bugs arquitecturales (#1, #2, #3) son del **protocolo entre Rust desktop y Kotlin Android**. Llevan en el código desde TS-0c-002 (2026-04-24, ~5 días). Pasaron QA-REVIEW-0c-002 y se commitearon como funcionales.

**Por qué nunca se detectaron:**
- Los tests de Rust desktop testean `crypto.rs::encrypt_aes / decrypt_aes` haciendo roundtrip dentro de Rust. Pasan trivialmente porque ambos lados usan SHA-256.
- Los tests de Kotlin Android (si existen) testean `FieldCrypto` aislado. Pasan trivialmente porque ambos lados usan hex_decode.
- Los tests de Rust contra `process_android_event` usan datos sintéticos cifrados con la misma lógica Rust → no detectan que Android cifra distinto.
- El test E2E `tests/e2e_relay_roundtrip.rs` (creado en sesión OD-007) usa **el mismo Rust en ambos lados** → no detecta divergencia con Kotlin.

**No existe ningún test que ejercite el protocolo cross-language real.** Esto es un **fallo de proceso**, no de implementación. La QA review aprobó cada lado por separado sin gate cross-language.

**Mitigación obligatoria** (a ejecutar antes de declarar el relay funcional, ver `SESSION-2026-04-29-resume.md`):
- Test que cifra desde Rust con `shared_key` y descifra desde Kotlin con la misma → debe pasar.
- Test que cifra desde Kotlin y descifra desde Rust → debe pasar.
- Test que valida naming convention idéntica en Drive AppData (mismo prefix de subida y query de búsqueda en ambos lados).

Sin estos tests no se cierran los Bugs #1/#2/#3.

**Riesgo a registrar (próxima sesión):** R20 — tests de integración cross-language ausentes en relay Android↔Desktop. Severidad CRÍTICA. Owner: QA Auditor + Sync & Pairing Specialist.

---

## Estado actual de cada componente

| Componente | Estado |
|---|---|
| `tauri dev` desktop (background ID `blfqtr0j2`) | ✅ Arriba, escuchando, `drive_config.json` activo |
| Conexión adb a tablet `OZ4H9HBYKNSWV86H` | ✅ Activa |
| `drive_config.json` desktop | ✅ Cifrado AES-256-GCM (`fw1a`) en `%APPDATA%\com.flowweaver.app\drive_config.json` (1602 hex chars) |
| Prefs Drive Android (`shared_prefs/flowweaver_relay.xml`) | ✅ 8 campos: `device_id`, `drive_access_token`, `drive_token_expires_at`, `drive_client_id`, `drive_client_secret`, `drive_refresh_token`, `pairing_shared_key`, `drive_oauth_state`(vacío) |
| APK instalado en tablet | ⚠️ uid 10196, bundle JS `index-x1gF9dye.js` SIN fixes R14-mobile/safe-area. SÍ tiene R16+R16-hardening |
| APK file local (`app-universal-debug.apk`, 12:44) | ⚠️ También sin fixes — `tauri android build` no regeneró bundle |
| `dist/` (frontend compilado) | ✅ Actualizado 12:44 con todos los fixes (`index-HeRMfNc0.js`) |
| Código fuente (FlowWeaver) | ✅ Todos los fixes aplicados, NO commiteado todavía (cambios desde push `2a70673`) |
| Drive AppData del usuario | 🚨 24 archivos huérfanos sin prefijo + 13 desktop_pending sin ACK |

---

## Cambios sin commit en repos

### `FlowWeaver/`
- `src-tauri/gen/android/app/src/main/java/com/flowweaver/app/DriveRelayWorker.kt` — R16-fix + R16-hardening (TokenResult sealed class). NO commiteado.

### `EquipoEnjambre/`
- `tmp_oauth_flow.js` — script con bug del `^&` arreglado (no abre navegador). Temporal, NO commiteable.
- `operations/sessions/SESSION-2026-04-29-state.md` — este archivo.
- `operations/sessions/SESSION-2026-04-29-resume.md` — plan de retoma.

---

## Archivos `tmp_*` pendientes (NO BORRAR HASTA PRÓXIMA SESIÓN)

Rutas absolutas — necesarias para retomar:

1. `C:\Users\pinnovacion\Desktop\EquipoEnjambre\tmp_oauth_flow.js` — script OAuth (sin secretos en sí, lee del JSON OAuth Downloads).
2. `C:\Users\pinnovacion\Desktop\EquipoEnjambre\tmp_oauth_tokens.json` — contiene `access_token`, `refresh_token`, `expires_in`, `scope`, `token_type`, `issued_at`. **CONTIENE SECRETOS.**
3. `C:\Users\pinnovacion\Desktop\EquipoEnjambre\tmp_drive_config_artifacts.json` — consolidado: `client_id`, `client_secret`, `access_token`, `refresh_token`, `expires_at`, `desktop_device_id`, `paired_android_id`, `shared_key_hex`, `app_data_dir`. **CONTIENE SECRETOS.**
4. `C:\Users\pinnovacion\Desktop\EquipoEnjambre\tmp_android_prefs.xml` — XML escrito en SharedPreferences Android. **CONTIENE SECRETOS** (refresh_token, client_secret).

⚠️ Estos archivos contienen secretos. **Borrar tras la documentación post-fix completa (Prioridad 5 de resume) y la rotación de credenciales** (R19).

---

## Riesgos pendientes a registrar (próxima sesión)

- **R16** → MITIGADO en código (no ABIERTO), severidad alta, bloqueante Fase 3 hasta verificación E2E real pasada.
- **R17** → ABIERTO. `refresh_token` caduca a 7 días en modo prueba Google Cloud. Severidad alta. Bloqueante Fase 3.
- **R18** → ABIERTO. Scripts auxiliares de setup sin tests automatizados. Severidad media.
- **R19** → ABIERTO. Secretos OAuth (`client_secret`, `refresh_token`) expuestos en log de sesión Claude Code 2026-04-29. Severidad media. Mitigación: rotar tras prueba de 7 días.
- **R20 NUEVO** → ABIERTO. Tests de integración cross-language ausentes en relay Android↔Desktop. Severidad **CRÍTICA**. Owner: QA Auditor + Sync & Pairing Specialist.
- **INC-001** — bug del `^&` en script OAuth (~2h perdidas).
- **INC-002 NUEVO** — los 4 bugs del relay, descripción de por qué nunca se detectaron, qué cambios de proceso evitan que vuelva a pasar.

---

## Update 2026-04-30 — Prio 2 CERRADA, Prio 1 PENDIENTE

### Prio 2 CERRADA

- **11 tests cross-lang (6 Rust + 5 Kotlin), 2 fixtures compartidas, 3h invertidas. Gate de tests satisfecho para bugs #1/#2/#3/#5.**
- Breakdown exacto verificado:
  - Rust (`cargo test --test cross_lang_crypto`): **3 passed; 0 failed; 0 ignored**.
  - Rust (`cargo test --test relay_naming_convention`): **2 passed; 0 failed; 1 ignored** (post-fix Bug #5).
  - Kotlin (`gradle :app:testUniversalDebugUnitTest`): **BUILD SUCCESSFUL**, 8 tests, 0 failures, 1 skipped (@Ignore Bug #5 counterpart). Distribuidos: SmokeTest 2 passing (no cross-lang), RelayCryptoTest 3 passing, RelayNamingTest 2 passing + 1 skipped.
- Cross-lang neto = 6 Rust + 6 Kotlin escritos (5+5 activos passing, 1+1 ignored guardando Bug #5).
- Fixtures: `src-tauri/tests/fixtures/cross_lang_vectors.json` (crypto) y `cross_lang_naming.json` (naming). Ambos lados las cargan en runtime — INC-002 root cause cerrado para los vectores cubiertos.
- Refactors no funcionales acompañantes: `RelayCrypto.kt`, `RelayNaming.kt`, helpers naming `drive_relay.rs` expuestos `#[doc(hidden)] pub`, `encrypt_aes_for_test_with_explicit_nonce` añadido. Sin cambio de comportamiento producción.
- Bug #5 detectado y documentado en `SESSION-2026-04-29-state-update-1.md` (causa raíz, impacto, fix propuesto, procedimiento de cierre).

### Prio 1 PENDIENTE — fixes en próxima sesión

**Orden estricto: #2 → #3 → #1 → #5 → #4.**

Estado a 2026-04-30 EOD:
- Bug #2 (Android crypto SHA-256 alignment) — **ya aplicado** en `DriveRelayWorker.decryptDesktopField` vía `RelayCrypto.decryptFw1a`. Pendiente validación E2E en device.
- Bug #3 (Android transit/local split) — **ya aplicado** en `ShareIntentActivity` vía `RelayCrypto.encryptFw1a`. Pendiente validación E2E.
- Bug #1 (flat naming) — **ya aplicado** en `DriveRelayWorker` vía `RelayNaming`. Pendiente validación E2E.
- Bug #5 (desktop_acked prefix con event_id vacío) — **NO aplicado**. Helper canónico `desktop_acked_prefix` existe pero línea 314 sigue rota. Tests en doble capa lo guardan.
- Bug #4 (rebuild APK con bundle JS fresh) — **NO aplicado**. Pendiente tras todos los anteriores.

Próxima sesión empieza por validación de tests existentes + fix Bug #5 + rebuild + E2E.

---

## Update 2026-04-30 EOD — VALIDACIÓN E2E EXITOSA

**Estado: PUENTE OPERATIVO. Día 0 de la prueba de 7 días: 2026-04-30.**

### Prio 1 CERRADA

- Bug #5 fix aplicado: `drive_relay.rs:334` → `desktop_acked_prefix(&config.device_id)`.
- Tests finales: `relay_naming_convention` → **3 passed, 0 failed, 0 ignored** (post-fix Bug #5 activado, characterization test retenido como pin de contrato).
- Bug #4 (rebuild APK): rebuild limpio ejecutado. APK instalado en tablet `OZ4H9HBYKNSWV86H`.
- Prefs Android reescritas con access_token renovado.

### Validación E2E

- Latencia: ~30 segundos P50. P95 < 60s. **R15 MITIGADO.**
- Consistencia: 5 URLs compartidas → 5 recibidas en desktop. 0 pérdidas.
- Desktop se actualizó solo sin acción del usuario. **R14 desktop MITIGADO.**
- R14 mobile (galería tablet): APK rebuild activo. Bajo observación durante los 7 días.

### Hallazgos de producto (día 1)

Documentados en `operations/validation/VALIDATION-7DAY-day1-findings.md`.

- **H-001** (severidad media): YouTube no guarda título. Fix planificado para próxima sesión.
- **H-002** (severidad media): Categorías demasiado genéricas. Defer post-7-días.
- **H-003** (severidad alta): 5 películas de terror no se agrupan como episodio. Diagnóstico + fix planificado para próxima sesión.

### Documentación Prio 5 completada

- `operations/validation/VALIDATION-7DAY-day1-findings.md` — creado.
- `operations/incidents/INC-001-oauth-script-escape-bug.md` — creado.
- `operations/incidents/INC-002-bridge-bidirectional-broken.md` — creado (incluye Bug #5).
- `operations/handoffs/HO-024-drive-oauth-setup-completed.md` — creado.
- `operations/architecture-notes/AN-oauth-edge-cases.md` — creado (9 casos).
- `Project-docs/risk-register.md` — R14 parcialmente mitigado, R15 mitigado, R16-R20 añadidos.
- Archivos `tmp_*` — **PENDIENTES DE BORRAR** (ver nota abajo).

### Nota sobre tmp_*

Los archivos `tmp_*` NO se borran hasta la rotación de secretos (R19). Contienen los tokens activos que se necesitan para renovar las prefs Android si la sesión se reinicia antes de los 7 días. Borrar después de rotar en ~2026-05-06.
