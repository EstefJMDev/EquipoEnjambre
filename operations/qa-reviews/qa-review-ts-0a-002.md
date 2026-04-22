# QA Review — TS-0a-002 Bookmark Importer Retroactive

document_id: QA-REVIEW-TS-0a-002
reviewer_agent: QA Auditor
phase: 0a
date: 2026-04-22
status: APROBADO — sin bloqueos
document_reviewed: operations/task-specs/TS-0a-002-bookmark-importer-retroactive.md
references_checked:
  - Project-docs/decisions-log.md (D1, D9, D12)
  - Project-docs/scope-boundaries.md
  - Project-docs/phase-definition.md
  - operations/architecture-notes/arch-note-phase-0a.md
  - operations/backlogs/backlog-phase-0a.md
  - operations/handoffs/HO-002-phase-0a-spec-cycle-1.md

---

## Resultado Global

| Documento | Resultado | Bloqueos | Correcciones aplicadas |
| --- | --- | --- | --- |
| TS-0a-002 | APROBADO | ninguno | ninguna |

---

## A. Coherencia Con Decisiones Cerradas

### A.1 D1 — Privacidad Nivel 1

PASS.

| Control | Evidencia en TS-0a-002 | Estado |
| --- | --- | --- |
| URL cifrada antes de persistir | "url — URL cifrada (TEXT NOT NULL, D1)"; criterio de aceptación explícito | ✅ |
| Título cifrado antes de persistir | "title — título cifrado (TEXT NOT NULL, D1)"; criterio de aceptación explícito | ✅ |
| Dominio en claro con justificación | "dominio en claro (D1 — nivel de abstracción aceptado)" | ✅ |
| Categoría en claro con justificación | "derivada del dominio por el Classifier; no revela contenido" | ✅ |
| Contenido completo de páginas excluido | "No se extrae ni se almacena contenido completo de páginas en ningún caso (D1)"; criterio de aceptación | ✅ |
| Sin API de red para enriquecer metadatos | Fuente PROHIBIDA explícita: "Cualquier API de red para enriquecer metadatos — invariante 2 de arch-note, D6" | ✅ |
| Lectura solo desde filesystem local | "lee el archivo de bookmarks del navegador desde el filesystem local; sin red" | ✅ |

D1 verificado campo a campo. No hay campo sensible sin cifrar ni mecanismo que exponga contenido de páginas.

### A.2 D9 — Único Observer MVP = Share Extension iOS. Desktop No Observa En MVP.

PASS.

| Control | Evidencia en TS-0a-002 | Estado |
| --- | --- | --- |
| Sin observación continua de bookmarks | "Observación continua de nuevos bookmarks — MVP: nunca — D9" en tabla de exclusiones | ✅ |
| Sin monitoring de cambios en archivo | "Monitoring de cambios en el archivo de bookmarks — MVP: nunca — D9, invariante 1 de arch-note" | ✅ |
| Sin API de observación activa | Criterio de aceptación: "el Importer no usa ninguna API de observación activa (Accessibility, clipboard, FS Watcher, etc.)" | ✅ |
| Share Extension iOS prohibida en 0a | Fuente PROHIBIDA explícita: "Share Extension iOS — Módulo de 0b — D9" | ✅ |
| Clipboard prohibido | Fuente PROHIBIDA explícita: "Clipboard del sistema — Observer activo — D9" | ✅ |
| Accesibilidad prohibida | Fuente PROHIBIDA explícita: "Accesibilidad o ventanas del sistema — D9" | ✅ |
| Operación discreta de una pasada | "opera como una sola pasada discreta al abrir la app; no monitorea" | ✅ |
| Señal de contaminación registrada | "el importer observa nuevos bookmarks en tiempo real — BLOQUEAR — D9" | ✅ |

La tabla Importer vs Observer documenta explícitamente la distinción modal
("Operación discreta de una pasada" frente a "Observer continuo activo").
D9 está operativamente contenido.

### A.3 D12 — Bookmarks = Onboarding/Cold Start. No Caso Núcleo.

PASS.

| Control | Evidencia en TS-0a-002 | Estado |
| --- | --- | --- |
| Sección dedicada a la distinción | "Por Qué Pertenece A Onboarding Y No Al Caso Núcleo" — sección íntegra | ✅ |
| Definición como bootstrap explícita | "D12 los define como bootstrap y cold start, no como señales del producto" | ✅ |
| Caso núcleo correctamente ubicado en 0b | "El caso núcleo del producto es el puente móvil→desktop [...] Ese caso pertenece a Fase 0b." | ✅ |
| Bloqueo PMF declarado | "Cualquier entregable que presente los bookmarks como validación del producto real debe bloquearse. Esta tarea no valida PMF." | ✅ |
| Criterio de aceptación documental | "un observador externo que lea este documento entiende que los bookmarks son datos de arranque y no el caso de uso núcleo del producto" | ✅ |
| Señales de contaminación registradas | "los bookmarks demuestran que el flujo móvil→desktop funciona" → ESCALAR; "los bookmarks ya validan que el producto funciona" → ESCALAR | ✅ |

