# Phase Integrity Review

owner_agent: Phase Guardian
document_id: PIR-002
phase_protected: 0a
review_type: cierre del ciclo de especificación completo de Fase 0a
date: 2026-04-23
referenced_handoff: HO-004
status: APROBADO — ciclo de especificación íntegro y apto para implementación;
  gate de salida pendiente de demo real y evidencia de observador externo

---

## Objetivo

Verificar que el ciclo de especificación completo de Fase 0a —siete task specs
producidos y aprobados a lo largo de cuatro ciclos operativos— es coherente,
libre de contaminación de fase y apto para servir como base documental de la
implementación de 0a.

Declarar el estado de los riesgos activos al cierre del ciclo de especificación.

Registrar las condiciones pendientes del gate de salida de Fase 0a.

Este documento no activa la implementación. No abre el repo del producto. La
apertura del repo del producto requiere una OD explícita del Orchestrator, que
no puede emitirse hasta que PIR-002 esté aprobado.

---

## Documentos Revisados

### Task Specs

| Documento | Revisado |
| --- | --- |
| `operations/task-specs/TS-0a-001-desktop-workspace-shell.md` | ✓ |
| `operations/task-specs/TS-0a-002-bookmark-importer-retroactive.md` | ✓ |
| `operations/task-specs/TS-0a-003-domain-category-classifier.md` | ✓ |
| `operations/task-specs/TS-0a-004-basic-similarity-grouper.md` | ✓ |
| `operations/task-specs/TS-0a-005-panel-a-recursos-agrupados.md` | ✓ |
| `operations/task-specs/TS-0a-006-panel-c-siguientes-pasos.md` | ✓ |
| `operations/task-specs/TS-0a-007-sqlcipher-local-storage.md` | ✓ |

### Documentos Normativos

| Documento | Revisado |
| --- | --- |
| `operating-system/phase-gates.md` | ✓ |
| `operating-system/orchestration-rules.md` | ✓ |
| `project-docs/phase-definition.md` | ✓ |
| `project-docs/scope-boundaries.md` | ✓ |
| `project-docs/decisions-log.md` (D1–D18) | ✓ |
| `project-docs/risk-register.md` (R7, R9, R11, R12) | ✓ |
| `operations/architecture-notes/arch-note-phase-0a.md` | ✓ |
| `operations/backlogs/backlog-phase-0a.md` | ✓ |

### Revisiones Del Ciclo

| Documento | Revisado |
| --- | --- |
| `operations/architecture-reviews/AR-0a-001-task-specs-review.md` | ✓ |
| `operations/architecture-reviews/AR-0a-002-classifier-review.md` | ✓ |
| `operations/architecture-reviews/AR-0a-003-grouper-review.md` | ✓ |
| `operations/architecture-reviews/AR-0a-004-panel-a-panel-c-review.md` | ✓ |
| `operations/qa-reviews/qa-review-phase-0a-task-specs.md` | ✓ |
| `operations/qa-reviews/qa-review-ts-0a-002.md` | ✓ |
| `operations/qa-reviews/qa-review-ts-0a-004.md` | ✓ |
| `operations/qa-reviews/qa-review-ts-0a-005-006.md` | ✓ |
| `operations/handoffs/HO-004-phase-0a-spec-cycle-close.md` | ✓ |
| `operations/phase-integrity-reviews/PIR-001-phase-0a-activation-check.md` | ✓ |

---

## 1. Coherencia De La Cadena De Especificación

El Phase Guardian ha trazado los contratos de input y output de los siete
módulos de la cadena para verificar que no hay desajustes entre especificaciones.

### 1.1 Cadena de datos declarada

