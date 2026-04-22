# QA Review — TS-0a-004 Basic Similarity Grouper

document_id: QA-REVIEW-0a-003
reviewer_agent: QA Auditor
phase: 0a
date: 2026-04-22
status: APROBADO — sin bloqueos; corrección menor coordinada con AR-0a-003
documents_reviewed:
  - operations/task-specs/TS-0a-004-basic-similarity-grouper.md
references_checked:
  - operations/architecture-notes/arch-note-phase-0a.md
  - operating-system/phase-gates.md
  - Project-docs/scope-boundaries.md
  - Project-docs/phase-definition.md
  - Project-docs/decisions-log.md (D2, D3, D6, D8, D9, D12, D16)
  - Project-docs/risk-register.md (R12)
  - operations/architecture-reviews/AR-0a-003-grouper-review.md (revisión arquitectónica conjunta)

---

## Resultado Global

| Documento | Resultado QA | Bloqueos | Correcciones |
| --- | --- | --- | --- |
| TS-0a-004 | APROBADO | ninguno | 1 — coordinada con AR-0a-003 (conteo 14 → 15) |

---

## 1. Verificación De Criterios De Aceptación

Cada criterio se evalúa por verificabilidad externa (puede un auditor independiente
confirmar o refutar el cumplimiento sin acceso al autor).

### 1.1 Agrupación nivel 1 por dominio y categoría

> "los recursos importados se agrupan por dominio y categoría (nivel 1) como
> criterio primario; el agrupador no inventa grupos que no existen en los datos
> del Classifier"

**Verificabilidad**: ALTA. Un auditor puede cruzar los valores {domain, category}
presentes en SQLCipher con los grupos generados por el Grouper y confirmar que
no aparece ningún group_key sin correspondencia en los datos. El criterio es
determinístico y falseable. ✅

### 1.2 Sub-agrupación nivel 2 por tokens, no Jaccard

> "la sub-agrupación por similitud de título (nivel 2) opera por coincidencia de
> tokens, no por coeficiente de Jaccard ni por embeddings; el método de similitud
> queda descrito con suficiente detalle en la implementación como para ser auditado"

**Verificabilidad**: ALTA. Un auditor puede inspeccionar el código e identificar
si se calcula un coeficiente |A∩B|/|A∪B| o simplemente una intersección de tokens.
La exigencia de descripción auditable en la implementación ancla el criterio a
evidencia verificable. ✅

**Control adicional de R12**: este criterio es el punto de entrada más probable
para contaminación del Episode Detector. La formulación "no por coeficiente de
Jaccard ni por embeddings" es operativa: nombra los métodos prohibidos, no solo
dice "sin similitud avanzada". Correcto. ✅

### 1.3 Sin conexión de red

**Verificabilidad**: ALTA. Verificable por monitorización de red durante la
ejecución del Grouper. Sin ambigüedad posible. ✅

### 1.4 Sin LLM en ninguna variante del flujo nominal

**Verificabilidad**: ALTA. Inspección de código + absence of LLM SDK imports.
La especificación "en ninguna variante del flujo nominal" cierra el escape de
"LLM como mejora no nominal" correctamente. ✅

### 1.5 Sin estado entre ejecuciones

**Verificabilidad**: ALTA. Un auditor puede ejecutar el Grouper dos veces con
el mismo conjunto de datos y verificar: (a) outputs idénticos, (b) ausencia de
archivos de estado persistido entre ejecuciones. ✅

### 1.6 Sin ventana temporal

**Verificabilidad**: ALTA. Inspección de código: ausencia de filtros por
timestamp o de lógica de acumulación con referencia al momento de captura.
El criterio es falseable. ✅

**Control adicional de R12**: "ventana temporal" es la segunda señal de
contaminación más probable para confusión con el Episode Detector de 0b (que
opera con ventana de <24h). El criterio la nombra explícitamente. Correcto. ✅

### 1.7 Sin veredicto accionable/no-accionable

**Verificabilidad**: ALTA. Inspección del output: si el schema del cluster no
contiene campos de tipo `is_actionable`, `verdict`, `status_episodic` o
equivalentes, el criterio pasa. El criterio es falseable por presencia de campo. ✅

### 1.8 Sin trigger, sin cross-device, sin notificación

**Verificabilidad**: ALTA. Testing de integración: el Grouper no debe emitir
eventos, notificaciones ni solicitudes a servicios externos. Verificable en
entorno de sandbox. ✅

### 1.9 R12 — Control explícito

