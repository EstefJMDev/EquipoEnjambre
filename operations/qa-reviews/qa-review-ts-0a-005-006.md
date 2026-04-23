# QA Review — TS-0a-005 Panel A + TS-0a-006 Panel C

document_id: QA-REVIEW-0a-004
reviewer_agent: QA Auditor
phase: 0a
date: 2026-04-23
status: APROBADO — sin bloqueos; sin correcciones
documents_reviewed:
  - operations/task-specs/TS-0a-005-panel-a-recursos-agrupados.md
  - operations/task-specs/TS-0a-006-panel-c-siguientes-pasos.md
references_checked:
  - operations/architecture-notes/arch-note-phase-0a.md
  - operating-system/phase-gates.md
  - Project-docs/scope-boundaries.md
  - Project-docs/phase-definition.md
  - Project-docs/decisions-log.md (D1, D8, D9, D12)
  - Project-docs/risk-register.md (R9, R11, R12)
  - operations/architecture-reviews/AR-0a-004-panel-a-panel-c-review.md (revisión arquitectónica conjunta)
  - operations/backlogs/backlog-phase-0a.md (T-0a-005, T-0a-006)

---

## Resultado Global

| Documento | Resultado QA | Bloqueos | Correcciones |
| --- | --- | --- | --- |
| TS-0a-005 Panel A | APROBADO | ninguno | ninguna |
| TS-0a-006 Panel C | APROBADO | ninguno | ninguna |

---

## 1. Verificación De Criterios De Aceptación — TS-0a-005 Panel A

Cada criterio se evalúa por verificabilidad externa: ¿puede un auditor
independiente confirmar o refutar el cumplimiento sin acceso al autor?

### 1.1 Renderizado de todos los clusters sin filtrar

> "Panel A renderiza todos los clusters producidos por el Grouper sin filtrar,
> reordenar ni ocultar ningún grupo; el número de grupos visibles en Panel A
> coincide con el número de clusters en el payload del Grouper"

**Verificabilidad**: ALTA. Un auditor puede contar los clusters en el payload
y compararlos con los grupos visibles en la UI. El criterio es falseable. ✅

### 1.2 Encabezado de grupo con sub_label opcional

> "cada encabezado de grupo muestra dominio, categoría y sub_label si el cluster
> lo incluye; si sub_label está vacío, el encabezado muestra solo dominio y
> categoría sin error ni espacio vacío visible"

**Verificabilidad**: ALTA. Verificable con un conjunto de datos de prueba donde
algunos clusters tienen sub_label y otros no. El comportamiento con cadena vacía
es falseable. ✅

### 1.3 Recurso con título, dominio y favicon opcional

> "cada recurso dentro de un grupo muestra el título (descifrado localmente) y
> el dominio; si el favicon no está disponible localmente, su ausencia no bloquea
> el renderizado ni genera error visible al observador"

**Verificabilidad**: ALTA. Verificable con recursos que no tienen favicon en el
caché local. La ausencia del favicon no puede producir error ni espacio vacío
con etiqueta de error. ✅

**Coherencia con D1**: el título se descifra localmente dentro del proceso de la
aplicación; el dominio está en claro en SQLCipher según TS-0a-007. El criterio
es coherente con Privacy Level 1. ✅

### 1.4 Sin resumen, abstract ni texto de contenido de páginas

**Verificabilidad**: ALTA. Inspección de UI: ausencia de elementos de texto
derivados de contenido de páginas. El criterio es falseable por presencia de
cualquier resumen, bullet o extracto. ✅

**Control de R11**: este criterio es el control principal de Panel B en Panel A.
La formulación cubre todas las variantes (resumen, abstract, bullets, texto
derivado) sin dejar escapatoria semántica. ✅

### 1.5 Invocación al Grouper: una sola vez por sesión de demo

> "Panel A no invoca al Grouper más de una vez durante el ciclo de vida de la
> sesión de demo; el payload se recibe una sola vez al arrancar el workspace"

**Verificabilidad**: ALTA. Verificable por logging de invocaciones al Grouper
durante la sesión de demo. El criterio es falseable por registro de dos o más
invocaciones. ✅

### 1.6 Sin invocación al Classifier ni al Importer

**Verificabilidad**: ALTA. Inspección de código: ausencia de llamadas a los
módulos Classifier e Importer en el flujo de renderizado de Panel A. ✅

