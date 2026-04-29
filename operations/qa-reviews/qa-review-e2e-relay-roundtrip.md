# QA Review — E2E Drive Relay Data Round-Trip (baseline)

document_id: QA-REVIEW-E2E-RELAY-001
reviewer_agent: QA Auditor (executor: Claude Code)
phase: 0c (post-cierre) / Fase 2 (vigente)
date: 2026-04-29
tasks_reviewed: D.1 of OD-007 audit — E2E test of the Drive relay data round-trip
status: APROBADO — baseline test activo + full-cycle test ignored con TODO
documents_reviewed:
  - operations/orchestration-decisions/OD-007-defer-d22-mobile-standalone.md
  - operations/task-specs/TS-0c-002-relay-bidireccional.md
  - operations/architecture-reviews/AR-0c-001-phase-0c-contracts.md
  - Project-docs/decisions-log.md (D1, D6, D9, D20, D21)
  - Project-docs/risk-register.md (R3, R6, R15)
referenced_risk: R15 (latencia del Drive relay no medida)

---

## Resultado Global

**APROBADO como baseline.** El test `e2e_relay_data_roundtrip` (en
`FlowWeaver/src-tauri/tests/e2e_relay_roundtrip.rs`) pasa de forma
determinística sin red ni Drive real, y pin-fija el contrato semántico
del relay end-to-end:

1. Cifrado handover triple: `local_key (android)` → `shared_key (relay)`
   → `local_key (desktop)` con AES-256-GCM en cada salto. Asegura que la
   `shared_key` es la única clave compartida entre dispositivos y que la
   base local de cada uno permanece soberana (D6, D21).
2. Forma del payload sobre Drive: `RawEvent` serializado a JSON,
   deserializado idénticamente en el otro extremo. `domain` y `category`
   en claro como permite D1; `url`/`title` cifrados con `shared_key`.
3. Derivación determinística del UUID en el receptor:
   `Uuid::new_v5(NAMESPACE_URL, domain || url)`. Pinned para evitar
   regresiones sobre la idempotencia.
4. Idempotencia: el `event_id` queda registrado en `relay_events` después
   del primer import, y una redelivery del mismo `RawEvent` no duplica
   el recurso (verificado con `process_android_event` invocado dos veces
   con el mismo evento).
5. Métrica `[METRIC] e2e_latency_ms=X` emitida por stdout en cada run —
   en local el roundtrip de datos puro está en el orden de < 5 ms (sin
   red). El valor real con red lo aporta el test futuro non-mock; este
   test deja la línea de instrumentación lista.

El segundo test `e2e_relay_full_cycle_with_mock_drive` queda **ignored**
con TODO documentado en su doc-comment: cuatro pasos de refactor
concretos (extraer `trait DriveApi`, mover impl `reqwest` a
`HttpDriveApi`, pasar `&dyn DriveApi` a `run_relay_cycle`, escribir
`InMemoryDriveApi` en el test) que activarán el ciclo completo cuando se
priorice. No se introducen dependencias nuevas en `Cargo.toml`.

---

## Carácter de baseline

Este test queda fijado como **baseline regresional** del relay. Cualquier
cambio en `drive_relay.rs`, `crypto.rs` o el schema de `relay_events` en
`storage.rs` que rompa este test debe considerarse regresión bloqueante.
Específicamente:

- modificar `build_raw_event` o `process_android_event` (firma o
  comportamiento) requiere mantener este test pasando o adjuntar
  justificación explícita en el commit
- cualquier cambio en el formato wire de `RawEvent` (campos, schema_version,
  semántica de los `*_encrypted`) debe acompañarse de actualización del
  test para reflejar la nueva forma — el test es, en este sentido, el
  contrato wire ejecutable
- el rename o eliminación del magic `fw1a` en `crypto.rs` rompería
  silenciosamente el handover y este test lo detectaría inmediatamente

---

## Coberturas y Lagunas

### Cubierto