> "un observador externo que lea este documento y la tabla de diferenciación
> comprende sin ambigüedad que el Grouper de 0a no es el Episode Detector de 0b,
> no es una versión simplificada del Episode Detector de 0b, y no puede crecer
> hasta convertirse en él"

**Verificabilidad**: MEDIA — cualitativa. Este criterio requiere juicio del
revisor, no puede automatizarse. Esto es apropiado para R12: el riesgo es
narrativo y documental, y solo puede contenerse con comprensión real del
documento.

**Evaluación propia de este criterio**: el QA Auditor, leyendo TS-0a-004 en
su totalidad, confirma que:
- la sección "Por Qué Este Grouper No Equivale Al Episode Detector De 0b" es
  clara, sin ambigüedad y no deja espacio para la interpretación proto-detector
- la tabla de 15 atributos articula cada dimensión de diferenciación de manera
  completa y sin solapamiento de funciones
- la declaración explícita "El Grouper de 0a no crece hasta convertirse en el
  Episode Detector de 0b. El Episode Detector de 0b se implementa como módulo
  nuevo en 0b, independientemente del Grouper de 0a." cierra la interpretación
  evolutiva que constituye el núcleo de R12

**Veredicto para criterio 1.9**: SATISFECHO. ✅

### 1.10 Tabla cubre los 15 atributos

> (después de la corrección aplicada) "la tabla Grouper vs Episode Detector de
> este documento cubre los 15 atributos enumerados en la sección correspondiente"

**Verificabilidad**: ALTA. Conteo directo de filas en la tabla. La corrección
coordinada con AR-0a-003 actualiza el conteo de 14 a 15 para que el criterio
sea falseable contra el contenido real de la tabla. ✅

### 1.11 Panel A puede renderizar sin campos adicionales

**Verificabilidad**: ALTA. Cruzar el schema de output del Grouper
`{group_key, domain, category, sub_label, resources[]}` con las necesidades
de renderizado de Panel A. El criterio es falseable: Panel A solicita un campo
ausente → falla. ✅

**Evaluación de coherencia**: el arch-note define el output de Panel A como
"lista visual de recursos agrupados [título, favicon, domain, subtema]". El
`sub_label` del cluster corresponde a "subtema". El campo `favicon` no está
en el contrato de output del Grouper; Panel A debería derivarlo del `domain`
(esto es propio de la especificación de Panel A, no del Grouper). No se detecta
brecha en el contrato del Grouper. ✅

**Resumen de criterios de aceptación**:

| Criterio | Verificabilidad | Estado R12 |
| --- | --- | --- |
| 1 — agrupación nivel 1 | alta | n/a |
| 2 — nivel 2 por tokens, no Jaccard | alta | control directo de R12 |
| 3 — sin red | alta | n/a |
| 4 — sin LLM | alta | n/a |
| 5 — sin estado entre ejecuciones | alta | n/a |
| 6 — sin ventana temporal | alta | control directo de R12 |
| 7 — sin veredicto accionable | alta | control directo de R12 |
| 8 — sin trigger/cross-device/notificación | alta | control directo de R12 |
| 9 — R12 explícito | media (cualitativa) | control central de R12 — satisfecho |
| 10 — tabla cubre 15 atributos (corregido) | alta | n/a |
| 11 — Panel A sin campos adicionales | alta | n/a |

---

## 2. Verificación De Señales De Contaminación

Las 12 señales se evalúan por cobertura de vectores y por accionabilidad de
cada entrada (diagnóstico + acción + regla violada).

### 2.1 Cobertura de vectores de riesgo

| Vector de riesgo | Señal(es) que lo cubren |
| --- | --- |
| Jaccard en el Grouper | señal 1 |
| Ventana temporal en el Grouper | señal 2 |
| Detección de intención en el Grouper | señal 3 |
| Confusión directa Grouper = Episode Detector | señal 4 |
| Interpretación evolutiva (Grouper → Episode Detector) | señal 5 |
| Grouper como trigger de workspace | señal 6 |
| Cross-device / Sync en 0a | señal 7 |
| Wow moment asignado al Grouper | señal 8 |
| Embeddings como mejora | señal 9 |
| Grouper como Session Builder | señal 10 |
| Ranqueo de grupos por relevancia | señal 11 |
| Persistencia de clusters en SQLCipher | señal 12 |

