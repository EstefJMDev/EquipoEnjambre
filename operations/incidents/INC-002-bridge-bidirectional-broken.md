# INC-002 — Puente bidireccional Android↔Desktop roto (4+1 bugs)

date_detected: 2026-04-29
date_resolved: 2026-04-30
severity: crítica (relay nunca había funcionado end-to-end)
status: CERRADO — E2E validado 2026-04-30 (5/5 URLs, latencia ~30s)

---

## Descripción

El relay Android↔Desktop (Drive AppData como bus) nunca había funcionado end-to-end. Los lados Rust (desktop) y Kotlin (Android) se testearon aisladamente. Al hacer la primera validación E2E real el 2026-04-29, se detectaron 4 bugs arquitecturales + 1 bug de desktop (Bug #5) que bloqueaban la comunicación completa.

---

## Por qué no se detectaron antes

Los tests de Rust validaban `crypto.rs::encrypt_aes/decrypt_aes` haciendo roundtrip dentro de Rust (mismo lado). Los tests de Kotlin (si existían) validaban `FieldCrypto` aislado. El test E2E `tests/e2e_relay_roundtrip.rs` usaba Rust en ambos lados.

**No existía ningún test que ejercitara el protocolo cross-language real (Rust desktop ↔ Kotlin Android).** La QA-review aprobó cada lado por separado sin gate cross-language. Esto es el fallo de proceso raíz.

---

## Bug #1 — Naming flat Drive AppData (Android → Desktop)

**Causa:** Drive AppData es plano. `DriveRelayWorker.driveUploadOrUpdate` hacía `remotePath.split("/").last()` perdiendo el namespace.

**Impacto:** Android subía `<event_id>.json` puro (sin prefijo `fw-`). Desktop buscaba `fw-android-*-pending-*` y no encontraba nada. 24 archivos huérfanos acumulados en Drive.

**Fix:** `RelayNaming.kt` + helpers `android_pending_prefix` / `android_acked` en `drive_relay.rs`. Naming flat con prefijo canónico en ambos lados.

---

## Bug #2 — Crypto key derivation mismatch (Desktop → Android)

**Causa:** misma `shared_key_hex` pero interpretación diferente al derivar la clave AES.
- Desktop (`crypto.rs`): `SHA-256(keyHex.as_bytes())` → 32 bytes derivados.
- Android (`DriveRelayWorker`): `keyHex.hexToByteArray()` → 32 bytes literales del hex.

**Impacto:** claves AES distintas al cifrar/descifrar. `BAD_DECRYPT` en 13/13 eventos desktop. Sync Desktop→Android bloqueada.

**Decisión:** alinear Android a `SHA-256(string)` para no invalidar los 13 eventos desktop ya cifrados.

**Fix:** `RelayCrypto.decryptFw1a` en Kotlin usa `MessageDigest.SHA-256` sobre el string hex.

---

## Bug #3 — Android cifra upload con field key local (Android → Desktop)

**Causa:** `ShareIntentActivity` cifraba el payload de tránsito con `FIELD_KEY_PASSPHRASE` (ligada al Keystore Android), en lugar de la `pairing_shared_key` compartida con el desktop.

**Impacto:** aunque se arreglaran #1 y #2, el desktop no podía descifrar el payload Android porque no tiene acceso al Keystore Android.

**Fix:** `RelayCrypto.encryptFw1a` en Kotlin. `ShareIntentActivity` separa cifrado de tránsito (pairing_key) del cifrado local (field_key Keystore).

---

## Bug #4 — APK con bundle JS desfasado

**Causa:** `tauri android build --debug` reutilizó assets cacheados de `src/main/assets/` sin regenerar desde `dist/`.

**Impacto:** fixes R14-mobile (visibilitychange) y safe-area no activos en el APK instalado.

**Fix:** `rm -rf src-tauri/gen/android/app/src/main/assets/ dist` + `npm run build` + `npx tauri android build --debug`.

---

## Bug #5 — `desktop_acked` con event_id vacío (Desktop, sub-hallazgo)

**Detectado:** 2026-04-30 durante Phase 2.3 de Prio 2.

**Causa:** `drive_relay.rs:334` usaba `desktop_acked(&config.device_id, "")` para construir el prefijo de búsqueda de ACKs. Con `event_id=""` el prefijo resultante era `"fw-{id}-acked-.json"`, que nunca matchea contra ACKs reales (`"fw-{id}-acked-{event_id}.json"`).

**Impacto:** desktop nunca veía ACKs escritos por Android. Cola pending crecía monótonamente. Sin corrupción de datos.

**Fix:** `drive_relay.rs:334` → `desktop_acked_prefix(&config.device_id)` que retorna `"fw-{id}-acked-"`.

---

## Tests cross-language añadidos como gate obligatorio

**Ubicación:**
- `src-tauri/tests/cross_lang_crypto.rs` — 3 tests Rust (crypto roundtrip)
- `src-tauri/tests/relay_naming_convention.rs` — 3 tests Rust (naming convention)
- `app/src/test/.../RelayCryptoTest.kt` — 3 tests Kotlin
- `app/src/test/.../RelayNamingTest.kt` — 3 tests Kotlin + 1 @Ignore (Bug #5 post-fix)
- `app/src/test/.../SmokeTest.kt` — 2 tests Kotlin (smoke)

**Fixtures compartidas:**
- `src-tauri/tests/fixtures/cross_lang_vectors.json` — vectores de crypto
- `src-tauri/tests/fixtures/cross_lang_naming.json` — tabla de naming (3 casos)

**Estado a cierre:** `cargo test --test cross_lang_crypto` → 3 passed. `cargo test --test relay_naming_convention` → 3 passed, 0 ignored. Kotlin → BUILD SUCCESSFUL, 8 tests, 0 failures.

---

## Cambios de proceso para evitar recurrencia

**Gate obligatorio antes de cualquier QA-review de cambios en:**
- `crypto.rs`
- `drive_relay.rs`
- `DriveRelayWorker.kt`
- `ShareIntentActivity.kt`
- `FieldCrypto.kt`
- `RelayCrypto.kt`
- `RelayNaming.kt`

**Gate:** `cargo test --test cross_lang_crypto && cargo test --test relay_naming_convention` y `gradle :app:testUniversalDebugUnitTest` deben pasar en verde antes de abrir QA-review.

**Regla:** nunca validar un protocolo cross-language testando cada lado de forma aislada.

---

## Validación final

- E2E completo: 2026-04-30.
- Latencia: ~30s. P95 < 60s. R15 MITIGADO.
- 5 URLs compartidas desde Android → 5 recibidas en desktop. 0 pérdidas.
- R14 desktop: MITIGADO.
