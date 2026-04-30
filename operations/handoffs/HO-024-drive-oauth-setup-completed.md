# HO-024 — Drive OAuth Setup Completado + E2E del Puente Validado

date: 2026-04-30
from: Sync & Pairing Specialist
to: Orchestrator
status: CERRADO
related: INC-001, INC-002, SESSION-2026-04-29-state.md

---

## Qué se completó

### Setup OAuth Drive

- Credenciales obtenidas: `client_id`, `client_secret`, `refresh_token`, `access_token`.
- `drive_config.json` cifrado AES-256-GCM (`fw1a`) escrito en `%APPDATA%\com.flowweaver.app\drive_config.json`.
- SharedPreferences Android escritas via `run-as` con 8 campos: `device_id`, `drive_access_token`, `drive_token_expires_at`, `drive_client_id`, `drive_client_secret`, `drive_refresh_token`, `pairing_shared_key`, `paired_desktop_id`.
- `pairing_shared_key`: `a49cf18e187ece5c53d97ff20706b0c8c0afc035504bf5eb87ca54a1cafc50e5` (32 bytes random, hex).
- `paired_desktop_id`: `desktop-cf1e1e75-adae-5b90-8400-aaca0a732b50`.
- `android_device_id`: `android-53d34ffd-0e6d-484b-8eda-b55af7a4116c`.

*Nota: no se incluyen los valores de token en este documento. Ver `tmp_drive_config_artifacts.json` mientras esté disponible. Rotar tras 7 días de prueba (R19).*

### Bugs del relay corregidos

5 bugs corregidos (INC-002). Ver detalle en `INC-002-bridge-bidirectional-broken.md`.

- Bug #1: naming flat Drive AppData → fix `RelayNaming.kt` + `drive_relay.rs`
- Bug #2: crypto key derivation mismatch → fix `RelayCrypto.decryptFw1a` (SHA-256 alignment)
- Bug #3: Android cifra con field key local → fix `RelayCrypto.encryptFw1a` (transit/local split)
- Bug #4: APK con bundle JS desfasado → rebuild limpio
- Bug #5: `desktop_acked` con event_id vacío → fix línea 334 `drive_relay.rs`

### Tests cross-language

11 tests añadidos (6 Rust + 5 Kotlin activos). Gate obligatorio pre-QA-review de cualquier cambio en el protocolo relay.

### E2E validado

- Fecha: 2026-04-30.
- Resultado: 5/5 URLs recibidas en desktop. Latencia ~30s. P95 < 60s.
- R14 desktop MITIGADO. R15 MITIGADO.

---

## Lecciones aprendidas

**INC-001 — Bug del `^&` en script OAuth:**
Al construir comandos shell para Windows con URLs en comillas dobles, no aplicar `replace(/&/g, '^&')`. El escape `^` es para argumentos sin comillas. Con comillas, el `^` pasa literalmente al receptor y corrompe la URL. Solución aplicada: no autoabrir el navegador, copiar/pegar manual.

**INC-002 — Protocolo cross-language no testado:**
Nunca validar un protocolo entre dos lenguajes (Rust ↔ Kotlin) testando cada lado de forma aislada. El relay llevaba 5+ días en el repositorio con tests verdes y el protocolo roto. Gate cross-language obligatorio a partir de ahora.

---

## Estado de riesgos al cierre

| Riesgo | Estado |
|---|---|
| R14 (workspace no refresca) | MITIGADO en desktop. Mobile bajo observación (APK rebuild 2026-04-30). |
| R15 (latencia relay no medida) | MITIGADO — ~30s P50, P95 < 60s medido en day 1. |
| R16 (token refresh) | MITIGADO en código — `ensureValidAccessToken()` + `TokenResult` sealed class. Verificado en E2E. |
| R17 (refresh_token caduca 7d) | ABIERTO. Caducidad: ~2026-05-06. Rotación pendiente si la prueba pasa a producción. |
| R18 (scripts auxiliares sin tests) | ABIERTO. Mitigación Fase 3: mover OAuth setup a UI de FlowWeaver. |
| R19 (secretos en log sesión) | ABIERTO. Mitigación: rotar `client_secret` + revocar `refresh_token` tras los 7 días. |
| R20 (tests cross-language ausentes) | MITIGADO — 11 tests añadidos, gate obligatorio establecido. |

---

## Pendiente para próxima sesión

- H-001: leer `EXTRA_SUBJECT` en `ShareIntentActivity.kt` para capturar título YouTube.
- H-003: diagnosticar agrupación de episodios (5 URLs terror no agrupadas).
- Continuar prueba de 7 días con fixes H-001/H-003 aplicados.
- Rotar credenciales OAuth (R19) tras los 7 días.