Todos los vectores identificados como probables en la demo de 0a están
cubiertos. Las señales 4 y 5 son las más importantes para R12 (confusión
directa e interpretación evolutiva) y ambas tienen acción ESCALAR al Phase
Guardian, que es la acción correcta: no son errores implementables sino
desviaciones conceptuales que requieren intervención de governance.

### 2.2 Accionabilidad de cada señal

Cada señal tiene tres campos: diagnóstico, acción y regla violada. Los
tres campos son operativos en todas las señales.

La escala de acciones es apropiada:
- BLOQUEAR: para desviaciones implementables (Jaccard, red, sync, trigger)
- ESCALAR al Phase Guardian: para confusiones conceptuales (R12 directo,
  wow moment asignado, interpretación evolutiva)
- ADVERTIR: para el único caso de "mejora eventual" (embeddings) que no
  es bloqueante mientras no sea un requisito

Esta gradación es más precisa que en documentos anteriores de la cadena.
La distinción BLOQUEAR/ESCALAR para confusión documental es correcta porque
algunas señales no son errores técnicos sino problemas de framing que el
Phase Guardian debe abordar. ✅

### 2.3 Señales no cubiertas evaluadas

**"añadimos boosting por fecha de creación para que los bookmarks más recientes
aparezcan primero"**: este vector introduce temporalidad (recency weighting) sin
ser una ventana temporal explícita. La señal 2 ("añadimos una ventana de 24 horas
para ver los bookmarks más recientes") es adyacente pero no la misma cosa.
Sin embargo, el criterio de aceptación 6 ("sin ventana temporal ni acumulación
de señales con referencia al momento de captura") bloquea esta variante.
No se requiere señal adicional en la tabla: el criterio de aceptación es suficiente.

**"añadimos un campo relevance_score al cluster"**: cubierto por señal 11
("ranqueamos los grupos por relevancia para el usuario").

**Veredicto**: las 12 señales son suficientes para los vectores de riesgo
identificables en la demo de 0a. No se requiere expansión.

---

## 3. Verificación De Ausencia De Conceptos Contaminantes

| Concepto prohibido | ¿Aparece en positivo en TS-0a-004? | Verificación |
| --- | --- | --- |
| Intención del usuario | No | "El Grouper no interpreta la intención del usuario al guardar esos recursos" — explícitamente excluido |
| Episodios | No | "El Grouper no infiere... si los recursos forman un episodio de trabajo accionable" — explícitamente excluido |
| Wow moment | No | Aparece únicamente en la tabla de diferenciación en la columna del Episode Detector y en la señal de contaminación 8 |
| Sync | No | Tabla de exclusiones con D6; señal de contaminación 7 |
| Observer activo | No | Tabla de exclusiones con D9; invariante 1 del arch-note |
| Lógica de 0b | No | Todas las referencias a 0b son en contexto de exclusión o diferenciación |
| PMF / validación del producto | No | "No valida PMF"; "Valida que el contenedor workspace puede presentar recursos agrupados" |
| Puente móvil→desktop | No | "Sin relación directa con el caso núcleo del producto: es bootstrap / cold start (D12)" |
| Panel B | No | No mencionado como dependencia ni como output |
| LLM como requisito | No | Tabla de exclusiones + criterio de aceptación |
| Jaccard | No (en positivo) | Mencionado exclusivamente como excluido: "No aplica similitud de Jaccard" |

Ninguno de los conceptos prohibidos aparece en contexto positivo en el documento.
Todas las menciones son de exclusión, diferenciación o señal de contaminación. ✅

---

## 4. Verificación De Pertenencia A 0a

| Control | Resultado |
| --- | --- |
| Cabecera: phase = 0a | ✅ |
| Backlog referenciado = backlog-phase-0a.md | ✅ |
| Módulos dependientes = todos de 0a | ✅ — TS-0a-003 (APROBADO), TS-0a-007 (APROBADO) |
| Módulos siguientes = TS-0a-005 + TS-0a-006 (0a) | ✅ |
| Tabla de exclusiones con primera-fase-permitida para cada elemento | ✅ |
| Nota de gobernanza explícita: "no autoriza implementación" | ✅ |
| Hipótesis de 0a validada = formato workspace, no PMF | ✅ |

El documento pertenece claramente a 0a en todos los controles. ✅

---

## 5. Evaluación De La Tabla De Diferenciación Como Control De R12

La tabla de 15 atributos se evalúa como cierre de ambigüedad narrativa y
funcional para R12.

### 5.1 ¿La tabla cierra la ambigüedad narrativa?

La frase más peligrosa en el espacio narrativo de R12 es:
"el Grouper es el Episode Detector básico de la Fase 0a."

Para que esta frase sea imposible de sostener, la tabla debe demostrar que
Grouper y Episode Detector tienen:
(a) funciones distintas
(b) inputs distintos
(c) algoritmos distintos
(d) outputs distintos
(e) relaciones distintas con el producto

La tabla cubre los cinco ejes:
- (a) → atributo "Objetivo"
- (b) → atributo "Tipo de input"
- (c) → atributos "Criterio de agrupación", "Algoritmo de similitud", "Modo dual"
- (d) → atributo "Output"
- (e) → atributos "Relación con el caso núcleo", "Relación con el wow moment",
         "Capacidad de activar flujo cross-device"

**Veredicto: la tabla cierra la ambigüedad narrativa.** Una persona con la
tabla no puede sostener que el Grouper es el Episode Detector básico sin
ignorar evidencia explícita en 15 dimensiones. ✅

### 5.2 ¿La tabla cierra la ambigüedad funcional?

La ambigüedad funcional más probable es:
"si añadimos Jaccard y ventanas temporales al Grouper, obtenemos el Episode Detector."

La tabla responde a esto con:
- "Determinismo": el Grouper es determinístico; el Episode Detector no lo es
  (depende de señales acumuladas en ventana temporal)
- "Temporalidad": el Grouper no tiene ventana temporal; el Episode Detector sí
- "Algoritmo de similitud": los algoritmos son distintos, no el mismo con más parámetros

La sección "Riesgo Principal: R12" refuerza con texto explícito:
"añadir Jaccard, ventanas temporales o modo dual al Grouper de 0a no produce
el Episode Detector de 0b: produce un Grouper contaminado de 0a."

**Veredicto: la tabla cierra la ambigüedad funcional.** ✅

---

## 6. Hallazgos

| Tipo | Descripción | Acción |
| --- | --- | --- |
| PASS | Criterios de aceptación: todos verificables externamente; 4 controlan R12 directamente | ninguna |
| PASS | Señales de contaminación: 12 señales con cobertura completa de vectores; accionabilidad correcta | ninguna |
| PASS | Ausencia de conceptos contaminantes en positivo: intención, episodios, wow moment, sync, observer, lógica de 0b | ninguna |
| PASS | Documento pertenece claramente a 0a en todos los controles | ninguna |
| PASS | Tabla de diferenciación: cierra ambigüedad narrativa y funcional en 15 dimensiones | ninguna |
| PASS | R12 control: multi-capa (narrativa, tabla, criterio, señales, contención); nivel de control más completo de toda la cadena de 0a | ninguna |
| CORRECCIÓN MENOR | Conteo de atributos "14 → 15" coordinada con AR-0a-003 | aplicada |

---

## 7. Bloqueos

**Ninguno.**

TS-0a-004 es el documento de mayor exposición a R12 en la Fase 0a y el único
donde el riesgo de confusión con el Episode Detector es estructural, no
incidental. El QA Auditor confirma que el documento contiene los controles
operativos necesarios para que esa confusión no pueda introducirse sin
evidencia documental de desviación.

El nivel de control de R12 en TS-0a-004 es significativamente más alto que
en los documentos previos de la cadena. Esto es apropiado.

---

## 8. Siguiente Agente Responsable

**Desktop Tauri Shell Specialist**

Razón: ambas revisiones (AR-0a-003 y QA-REVIEW-0a-003) cierran sin bloqueos.
La corrección menor está aplicada en TS-0a-004. El documento puede cerrarse
con status APROBADO.

El Desktop Tauri Shell Specialist puede avanzar a:
- TS-0a-005 (Panel A) — que consume los clusters del Grouper
- TS-0a-006 (Panel C) — que recibe el mismo payload de clusters

Ambos documentos deben referenciar la tabla de diferenciación de TS-0a-004
conforme a la condición 2 de la contención operativa de R12:
"La tabla de diferenciación de este documento debe citarse en cualquier
entregable de 0a o de 0b que mencione el Grouper."

---

## 9. Trazabilidad De Entregable

| Acción | Archivo | Estado |
| --- | --- | --- |
| Revisado y corregido | operations/task-specs/TS-0a-004-basic-similarity-grouper.md | APROBADO con corrección menor |
| Revisado | operations/architecture-reviews/AR-0a-003-grouper-review.md | utilizado como referencia |
| Creado | operations/qa-reviews/qa-review-ts-0a-004.md | este documento |
