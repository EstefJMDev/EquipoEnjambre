# EquipoEnjambre — Contexto para Claude

Este archivo se carga automáticamente en cada sesión. Contiene todo el contexto necesario para operar sin memoria previa.

---

## Qué es este repositorio

**EquipoEnjambre** es el sistema de orquestación multi-agente que gobierna el desarrollo de FlowWeaver. Contiene agentes, backlogs, decisiones de arquitectura, revisiones de QA, handoffs y gates de fase. No hay código de producto aquí.

El código de la app vive en el repositorio separado **FlowWeaver**: `https://github.com/EstefJMDev/FlowWeaver`

---

## El producto: FlowWeaver

App de escritorio (Tauri 2 + React/TypeScript + Rust) con companion Android. Detecta intención de trabajo a partir de recursos guardados desde el móvil y prepara el workspace del ordenador automáticamente antes de que el usuario lo pida.

**Repositorio del producto:** `https://github.com/EstefJMDev/FlowWeaver`

**Stack técnico:**
- Backend: Rust (`src-tauri/src/`) — storage.rs (SQLCipher), commands.rs, classifier.rs, grouper.rs, session_builder.rs, episode_detector.rs, importer.rs, crypto.rs
- Frontend: React + TypeScript (`src/`) — PanelA, PanelB, PanelC, EpisodePanel, AnticipatedWorkspace, PrivacyDashboard
- Tests: `cargo test` en src-tauri (suite determinística)
- TypeScript: `npx tsc --noEmit`

---

## Usuario

Product owner de FlowWeaver. Opera el sistema de orquestación EquipoEnjambre. Toma decisiones de go/no-go como Orchestrator. No es perfil técnico de implementación — supervisa y dirige el enjambre de agentes.

---

## Estado actual del proyecto

### Fases completadas
- **Fase 0a** — Workspace desktop con Panel A + Panel C, bookmark importer, classifier, grouper, SQLCipher
- **Fase 0b** — Session Builder, Episode Detector dual-mode, Privacy Dashboard mínimo, add_capture (simulación Share Intent). Track Android primario (D19). Track iOS paralelo pendiente de entorno macOS.
- **Fase 1** — Panel B con resumen por plantillas. Gate pasado (PIR-003). OD-004 emitido el 2026-04-24.

### Fase activa: Fase 2
Abierta por OD-004 (2026-04-24). Backlog aprobado por Technical Architect (AR-2-001, 2026-04-24).

**Cadena de entregables:**
```
T-2-000  Delimitación de FS Watcher (documental)
T-2-001  Pattern Detector
    └── T-2-002  Trust Scorer
        └── T-2-003  State Machine
T-2-004  Privacy Dashboard completo
```

**Lo que valida Fase 2:** aprendizaje longitudinal, escalera de confianza, tolerancia del usuario a automatización progresiva, Privacy Dashboard completo antes de beta.

### Fase siguiente: Fase 3
Beta pública, métricas, calibración de umbrales, LLM local opcional.

---

## Decisiones cerradas que el enjambre debe respetar

| ID | Decisión |
|---|---|
| D1 | Solo domain y category en claro. url y title siempre cifrados. |
| D4 | State Machine tiene autoridad. trust_score es input, no decide solo. |
| D5 | Stability score usa slot concentration con entropía normalizada (0–1). |
| D8 | Baseline determinístico sin LLM. LLM es mejora opcional declarada. |
| D9 | FS Watcher es el único módulo de observación activa en Fase 2. Requiere delimitación formal antes de implementar. |
| D14 | Privacy Dashboard completo obligatorio antes de beta. |
| D17 | Pattern Detector completo solo en Fase 2. No se divide entre fases. |
| D19 | Plataforma primaria: Android + Windows. iOS track paralelo secundario. |
| R12 WATCH | Pattern Detector ≠ Episode Detector. Propósitos distintos: longitudinal vs sesión. Declarar explícitamente en cada TS de Fase 2. |

---

## Entorno de desarrollo

Guía completa en `docs/setup-entorno-dev.md` (en este repo).

**Stack resumido:**
- Rust 1.95.0 / Cargo 1.95.0 (via rustup)
- Node.js 24.13.0 / npm 11.6.2
- Python 3.14.2
- Strawberry Perl 5.42 (necesario antes de Rust — OpenSSL)
- Visual Studio Build Tools 2022 (necesario para Rust en Windows)
- Android NDK 27.3.13750724
- Claude Code 2.1.119 (`npm install -g @anthropic-ai/claude-code`)
- Ollama 0.21.1

**Rust targets Android instalados:**
```
aarch64-linux-android
armv7-linux-androideabi
i686-linux-android
x86_64-linux-android
```

**Variables de entorno necesarias:**
```
ANDROID_HOME     = <usuario>\AppData\Local\Android\Sdk
ANDROID_SDK_ROOT = <usuario>\AppData\Local\Android\Sdk
NDK_HOME         = <usuario>\AppData\Local\Android\Sdk\ndk\27.3.13750724
JAVA_HOME        = JDK de Android Studio (no el JRE de Autofirma)
```

---

## Estructura de este repositorio

```
agents/          — definiciones de cada agente del enjambre
Project-docs/    — visión, roadmap, scope, decisiones, arquitectura
operating-system/ — reglas de colaboración, gates, checklists
operations/
  backlogs/      — backlog-phase-0a.md, backlog-phase-1.md, backlog-phase-2.md
  orchestration-decisions/ — OD-001 a OD-004
  architecture-reviews/    — AR por fase
  qa-reviews/              — revisiones de QA
  handoffs/                — HO-001 a HO-006
  phase-integrity-reviews/ — PIR-001 a PIR-003
  task-specs/              — TS por tarea
docs/            — product-spec.md, setup-entorno-dev.md
```

---

## Norma operativa

Ningún agente puede implementar sin backlog aprobado. Ninguna fase puede abrirse sin gate pasado y OD emitida. Los constraints D1–D19 y R12 son no negociables.