```
Bookmarks exportados (archivo local)
    ↓
T-0a-002 Bookmark Importer
    — output → SQLCipher: {bookmark_id UUID, url cifrada, titulo cifrado,
                           dominio en claro, favicon_url en claro,
                           categoria vacía (pendiente de Classifier)}
    ↓
T-0a-007 SQLCipher Local Storage
    — contrato: almacena y sirve los campos anteriores; cifra url y titulo;
                expone dominio y categoria en claro para lectura del Classifier
    ↓
T-0a-003 Domain/Category Classifier
    — input  ← SQLCipher: dominio en claro
    — output → SQLCipher: categoria asignada (uno de los 10 valores canónicos)
    ↓
T-0a-004 Basic Similarity Grouper
    — input  ← SQLCipher: {bookmark_id, titulo descifrado localmente,
                           dominio, categoria}
    — output → payload de clusters: {cluster_id, domain, category,
                                     sub_label?, resources[]{id, title, domain}}
    ↓
T-0a-001 Desktop Workspace Shell
    — coordina: invoca al Grouper; distribuye el payload de clusters a Panel A
                y Panel C al arrancar el workspace
    ↓
T-0a-005 Panel A  ←── mismo payload de clusters
T-0a-006 Panel C  ←── mismo payload de clusters (extrae campo `category`)
    — outputs: exclusivamente visuales; sin escritura en SQLCipher;
               sin retorno de datos a ningún módulo upstream
```

### 1.2 Verificación Punto A Punto De Los Contratos

| Interfaz | Proveedor | Consumidor | Coherente |
| --- | --- | --- | --- |
| Bookmarks → SQLCipher | T-0a-002 | T-0a-007 | ✅ — TS-0a-002 define los campos; TS-0a-007 los recibe con el schema correspondiente |
| SQLCipher → Classifier (dominio) | T-0a-007 | T-0a-003 | ✅ — dominio en claro en schema de TS-0a-007; TS-0a-003 lee solo dominio |
| Classifier → SQLCipher (categoría) | T-0a-003 | T-0a-007 | ✅ — TS-0a-003 escribe el campo categoria; schema de TS-0a-007 lo contempla |
| SQLCipher → Grouper (recursos con categoría) | T-0a-007 | T-0a-004 | ✅ — TS-0a-004 lee titulo (descifrado localmente), dominio y categoria; todos presentes en schema de TS-0a-007 |
| Grouper → Shell (payload de clusters) | T-0a-004 | T-0a-001 | ✅ — TS-0a-001 recibe el payload del Grouper al arrancar el workspace; TS-0a-004 define el contrato de output del payload |
| Shell → Panel A (payload de clusters) | T-0a-001 | T-0a-005 | ✅ — TS-0a-005 declara "el contrato de input es exactamente el contrato de output del Grouper"; confirmado en AR-0a-004 |
| Shell → Panel C (payload de clusters, campo category) | T-0a-001 | T-0a-006 | ✅ — TS-0a-006 extrae el campo `category` del payload del Grouper; coherente con los 10 valores del Classifier; confirmado en AR-0a-004 |
| Panel A → ningún módulo | T-0a-005 | — | ✅ — output exclusivamente visual; sin retorno de datos |
| Panel C → ningún módulo | T-0a-006 | — | ✅ — output exclusivamente visual; estado efímero de demo no persiste en SQLCipher |

**Veredicto: la cadena de contratos es coherente en todos los puntos de
interfaz. No hay desajuste de tipos, ni campo faltante, ni módulo que asuma
datos que ningún proveedor declara entregar.**

### 1.3 Solapamiento De Responsabilidades

| Par de módulos | Responsabilidad potencialmente solapada | Veredicto |
| --- | --- | --- |
| Classifier / Grouper | asignación de categoría | LIMPIO — el Classifier escribe categoría en SQLCipher; el Grouper la lee como dato ya persistido; no la reasigna |
| Grouper / Panel A | presentación visual de grupos | LIMPIO — el Grouper produce datos; Panel A los presenta; el Grouper no conoce la estructura visual de Panel A |
| Panel A / Panel C | renderizado del workspace | LIMPIO — Panel A renderiza recursos; Panel C renderiza plantillas de acción; cada panel opera sobre un subconjunto distinto del payload; ninguno invoca al otro |
| Importer / Classifier | procesamiento de URL/dominio | LIMPIO — el Importer extrae el dominio y lo persiste en claro; el Classifier lo lee y escribe categoría; el Importer no clasifica |
| Shell / Grouper | coordinación del workspace | LIMPIO — el Shell invoca al Grouper y distribuye el resultado; el Grouper no coordina el workspace |

