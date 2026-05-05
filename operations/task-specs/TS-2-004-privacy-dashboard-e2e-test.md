# Task Spec — TS-2-004-e2e

document_id: TS-2-004-e2e
task_id: T-2-004-e2e
title: Test E2E con datos sintéticos — sustituto de capturas manuales del Privacy Dashboard
phase: 2
produced_by: Functional Analyst
status: APPROVED
date: 2026-05-05
depends_on: T-2-004 (Privacy Dashboard completo implementado)
unblocks: AR-2-006 (revisión arquitectónica post-implementación de T-2-004)

---

## Objetivo

Crear un artefacto de verificación automatizado que sustituye las 5 capturas manuales
del Privacy Dashboard previstas en TS-2-004 §"Verificación Doble (ii)" como condición
externa para AR-2-006.

El test verifica que el backend produce los datos correctos para cada uno de los 4
estados del sistema (Observing, Learning, Trusted, Autonomous), cubriendo los 4
elementos de UI declarados en TS-2-004 §Estructura del Componente.

---

## Justificación

Las capturas manuales originalmente planificadas en TS-2-004 §"Mecanismo ii" requieren:
1. Forzar los estados Trusted y Autonomous mediante datos reales o comandos debug temporales.
2. Capturas manuales no automatizables ni reproducibles.
3. Dependencia del entorno de desarrollo (pantalla, resolución, sistema operativo).

Un test E2E con datos sintéticos en Rust (`cargo test`) cubre los mismos 4 estados de
forma:
- **Reproducible**: misma entrada → mismo resultado (D8).
- **Automatizable**: se ejecuta en CI sin intervención manual.
- **Mantenible**: cuando el Privacy Dashboard evolucione, el test falla explícitamente en
  lugar de quedar obsoleto silenciosamente.
- **Objetivamente más robusto**: verifica contratos de backend, no solo apariencia visual.

La sustitución es aprobada por consenso entre Functional Analyst, Technical Architect y
Orchestrator. Las capturas manuales originales se archivan como deuda documental
no-bloqueante.

---

## Scope del Test

### In Scope

- Inicialización de BD en memoria (sin disco, sin estado externo) con datos sintéticos
  para cada uno de los 4 estados del Privacy Dashboard.
- Verificación de los 4 elementos de UI requeridos por TS-2-004:
  1. **Indicador de estado** (`current_state` en `TrustStateView`): correcto para cada
     estado.
  2. **Lista de mecanismos activos** (`Vec<PatternSummary>` de `get_detected_patterns`):
     estructura válida, no vacía cuando corresponde.
  3. **Controles disponibles** (`available_transitions` en `TrustStateView`): correctos
     para cada estado (Reset siempre presente; EnableAutonomous solo en Trusted).
  4. **Métricas de privacidad** (`PrivacyStats` de `privacy_stats()`): campos presentes
     con valores correctos.
- Ejecución sin red externa, sin LLM, sin proxy (D8 — baseline determinístico).
- Ejecución como `cargo test` (integrado en el suite existente de FlowWeaver).
- Determinismo total: misma entrada → mismo resultado.

### Out of Scope

- Renderizado visual del componente React (no es un test de UI/frontend).
- Verificación de CSS o de la apariencia visual del dashboard.
- Integración con Tauri (el test llama directamente a las funciones Rust de backend).
- Capturas de pantalla o grabación de video.

---

## Criterios de Aceptación

| # | Criterio | Verificable |
|---|---|---|
| AC-1 | El test inicializa la BD con datos sintéticos para el estado Observing (BD vacía) y verifica que `evaluate_transition` devuelve `current_state = Observing`, `detect_patterns` devuelve lista vacía, `privacy_stats` devuelve `resource_count = 0`. | `cargo test` |
| AC-2 | El test inicializa la BD con scores sintéticos (≥3 patrones, trust_score > 0.4) y verifica que `evaluate_transition` desde Observing devuelve `current_state = Learning`. | `cargo test` |
| AC-3 | El test inicializa la BD con scores sintéticos (trust_score > 0.75) y verifica que `evaluate_transition` desde Learning devuelve `current_state = Trusted`. `available_transitions` incluye `EnableAutonomous` disponible. | `cargo test` |
| AC-4 | El test verifica que `evaluate_transition` con `UserAction::EnableAutonomous { confirmed: true }` desde Trusted devuelve `current_state = Autonomous`. | `cargo test` |
| AC-5 | El test verifica que `privacy_stats()` sobre una BD con recursos sintéticos devuelve `resource_count > 0`, `categories` no vacío, `domains` no vacío. | `cargo test` |
| AC-6 | El test verifica que `detect_patterns()` sobre una BD con recursos sintéticos suficientes devuelve al menos un `PatternSummary` con los 4 campos requeridos: `pattern_id`, `label`, `category_signature`, `domain_signature`. | `cargo test` |
| AC-7 | El test se ejecuta sin red externa, sin LLM, sin proxy. Sin dependencias externas. | Inspección + `cargo test --offline` |
| AC-8 | El test es determinístico: misma entrada (`now_unix` fijo, datos sintéticos fijos) → mismo resultado. | Ejecución múltiple del suite |
| AC-9 | `cargo test` pasa ≥ tests previos + nuevos tests E2E del Privacy Dashboard. No regresiones. | `cargo test` |