### 1.7 Sin conexión de red (incluido favicon)

**Verificabilidad**: ALTA. Monitorización de red durante el renderizado de
Panel A: cero conexiones iniciadas, incluida la resolución de favicons. La
especificación "incluida la carga de favicons" cierra el único escape semántico
posible para este criterio. ✅

### 1.8 Sin LLM en ninguna variante del flujo nominal

**Verificabilidad**: ALTA. Inspección de código: ausencia de imports del SDK
de LLM, ausencia de invocaciones a modelos en el flujo de renderizado. ✅

### 1.9 Sin Panel B (ni componente ni placeholder)

**Verificabilidad**: ALTA. Inspección de UI y de código: ausencia de cualquier
elemento de Panel B bajo cualquier nombre. El criterio incluye "placeholder",
que cierra el escape de "reservamos el espacio para después". ✅

### 1.10 Distinción visual Panel A / Panel C

> "Panel A es visualmente distinguible de Panel C: el observador puede
> identificar sin instrucción previa cuál es la zona de recursos agrupados y
> cuál es la zona de siguientes pasos"

**Verificabilidad**: MEDIA — cualitativa. Requiere juicio del observador, pero
es externamente verificable: el observador no puede necesitar instrucción para
distinguir las dos zonas. El criterio se satisface con una demo real. ✅

### 1.11 Criterio de gate de 0a

> "el criterio de gate de 0a — 'un observador externo entiende la organización
> del workspace sin explicación previa' — puede evaluarse positivamente con
> Panel A renderizado; este criterio requiere evidencia de demo real"

**Verificabilidad**: BAJA por definición — cualitativa y requiere demo real.
Esto es correcto: el criterio de gate no es automatizable. TS-0a-005 lo incorpora
como criterio de Panel A y declara explícitamente que requiere demo real. La
incorporación del criterio de gate en la especificación de Panel A es el mecanismo
correcto para que la revisión de 0a pueda evaluarlo contra un componente concreto.

**Evaluación propia de este criterio**: el QA Auditor confirma que un observador
que vea Panel A con clusters renderizados (grupos con encabezado de categoría/dominio
y lista de recursos con título y dominio) puede entender la organización del
workspace sin instrucción previa. El diseño es coherente con la hipótesis de 0a.
✅

### 1.12 R12 control explícito (condición 2)

> "este documento cita la tabla de diferenciación Grouper 0a vs Episode Detector
> 0b de TS-0a-004; un observador que lea este documento comprende que Panel A es
> consumidor del Grouper de 0a y no tiene relación con el Episode Detector de 0b"

**Verificabilidad**: ALTA para la cita (documento contiene referencia trazable),
MEDIA para la comprensión (requiere lectura). La verificación de que la cita
existe es objetiva. AR-0a-004 confirmó que la condición 2 está operativa. ✅

**Resumen de criterios de aceptación de TS-0a-005:**

| Criterio | Verificabilidad | Control de riesgo |
| --- | --- | --- |
| 1 — todos los clusters renderizados | alta | n/a |
| 2 — encabezado con sub_label opcional | alta | n/a |
| 3 — recurso con título + dominio + favicon opcional | alta | D1 |
| 4 — sin Panel B bajo ninguna forma | alta | R11 — control principal |
| 5 — una sola invocación al Grouper | alta | n/a |
| 6 — sin Classifier ni Importer | alta | n/a |
| 7 — sin red, incluido favicon | alta | n/a |
| 8 — sin LLM | alta | n/a |
| 9 — sin Panel B ni placeholder | alta | R11 — control secundario |
| 10 — distinción visual Panel A / Panel C | media (cualitativa) | n/a |
| 11 — criterio de gate de 0a | baja (demo real) | gate de salida |
| 12 — R12 condición 2 | alta (cita) + media (comprensión) | R12 |

---

## 2. Verificación De Criterios De Aceptación — TS-0a-006 Panel C

### 2.1 Una plantilla por categoría distinta

> "Panel C muestra una plantilla de acciones por cada categoría distinta presente
> en los clusters del workspace; si el workspace tiene tres categorías distintas,
> Panel C muestra tres secciones de plantilla"

**Verificabilidad**: ALTA. Verificable con un conjunto de datos de prueba donde
los clusters tienen N categorías distintas y el UI muestra exactamente N secciones.
El criterio es falseable. ✅