---

## B. Coherencia Con Fase 0a

### B.1 Que TS-0a-002 Sirve A La Validación Del Formato Workspace

PASS. El documento establece el propósito instrumental con precisión:

> "la demo de Fase 0a necesita datos reales del usuario para mostrar que el
> formato workspace es comprensible y tiene valor. Sin datos, el workspace es
> una pantalla vacía y el gate de 0a no puede cerrarse."

El Importer no introduce funcionalidad de producto; su rol es producir la
carga de datos que permite que el resto de la cadena de 0a sea demostrable.
Esto es coherente con la hipótesis de 0a definida en phase-definition: validar
el formato workspace, no PMF.

### B.2 Que No Se Presenta Como Validación Del Puente Móvil → Desktop

PASS. La tabla Importer vs Observer diferencia explícitamente las dos columnas
en la dimensión de "Qué valida":

| — | Bookmark Importer (T-0a-002) | Share Extension Observer (0b) |
| --- | --- | --- |
| Valida | Formato workspace | Hipótesis del puente |
| Fase | 0a | 0b |

No hay formulación en el documento que atribuya al Importer capacidad de
validar la hipótesis del puente. El caso núcleo está correctamente descrito
como perteneciente a 0b.

### B.3 Que No Introduce Lógica Propia De 0b

PASS. Exclusiones explícitas con primera fase permitida y regla que las bloquea:

| Elemento | Primera fase | Regla |
| --- | --- | --- |
| Share Extension iOS | 0b | D9 |
| Sync de cualquier tipo | 0b | D6 |
| Detección de episodios / Session Builder | 0b | arch-note |
| Captura activa de URLs | 0b | D9 |
| Lógica de ventanas temporales | 0b | Session Builder es de 0b |

Ninguna de estas exclusiones es ambigua ni está declarada como "reservada
para futuro" (patrón de contaminación preventiva). Todas están clausuradas
con referencia normativa.

### B.4 Que No Introduce Observer Activo

PASS. Verificado en A.2. El modo de operación del Importer es estructuralmente
opuesto al de un observer: activación única por invocación del Shell al
arrancar, sin proceso en background, sin watcher de filesystem, sin API de
observación.

### B.5 Que No Introduce Sync

PASS. "Sync de cualquier tipo | 0b | D6" en tabla de exclusiones.
Señal de contaminación registrada: "dejamos preparado el formato para que
sync lo recoja en 0b" → BLOQUEAR. El schema del recurso no contiene campos
preparatorios para sync.

### B.6 Que No Introduce Captura Continua

PASS. "Monitoring de cambios en el archivo de bookmarks | MVP: nunca" y
"Observación continua de nuevos bookmarks | MVP: nunca" en tabla de
exclusiones. Criterio de aceptación: "no persiste como proceso en background".

### B.7 Que No Mezcla Bookmarks Con El Caso Núcleo

PASS. La sección "Por Qué Pertenece A Onboarding Y No Al Caso Núcleo"
cierra esta posibilidad con argumentación explícita:

> "Son el equivalente funcional de los datos de demo: útiles para validar el
> formato, no para validar la hipótesis núcleo."

---

## C. Coherencia Narrativa

### C.1 Que La Tabla Importer vs Observer Contiene El Riesgo R2

PASS. La tabla opera directamente sobre el riesgo narrativo R2 (bookmarks
como caso núcleo). Las dimensiones de la tabla ("Señal que representa",
"Cuándo actúa", "Qué captura", "Valida", "Fase") atacan las cinco formas
posibles de confusión entre el Importer y un observer de intención activa.

La contención operativa en la sección "Riesgo Principal: Reinterpretación
Como Puente Real" añade tres condiciones de control concretas, incluyendo
que el gate de salida de 0a no puede cerrarse si la evidencia de demo usa
lenguaje de validación de producto.

R2 está contenido en el nivel narrativo que corresponde a un task spec.

### C.2 Que El Documento No Deja Ambigüedad Sobre El Papel Instrumental Del Importer

PASS. El documento usa tres formulaciones complementarias que cubren el
riesgo de ambigüedad desde ángulos distintos:

1. Declaración directa: "No genera valor de producto por sí mismo."
2. Rol funcional: "Su valor es instrumental: permite que la cadena de
   módulos de 0a funcione sobre datos reales."
3. Metáfora operativa: "Son el equivalente funcional de los datos de demo."

Ninguna formulación del documento atribuye al Importer autonomía, señal de
intención del usuario ni papel de validación del producto.

### C.3 Que No Hay Formulaciones Que Puedan Hacer Parecer Que 0a Ya Valida PMF

PASS. El documento incluye clausuras directas:

