# Revisión Arquitectónica — TS-0a-003 Domain/Category Classifier

document_id: AR-0a-002
owner_agent: Technical Architect
phase: 0a
date: 2026-04-22
status: APROBADO — sin bloqueos; una observación de precisión aplicada
documents_reviewed:
  - operations/task-specs/TS-0a-003-domain-category-classifier.md
reference_normativo:
  - operations/architecture-notes/arch-note-phase-0a.md
  - Project-docs/decisions-log.md (D2, D3, D8)
  - Project-docs/risk-register.md (R12)
  - operations/backlogs/backlog-phase-0a.md (T-0a-003)
precede_a: Desktop Tauri Shell Specialist → TS-0a-004

---

## Resultado Global

| Documento | Resultado arquitectónico | Bloqueos | Correcciones |
| --- | --- | --- | --- |
| TS-0a-003 | APROBADO | ninguno | 1 — precisión en la condición de no-bloqueo del INSERT |

---

## A. Verificación Del Contrato De Módulo

El arch-note define el contrato del Domain/Category Classifier así:

```
input:  recursos normalizados del Importer
output: recursos con dominio y categoría asignados por reglas determinísticas
restricciones duras:
  sin red
  sin LLM
  sin aprendizaje longitudinal
  sin ventanas temporales
  clasificación determinística: mismo input → mismo output
  no es el Episode Detector de 0b
```

Verificación punto a punto contra TS-0a-003:

| Atributo del contrato | Requerido por arch-note | Declarado en TS-0a-003 | Coherente |
| --- | --- | --- | --- |
| input: recursos normalizados del Importer | sí | "recibe un recurso normalizado del Importer con URL y título" | ✅ |
| output: dominio + categoría por reglas determinísticas | sí | "devuelve el recurso enriquecido con dominio y categoría al Importer" | ✅ |
| sin red | sí | criterio de aceptación explícito; columna PROHIBIDA en tabla de fuentes | ✅ |
| sin LLM | sí | criterio de aceptación explícito; tabla de exclusiones con D8 | ✅ |
| sin aprendizaje longitudinal | sí | criterio de aceptación explícito: "no mantiene estado entre invocaciones" | ✅ |
| sin ventanas temporales | sí | criterio de aceptación explícito; tabla de exclusiones | ✅ |
| determinismo: mismo input → mismo output | sí | "la clasificación es determinística: el mismo dominio siempre produce la misma categoría" | ✅ |
| no es el Episode Detector de 0b | sí | sección dedicada + tabla Classifier vs Episode Detector de 9 atributos | ✅ |

**Veredicto: contrato de módulo alineado sin desviaciones.**

---

## B. Verificación Del Mecanismo De Clasificación

### B.1 Extracción de dominio

El Paso 1 define que el dominio se extrae por parsing de hostname de la URL:
subdominio normalizado, `www` eliminado. Los tres ejemplos son arquitectónicamente
correctos:

```
https://github.com/usuario/repo  →  github.com   ✅
https://mail.google.com/...      →  google.com   ✅ (subdominio eliminado)
https://www.notion.so/...        →  notion.so    ✅ (www eliminado)
```

Observación arquitectónica: la normalización de subdominios (`mail.google.com` → `google.com`)
es una decisión de diseño razonable para la demo de 0a. El criterio de aceptación
correspondiente debe ser inequívoco: "el dominio se extrae por parsing de hostname
de la URL". TS-0a-003 lo formula correctamente.

### B.2 Tabla de correspondencia dominio → categoría

La tabla de la sección "Mecanismo de Clasificación" es estática y sin lógica de
inferencia: para cada grupo de dominios hay una categoría asignada, más un fallback
explícito a `other`. Esto es arquitectónicamente correcto para 0a:

- el fallback `other` garantiza que no hay bloqueo por dominio desconocido
- la tabla es extensible sin cambio de contrato (nuevo dominio → nueva fila, misma lógica)
- la tabla no introduce similitud, embeddings ni LLM en ningún caso