### 2.2 Plantilla con 3-5 acciones; ninguna categoría vacía

> "cada plantilla muestra entre 3 y 5 acciones; ninguna categoría reconocida
> produce una lista vacía de acciones"

**Verificabilidad**: ALTA. Conteo de ítems por sección. El criterio es falseable
por sección con menos de 3 o más de 5 ítems, o por sección vacía. ✅

### 2.3 Baseline sin LLM verificable en entorno sin modelo local

> "las acciones se generan por plantilla estática sin LLM; Panel C renderiza sus
> plantillas correctamente en un entorno sin modelo local disponible"

**Verificabilidad**: ALTA. Este es el criterio más crítico de Panel C para el
control de R9. La verificación exige demostrar el renderizado completo de Panel C
en un entorno donde ningún modelo local está disponible (local LLM desactivado,
sin SDK de LLM instalado). Si Panel C produce alguna sección vacía o error en
ese entorno, el criterio falla y R9 se activa.

La plantilla de referencia de 10 categorías de TS-0a-006 funciona como el
contrato verificable del baseline: si todas las categorías representadas en
el workspace tienen plantilla no vacía en ausencia de LLM, el criterio pasa.

**Evaluación de R9**: el documento es el más explícito de la cadena de 0a sobre
la condición de activación de R9 ("si Panel C deja de funcionar cuando el LLM
no está disponible, el LLM se ha convertido en una dependencia"). Esta formulación
convierte R9 de riesgo abstracto a criterio falseable concreto. ✅

### 2.4 Categoría `other` produce plantilla, no error

**Verificabilidad**: ALTA. Falseable con un workspace donde todos los recursos
tienen categoría `other`. La sección de Panel C debe mostrar la plantilla `other`
sin error, sin sección vacía y sin llamada externa. ✅

### 2.5 Las 10 categorías del Classifier tienen plantilla de fallback

> "las plantillas cubren las 10 categorías posibles del Classifier (incluida
> `other`); no hay categoría que el Classifier pueda producir para la que
> Panel C no tenga plantilla de fallback"

**Verificabilidad**: ALTA. Conteo directo. La tabla de plantillas de TS-0a-006
cubre exactamente las 10 categorías del Classifier (TS-0a-003): development,
notes, design, video, productivity, articles, social, commerce, research, other.
Verificación cruzada completada:

| Categoría del Classifier | Plantilla en TS-0a-006 |
| --- | --- |
| development | ✅ |
| notes | ✅ |
| design | ✅ |
| video | ✅ |
| productivity | ✅ |
| articles | ✅ |
| social | ✅ |
| commerce | ✅ |
| research | ✅ |
| other | ✅ |

Cobertura completa. No hay categoría huérfana. ✅

### 2.6 Sin resumen ni texto de contenido de páginas

**Verificabilidad**: ALTA. Inspección de UI: ausencia de cualquier texto derivado
del contenido completo de los recursos en las secciones de plantilla. ✅

### 2.7 Sin invocación al Grouper, Classifier ni Importer

**Verificabilidad**: ALTA. Inspección de código. ✅

### 2.8 Sin conexión de red

**Verificabilidad**: ALTA. Monitorización de red durante el renderizado. ✅

### 2.9 Sin dependencia de Panel B para funcionar

> "el renderizado de Panel C es completo en ausencia de Panel B"

**Verificabilidad**: ALTA. Panel B no existe en 0a, por lo que esta condición
siempre se cumple en el entorno de demo. La especificación lo declara como
criterio explícito para proteger contra reinterpretaciones retroactivas si
Panel B se introduce en Fase 1. ✅

### 2.10 Distinción visual Panel C / Panel A

**Verificabilidad**: MEDIA — cualitativa. Mismo análisis que criterio 1.10. ✅

### 2.11 Criterio de gate de 0a con Panel A + Panel C juntos

> "Panel C contribuye a ese criterio haciendo visible la dimensión accionable
> del workspace"

**Verificabilidad**: BAJA por definición — demo real. Mismo análisis que criterio
1.11. La incorporación de ambos paneles en el criterio de gate es correcta:
el gate de 0a evalúa el workspace completo, no cada panel individualmente. ✅

### 2.12 R12 control explícito (condición 2)

