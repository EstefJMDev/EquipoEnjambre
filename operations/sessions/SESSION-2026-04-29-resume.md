# SESSION RESUME — Próxima sesión tras 2026-04-29

**ANTES DE NADA:** lee `SESSION-2026-04-29-state.md` íntegro. Contiene el reporte A+B+C, los 4 bugs detectados con detalle técnico, la implicación de QA (deuda crítica de testing cross-language), el estado de cada componente y los archivos `tmp_*` que NO se han borrado.

**ACTUALIZACIÓN 2026-04-30:** lee también `SESSION-2026-04-29-state-update-1.md`.
Documenta Bug #5 (desktop_acked con event_id vacío) detectado durante Phase 2.3 de Prio 2.
**Orden de fixes revisado:** #2 → #3 → #1 → **#5** → #4. Bugs #2/#3/#1 ya aplicados durante 2026-04-30. Tests cross-language MVP (Phases 2.1+2.2+2.3) cerrados. Bug #5 pendiente de fix en sesión de Prio 1 extendida.

---

## Plan de retoma — 5 prioridades en orden estricto

**Las prioridades 1, 2, 3 y 4 NO se pueden paralelizar.** Cada una bloquea a la siguiente. Se valida cada paso antes de empezar el siguiente.

---

## PRIORIDAD 1 — Arreglar los 4 bugs en orden estricto

### Orden obligatorio de los fixes

**No es el orden lógico de "primero lo más fácil", es el orden de dependencia funcional.** Cada bug bloquea al siguiente.

### a) Bug #2 PRIMERO — Crypto key derivation mismatch

**Por qué primero:** sin esto Android sigue sin descifrar nada del desktop, aunque corrijamos los demás bugs.

**Decisión arquitectural — formato canónico de la clave:**

Hay dos opciones técnicamente válidas:
- Opción A: `hex_decode` literal (Android actual).
- Opción B: `SHA-256(string)` (Desktop actual).

**Decisión recomendada: alinear Android a SHA-256(string)**, manteniendo Desktop como está. Razones:

1. **Hay 13 eventos desktop ya en Drive cifrados con SHA-256(string)**. Si cambiamos desktop a hex literal, esos 13 eventos se vuelven irrecuperables.
2. La clave `shared_key_hex` es ya de 32 bytes random de alta entropía generados por `crypto.randomBytes(32)`. Hacer SHA-256 sobre los 64 chars hex no debilita la entropía resultante (sigue siendo 256 bits efectivos).
3. Modificar Android es 1 archivo (`DriveRelayWorker.kt`); modificar Desktop sería tocar `crypto.rs` que está en path de tests existentes y pinea contrato wire en `tests/e2e_relay_roundtrip.rs`.

**Acción:**
- Archivo: `FlowWeaver/src-tauri/gen/android/app/src/main/java/com/flowweaver/app/DriveRelayWorker.kt`
- En `decryptDesktopField` (~línea 350) reemplazar:
  ```kotlin
  val keyBytes = keyHex.hexToByteArray() ?: return null  // 32 bytes from 64 hex chars
  val secretKey = SecretKeySpec(keyBytes, "AES")
  ```
  por:
  ```kotlin
  val keyBytes = MessageDigest.getInstance("SHA-256")
      .digest(keyHex.toByteArray(Charsets.UTF_8))  // SHA-256 del string hex completo
  val secretKey = SecretKeySpec(keyBytes, "AES")
  ```
