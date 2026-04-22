# Revisión Arquitectónica — TS-0a-004 Basic Similarity Grouper

document_id: AR-0a-003
owner_agent: Technical Architect
phase: 0a
date: 2026-04-22
status: APROBADO — sin bloqueos; una corrección menor aplicada
documents_reviewed:
  - operations/task-specs/TS-0a-004-basic-similarity-grouper.md
reference_normativo:
  - operations/architecture-notes/arch-note-phase-0a.md
  - Project-docs/decisions-log.md (D2, D3, D8, D9, D12, D16)
  - Project-docs/risk-register.md (R12)
  - operations/backlogs/backlog-phase-0a.md (T-0a-004)
  - operations/architecture-reviews/AR-0a-002-classifier-review.md
precede_a: Desktop Tauri Shell Specialist → TS-0a-005 + TS-0a-006

---

## Resultado Global

| Documento | Resultado arquitectónico | Bloqueos | Correcciones |
| --- | --- | --- | --- |
| TS-0a-004 | APROBADO | ninguno | 1 — discrepancia de conteo de atributos en la tabla de diferenciación |

---

## A. Verificación Del Contrato De Módulo

El arch-note define el contrato del Basic Similarity Grouper así:

```
input:  recursos clasificados (con dominio y categoría)
output: clusters de recursos [dominio, categoría, sub-agrupación por título]
restricciones duras:
  heurística simple sobre título (no Jaccard del Episode Detector preciso)
  sin clustering semántico con embeddings o LLM
  sin ventanas temporales de sesión (Session Builder es de 0b)
  no es el Episode Detector dual-mode de 0b
```

Verificación punto a punto contra TS-0a-004:

| Atributo del contrato | Requerido por arch-note | Declarado en TS-0a-004 | Coherente |
| --- | --- | --- | --- |
| input: recursos con dominio y categoría | sí | "El Grouper lee de SQLCipher los recursos ya persistidos por el Importer tras la invocación al Classifier. Cada recurso llega con los campos: {id, uuid, url (cifrada), title (cifrado), domain, category}" | ✅ |
| output: clusters [dominio, categoría, sub-agrupación] | sí | "cluster {group_key, domain, category, sub_label, resources[]}" | ✅ — schema de output más explícito que el arch-note, sin desviaciones |
| heurística simple (no Jaccard) | sí | "La heurística es local, sin red, sin embeddings, sin LLM. No aplica similitud de Jaccard entre conjuntos: la comparación es por token compartido, no por coeficiente de similitud entre sets de n-gramas." | ✅ |
| sin embeddings / sin LLM | sí | tabla de exclusiones; criterios de aceptación 4 y 2 | ✅ |
| sin ventanas temporales | sí | "el Grouper no implementa ninguna forma de ventana temporal ni de acumulación de señales con referencia al momento de captura" | ✅ |
| no es el Episode Detector dual-mode de 0b | sí | sección dedicada + tabla de 15 atributos + contención operativa de 4 condiciones | ✅ |

**Veredicto: contrato de módulo alineado con arch-note sin desviaciones.**

---

## B. Verificación De Entrada Y Salida

### B.1 Entrada

El Grouper lee desde SQLCipher los campos `domain`, `category` y el `title` cifrado.
No invoca al Classifier ni al Importer directamente. La mediación es exclusivamente
a través de la capa de persistencia. El diagrama del documento es correcto:

```
Classifier → [produce domain + category] → Importer → SQLCipher
                                                         ↓
                                               Grouper ← lee domain + category + title cifrado
```

El campo `title` se descifra localmente para la heurística de nivel 2. Esto es
arquitectónicamente correcto: el descifrado ocurre en memoria, sin red, dentro
del proceso de la aplicación. La clave SQLCipher está disponible en el contexto
de la aplicación Tauri. No hay implicación de red ni violación de D1.

**Observación de precisión (no bloqueante)**: el contrato de output no indica
explícitamente que el campo `title` en `resources[]` se entrega en forma descifrada.
Dado que el Grouper ya descifra el título para la heurística y Panel A necesita
mostrarlo, la entrega descifrada en memoria es la única interpretación coherente.
No se requiere corrección documental, pero la implementación debe asumir que
`resources[].title` es el título descifrado. Se registra como observación.