- ✅ encriptación handover (D1, D6)
- ✅ wire format JSON estable (T-0c-002 — AR-0c-001 §A)
- ✅ idempotencia sobre `event_id` (T-0c-002 AC §6)
- ✅ derivación v5 del UUID en receptor — clave de la unicidad cross-device
- ✅ no exposición de `url` ni `title` en claro en ninguna fase del
  payload de tránsito (D1)
- ✅ instrumentación de latencia local (R15 — primer paso de medición)

### No cubierto por este test (intencional)

- ❌ red real / Drive REST: imposible sin cuenta de servicio. Lo cubre
  el test ignored cuando el refactor `DriveApi` esté hecho.
- ❌ refresh OAuth / token expiry: pertenece al ciclo completo, no al
  roundtrip de datos.
- ❌ retry/backoff sobre `increment_relay_retry`: lógica del ciclo
  completo, no del roundtrip.
- ❌ ACK de vuelta (desktop → android-acked): pertenece al ciclo completo.
- ❌ medida de latencia P50/P95 con red real (R15 sigue ABIERTO hasta
  que existan datos de producción).

---

## Observaciones

### O-001 — Refactor `DriveApi` pendiente

El test `e2e_relay_full_cycle_with_mock_drive` no se activará hasta que
exista la abstracción `trait DriveApi` documentada en su doc-comment.
El refactor es de bajo riesgo (no introduce dependencias, no cambia el
comportamiento en producción) pero requiere ownership de Sync & Pairing
Specialist. Recomendación: priorizar el refactor antes del próximo
sprint que toque `drive_relay.rs` para no acumular deuda de testabilidad.

### O-002 — R15 sigue abierto

El test emite la métrica `e2e_latency_ms` localmente, pero R15 (latencia
del Drive relay no medida en producción) sigue abierto. El test es un
**floor** (puro coste de procesado sin red), no una medida real del
P95/P50 con Drive de por medio. Para cerrar R15 se necesita
instrumentación on-device en producción durante la beta de Fase 3.

### O-003 — Visibilidad pública de helpers internos

Para habilitar el test integration, se cambió la visibilidad de
`build_raw_event` y `process_android_event` de privadas a `pub`, y los
módulos `crypto`, `raw_event`, `storage` y `drive_relay` se marcaron
`pub mod` en `lib.rs`. Este cambio no expone APIs Tauri nuevas (los
commands siguen siendo los mismos); solo abre la superficie del crate
library `flowweaver_lib` para tests. Si en el futuro se introduce
`flowweaver_lib` como crate consumido por terceros, revisar.

---

## Criterio de Cierre

- [x] el archivo `tests/e2e_relay_roundtrip.rs` existe en FlowWeaver
- [x] `cargo test --test e2e_relay_roundtrip` pasa
      (1 passed; 1 ignored)
- [x] la línea `[METRIC] e2e_latency_ms=X` aparece en stdout del test
      (visible con `cargo test -- --nocapture`)
- [x] el test no requiere red ni dependencias nuevas
- [x] el test ignored documenta el refactor mínimo para activarlo
- [x] esta QA review queda registrada en
      `operations/qa-reviews/qa-review-e2e-relay-roundtrip.md`

---

## Próximos pasos

1. **Refactor `trait DriveApi`** (Sync & Pairing Specialist) — habilita
   el test ignored y cierra la deuda de testabilidad del módulo.
2. **Instrumentación P50/P95 producción** (Sync & Pairing Specialist) —
   cierra R15. Requiere telemetría mínima opt-in en Fase 3.
3. **Test análogo en sentido desktop → android** — el test actual cubre
   solo Android → Desktop. La dirección inversa (`build_raw_event`
   desktop + `process_*` android-side) merece test simétrico cuando se
   prioricen los flujos de relay desktop-emisor.

---

## Referencia cruzada

- OD-007 §"Documentation updates required" — este QA review da soporte
  al item 4 (revisión de items dependientes de D22) y al item de
  validación de relay infraestructura preservada.
- R15 (risk-register) — instrumentación parcial; sigue ABIERTO.