Mismo análisis que criterio 1.12 para Panel A. AR-0a-004 confirmó que la
condición 2 está operativa en TS-0a-006. ✅

**Resumen de criterios de aceptación de TS-0a-006:**

| Criterio | Verificabilidad | Control de riesgo |
| --- | --- | --- |
| 1 — una plantilla por categoría distinta | alta | n/a |
| 2 — 3-5 acciones por plantilla; ninguna vacía | alta | n/a |
| 3 — baseline sin LLM en entorno sin modelo | alta | R9 — control principal |
| 4 — categoría `other` produce plantilla | alta | n/a |
| 5 — 10 categorías con cobertura completa | alta | trazabilidad con TS-0a-003 |
| 6 — sin resumen ni texto de contenido | alta | D1; R11 |
| 7 — sin Grouper/Classifier/Importer | alta | n/a |
| 8 — sin red | alta | n/a |
| 9 — sin dependencia de Panel B | alta | R11 |
| 10 — distinción visual | media (cualitativa) | n/a |
| 11 — criterio de gate con ambos paneles | baja (demo real) | gate de salida |
| 12 — R12 condición 2 | alta (cita) + media (comprensión) | R12 |

---

## 3. Verificación De Señales De Contaminación

### 3.1 Cobertura de vectores — Panel A (14 señales)

| Vector de riesgo | Señal(es) que lo cubren |
| --- | --- |
| Panel B como resumen de recursos | señales 1, 2 |
| Panel B como placeholder explícito | señal 5 |
| Red para favicons | señal 3 |
| Observer activo / actualización en tiempo real | señal 4 |
| Inferencia de relevancia de grupos | señal 6 |
| Temporalidad de sesión en la UI | señal 7 |
| Detección de intención en la capa visual | señal 8 |
| LLM para etiquetas | señal 9 |
| Share Extension en 0a | señal 10 |
| Confusión R12 (Grouper = Episode Detector) | señal 11 |
| Panel A asumiendo rol de Panel C (acciones por recurso) | señal 12 |
| Sync Layer | señal 13 |
| Temporalidad + relevancia combinadas | señal 14 |

Cobertura completa de vectores identificables para Panel A. La distinción entre
BLOQUEAR (para desviaciones técnicas concretas) y ESCALAR al Phase Guardian
(para confusión R12 conceptual) es correcta. ✅

### 3.2 Cobertura de vectores — Panel C (13 señales)

| Vector de riesgo | Señal(es) que lo cubren |
| --- | --- |
| Panel B como dependencia de Panel C | señal 1 |
| LLM como requisito duro | señal 2, señal 13 |
| Aprendizaje longitudinal | señal 3 |
| Panel B bajo nombre de Panel C (resumen + acciones) | señal 4 |
| Detección de intención para acciones específicas | señal 5 |
| Red para plantillas | señal 6 |
| Persistencia de estado en SQLCipher | señal 7 |
| Panel C activando flujos automáticos | señal 8 |
| Confusión R12 (Episode Detector como fuente de acciones) | señal 9 |
| Urgencia / relevancia en acciones | señal 10 |
| Placeholder Panel B vinculado a Panel C | señal 11 |
| Panel C operando por recurso en vez de por categoría | señal 12 |

La señal 13 ("si no hay LLM, Panel C no muestra nada en esa sección") es el
control de R9 más específico de todos los documentos de la cadena. Nombra
exactamente el modo de fallo que activa R9 y lo marca como BLOQUEAR. Correcto. ✅

Observación: la cobertura de señales de TS-0a-006 es la más completa para R9
de toda la cadena de 0a. Ningún documento previo había especificado el modo de
fallo de R9 (LLM como de-facto requisito) con esta precisión.

### 3.3 Señales no cubiertas — evaluación

**Panel A**: el vector "Panel A carga metadata adicional desde la URL sin acceso
a red explícito" (e.g., metadata tags en HTML) está implícitamente cubierto por
el criterio de sin red y por la restricción de favicon local. No se requiere señal
adicional.

**Panel C**: el vector "Panel C genera un template distinto para cada idioma del
título de los recursos" introduciría lógica de procesamiento de contenido fuera
de contrato. Está implícitamente bloqueado por la definición de plantillas
estáticas por categoría, no por idioma ni por contenido. No se requiere señal
adicional.