### B.2 Salida

El output es una lista de clusters en memoria:

```
cluster {
  group_key: string      -- e.g., "development/github.com"
  domain: string
  category: string
  sub_label: string      -- opcional, derivado de tokens comunes
  resources: [
    {uuid, title, domain, category}
  ]
}
```

El Grouper no escribe en SQLCipher. El Grouper no modifica el schema de 0a.
El output en memoria es coherente con el contrato de input de Panel A
(`input: clusters del Grouper`) y de Panel C (`input: clusters + tipo de
contenido del Classifier`). El campo `category` del cluster permite a Panel C
seleccionar la plantilla sin invocar al Classifier independientemente.

**Veredicto: input y output correctamente delimitados. Sin escritura en
SQLCipher. Sin conexión de red. Sin modificación de schema.**

---

## C. Verificación De Separación Con Módulos Adyacentes

| Módulo | Separación declarada en TS-0a-004 | Coherente |
| --- | --- | --- |
| Bookmark Importer (T-0a-002) | "El Grouper no invoca al Importer. Lee los campos domain y category desde la capa de persistencia." | ✅ |
| Domain/Category Classifier (T-0a-003) | "El Grouper no llama al Classifier directamente." La relación es unidireccional mediada por SQLCipher. | ✅ |
| SQLCipher (T-0a-007) | "El Grouper lee de SQLCipher. No escribe en SQLCipher. El Grouper no modifica el schema de 0a ni añade tablas." | ✅ |
| Panel A (T-0a-005) | "Panel A consume los clusters producidos por el Grouper." El Grouper no conoce la estructura visual de Panel A. | ✅ |
| Panel C (T-0a-006) | "Panel C recibe el mismo payload de clusters que Panel A." Panel C no invoca al Grouper independientemente. | ✅ |
| Desktop Workspace Shell (T-0a-001) | "El Shell no invoca al Grouper directamente." El Shell recibe los clusters procesados a través de los paneles. | ✅ |

No se detecta solapamiento de responsabilidades entre ninguno de los módulos.
La cadena de invocación está correctamente trazada y es coherente con la
descrita en AR-0a-002 y en el arch-note.

**Veredicto: separación de módulos limpia en todos los puntos de contacto.**

---

## D. Verificación De La Heurística De Nivel 2

La heurística de sub-agrupación por similitud de título opera así:

1. tokenizar por espacios + eliminación de stopwords
2. identificar si dos o más recursos del mismo grupo (dominio+categoría)
   comparten al menos N tokens no stopword (N ≥ 2 como referencia de demo)
3. recursos que comparten tokens forman un sub-grupo con etiqueta derivada
   de los tokens comunes

Este mecanismo **no es Jaccard**. La similitud de Jaccard opera sobre conjuntos
de n-gramas y produce un coeficiente |A∩B|/|A∪B|. La heurística de TS-0a-004
comprueba únicamente presencia de tokens compartidos (boolean), no calcula
ningún coeficiente de similitud. La distinción es explícita en el documento:

> "No aplica similitud de Jaccard entre conjuntos: la comparación es por token
> compartido, no por coeficiente de similitud entre sets de n-gramas."

La heurística tampoco anticipa ninguna forma de detección episódica:
- no opera con ventana temporal
- no acumula señales de captura activa
- no produce veredicto de accionable/no-accionable
- no evalúa si los tokens comunes indican intención de trabajo

El umbral N ≥ 2 es ajustable durante la demo sin cambio de contrato, siempre
que el método de similitud no cambie. Esto es correcto: el parámetro de umbral
no es parte del contrato de módulo, sino de la calibración de demo.

**Veredicto: heurística de nivel 2 correcta. No anticipa Jaccard ni lógica
de Episode Detector.**

---

## E. Verificación De Decisiones Cerradas

### D.2 — Episode Detector dual-mode en 0b; Pattern Detector en Fase 2