**Veredicto: ningún solapamiento de responsabilidades entre módulos.**

---

## 2. Auditoría De Contaminación De Fase

El Phase Guardian ha verificado los siete task specs contra las restricciones
no negociables del MVP y las condiciones de no-paso del gate de 0a.

### 2.1 Restricciones Críticas — Verificación Transversal

| Restricción | Fuente normativa | Estado en los siete task specs |
| --- | --- | --- |
| Desktop no observa activamente | D9 | PASS — TS-0a-001 (criterio explícito), TS-0a-005 (renderizado estático), TS-0a-006 (renderizado estático); ningún spec introduce polling, push ni proceso de fondo |
| Share Extension iOS: LOCKED en 0a | D9 | PASS — ausente en todos los task specs; ninguno la referencia como dependencia o como módulo futuro |
| Sync de ningún tipo en 0a | D6 | PASS — TS-0a-007 sin campos de relay; TS-0a-001 excluye sync con referencia explícita; todos los specs restantes la excluyen en sus tablas de exclusiones |
| LLM no es requisito en ningún componente | D8 | PASS — ausente en TS-0a-001, TS-0a-002, TS-0a-003, TS-0a-004, TS-0a-005, TS-0a-007; documentado como mejora opcional no bloqueante en TS-0a-006 con cuatro capas de control; verificado en AR-0a-004 y QA-REVIEW-0a-004 |
| Panel B no existe en 0a | scope-boundaries, phase-definition | PASS — explícitamente excluido en todos los task specs; TS-0a-001, TS-0a-005 y TS-0a-006 lo nombran como señal de contaminación con acción BLOQUEAR |
| Bookmarks = bootstrap y cold start; no caso núcleo | D12 | PASS — TS-0a-002 lo clausura explícitamente; TS-0a-005 y TS-0a-006 declaran que no validan PMF ni el puente móvil→desktop |
| 0a no valida PMF | phase-definition | PASS — declarado en propósitos de TS-0a-005 y TS-0a-006; coherente con el backlog (does_not_validate) y con arch-note invariante 8 |
| Pattern Detector / Trust Scorer: PROHIBIDOS | D2, D17 | PASS — ausentes en todos los task specs; ninguno introduce lógica de detección longitudinal |
| Session Builder / Episode Detector real: PROHIBIDOS | D2, D10 | PASS — TS-0a-001 excluye el Episode Detector con referencia explícita; TS-0a-004 contiene tabla de diferenciación Grouper 0a vs Episode Detector 0b; TS-0a-005 y TS-0a-006 citan la tabla de diferenciación (condición 2 de R12) |
| FS Watcher: PROHIBIDO | D9 | PASS — ausente en todos los task specs |
| Schema SQLCipher mínimo; sin tablas de fases futuras | D1, D16 | PASS — TS-0a-007 define schema mínimo con cinco campos; ningún task spec agrega tabla de sesiones, episodios ni relay al schema |
| Ningún componente de 0a valida el puente móvil→desktop | phase-definition | PASS — declarado explícitamente en TS-0a-005 y TS-0a-006; ausente como narrativa en todos los demás task specs |
| Este repo solo produce gobernanza; no código del producto | AGENTS.md §3 | PASS — todos los task specs son documentos de especificación operativa, no código |

### 2.2 Invariantes Arquitectónicas (arch-note §Invariantes) — Verificación Transversal