---

## Ubicación del Test

El test se implementa como módulo de tests en `src-tauri/src/commands.rs`, dentro del
bloque `#[cfg(test)] mod tests` existente.

**Justificación:** los módulos `state_machine`, `pattern_detector`, `trust_scorer` y
`pattern_blocks` son `pub(crate)` y no accesibles desde `src-tauri/tests/`. El bloque
de tests en `commands.rs` tiene acceso a todos los módulos privados del crate,
coherente con el test estructural D1 ya existente en el mismo módulo.

---

## Estructura del Test

```rust
// En src-tauri/src/commands.rs — bloque #[cfg(test)] mod tests existente

/// E2E Privacy Dashboard — T-2-004-e2e
/// Verifica los 4 elementos de UI del Privacy Dashboard para cada uno de los
/// 4 estados (Observing, Learning, Trusted, Autonomous) con datos sintéticos.
/// Sustituto de las 5 capturas manuales de TS-2-004 §"Mecanismo ii".
/// Determinístico, sin red, sin LLM, sin proxy (D8).

fn open_test_db() -> crate::storage::Db {
    let db = crate::storage::Db::open(std::path::Path::new(":memory:"), "test-key")
        .expect("open db");
    db.migrate().expect("migrate");
    db
}

fn synthetic_scores(trust: f64, count: usize) -> Vec<crate::trust_scorer::TrustScore> {
    (0..count).map(|i| crate::trust_scorer::TrustScore {
        pattern_id: format!("pattern-{i:03}"),
        trust_score: trust,
        stability_score: 0.8,
        recency_weight: 1.0,
        confidence_tier: crate::trust_scorer::ConfidenceTier::High,
    }).collect()
}

/// Elemento 1: indicador de estado Observing
/// Elemento 2: mecanismos activos vacíos
/// Elemento 3: controles sin EnableAutonomous
/// Elemento 4: métricas vacías
#[test]
fn e2e_dashboard_observing_state() { ... }

/// Elemento 1: indicador de estado Learning (transición desde Observing)
#[test]
fn e2e_dashboard_learning_state() { ... }

/// Elemento 1: indicador de estado Trusted (transición desde Learning)
/// Elemento 3: EnableAutonomous disponible en controles
#[test]
fn e2e_dashboard_trusted_state() { ... }

/// Elemento 1: indicador de estado Autonomous (acción usuario desde Trusted)
#[test]
fn e2e_dashboard_autonomous_state() { ... }

/// Elemento 4: métricas de privacidad con datos sintéticos
#[test]
fn e2e_dashboard_privacy_stats_with_synthetic_data() { ... }

/// Elemento 2: lista de mecanismos activos con recursos sintéticos suficientes
#[test]
fn e2e_dashboard_patterns_detected_with_synthetic_resources() { ... }
```

---

## Constraints

| Constraint | Aplicación |
|---|---|
| D1 | Los datos sintéticos del test usan exclusivamente `domain` y `category` en claro. `url` y `title` se cifran antes de inserción en BD. El test no accede a `url`/`title` desencriptados. |
| D4 | El test no invoca `evaluate_transition` para tomar decisiones de acción — solo para verificar el estado resultante. La autoridad permanece en la State Machine. |
| D8 | `now_unix` se pasa como constante fija (`1_714_000_000_i64`) en todos los tests. Sin `SystemTime::now()` en el path de test. |
| R12 | El test distingue explícitamente entre datos para Pattern Detector (longitudinales, múltiples capturas a lo largo de días) y datos para Episode Detector (sesión). Los tests E2E del dashboard solo usan datos longitudinales. |

---

## Handoffs Requeridos Post-Implementación

1. **Functional Analyst → Technical Architect**: TS-2-004-e2e lista. Solicitar AR-2-006.
2. **Technical Architect → Orchestrator**: AR-2-006 emitido con declaración de D14 satisfecho.
3. **Orchestrator**: emitir PIR-005-addendum declarando cierre formal de Fase 2.

---

## Firma

approved_by: Functional Analyst
approval_date: 2026-05-05
notes: TS-2-004-e2e sustituye las 5 capturas manuales de TS-2-004 §"Mecanismo ii". Las capturas manuales se archivan como deuda documental no-bloqueante. El test E2E es objetivamente más robusto: verificación de contratos de backend para los 4 estados, reproducible, automatizable y mantenible. AR-2-006 puede proceder con este test como único artefacto de verificación. D14 se declara satisfecho en AR-2-006 y confirmado en PIR-005-addendum.