**Veredicto: mecanismo de clasificación correcto. Determinístico, local y sin dependencias externas.**

---

## C. Verificación De Límites De Módulo

### C.1 Separación de responsabilidades en la cadena de 0a

| Módulo | Responsabilidad | Separación en TS-0a-003 |
| --- | --- | --- |
| Importer (T-0a-002) | invocar al Classifier; normalizar; persistir en SQLCipher | ✅ — el Classifier no escribe en SQLCipher; no conoce al Grouper |
| Classifier (T-0a-003) | extracción de dominio + asignación de categoría | ✅ — responsabilidad atómica y acotada |
| SQLCipher (T-0a-007) | persistencia cifrada | ✅ — el Classifier no toca SQLCipher directamente |
| Grouper (T-0a-004) | leer `domain` y `category` de SQLCipher; producir clusters | ✅ — el Grouper no invoca al Classifier; lee de la capa de persistencia |
| Panel C (T-0a-006) | seleccionar plantilla por `category` | ✅ — Panel C lee el campo ya persistido; no invoca al Classifier |

No se detecta solapamiento de responsabilidades. La cadena de invocación es:

```
Importer → [invoca] → Classifier → [devuelve {domain, category}] → Importer → [INSERT] → SQLCipher
                                                                                    ↓
                                                                              Grouper ← lee
                                                                                    ↓
                                                                             Shell / Panel C ← consume
```

**Veredicto: separación de responsabilidades correcta en todos los puntos de contacto.**

### C.2 Límite Classifier / Episode Detector (D2, D3, R12)

La tabla Classifier vs Episode Detector de TS-0a-003 es el control arquitectónico
principal para R12 en este módulo. Verificación de los 9 atributos comparativos:

| Atributo | Classifier (T-0a-003) | Episode Detector (0b) | Correcto |
| --- | --- | --- | --- |
| Función | Asignar categoría a recurso individual | Detectar episodio accionable | ✅ |
| Input | URL ya importada | URLs capturadas en tiempo real | ✅ |
| Algoritmo | Tabla dominio → categoría | Jaccard + categoría fallback | ✅ |
| Ventana temporal | No aplica | Menos de 24 horas | ✅ |
| Resultado | Dominio + categoría (siempre) | Episodio accionable / no accionable | ✅ |
| Modo dual | No existe | Precise + broad (D3) | ✅ |
| Determinismo | Sí | No (depende de señales acumuladas) | ✅ |
| Aprendizaje | No | No en 0b; Pattern Detector en Fase 2 | ✅ |
| Fase | 0a | 0b | ✅ |

La columna "Aprendizaje" merece una nota: el Episode Detector de 0b tampoco
aprende (el aprendizaje longitudinal pertenece al Pattern Detector de Fase 2
per D2 y D17). TS-0a-003 lo declara correctamente en la tabla.

La contención operativa de tres condiciones en la sección "Riesgo Principal"
es adecuada y coherente con el nivel de exposición de este módulo a R12.

**Veredicto: R12 correctamente contenido para el Classifier. Distinción con Episode Detector operativa en tabla y en sección de riesgo.**

---

## D. Verificación De Decisiones Cerradas

### D.2 — Episode Detector dual-mode inmediato; Pattern Detector completo solo en Fase 2

PASS. El Classifier no anticipa ni al Episode Detector (0b) ni al Pattern Detector
(Fase 2). La tabla de exclusiones declara:

- `Similitud de Jaccard | 0b | D3: modo preciso del Episode Detector dual-mode`
- `Aprendizaje longitudinal de categorías | Fase 2 | D2, D17: Pattern Detector`

Ambas exclusiones tienen primera fase permitida y regla normativa. ✅

### D.3 — Precisión del Episode Detector: dual-mode con Jaccard + ecosistemas, fallback broad

PASS. TS-0a-003 confirma que Jaccard pertenece al Episode Detector preciso de 0b
y no tiene lugar en el Classifier de 0a. La distinción está en la tabla de exclusiones
y en la tabla Classifier vs Episode Detector. El Classifier no implementa ningún
tipo de similitud entre recursos; opera recurso a recurso. ✅