| # | Invariante | Estado al cierre del ciclo de especificación |
| --- | --- | --- |
| 1 | El desktop no observa activamente | CONFIRMADA — ningún módulo especificado introduce observer activo; TS-0a-001 la clausura explícitamente |
| 2 | No se inicia ninguna conexión de red desde la app | CONFIRMADA — TS-0a-005 (sin red, incluido favicon) y TS-0a-006 (sin red para plantillas) tienen criterios de aceptación verificables; los módulos upstream no usan red en sus contratos |
| 3 | La única fuente de datos es el import local de bookmarks | CONFIRMADA — la cadena completa arranca en TS-0a-002 (archivo exportado local); ningún módulo posterior introduce fuente de datos externa |
| 4 | El LLM no es requisito funcional en ningún componente | CONFIRMADA — verificada módulo a módulo en AR-0a-004; el control de cuatro capas de TS-0a-006 es el más operativo de la cadena |
| 5 | Panel B no existe en 0a | CONFIRMADA — excluido explícitamente en todos los task specs de 0a con nomenclatura de señal de contaminación |
| 6 | El schema de SQLCipher no incluye tablas de 0b ni posteriores | CONFIRMADA — schema de TS-0a-007 verificado campo a campo en AR-0a-001; ningún task spec agregó campo ni tabla fuera del schema original |
| 7 | El Grouper de 0a no es el Episode Detector dual-mode de 0b | CONFIRMADA — tabla de diferenciación con 15 atributos comparativos en TS-0a-004; condición 2 de R12 operativa en TS-0a-004, TS-0a-005 y TS-0a-006 |
| 8 | Ningún componente se presenta como validación del puente móvil→desktop | CONFIRMADA — declarado en propósitos de TS-0a-005 y TS-0a-006; ausente como narrativa en todos los demás specs |
| 9 | Bookmarks siempre como bootstrap y cold start, nunca como caso núcleo | CONFIRMADA — TS-0a-002 la clausura; TS-0a-005 y TS-0a-006 la confirman en sus propósitos |

**Veredicto: las nueve invariantes arquitectónicas están satisfechas de forma
consistente en los siete task specs de Fase 0a.**

---

## 3. Trazabilidad De Decisiones

Las decisiones aplicadas en cada task spec son consistentes entre sí y con el
decisions-log. No hay contradicciones entre especificaciones.

| Decisión | Aplicación en la cadena | Consistencia |
| --- | --- | --- |
| D1 — Privacy Level 1 | TS-0a-007: schema con url y titulo cifrados; dominio en claro. TS-0a-002: import sin contenido completo. TS-0a-003: lee solo dominio. TS-0a-004: descifra titulo localmente. TS-0a-005: titulo descifrado recibido del Grouper; favicon local. TS-0a-006: opera sobre campo category, no contenido. | CONSISTENTE en los siete specs |
| D6 — Sin sync | TS-0a-007: schema sin campos de relay. TS-0a-001: sync excluida con referencia explícita. Ningún spec introduce sync en ninguna variante. | CONSISTENTE |
| D8 — LLM no es requisito | TS-0a-003: clasificación determinística. TS-0a-004: heurística de similitud sin LLM. TS-0a-005: renderizado puramente presentacional. TS-0a-006: baseline por plantillas estáticas; LLM como mejora opcional con condición de activación de R9. | CONSISTENTE — la aplicación más precisa es TS-0a-006 |
| D9 — Desktop no observa | TS-0a-001: sin Accessibility API, sin FS Watcher, sin process monitor. TS-0a-005: renderizado estático. TS-0a-006: renderizado estático. Ningún spec introduce observer activo bajo ningún nombre. | CONSISTENTE |
| D12 — Bookmarks como bootstrap | TS-0a-002: bootstrap y cold start; no caso núcleo. TS-0a-005: renderiza datos de bootstrap sin presentarlos como validación del producto. TS-0a-006: opera sobre categorías de recursos de bootstrap. | CONSISTENTE |
| D16 — Schema INTEGER PRIMARY KEY + UUID | TS-0a-007: INTEGER PRIMARY KEY + UUID indexado confirmado. Ningún spec posterior contradice el schema. | CONSISTENTE |