PASS. El Grouper no implementa ningún componente del Episode Detector ni del
Pattern Detector. La tabla de exclusiones declara explícitamente:
- `Detección de episodios | 0b | D2`
- `Aprendizaje longitudinal de agrupaciones | Fase 2 | D2, D17`
Ambas con primera fase permitida y regla normativa. ✅

### D.3 — Precisión del Episode Detector: Jaccard + ecosistemas + broad fallback

PASS. Jaccard está explícitamente excluido tanto del mecanismo de agrupación
(nivel 1 y nivel 2) como de la tabla de exclusiones con referencia a D3.
El modo dual (precise + broad) está declarado en la tabla de diferenciación
como propiedad exclusiva del Episode Detector de 0b. ✅

### D.8 — LLM no es requisito funcional

PASS. LLM excluido en tabla de exclusiones, criterio de aceptación y señales
de contaminación. La heurística de nivel 2 es puramente lexical. ✅

### D.9 — Observer activo prohibido

PASS. "El Grouper no activa ningún flujo de workspace, ningún trigger de
cross-device ni ninguna notificación." El Grouper es invocado, no observa.
No hay mecanismo de captura activa ni de polling. ✅

### D.12 — Bookmarks como bootstrap/cold start, no como caso núcleo

PASS. "Su rol en 0a es estrictamente instrumental y orientado a la demo:
produce la estructura mínima que hace el workspace comprensible para un
observador externo." La relación del Grouper con el caso núcleo del producto
está declarada como "Sin relación directa" en la tabla de diferenciación. ✅

### D.16 — Schema mínimo de SQLCipher

PASS. "El Grouper no escribe en SQLCipher. No modifica el schema de 0a ni
añade tablas." El schema permanece inalterado por este módulo. ✅

---

## F. Verificación De Invariantes Arquitectónicas (arch-note)

| Invariante | Verificación en TS-0a-004 | Estado |
| --- | --- | --- |
| 1. El desktop no observa activamente (D9) | El Grouper no observa; es invocado; no hay captura activa ni polling | ✅ |
| 2. Sin conexión de red | Criterio de aceptación explícito; señal de contaminación bloqueante | ✅ |
| 3. Única fuente de datos = import local de bookmarks | Los datos llegan del Importer vía SQLCipher; no hay fuente externa | ✅ |
| 4. LLM no es requisito (D8) | Explícitamente excluido en tabla, criterios y señales | ✅ |
| 5. Panel B no existe en 0a | No mencionado como dependencia ni en el output del Grouper | ✅ |
| 6. Schema SQLCipher sin tablas de 0b | "El Grouper no modifica el schema de 0a ni añade tablas." | ✅ |
| 7. Grouper ≠ Episode Detector 0b | Propósito central del documento; tabla de 15 atributos; contención de 4 condiciones | ✅ |
| 8. Ningún componente de 0a = validación del puente móvil→desktop | "Sin relación directa con el caso núcleo del producto: es bootstrap / cold start (D12)" | ✅ |
| 9. Bookmarks = bootstrap y cold start (D12) | "produce la estructura mínima que hace el workspace comprensible"; no valida PMF | ✅ |

**Todas las invariantes satisfechas.**

---

## G. Verificación De La Tabla De Diferenciación

La tabla "Grouper 0a vs Episode Detector 0b" contiene **15 atributos**:

1. Objetivo
2. Tipo de input
3. Temporalidad
4. Criterio de agrupación / detección
5. Output
6. Relación con el caso núcleo
7. Capacidad de detectar intención
8. Capacidad de activar flujo cross-device
9. Relación con el wow moment
10. Algoritmo de similitud
11. Modo dual
12. Determinismo
13. Aprendizaje
14. Owner documental
15. Fase

Los 15 atributos cubren todas las dimensiones de diferenciación relevantes:
función, input, temporalidad, algoritmo, output, relación con el producto,
intención, cross-device, wow moment, modo dual, determinismo, aprendizaje
y propiedad documental. La tabla cierra la ambigüedad narrativa y funcional
con mayor profundidad que la tabla equivalente del arch-note (8 atributos)
y que la de TS-0a-003 (9 atributos), lo cual es apropiado dado que TS-0a-004
es el documento de mayor exposición a R12 en la Fase 0a.