Ninguna señal adicional es necesaria para cubrir los vectores no mencionados. ✅

---

## 4. Verificación De Ausencia De Conceptos Contaminantes

### 4.1 Panel A (TS-0a-005)

| Concepto prohibido | ¿Aparece en positivo? | Verificación |
| --- | --- | --- |
| Panel B / resumen de contenido | No | "Panel A no muestra resumen, abstract, bullets ni ningún texto derivado del contenido completo de los recursos" |
| LLM | No | Aparece únicamente en tabla de exclusiones y señal de contaminación |
| Red | No | Aparece únicamente como restricción (favicon local) y en señal de contaminación |
| Observer activo | No | "renderizado estático"; sin polling, sin push |
| Episodios / intención | No | Aparece únicamente en exclusiones y señales de contaminación |
| Temporalidad | No | "timestamps de captura" aparece únicamente en "Qué No Renderiza" |
| Sync | No | Aparece únicamente en tabla de exclusiones y señal de contaminación |
| Puente móvil→desktop | No | Panel A no hace referencia al caso núcleo del producto en ningún contexto positivo |
| PMF | No | "no valida PMF" en propósito |

Sin conceptos contaminantes en positivo en TS-0a-005. ✅

### 4.2 Panel C (TS-0a-006)

| Concepto prohibido | ¿Aparece en positivo? | Verificación |
| --- | --- | --- |
| Panel B | No | Aparece únicamente como exclusión y como dependencia prohibida |
| LLM como requisito | No | Aparece exclusivamente como mejora opcional con condición de activación de R9 |
| Aprendizaje longitudinal | No | Tabla de exclusiones; señal de contaminación 3 |
| Intención del usuario | No | "Panel C no detecta intención" — señal de contaminación 5 y tabla de exclusiones |
| Sync | No | Tabla de exclusiones y señal de contaminación 13 |
| Puente móvil→desktop | No | "no valida el puente móvil→desktop" en propósito |
| PMF | No | "Panel C no valida PMF" |
| Episode Detector | No | Aparece únicamente en R12 condición 2 como módulo diferenciado |

Sin conceptos contaminantes en positivo en TS-0a-006. ✅

---

## 5. Verificación De Pertenencia A Fase 0a

| Control | TS-0a-005 | TS-0a-006 |
| --- | --- | --- |
| Cabecera: phase = 0a | ✅ | ✅ |
| Backlog referenciado = backlog-phase-0a.md | ✅ | ✅ |
| Arch-note referenciado = arch-note-phase-0a.md | ✅ | ✅ |
| Módulos dependientes = todos de 0a | ✅ — depende de TS-0a-004 (APROBADO) | ✅ — depende de TS-0a-004 y TS-0a-003 (ambos APROBADO) |
| Tabla de exclusiones con primera-fase-permitida | ✅ — 17 entradas | ✅ — 15 entradas |
| Nota de gobernanza: "no autoriza implementación" | ✅ | ✅ |
| Hipótesis validada = formato workspace, no PMF | ✅ | ✅ |

Ambos documentos pertenecen claramente a Fase 0a en todos los controles. ✅

---

## 6. Evaluación Del Control De R9 En Panel C

R9 es el riesgo de que el LLM se convierta en dependencia prematura de Panel C.
TS-0a-006 lo controla de manera explícita en múltiples capas:

**Capa 1 — Definición estructural (sección "Nota Sobre D8"):** establece que
el baseline de plantillas es el requisito duro y que el LLM es mejora opcional.
Define la condición de activación de R9 de forma falseable: "si Panel C deja de
funcionar cuando el LLM no está disponible."

**Capa 2 — Plantillas de referencia completas:** las 10 plantillas están
definidas con acciones concretas. Un implementador tiene el baseline completo
sin necesidad de LLM para producir ninguna plantilla.

**Capa 3 — Criterio de aceptación 3:** exige demostración en entorno sin modelo
local. Convierte R9 en criterio falseable verificable en demo.