---

## 4. Trazabilidad De Riesgos

### R7 — Pérdida De Trazabilidad

Estado: MONITOREADO — bajo control al cierre del ciclo de especificación.

Cada task spec cita los documentos normativos que lo sustentan. La cadena
arch-note → backlog → task spec está trazada en todos los documentos. Los
documentos de revisión (AR y QA) verificaron trazabilidad en cada ciclo.

El Phase Guardian declara R7 bajo control en el ciclo de especificación. La
trazabilidad deberá mantenerse activa durante la implementación: cada decisión
de implementación que desvíe de un task spec debe registrarse con referencia
al spec correspondiente.

### R9 — LLM Como Dependencia Prematura De Panel C

Estado: WATCH — mitigado en la especificación con control de cuatro capas.

TS-0a-006 es el documento con mayor exposición a R9. El control verificado
por QA-REVIEW-0a-004 opera en cuatro capas:

1. **Definición estructural** — baseline de plantillas declarado como el requisito
   duro; LLM documentado como mejora opcional con condición explícita de no
   degradar el baseline.
2. **Plantillas de referencia completas** — las 10 plantillas están definidas con
   acciones concretas; un implementador tiene el baseline completo sin LLM.
3. **Criterio de aceptación verificable** — Panel C debe renderizarse en un entorno
   sin modelo local disponible; el criterio es falseable en demo.
4. **Señal de contaminación 13** — nombra el modo de fallo exacto y lo marca BLOQUEAR.

**Posición del Phase Guardian**: el control de R9 en la especificación es
suficiente. El riesgo permanece en WATCH durante la implementación porque la
violación no ocurre en la especificación sino en el código: un implementador
podría introducir LLM como requisito de facto aunque el spec lo prohíbe. El
criterio de aceptación 3 de TS-0a-006 convierte R9 en verificable en demo.

**Línea de vigilancia activa**: el Phase Guardian bloqueará cualquier PR o
entregable de implementación donde Panel C no renderice en ausencia de modelo
local o donde el SDK de LLM sea importado como dependencia no opcional.

### R11 — Panel B Como Dependencia Prematura

Estado: MITIGADO — vigilancia continua.

Panel B está explícitamente excluido en todos los task specs de 0a. Los tres
documentos donde R11 tenía mayor riesgo de activación —TS-0a-001, TS-0a-005
y TS-0a-006— lo nombran como señal de contaminación con acción BLOQUEAR o
ESCALAR. La exclusión es consistente en toda la cadena.

R11 pasa de WATCH a MITIGADO en el ciclo de especificación. El Phase Guardian
mantiene vigilancia continua durante la implementación: ningún componente de
la implementación puede introducir Panel B bajo ningún nombre.

### R12 — Confusión Grouper 0a Vs Episode Detector 0b

Estado: WATCH ACTIVO — control operativo verificado en la especificación.

La condición 2 de contención de R12 está operativa en tres documentos:

| Documento | Puntos de control |
| --- | --- |
| TS-0a-004 | Tabla de diferenciación con 15 atributos comparativos; sección de contención operativa con condición 2 explícita |
| TS-0a-005 | Cita de la tabla de diferenciación en sección relacional; criterio de aceptación 12 como control explícito verificable |
| TS-0a-006 | Cita de la tabla de diferenciación en sección relacional; criterio de aceptación 12 como control explícito verificable |

**Posición del Phase Guardian**: R12 permanece en WATCH ACTIVO. La
especificación tiene el control más robusto de toda la cadena de 0a para
este riesgo. El vector de mayor exposición no es la especificación sino la
narrativa de implementación y los entregables de 0b: si en 0b el Episode
Detector se describe como "una evolución del Grouper de 0a", la separación
colapsa aunque los task specs sean correctos.