- "Esta tarea no valida PMF." (sección Propósito)
- "El gate de salida de 0a no puede cerrarse si la evidencia de demo usa
  lenguaje de validación de producto." (sección Riesgo Principal)
- Señales de contaminación con acción ESCALAR para las dos formulaciones
  PMF más probables.

No se encontró ninguna formulación ambigua o de doble lectura que permita
interpretar que 0a valida PMF.

---

## D. Calidad Del Entregable

### D.1 Criterios De Aceptación Verificables

PASS. Los ocho primeros criterios de aceptación son verificables técnicamente
en implementación (red, filesystem, cifrado, unicidad, procesos en background,
APIs de observación, delegación al Classifier). Los dos últimos son criterios
documentales que verifican el entregable mismo, no la implementación; son
correctos para un document spec del proyecto marco.

### D.2 Límites Claros

PASS. El documento define límites en tres capas complementarias:
- tabla de fuentes (PERMITIDA / PROHIBIDA)
- tabla de exclusiones (primera fase permitida + regla que bloquea)
- señales de contaminación de fase (acción + regla violada)

No hay zona gris entre lo que el Importer hace y lo que está prohibido.

### D.3 Handoff Razonable Al Siguiente Task Spec

PASS. La sección "Handoff Esperado" establece el flujo correcto:
QA Auditor → correcciones si las hubiera → aprobación → Desktop Tauri Shell
Specialist produce TS-0a-003. La cadena de dependencias está trazada:

```
TS-0a-002 → TS-0a-003 → TS-0a-004 → TS-0a-005 + TS-0a-006
```

Esto es coherente con HO-002 y con el mapa de dependencias del backlog.

### D.4 Ausencia De Contaminación De Fase

PASS.

| Control | Resultado |
| --- | --- |
| Panel B ausente | ✅ — excluido en tabla con primera fase = Fase 1 |
| Sync ausente | ✅ — excluido con D6; señal de contaminación registrada |
| Observer activo ausente | ✅ — D9 referenciado; operación discreta declarada |
| Session Builder ausente | ✅ — excluido en tabla con primera fase = 0b |
| Episode Detector real ausente | ✅ — excluido; primera fase = 0b |
| Pattern Detector ausente | ✅ — excluido; primera fase = Fase 2 |
| Trust Scorer ausente | ✅ — excluido; primera fase = Fase 2 |
| State Machine ausente | ✅ — excluida; primera fase = Fase 2 |
| LLM como requisito ausente | ✅ — excluido; D8 referenciado; señal de advertencia registrada |
| Schema sin campos de fases futuras | ✅ — schema mínimo de 6 campos; ninguno pertenece a 0b+ |
| Nota de gobernanza presente | ✅ — "Esta especificación no autoriza implementación en el repo de producto" |

---

## Hallazgos

| Tipo | Descripción | Acción |
| --- | --- | --- |
| PASS | D1: campo a campo verificado; cifrado correcto; contenido de páginas excluido | ninguna |
| PASS | D9: operación discreta; sin observer activo; sin fuentes de observación | ninguna |
| PASS | D12: bookmarks como bootstrap; PMF bloqueado; tabla Importer vs Observer operativa | ninguna |
| PASS | Coherencia completa con Fase 0a; ningún elemento de 0b+ | ninguna |
| PASS | Criterios de aceptación verificables; límites claros; handoff correcto | ninguna |
| OBSERVACIÓN MENOR | La frase sobre la invocación al Classifier mezcla dos enunciados: "síncrona y local" y el recordatorio D8 sobre LLM. No es contradictoria pero puede generar pregunta al leer TS-0a-003. | Aceptable en TS-0a-002; TS-0a-003 deberá aclarar el modelo de ejecución del Classifier. No requiere corrección aquí. |

No se encontraron contradicciones bloqueantes, señales de contaminación
activa, riesgos con IDs no canónicos ni texto de implementación de producto.

---

## Bloqueos

**Ninguno.**

TS-0a-002 puede avanzar al siguiente paso del handoff definido en su sección
"Handoff Esperado".

---

## Siguiente Agente Responsable

**Desktop Tauri Shell Specialist**

Razón: TS-0a-002 queda aprobado sin correcciones. El paso siguiente definido
en la sección "Handoff Esperado" de TS-0a-002 y en HO-002 es que el Desktop
Tauri Shell Specialist produzca TS-0a-003 (Domain/Category Classifier).

El Classifier tiene revisión obligatoria por Technical Architect (límite de
módulo y diferenciación con Episode Detector, conforme a HO-002).

La observación menor sobre la invocación al Classifier debe resolverse
al especificar TS-0a-003, no al corregir TS-0a-002.

---

## Trazabilidad De Entregable

| Acción | Archivo | Estado |
| --- | --- | --- |
| Revisado | operations/task-specs/TS-0a-002-bookmark-importer-retroactive.md | APROBADO |
| Creado | operations/qa-reviews/qa-review-ts-0a-002.md | este documento |