**Capa 4 — Señal de contaminación 13:** nombra el modo de fallo exacto ("si no
hay LLM, Panel C no muestra nada en esa sección") y lo marca BLOQUEAR.

**Evaluación de suficiencia del control de R9**: el control de R9 en TS-0a-006
es el más operativo de toda la cadena de 0a. Las cuatro capas se refuerzan
mutuamente. Un implementador que lea el documento no puede introducir
dependencia de LLM sin violar al menos uno de los cuatro controles de manera
observable. ✅

---

## 7. Evaluación Del Criterio De Gate De 0a

El criterio de gate — "un observador externo entiende la organización del
workspace sin explicación previa" — está incorporado en ambos documentos
como criterio de aceptación y correctamente marcado como requiriendo demo real.

TS-0a-005 (Panel A) lo incorpora como criterio 11 con la nota explícita:
"requiere evidencia de demo real y no es verificable automáticamente."

TS-0a-006 (Panel C) lo incorpora como criterio 11 especificando que "Panel C
contribuye a ese criterio haciendo visible la dimensión accionable del workspace."

El criterio de gate no puede satisfacerse solo con la especificación documental.
Requiere una sesión de demo real donde un observador externo vea Panel A y
Panel C renderizados con datos del Grouper. Esta condición está correctamente
trazada en ambos documentos. ✅

---

## 8. Hallazgos

| Tipo | Descripción | Documento | Acción |
| --- | --- | --- | --- |
| PASS | Criterios de aceptación: todos verificables externamente; criterio de gate correctamente incorporado | TS-0a-005 | ninguna |
| PASS | Criterios de aceptación: todos verificables externamente; criterio baseline sin LLM es falseable en entorno de demo | TS-0a-006 | ninguna |
| PASS | Señales de contaminación: cobertura completa de vectores; gradación BLOQUEAR/ESCALAR correcta | TS-0a-005 y TS-0a-006 | ninguna |
| PASS | Ausencia de conceptos contaminantes en positivo en ambos documentos | TS-0a-005 y TS-0a-006 | ninguna |
| PASS | Pertenencia a Fase 0a verificada en todos los controles | TS-0a-005 y TS-0a-006 | ninguna |
| PASS | R9: control de cuatro capas en TS-0a-006; el más operativo de la cadena de 0a | TS-0a-006 | ninguna |
| PASS | R11: Panel B explícitamente ausente como componente, dependencia y placeholder | TS-0a-005 y TS-0a-006 | ninguna |
| PASS | R12 condición 2: operativa y trazable en dos puntos de cada documento | TS-0a-005 y TS-0a-006 | ninguna |
| PASS | Cobertura de categorías: las 10 categorías del Classifier tienen plantilla en TS-0a-006 | TS-0a-006 | ninguna |
| OBSERVACIÓN | Criterio de gate requiere demo real; es prerrequisito del gate de salida de 0a que ningún documento puede satisfacer por sí solo | TS-0a-005 y TS-0a-006 | registrar como condición pendiente del gate |

---

## 9. Bloqueos

**Ninguno.**

TS-0a-005 y TS-0a-006 contienen los controles operativos necesarios para los
riesgos activos de Fase 0a. Con estos dos documentos aprobados, el ciclo de
especificación de Fase 0a está formalmente cerrado desde el punto de vista de
la auditoría QA.

La única condición pendiente para el gate de salida de 0a es la evidencia de
demo real, que es prerrequisito del gate por diseño y no bloquea el cierre del
ciclo de especificación.

---

## 10. Siguiente Agente Responsable

**Handoff Manager**

Razón: ambas revisiones (AR-0a-004 y QA-REVIEW-0a-004) cierran sin bloqueos y
sin correcciones. Conforme a HO-003, el ciclo de especificación de Fase 0a queda
formalmente cerrado.

El Handoff Manager registra el cierre del ciclo y determina el siguiente paso:
preparación del gate de salida de Fase 0a. La cadena pendiente es:

```
Ciclo de especificación de 0a: CERRADO
              ↓
Preparación del gate de salida de Fase 0a
(Phase Integrity Review de cierre + demo real)
```

---

## 11. Trazabilidad De Entregable

| Acción | Archivo | Estado |
| --- | --- | --- |
| Revisado y aprobado | operations/task-specs/TS-0a-005-panel-a-recursos-agrupados.md | APROBADO |
| Revisado y aprobado | operations/task-specs/TS-0a-006-panel-c-siguientes-pasos.md | APROBADO |
| Revisado | operations/architecture-reviews/AR-0a-004-panel-a-panel-c-review.md | utilizado como referencia |
| Creado | operations/qa-reviews/qa-review-ts-0a-005-006.md | este documento |