- Hacer cambio simétrico en cualquier punto del Worker que cifre con `pairing_shared_key` (será necesario también para Bug #3 — se pueden hacer juntos).

**Verificación antes de declarar resuelto:**
- Test cross-language obligatorio (ver Prioridad 2).
- Re-ejecutar Worker en device (`adb shell cmd jobscheduler run` o trigger via share). En logcat debe desaparecer `BAD_DECRYPT` de los 13 eventos pending del desktop.

**Documentar la decisión** en INC-002 (Prioridad 5) con justificación de "13 eventos legacy ya cifrados así".

### b) Bug #3 SEGUNDO — Android cifra upload con field key local

**Por qué después de #2:** sin Bug #2 arreglado, aunque Android cifre con `pairing_shared_key`, Desktop no podría descifrarlo (mismo mismatch en sentido inverso).

**Acción:**
- Archivo: `FlowWeaver/src-tauri/gen/android/app/src/main/java/com/flowweaver/app/ShareIntentActivity.kt`
- Líneas 90-92, separar el cifrado de tránsito del cifrado local:
  ```kotlin
  // Tránsito (lo que sube a Drive) — cifrado con pairing_shared_key (compartida con desktop)
  val pairingKeyHex = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
      .getString("pairing_shared_key", null)
      ?: run { Log.e(TAG, "pairing_shared_key not configured"); finish(); return }
  val pairingKey = MessageDigest.getInstance("SHA-256")
      .digest(pairingKeyHex.toByteArray(Charsets.UTF_8))
  val urlEncryptedTransit   = encryptAesGcm(rawText,  pairingKey)
  val titleEncryptedTransit = encryptAesGcm(titleRaw, pairingKey)

  // Local (LocalDb storage) — sigue con field_key local Android via Keystore
  val fieldKey       = FieldCrypto.deriveKey(FieldCrypto.FIELD_KEY_PASSPHRASE)
  val urlEncryptedLocal   = FieldCrypto.encrypt(rawText,  fieldKey)
  val titleEncryptedLocal = FieldCrypto.encrypt(titleRaw, fieldKey)
  ```
- En el `rawEvent` JSON usar `urlEncryptedTransit` y `titleEncryptedTransit`.
- En `db.insertOrIgnore` usar `urlEncryptedLocal` y `titleEncryptedLocal`.
- La función `encryptAesGcm` puede compartirse con `decryptDesktopField` (es la operación inversa de la misma).

**Verificación antes de declarar resuelto:**
- Test cross-language: Kotlin cifra con `pairing_shared_key` → Rust descifra con misma clave (Bug #2 ya resuelto) → contenido idéntico.

### c) Bug #1 TERCERO — Naming flat Drive AppData

**Por qué después de #2 y #3:** los uploads del Android quedarán correctamente cifrados (gracias a #3) pero hace falta el naming correcto para que Desktop los encuentre.

**Acción:**
- Archivo: `FlowWeaver/src-tauri/gen/android/app/src/main/java/com/flowweaver/app/DriveRelayWorker.kt`
1. En `uploadPendingAndroidEvents` (~línea 155): cambiar a naming flat con prefijo:
   ```kotlin
   val remoteName = "fw-android-$deviceId-pending-$eventId.json"
   driveUploadOrUpdate(token, remoteName, eventJson)
   ```
2. En `driveUploadOrUpdate`: dejar de hacer `parts.last()` — usar el name tal cual recibido.
3. En `readAndroidAcks`: buscar con prefix flat `fw-android-$deviceId-acked-`.
4. En `downloadDesktopEvents`: buscar `fw-desktop-$pairedDesktopId-pending-`.
   - **Requiere conocer `paired_desktop_id`**. Añadir nueva pref `paired_desktop_id` en SharedPreferences. El desktop debe escribirla en alguna parte que Android pueda leer (o forzar que el usuario la introduzca en setup, o transportarla en el primer ACK).
   - **Decisión pendiente:** en este flow controlado, simplemente añadir el `paired_desktop_id` al `tmp_android_prefs.xml` y reescribirlo via `run-as` igual que hicimos en sesión 2026-04-29.
5. En `writeDesktopAck`: usar `fw-desktop-$pairedDesktopId-acked-$eventId.json` flat.

**Verificación antes de declarar resuelto:**
- Test cross-language de naming convention (ver Prioridad 2).
- Tras un share desde tablet, llamada Drive REST debe mostrar `fw-android-<paired>-pending-<event_id>.json` (no `<event_id>.json` puro).
- Tras leer el desktop, llamada Drive REST debe mostrar `fw-desktop-<id>-acked-<event_id>.json` con event_id correspondiente.

### d) Bug #4 CUARTO — APK con bundle JS desfasado

**Por qué al final:** los Bugs #1/#2/#3 son del side Kotlin del Android. Cuando arreglamos #1/#2/#3 hay que rebuild Android igual. El bug del bundle JS desfasado (frontend Tauri React) afecta solo la galería UI mobile, no el relay. Lo arreglamos en el mismo rebuild final.

**Acción:**
```bash
cd C:/Users/pinnovacion/Desktop/FlowWeaver
rm -rf src-tauri/gen/android/app/src/main/assets/  # borrar caché de assets stale
rm -rf dist                                          # forzar regeneración del frontend
cargo clean --target-dir src-tauri/target            # opcional, limpieza Rust
npm run build                                        # regenera dist/ con todos los fixes
npx tauri android build --debug                      # bundle JS y kotlin nuevos
```

**Verificación antes de declarar resuelto:**
1. Extraer el nuevo APK con `unzip` y verificar:
   - `grep -E "visibilitychange|relay-event-imported" assets/assets/*.js` → 3+ matches.
   - `grep "viewport-fit=cover" assets/index.html` → match.
   - `grep -E "fw-android-.*-pending-" classes.dex` (o equivalente) → match (Bug #1 fix presente en kotlin compilado).
2. `adb uninstall com.flowweaver.app` (perderá prefs Drive — reescribir tras install).
3. `adb install <nuevo-apk>`.
4. Reescribir prefs Android via `tmp_android_prefs.xml` (ver paso 1.5 de la sesión anterior).
5. Lanzar app, verificar UI safe-area OK, hacer un share, verificar que la galería se autorefresca tras volver de la share.

---

## PRIORIDAD 2 — Tests de integración cross-language obligatorios

**No se cierra ningún Bug #1/#2/#3 sin estos tests.** Sin ellos, el bug puede volver en cualquier rebuild posterior.

### Tests requeridos

**Test A — Crypto roundtrip cross-language:**
- Test que cifra desde Rust con `shared_key_hex` (vía `crypto::encrypt_aes`) y lo descifra desde Kotlin (con la lógica de `DriveRelayWorker.decryptDesktopField`) — el plaintext recuperado debe ser idéntico.
- Test simétrico: cifra desde Kotlin con `pairing_shared_key`, descifra desde Rust — idéntico.
- Implementación práctica: subprocess Kotlin (jvm-compatible) invocado desde test de Rust, o golden file con ciphertexts pre-generados de cada lado y descifrados en el otro.

**Test B — Naming convention:**
- Test que valida que el nombre que Android sube (función a extraer en helper testable) y el patrón que Desktop busca (función `drive_list_prefix` en `drive_relay.rs`) producen match.
- Lo mismo en sentido inverso.

**Test C — Wire format:**
- Test que cifra un evento completo desde Android, lo serializa a JSON, lo deserializa en Rust, y lo procesa con `process_android_event`. Debe producir `Ok(resource_uuid)` con el UUID v5 esperado.
- Ya existe parcialmente en `tests/e2e_relay_roundtrip.rs` (creado en sesión OD-007) pero **usa Rust en ambos lados**. Hay que extender con golden files generados por Kotlin real.

### Donde van los tests

- Test A y C: añadir a `FlowWeaver/src-tauri/tests/e2e_relay_roundtrip.rs` (extender el ignored test existente con golden files cross-language).
- Test B: archivo nuevo `FlowWeaver/src-tauri/tests/relay_naming_convention.rs`.

### Bloqueante

**Sin estos tests** los Bugs #1/#2/#3 no se cierran. Aunque el flow E2E manual pase (Prioridad 4), la regresión está garantizada en cualquier rebuild que toque crypto, naming o el contrato wire.

---

## PRIORIDAD 3 — Limpiar 24 archivos huérfanos en Drive AppData

**Por qué:** los archivos sin prefijo `fw-` que el Android subió mal son ruido. Pueden quedarse como basura inocua, pero conviene borrarlos antes de testing E2E para evitar confusión en logs futuros.

**Acción:**
- Script Node con Drive REST API:
  ```javascript
  // Lista archivos sin prefijo "fw-" en appDataFolder y los borra.
  // DELETE https://www.googleapis.com/drive/v3/files/<fileId>
  ```
- Pueden quedarse o borrarse, decisión del PO.

---

## PRIORIDAD 4 — Validación E2E real

**Solo después de Prioridades 1, 2 y 3 hechas.**

### Pasos

1. Tabletas y desktop arriba.
2. Compartir un URL real desde tablet (no de prueba).
3. Esperar ≤30s + propagación Drive (~30s real).
4. Ver que aparece en desktop sin tocar nada (R14 fix + relay funcionando).
5. Compartir un segundo URL del mismo dominio o tema.
6. Verificar que se agrupa con el primero en `Panel A` / `Episode Detector` desktop.

**Criterio de éxito:** ambos URLs aparecen automáticamente en desktop, agrupados, sin acción del usuario en desktop.

**Si falla:** diagnóstico antes de seguir. NO improvisar fixes.

---

## PRIORIDAD 5 — Documentación post-fix

**Solo después de Prioridad 4 OK.** Esta es la documentación que se postpuso del Paso 7 ampliado de la sesión 2026-04-29.

### Documentos a crear/modificar

| # | Documento | Resumen |
|---|---|---|
| 5.1 | `Project-docs/risk-register.md` R16 → MITIGADO en código | Severidad alta, bloqueante Fase 3 hasta verificación E2E pasada (ahora pasada). |
| 5.2 | `operations/handoffs/HO-024-drive-oauth-setup-completed.md` | **Solo cuando todo lo anterior esté hecho.** Fecha, valores usados (sin secretos), sección "Lecciones aprendidas" sobre el bug del `^&`. |
| 5.3 | `operations/architecture-notes/AN-oauth-edge-cases.md` | Inventario de 9 casos: refresh revocado, password change, quota agotada, conectividad, reloj desfasado, refresh caducado por inactividad 6m, password change Google, scopes parciales, refresh caduca 7d en modo prueba. |
| 5.4 | `operations/incidents/INC-001-oauth-script-escape-bug.md` | Síntoma, hipótesis incorrecta perseguida (~2h), causa raíz (`replace(/&/g, '^&')`), método de diagnóstico (lectura literal del mensaje de Google), fix. |
| 5.5 | `Project-docs/risk-register.md` R17 ABIERTO | `refresh_token` caduca a 7 días en modo prueba Google Cloud. Severidad alta. Bloqueante Fase 3. Owner: Sync & Pairing Specialist. |
| 5.6 | `Project-docs/risk-register.md` R18 ABIERTO | Scripts auxiliares de setup sin tests automatizados. Severidad media. Mitigación Fase 3: mover OAuth setup a UI de FlowWeaver. |
| 5.7 | `Project-docs/risk-register.md` R19 ABIERTO | Secretos OAuth expuestos en log de sesión Claude Code 2026-04-29. Severidad media. Mitigación: rotar `client_secret` + revocar `refresh_token` tras prueba de 7 días. |
| 5.8 | **`Project-docs/risk-register.md` R20 ABIERTO — NUEVO** | "Tests de integración cross-language ausentes en relay Android↔Desktop. Severidad **CRÍTICA**. Detectado en sesión 2026-04-29. Owner: QA Auditor + Sync & Pairing Specialist. Mitigación: añadir test suite de integración como gate obligatorio antes de cualquier modificación al relay protocol." |
| 5.9 | **`operations/incidents/INC-002-bridge-bidirectional-broken.md` — NUEVO** | Los 4 bugs del relay detectados en sesión 2026-04-29. Por qué nunca se detectaron (cada lado testeado aislado, sin gate cross-language). Cómo se diagnosticó (verificación A Drive REST API + verificación B logcat). Plan de fix aplicado en orden estricto #2 → #3 → #1 → #4. **Cambios de proceso para que no vuelva a pasar:** Prioridad 2 (tests cross-language) como gate obligatorio antes de QA-review de cualquier cambio en `crypto.rs`, `drive_relay.rs`, `DriveRelayWorker.kt`, `ShareIntentActivity.kt`, `FieldCrypto.kt`. |

### Borrar archivos `tmp_*`

Solo después de la documentación post-fix completa **Y** de la rotación de secretos (R19):

- `tmp_oauth_flow.js`
- `tmp_oauth_tokens.json`
- `tmp_drive_config_artifacts.json`
- `tmp_android_prefs.xml`

---

## FUERA DE SCOPE de la próxima sesión

- ❌ **NO reabrir D22 / OD-007.** Mantener decisión vigente. La sesión 2026-04-29 cerró el debate de producto.
- ❌ **NO empezar la prueba de 7 días hasta que el relay funcione.** El día 0 sigue siendo "cuando el puente funcione end-to-end al menos una vez". 2026-04-29 NO es ese día.
- ❌ **NO trabajar en captura automática / observador semi-pasivo / Pattern Detector móvil.** Sigue bloqueado por OD-007.

---

## Cómo retomar — checklist (revisado 2026-04-30)

**Contexto al inicio:** Bugs #2/#3/#1 ya aplicados en código durante 2026-04-30. Prio 2 (tests cross-lang MVP) cerrada. Falta validación E2E + fix Bug #5 + rebuild.

1. **Leer `SESSION-2026-04-29-state.md`** íntegro (incluye Update 2026-04-30) + `SESSION-2026-04-29-state-update-1.md` (Bug #5).
2. **Verificar tests siguen verdes overnight** (sanity check antes de tocar nada):
   ```bash
   cd C:/Users/pinnovacion/Desktop/FlowWeaver/src-tauri
   cargo test --test cross_lang_crypto              # esperado: 3 passed
   cargo test --test relay_naming_convention        # esperado: 2 passed, 1 ignored
   cd gen/android && ./gradlew :app:testUniversalDebugUnitTest --no-daemon   # esperado: BUILD SUCCESSFUL, 8 tests, 0 failures, 1 skipped
   ```
   Si algo está rojo, **paro y diagnostico antes de seguir**. Cualquier cambio overnight es señal de drift inesperado.
3. **Fix Bug #2** — crypto key derivation mismatch.
   - Cambio ya aplicado en código (`DriveRelayWorker.decryptDesktopField` → `RelayCrypto.decryptFw1a` con `SHA-256(keyHex.utf8)`).
   - Validación: cuando se haga rebuild + reinstall + share desde tablet, los 13 events legacy deben dejar de generar `BAD_DECRYPT` en logcat.
   - **Inversión esperada de tests crypto post-fix:** los tests crypto NO necesitan invertirse (no hay characterization activo de Bug #2 — el fix es Android-side y no quedó test ignored para él). Solo aplica a Bug #5.
4. **Fix Bug #3** — transit vs local encryption split. Ya aplicado en `ShareIntentActivity`. Pendiente validación E2E.
5. **Fix Bug #1** — flat naming. Ya aplicado en `DriveRelayWorker` vía `RelayNaming`. Pendiente validación E2E.
6. **Fix Bug #5** — desktop_acked prefix con event_id vacío.
   - Editar `src-tauri/src/drive_relay.rs:314`: sustituir `desktop_acked(&config.device_id, "")` por `desktop_acked_prefix(&config.device_id)` (helper ya existe `#[doc(hidden)] pub`).
   - **Inversión esperada de tests post-fix:**
     - El test characterization activo `characterization_bug5_desktop_acked_with_empty_event_id_yields_broken_prefix` sigue verde (la fn `desktop_acked` sin call site no cambia). Borrarlo solo si se considera ruido — opcional, decisión PO.
     - El test ignored `desktop_acked_prefix_matches_fixture_post_bug5_fix`: quitar `#[ignore]` y verificar que pasa con `cargo test --test relay_naming_convention`.
     - Kotlin counterpart `desktop_acked_prefix_post_bug5_fix_kotlin_counterpart`: dejar `@Ignore` (no aplica salvo que el Worker Kotlin necesite listar ACKs, que hoy no es el caso).
7. **Fix Bug #4** — rebuild APK limpio.
   ```bash
   cd C:/Users/pinnovacion/Desktop/FlowWeaver
   rm -rf src-tauri/gen/android/app/src/main/assets/
   rm -rf dist
   cargo clean --target-dir src-tauri/target
   npm run build
   npx tauri android build --debug
   ```
8. **Reinstalar en tablet** (`OZ4H9HBYKNSWV86H`):
   ```bash
   adb uninstall com.flowweaver.app   # perderá prefs Drive
   adb install <path-al-APK-nuevo>
   ```
   Reescribir prefs Android via `tmp_android_prefs.xml` (incluye ya `paired_desktop_id` añadido en Bug #1 fix). Si access_token caducó (>1h), regenerar con refresh_token via `POST oauth2.googleapis.com/token grant_type=refresh_token`.
9. **Validación E2E real del puente** (Prio 4 del plan original).
   - Tablet share URL → ≤30s + ~30s propagación Drive → aparece en desktop sin acción manual.
   - Segundo URL del mismo dominio → se agrupa en Panel A / Episode Detector.
   - Verificar logcat: sin `BAD_DECRYPT`, sin nombres con doble prefijo, lista pending desktop se limpia (gracias a Bug #5 fix).
10. **Si E2E pasa** → arrancar Prio 5 documentación (HO-024, AN-oauth-edge-cases, INC-001, INC-002 actualizado con Bug #5 sub-hallazgo, R16/R17/R18/R19/R20). Borrado de archivos `tmp_*` solo después de rotación R19.
11. **Si E2E falla** → diagnóstico antes de improvisar fixes. NO improvisar.

### Prerequisitos de entorno

- `tauri dev` desktop arriba o relanzable: `cd FlowWeaver && npm run tauri dev` en background.
- `adb devices` muestra `OZ4H9HBYKNSWV86H`.
- Archivos `tmp_*` intactos (NO borrar hasta Prio 5 + rotación de secretos).
- Variables entorno: `JAVA_HOME` (JDK 17 Microsoft), `ANDROID_HOME`, `NDK_HOME` (ver CLAUDE.md).

---

## Decisiones pendientes del product owner

1. **Crypto key alignment** (Bug #2): aceptar la recomendación de "alinear Android a SHA-256(string)" o sugerir alternativa. Default propuesto: SHA-256.
2. **Limpieza Drive AppData** (Prioridad 3): borrar los 24 archivos huérfanos o dejarlos como basura inocua.
3. **Rotación post-test** (R19): tras los 7 días con datos reales, rotar `client_secret` + revocar `refresh_token`.