### D.8 — Plantillas como baseline; LLM como mejora opcional

PASS. El Classifier no usa LLM. La señal de contaminación `"añadimos LLM para
clasificar dominios que no están en la tabla" → ADVERTIR — si bloquea el INSERT: ESCALAR`
está correctamente calibrada. ✅

---

## E. Corrección Aplicada

### Precisión en la condición de no-bloqueo del INSERT

**Ubicación**: sección "Contrato Con Otros Módulos De 0a — Con Bookmark Importer
Retroactive (T-0a-002)"

**Texto original**:
> si por algún error de parsing la URL no produce dominio válido, el Classifier
> asigna dominio vacío y categoría `other`; el INSERT no se cancela

**Problema**: "dominio vacío" es un valor que puede entrar en conflicto con el
schema de TS-0a-007, donde el campo `domain` es `TEXT NOT NULL`. Un dominio vacío
(`""`) técnicamente satisface `NOT NULL` en SQLite, pero introduce un valor semánticamente
inválido que el Grouper podría manejar de manera inesperada. El contrato debe
especificar un fallback que sea válido tanto sintáctica como semánticamente.

**Texto corregido**:
> si por algún error de parsing la URL no produce dominio válido, el Classifier
> asigna el literal `"unknown"` como dominio y la categoría `other`; el INSERT
> no se cancela

**Impacto**: Menor. No afecta la lógica de clasificación nominal ni los contratos
con el Grouper o Panel C. Sí garantiza que el Grouper siempre recibe un dominio
con valor semántico acotado y que el campo `NOT NULL` del schema de TS-0a-007
se respeta sin ambigüedad.

**Acción**: Corrección aplicada directamente en TS-0a-003, sección
"Contrato Con Otros Módulos De 0a — Con Bookmark Importer Retroactive (T-0a-002)".

---

## Hallazgos

| Tipo | Descripción | Acción |
| --- | --- | --- |
| PASS | Contrato de módulo: alineado con arch-note punto a punto | ninguna |
| PASS | Mecanismo de clasificación: determinístico, local, tabla estática con fallback | ninguna |
| PASS | Separación de responsabilidades: Classifier / Importer / SQLCipher / Grouper / Panel C | ninguna |
| PASS | D2, D3, D8 verificados sin desviaciones | ninguna |
| PASS | R12: tabla Classifier vs Episode Detector de 9 atributos; contención operativa de 3 condiciones | ninguna |
| CORRECCIÓN MENOR | Fallback de dominio inválido: `""` → `"unknown"` para coherencia con schema NOT NULL de TS-0a-007 | aplicada |

---

## Bloqueos

**Ninguno.**

TS-0a-003 es arquitectónicamente coherente con el arch-note y con el marco
normativo de Fase 0a. La corrección aplicada es menor y no afecta el contrato
de módulo ni las decisiones normativas.

---

## Siguiente Agente Responsable

**Desktop Tauri Shell Specialist**

Razón: TS-0a-003 queda aprobado con corrección menor acusada y aceptada.
El siguiente paso definido en la sección "Handoff Esperado" de TS-0a-003
y en HO-002 es que el Desktop Tauri Shell Specialist produzca TS-0a-004
(Basic Similarity Grouper).

TS-0a-004 es el documento de mayor exposición a R12 en todo el ciclo.
La diferenciación con el Episode Detector dual-mode debe ser explícita,
con tabla de atributos comparativos equivalente o más detallada que la
de TS-0a-003. El Technical Architect y el QA Auditor revisan TS-0a-004
conjuntamente conforme a HO-002.

---

## Trazabilidad De Entregable

| Acción | Archivo | Estado |
| --- | --- | --- |
| Revisado y corregido | operations/task-specs/TS-0a-003-domain-category-classifier.md | APROBADO con corrección menor |
| Creado | operations/architecture-reviews/AR-0a-002-classifier-review.md | este documento |
