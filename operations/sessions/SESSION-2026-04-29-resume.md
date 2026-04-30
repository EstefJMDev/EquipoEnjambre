# SESSION RESUME — Próxima sesión tras 2026-04-30

**ANTES DE NADA:** lee `SESSION-2026-04-29-state.md` íntegro (incluye todos los updates, el último es "CIERRE 2026-04-30").

**Estado al cierre de 2026-04-30:** Bugs #1/#2/#3/#4/#5 ARREGLADOS. Tests cross-lang PASANDO (62 Rust, 8 Kotlin). E2E EXITOSA. Prueba de 7 días en curso (día 1 = 2026-04-30). Documentación completa.

---

## Plan para próxima sesión

### Prioridad inmediata (antes de continuar prueba de 7 días)

**1. Arreglar H-001 — YouTube sin título en ShareIntentActivity.kt**

Causa probable: `ShareIntentActivity.kt` no lee `Intent.EXTRA_SUBJECT`.
Fix: leer `intent.getStringExtra(Intent.EXTRA_SUBJECT)` y usarlo como
`titleRaw` si no está vacío, antes del fallback a string vacío.

Archivo: `FlowWeaver/src-tauri/gen/android/app/src/main/java/com/flowweaver/app/ShareIntentActivity.kt`

Estimación: 30 min.

Tokens disponibles en `EquipoEnjambre/tmp_oauth_tokens.json` y
`tmp_drive_config_artifacts.json` (CONTIENEN SECRETOS — no commitear).
Si el access_token caducó (>1h), usar el refresh_token de esos archivos
para obtener uno nuevo via `POST oauth2.googleapis.com/token`.
R17: caducidad refresh_token estimada ~2026-05-06 — actuar antes.

**2. Reevaluar H-003 con H-001 arreglado**

Compartir 3-5 URLs del mismo tema (con títulos reales esta vez).
Verificar si el Episode Detector las agrupa en Precise mode.

Si agrupa: H-003 MITIGADO. Si no: diagnosticar umbrales (JACCARD_THRESHOLD=0.20,
PRECISE_MIN=3, tokens generados por tokenize_resource).

Estimación: 15 min diagnóstico + ajuste según hallazgo.

**3. Limpiar Drive AppData**

Quedan 24 archivos huérfanos UUID puros (del Android pre-Bug #1 fix).
Son basura inocua pero confunden los logs. Limpiar con Drive REST API.
Estimación: 15 min.

---

### Prueba de 7 días (en curso)
- Día 1: 2026-04-30
- Día 7: 2026-05-06
- Decisión D22: 2026-05-07
- R17 caduca: ~2026-05-06 — rotar refresh_token antes de ese día

Cada día anotar:
- ¿Qué compartiste? (2 palabras)
- ¿Apareció en desktop? (sí/no/cuánto tardó)
- ¿Hubo wow? (1-5)

---

### Post-prueba de 7 días (2026-05-07+)
- Decidir D22 con datos reales
- R17: resolver (publicar app en GCP o cambiar arquitectura relay)
- R19: rotar client_secret + revocar refresh_token en myaccount.google.com
- Borrar tmp_* (solo tras rotación R19)
- Evaluar AN-classifier-enrichment-options.md (opciones 3a-3d)
- H-002: taxonomía mejorada si los datos de 7 días lo justifican

---

## Prerequisitos de entorno

- `tauri dev` desktop: `cd FlowWeaver && npm run tauri dev` en background
- `adb devices` muestra `OZ4H9HBYKNSWV86H`
- Verificar estado de `tmp_drive_config_artifacts.json` (puede tener refresh_token)
- Si no hay tokens: ejecutar flujo OAuth antes de rebuild APK
- Variables entorno: `JAVA_HOME` (JDK 17 Microsoft), `ANDROID_HOME`, `NDK_HOME`

## Fuera de scope

- ❌ NO reabrir D22 / OD-007 hasta tener datos de 7 días
- ❌ NO empezar Pattern Detector móvil (bloqueado por OD-007)
- ❌ NO arreglar H-002 (taxonomía) antes de los 7 días