**Línea de vigilancia activa**: el Phase Guardian bloqueará en 0b cualquier
entregable que:
- Describa el Grouper de 0a como "versión inicial del Episode Detector"
- Reutilice el contrato de output del Grouper como punto de partida del
  Episode Detector dual-mode
- Presente la heurística de similitud de título de 0a como "precursor de Jaccard"
- Utilice el término "agrupación" en un contexto de 0b sin distinguirlo
  explícitamente del Grouper de 0a

---

## 5. Estado Del Gate De Salida De 0a

El gate de salida de Fase 0a requiere tres condiciones. Ninguna puede ser
sustituida por documentación.

| Condición del gate | Descripción | Estado |
| --- | --- | --- |
| PIR-002 aprobado | Phase Integrity Review de cierre de especificación sin bloqueos | CUMPLIDA — este documento |
| Demo real | Panel A y Panel C renderizados con datos de bookmarks importados reales; el workspace es visible y comprensible | PENDIENTE — requiere implementación previa |
| Evidencia de observador externo | "un observador externo entiende la organización del workspace sin explicación previa" — TS-0a-005 criterio 11, TS-0a-006 criterio 11 | PENDIENTE — requiere sesión de demo con observador que no haya participado en el desarrollo de 0a |

Las condiciones mínimas del gate definidas en `operating-system/phase-gates.md`
son:

| Condición mínima | Documento que la respalda | Estado |
| --- | --- | --- |
| El workspace se entiende | TS-0a-005 criterio 11; TS-0a-006 criterio 11 | PENDIENTE — requiere demo real |
| La agrupación se entiende | TS-0a-005 criterio 1–2; TS-0a-004 (Grouper produce clusters coherentes) | PENDIENTE — requiere demo real |
| El contenedor genera interés | TS-0a-001 (Shell coherente y funcional) | PENDIENTE — requiere demo real |
| El equipo distingue claramente 0a de 0b | Verificado en este PIR: TS-0a-004 tabla de diferenciación; condición 2 de R12 en TS-0a-005 y TS-0a-006 | DOCUMENTADO |
| Bookmarks siguen siendo bootstrap/onboarding | Verificado en este PIR: TS-0a-002, TS-0a-005, TS-0a-006 | DOCUMENTADO |

**Conclusión de gate**: el gate de salida de 0a NO está listo para revisión.
La condición de evidencia de demo es prerrequisito insustituible. La
especificación documental —por rigurosa que sea— no puede sustituir la demo
real con un observador externo.

El Phase Guardian activará el proceso de revisión del gate cuando:
1. La implementación esté completa y el workspace sea ejecutable.
2. El equipo haya preparado una sesión de demo con datos reales de bookmarks.
3. Exista evidencia registrada de al menos un observador externo.

---

## 6. Hallazgos

| ID | Tipo | Descripción | Documento | Acción |
| --- | --- | --- | --- | --- |
| H-PIR2-001 | PASS | Cadena de contratos coherente en todos los puntos de interfaz; sin desajustes de tipos ni campos faltantes | Cadena completa | ninguna |
| H-PIR2-002 | PASS | Nueve invariantes arquitectónicas satisfechas de forma consistente en los siete task specs | Cadena completa | ninguna |
| H-PIR2-003 | PASS | Decisiones D1, D6, D8, D9, D12 y D16 aplicadas de forma consistente y sin contradicciones entre specs | Cadena completa | ninguna |
| H-PIR2-004 | PASS | Condición 2 de R12 operativa y trazable en TS-0a-004, TS-0a-005 y TS-0a-006 | TS-0a-004, TS-0a-005, TS-0a-006 | ninguna |
| H-PIR2-005 | PASS | Control de R9 de cuatro capas en TS-0a-006; falseable en demo y en criterio de aceptación | TS-0a-006 | ninguna |
| H-PIR2-006 | PASS | Panel B explícitamente excluido como componente, dependencia y placeholder en todos los specs; R11 mitigado | Cadena completa | ninguna |
| H-PIR2-007 | PASS | Cierre de la observación de AR-0a-003 sobre `resources[].title`: declarado en TS-0a-005 y verificado en AR-0a-004 | TS-0a-005 | cerrado |
| H-PIR2-008 | REGISTRADO | Decisión de deduplicación por categoría en Panel C correcta según Technical Architect en AR-0a-004 | TS-0a-006 | registrado; sin corrección |
| H-PIR2-009 | CONDICIÓN DE GATE | El criterio "un observador externo entiende la organización del workspace sin explicación previa" requiere demo real; no verificable por documentación | TS-0a-005 y TS-0a-006 | registrado como condición del gate |