**Discrepancia detectada**: el documento declara "14 atributos" en dos puntos,
pero la tabla efectivamente contiene 15 filas. Ver sección H (Corrección).

---

## H. Corrección Aplicada

### Discrepancia de conteo: "14 atributos" → "15 atributos"

**Ubicación 1**: criterios de aceptación
> "la tabla Grouper vs Episode Detector de este documento cubre los 14 atributos
> enumerados en la sección correspondiente"

**Ubicación 2**: sección "Handoff Esperado — 1. Technical Architect"
> "que la tabla de diferenciación Grouper vs Episode Detector cubre los 14
> atributos con suficiente precisión técnica"

**Problema**: la tabla de diferenciación contiene 15 filas (Objetivo a Fase).
El conteo declarado de 14 es incorrecto y crea un criterio de aceptación que
falla en la verificación si el auditor cuenta las filas reales de la tabla.

**Texto corregido en ambas ubicaciones**:
> "la tabla Grouper vs Episode Detector de este documento cubre los 15 atributos
> enumerados en la sección correspondiente"
> "que la tabla de diferenciación Grouper vs Episode Detector cubre los 15
> atributos con suficiente precisión técnica"

**Impacto**: menor. No afecta la lógica de agrupación, el contrato de módulo
ni ninguna decisión normativa. Sí afecta la verificabilidad del criterio de
aceptación y la coherencia del criterio con el contenido real de la tabla.

**Acción**: corrección aplicada directamente en TS-0a-004.

---

## I. Hallazgos

| Tipo | Descripción | Acción |
| --- | --- | --- |
| PASS | Contrato de módulo: alineado con arch-note punto a punto | ninguna |
| PASS | Input/output correctamente delimitados; sin escritura en SQLCipher; sin red | ninguna |
| PASS | Separación de módulos limpia en todos los puntos de contacto | ninguna |
| PASS | Heurística de nivel 2: token sharing confirmado, no Jaccard, sin temporalidad episódica | ninguna |
| PASS | D2, D3, D8, D9, D12, D16 verificados sin desviaciones | ninguna |
| PASS | 9 invariantes arquitectónicas del arch-note satisfechas | ninguna |
| PASS | Tabla de diferenciación: 15 atributos; cierra ambigüedad narrativa y funcional | ninguna |
| OBSERVACIÓN | title en resources[] debe ser descifrado; implicado pero no declarado explícitamente | no requiere corrección documental |
| CORRECCIÓN MENOR | Conteo de atributos: "14" → "15" en criterio de aceptación y en handoff | aplicada |

---

## J. Bloqueos

**Ninguno.**

TS-0a-004 es arquitectónicamente coherente con el arch-note y con el marco
normativo de Fase 0a. El control de R12 es el más completo de todos los
documentos de la cadena de 0a. La corrección aplicada es de precisión interna
y no afecta ningún contrato de módulo.

---

## K. Siguiente Agente Responsable

**QA Auditor**

Razón: la revisión arquitectónica cierra sin bloqueos. Conforme a la
instrucción de revisión conjunta obligatoria establecida en TS-0a-004 y
en HO-002, el QA Auditor debe completar su revisión antes de que el documento
pueda cerrar. La corrección menor ya está aplicada; el QA Auditor revisa
el documento en su estado corregido.

Tras el QA Auditor: **Desktop Tauri Shell Specialist** recibe la conclusión
conjunta y puede avanzar a TS-0a-005 (Panel A) y TS-0a-006 (Panel C).

---

## L. Trazabilidad De Entregable

| Acción | Archivo | Estado |
| --- | --- | --- |
| Revisado y corregido | operations/task-specs/TS-0a-004-basic-similarity-grouper.md | pendiente de corrección (ver H) + revisión QA |
| Creado | operations/architecture-reviews/AR-0a-003-grouper-review.md | este documento |
