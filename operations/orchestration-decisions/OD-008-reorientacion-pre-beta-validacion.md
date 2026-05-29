# Orchestration Decision

## OD-008 — Reorientación Pre-Beta a Validación con Usuarios Reales

date: 2026-05-12
issued_by: Orchestrator
status: APPROVED
supersedes_partial: orden de ejecución de backlog-phase-3.md (P-0/P-1 ampliados,
                    T-3-002/003 reordenadas como P-1, T-3-007..T-3-028 conservadas
                    pero condicionadas)
referenced_decisions: D1, D8, D9, D12, D14, D17, D19, D20, D21, D22, D23, D24,
                      D25, D28, D29, D30
referenced_documents: OD-006-phase-3-activation.md, OD-007-defer-d22-mobile-standalone.md,
                      OD-007-execution-report.md, AN-crypto-migration-xor-to-aes.md,
                      backlog-phase-3.md

---

## Issue

Tras el ejercicio de revisión de producto del 2026-05-12 (prompt-nuevo.md +
análisis cruzado con el estado real del repositorio FlowWeaver), se identifica
un patrón de riesgo:

1. El framing actual del producto ("motor de workspaces anticipados", "agente
   local de anticipación contextual") es aspiracional respecto a lo que el
   producto realmente hace hoy (señales explícitas → episodio → workspace
   preparado).

2. Tres riesgos operativos (R13 migración crypto, R14 validación relay real,
   R15 instrumentación) están abiertos desde OD-007-execution-report.md y NO
   están mapeados como tareas accionables en backlog-phase-3.md.

3. La revisión técnica del repositorio FlowWeaver (2026-05-12) confirma:
   - CSP en `tauri.conf.json` está `null` (deshabilitada), no laxa
   - No existe framework de logging estructurado en el código Rust
     (sólo `println!`/`eprintln!` aislados)
   - `e2e_relay_full_cycle_with_mock_drive` permanece `#[ignore]` con TODO de
     refactor de `drive_relay.rs` (~120 LOC) para abstraer `DriveBackend`
   - `crypto.rs` mantiene coexistencia XOR (magic `fw0a`) + AES-256-GCM
     (magic `fw1a`), con derivación de clave AES aún determinística desde
     `app_data_dir` (no keychain del OS)
   - El código Kotlin custom en `src-tauri/gen/android/` no tiene plan
     documentado de supervivencia ante regeneración de Tauri

4. El backlog actual de Fase 3 contiene tareas que asumen un producto validado
   con usuarios (T-3-007..T-3-028, bloque síntesis + bloque mobile CR-006) pero
   el producto no ha tenido prueba con usuarios reales externos en ningún
   punto previo.

5. La norma operativa del repositorio (CLAUDE.md, decisions-log.md) exige que
   ningún agente implemente sin backlog aprobado. Cualquier reorientación debe
   pasar por una OD formal antes de modificar el backlog.

El riesgo agregado es **documentar antes de validar**: producir más decisiones,
specs y framing sin haber expuesto el producto a un solo usuario externo.

---

## Decision

1. **Fase 3 se reordena con tres bloqueantes pre-beta explícitos (P-0):**
   migración crypto (R13), validación relay con dispositivo real (R14) e
   instrumentación local mínima (R15). Estos tres riesgos pasan de "abiertos
   en execution report" a "tareas formales del backlog Fase 3" bajo el nombre
   colectivo **T-3-Hardening**.

2. **Antes de cualquier nuevo documento de visión, posicionamiento, UX spec
   formal o framing de producto, debe completarse una validation spec ligera**
   y una prueba con 5–10 usuarios reales. Hasta que esa prueba arroje datos,
   queda prohibido emitir:
   - nuevo `vision.md` o reescritura del actual
   - decisión `D33` o posterior sobre categoría/posicionamiento de producto
   - UX spec formal (DOC-3 propuesto en sesión 2026-05-12)
   - métricas framework formal (DOC-5 propuesto en sesión 2026-05-12)

3. **El framing del producto se opera en tres niveles explícitos** hasta nueva
   orden:
   - **Actual (validado hoy):** señales explícitas/manuales → episodio →
     workspace preparado. Único nivel sobre el que se puede hacer copy de
     marketing, claims públicos o discurso de prueba con usuarios.
   - **Beta cercana:** señales explícitas + observadores autorizados (FS
     Watcher background-persistent ya cerrado en Fase 2). Sólo se puede
     comunicar a usuarios beta firmantes del consentimiento.
   - **Visión futura:** agente local de anticipación contextual. NO se
     comunica externamente, NO se documenta como promesa, NO se referencia
     en copy. Permanece como dirección interna del enjambre.

4. **Se crea la categoría de tarea T-3-Hardening** dentro de
   backlog-phase-3.md con prioridad P-0 (bloqueante pre-beta). Sus subtareas
   son:
   - T-3-Hardening-1: Quality gate ejecutable (lint + tsc + vitest + cargo
     test + cargo clippy + cargo fmt --check + pre-commit hook + CI workflow)
   - T-3-Hardening-2: Decisión documentada sobre `src-tauri/gen/android`
     (custom code location + procedimiento de regeneración)
   - T-3-Hardening-3: CSP estricta (eliminar `csp: null` de tauri.conf.json)
   - T-3-Hardening-4: Key management real con keychain del OS (R13 fase 1 —
     desktop primero, Android como sub-tarea separable)
   - T-3-Hardening-5: Migración de datos XOR→AES on-startup, idempotente
     (R13 fase 2). Código XOR no se elimina aún (rotación, no ruptura)
   - T-3-Hardening-6: Framework de logging estructurado con `tracing` +
     `tracing-appender` rotativo en `app_data_dir/logs/`, comando Tauri
     `export_diagnostics()` (R15 fase 1)
   - T-3-Hardening-7: Diagnostics module con contadores en memoria + histograma
     P50/P95 del relay + comando `get_diagnostics_snapshot()` (R15 fase 2).
     Telemetría 100% local, sin upload remoto.
   - T-3-Hardening-8: Refactor `drive_relay.rs` para introducir
     `trait DriveBackend` + `MockDriveBackend`; reactivar
     `e2e_relay_full_cycle_with_mock_drive` (R14 fase 1)
   - T-3-Hardening-9: Checklist de validación manual relay real con dispositivo
     Android físico + cuenta Drive real + desktop Windows real, cubriendo los
     9 flujos críticos ya conocidos. Reporte firmado en `QA-relay-real-
     validation-report-YYYY-MM-DD.md` (R14 fase 2)
   - T-3-Hardening-10: UX mínima para prueba con usuarios — tarjeta de
     workspace + "¿por qué este workspace?" + acciones abrir/ignorar/borrar +
     estado de sync visible + error visible accionable. NO es UX spec formal.

5. **Se crea T-3-Validation como bloque P-1 (tras T-3-Hardening):**
   - T-3-Validation-1: Validation spec ligera
     (`Project-docs/validation-spec-pre-beta.md`) con 3 hipótesis máximo,
     definición operativa de "workspace útil", métricas mínimas (todas
     locales, vienen de R15), protocolo de 5–10 usuarios, señales de "no se
     entiende", lista de claims prohibidos hasta validación.
   - T-3-Validation-2: Protocolo de reclutamiento + guion de entrevista +
     formulario de consentimiento alineado con D14/D25/D28/D30
     (`operations/qa-reviews/UR-001-pre-beta-protocol.md`).
   - T-3-Validation-3: Ejecución de la prueba con usuarios reales y reporte
     `operations/qa-reviews/UR-001-report-YYYY-MM-DD.md` con resultados por
     hipótesis.

6. **Se crea T-3-Hardening-Framework como tarea documental paralela:**
   - T-3-Hardening-11: Observation Levels Framework
     (`Project-docs/observation-levels-framework.md`) — encuadrado
     explícitamente como extensión técnica de D9, NO como promesa de
     producto. Documenta L0 (Share Intent, implementado), L1 (FS Watcher
     vigilada, implementado), L2 (browser extension, futuro), L3
     (clipboard/active window, futuro con consentimiento granular), L4
     (power-user automations, fuera de scope MVP/beta).

7. **Reordenamiento de prioridades dentro de backlog-phase-3.md:**
   - **P-0 (bloqueante pre-beta):** T-3-Hardening-1..10 + verificación E2E
     del relay heredada + criterio #18 AR-2-007 FS Watcher heredado
   - **P-1 (bloqueante de claims/positioning):** T-3-Validation-1..3
   - **P-2 (paralelizable con P-0/P-1):** T-3-Hardening-11 (obs levels),
     T-3-001 (infra beta), T-3-006 (Classifier Capa A, ya CR-004 aprobado)
   - **P-3 (post-validación) — NUEVAS task-specs sobre estos módulos:**
     T-3-002 (telemetría D1), T-3-003 (calibración State Machine),
     refinamientos sobre T-3-007..T-3-013 (síntesis desktop) si surgieran
   - **P-4 (post-cierre desktop beta cerrada):** T-3-014..T-3-028
     (bloque mobile CR-006, ya BLOQUEADO GLOBAL en backlog actual)
   - **BLOQUEADO indefinido:** T-3-004 (observer Android tier paid,
     dependiente de D22 aplazada por OD-007), T-3-005 (Ollama, superseded
     por D23)

7.bis. **Cláusula de no-regresión sobre código ya productivo:**
   T-3-007..T-3-013 (bloque síntesis desktop) están IMPLEMENTADAS y se
   conservan OPERATIVAS. OD-008 NO exige revertir, deshabilitar, congelar
   ni esconder detrás de feature flag ninguno de los módulos ya en producción:
   - `src-tauri/src/synthesis_engine.rs` (SSE streaming cifrado al proxy)
   - `src-tauri/src/syntheses_store.rs` (persistencia AES-256-GCM)
   - `src-tauri/src/synthesis_tokens.rs` (install token cifrado)
   - `src-tauri/src/consent_log_store.rs` (consentimiento D25)
   - `src/components/SynthesisView.tsx`, `SynthesisConsentModal.tsx`
   - Auto-síntesis con cooldown 90s en estado Autonomous dentro de
     `src/components/AnticipatedWorkspace.tsx`

   La etiqueta P-3 sobre T-3-007..T-3-013 aplica EXCLUSIVAMENTE a:
   - apertura de NUEVAS task-specs que extiendan, refactoricen o calibren
     estos módulos con datos reales de usuarios
   - decisiones de producto sobre cambios funcionales visibles al usuario
     en síntesis (e.g. nuevos modos de síntesis, cambios en consentimiento)
   - integración de síntesis con futuras métricas remotas (T-3-002)

   Lo que SÍ aplica como P-0 a la síntesis ya productiva:
   - cumplir T-3-Hardening-3 (CSP estricta) sin romper el call al proxy →
     añadir el dominio del proxy de síntesis a `connect-src` cuando se
     redacte la TS de T-3-Hardening-3
   - cumplir T-3-Hardening-6 (logging estructurado) → migrar cualquier
     `eprintln!`/`println!` dentro de `synthesis_engine.rs` a
     `tracing::*` respetando D1 (nunca loguear contenido, sólo
     `event_id`, `latency_ms`, `error_kind`)
   - aparecer en T-3-Hardening-9 (checklist relay real) sólo si la
     prueba expone la síntesis a los usuarios reclutados; si no, queda
     fuera del checklist

   T-3-014..T-3-028 (bloque mobile CR-006) permanece BLOQUEADO sin
   excepción hasta UR-001 validado. La cláusula 7.bis NO aplica al
   bloque mobile — ahí no hay código en producción que preservar.

8. **Trabajo prohibido hasta nueva orden:**
   - Emitir D33 o posterior sobre categoría/posicionamiento de producto
   - Reescribir `vision.md` o `product-thesis.md`
   - Producir UX spec formal o métricas framework formal
   - Renombrar fases existentes (la nomenclatura "Fase A-G" del prompt
     2026-05-12 queda descartada)
   - Reactivar D22, CR-002 o cualquier feature mobile-only tier paid
   - Introducir telemetría remota (R15 es 100% local hasta T-3-002 aprobada
     con consentimiento explícito)
   - Eliminar el código XOR (`derive_key_xor`, rama `fw0a` en `decrypt_any`)
     hasta 2 versiones tras la migración fase 2

9. **Constraints reafirmados:**
   - D1 sigue siendo no negociable: logs estructurados sólo loguean
     `event_id`, `domain`, `category`, `latency_ms`, `error_kind`. Nunca
     `url`, `title` ni contenido.
   - D8 sigue siendo no negociable: el baseline determinístico debe seguir
     funcionando sin LLM. Las síntesis (T-3-007..) son mejora opcional.
   - D14 sigue siendo no negociable: Privacy Dashboard completo antes de
     beta pública.
   - D19 sigue siendo no negociable: Windows + Android first. iOS paralelo.
   - R12 WATCH sigue siendo no negociable: Pattern Detector ≠ Episode
     Detector en cualquier instrumentación T-3-Hardening-7.

---

## Rationale

El producto necesita exposición real antes que más documentación. El análisis
del 2026-05-12 mostró que el repositorio contiene D1–D32, OD-001–OD-007,
múltiples AR/PIR/HO/CR, pero ningún reporte de usuario externo. La hipótesis
fundacional del puente móvil → desktop (D12) sigue sin validar empíricamente.

Al mismo tiempo, el estado técnico del código contiene riesgos que invalidarían
cualquier dato de validación obtenido prematuramente:
- una CSP `null` deja la aplicación abierta a inyección de contenido si
  cualquier campo cifrado se renderiza sin sanitizar
- una clave AES derivada de `app_data_dir` no protege contra exfiltración del
  directorio de datos
- la ausencia de logging estructurado significa que cualquier reporte de
  problema de usuario será irreproducible
- el test E2E del relay con mock está deshabilitado, por lo que la regresión
  silenciosa del relay no se detecta automáticamente

Por estos motivos, hardening técnico y validation spec ligera son
prerrequisitos de cualquier nuevo framing de producto. La secuencia
correcta es:

```
Hardening técnico (R13/R14/R15) → UX mínima → Validation spec →
Prueba con usuarios reales → Reporte UR-001 →
Decisión informada sobre vision/positioning/UX spec
```

No al revés.

---

## Constraints respected

- OD-006 (activación Fase 3): no se revoca, se reordena
- OD-007 (aplazamiento D22): se reafirma; T-3-004 sigue bloqueada
- D12 (caso núcleo único puente móvil → desktop): reforzado por T-3-Validation
- D1 (privacidad nivel 1): blindado en T-3-Hardening-6/7 con whitelist de campos
- D8 (baseline determinístico sin LLM): reforzado al posponer T-3-007..T-3-013
- D17 (Pattern Detector cerrado en Fase 2): sin cambios
- D19 (Windows + Android first): sin cambios
- D22 (mobile standalone tier paid): permanece APLAZADA por OD-007
- D23–D32 (síntesis LLM + freemium + captura granular): preservadas pero
  movidas a P-3/P-4 hasta validación

---

## Reorientation exit criteria

OD-008 queda cumplida y Fase 3 puede continuar con backlog original cuando:

1. T-3-Hardening-1..10 completadas con AR formal de Technical Architect y
   QA pasada
2. T-3-Validation-1..3 completadas con UR-001 reporte firmado
3. UR-001 reporta resultado claro (H1/H2/H3 validan, invalidan, o son
   parcialmente válidas) — no se exige éxito, se exige conocimiento
4. Privacy Guardian firma revisión sobre T-3-Hardening-6/7 confirmando que
   logs y diagnostics respetan D1

Si UR-001 invalida H1 (los usuarios no entienden el producto sin tutorial),
se abre OD-009 con replanteamiento de framing antes de continuar.
Si UR-001 valida H1+H3, se desbloquea la emisión de D33 (posicionamiento)
y la reescritura formal de vision.md.

---

## Next agents

1. **Technical Architect** — emitir AR-3-002 ratificando la reordenación de
   prioridades en backlog-phase-3.md y la inclusión de T-3-Hardening como P-0
2. **Functional Analyst** — redactar las task-specs TS-3-Hardening-1..11 y
   TS-3-Validation-1..3 según el orden de OD-008
3. **Privacy Guardian** — revisar T-3-Hardening-6 (logging) y T-3-Hardening-7
   (diagnostics) antes de su implementación; ratificar whitelist de campos
4. **Context Guardian** — actualizar:
   - `decisions-log.md` con referencia a OD-008
   - `Project-docs/roadmap.md` reflejando la reordenación de Fase 3
   - `CLAUDE.md` (este repo) con la lista de "Trabajo prohibido hasta nueva orden"

---

## Documentation updates required

- [ ] backlog-phase-3.md: añadir bloque T-3-Hardening (P-0) y T-3-Validation
      (P-1); reordenar T-3-002/003 a P-3; mantener T-3-007..T-3-028 con
      etiqueta `BLOQUEADO hasta UR-001 validado`
- [ ] decisions-log.md: entrada OD-008 con resumen
- [ ] roadmap.md: anotación pre-beta hardening + validation antes de Fase 3
      operativa completa
- [ ] CLAUDE.md (EquipoEnjambre): añadir párrafo sobre los tres niveles de
      framing (actual / beta cercana / visión futura) y la prohibición de
      comunicar el tercero externamente
- [ ] FlowWeaver/CLAUDE.md (si existe): añadir nota "no implementar
      T-3-007..T-3-028 sin TS aprobada tras UR-001"

---

## Risks acknowledged

1. **El hardening puede tomar más de los 6 sprints estimados.** En particular,
   T-3-Hardening-4 (key management Android via JNI) puede requerir un sprint
   dedicado adicional. Mitigación: separable en T-3-Hardening-4a (desktop) y
   T-3-Hardening-4b (Android).

2. **La CSP estricta puede romper componentes frontend en producción.**
   Mitigación: T-3-Hardening-3 se ejecuta temprano en Sprint 2 para tener
   margen de iteración antes de la prueba con usuarios.

3. **UR-001 puede invalidar H1.** Si los usuarios no entienden el producto sin
   tutorial, el framing actual debe replantearse. Este riesgo se acepta
   explícitamente porque es lo que la prueba está diseñada para detectar.

4. **Reclutar 5–10 usuarios reales es trabajo humano no automatizable por el
   enjambre.** Product Owner asume esa responsabilidad operativa.

5. **El tiempo dedicado a hardening retrasa el bloque síntesis (T-3-007..) y
   el bloque mobile (T-3-014..).** Se acepta porque la alternativa es
   construir features sobre infraestructura no validada.

6. **Drive como único relay sigue siendo un riesgo (R21 pre-existente).**
   OD-008 no aborda plan B. Se difiere a post-UR-001.

7. **iOS sigue parado por D19.** Si en UR-001 aparece un segmento iOS
   significativo, no podemos atenderlo. Se acepta por restricción de entorno
   macOS.