---

## 7. Bloqueos

**Ninguno.**

El ciclo de especificación de Fase 0a es íntegro. El Phase Guardian no
encuentra en ninguno de los siete task specs ni en sus revisiones ningún
hallazgo que impida utilizarlos como contratos de referencia para la
implementación de Fase 0a.

---

## 8. Decisión Del Phase Guardian

**APROBADO — ciclo de especificación de Fase 0a íntegro y apto para
implementación.**

El ciclo de especificación completo de Fase 0a supera la revisión de integridad
de fase sin bloqueos. Los siete task specs son coherentes entre sí, con
arch-note-phase-0a.md y con el marco normativo del proyecto.

Los únicos elementos pendientes son las condiciones del gate de salida —demo
real y evidencia de observador externo— que son prerrequisitos del gate por
diseño y no dependen del ciclo de especificación.

Los riesgos R9 y R12 permanecen en WATCH ACTIVO durante la implementación.
El Phase Guardian mantiene las líneas de vigilancia declaradas en la sección 4.

---

## 9. Próximos Agentes Responsables

| Agente | Acción | Urgencia |
| --- | --- | --- |
| **Orchestrator** | Emitir OD de apertura del repo del producto y activación de la implementación de Fase 0a, tomando como base los siete task specs aprobados y este PIR-002 | ALTA — siguiente paso tras PIR-002 aprobado |
| **Phase Guardian** | Mantener vigilancia activa sobre R9 y R12 durante la implementación; preparar proceso de demo y revisión de gate cuando el workspace sea ejecutable | CONTINUA — vigilancia de fase activa |
| **Context Guardian** | Actualizar `project-docs/risk-register.md`: R11 → MITIGADO; R7 → BAJO CONTROL; R9 y R12 confirmar estado WATCH ACTIVO durante implementación | BAJA — próximo ciclo |
| **Handoff Manager** | Producir HO-005 cuando el Orchestrator emita la OD de implementación | CUANDO SE ACTIVE LA OD |

**Siguiente agente inmediato**: Orchestrator → OD de apertura del repo del
producto e inicio de implementación de Fase 0a.

---

## 10. Trazabilidad

```
PIR-001 (Phase Guardian) — activación de 0a
    ↓
[Cuatro ciclos operativos: HO-002, HO-003, HO-004]
    ↓
PIR-002 (Phase Guardian) ← este documento — cierre de especificación de 0a
    ↓
OD de implementación de 0a (Orchestrator)
    ↓
Implementación del producto en repo del producto
    ↓
Demo real + evidencia de observador externo
    ↓
Gate de salida de Fase 0a (Phase Guardian activa el gate)
    ↓
Apertura de Fase 0b
```

---

protected_phase: 0a
issue: Ciclo de especificación completo revisado. Siete task specs íntegros.
in_scope_or_not: Todos los entregables del ciclo de especificación son in-scope de 0a.
required_action: Orchestrator emite OD de implementación. Phase Guardian mantiene vigilancia de R9 y R12.
next_agent: Orchestrator (OD de apertura del repo del producto e inicio de implementación de Fase 0a).
