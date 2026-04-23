# Revisión Arquitectónica — TS-0a-005 Panel A + TS-0a-006 Panel C

document_id: AR-0a-004
owner_agent: Technical Architect
phase: 0a
date: 2026-04-23
status: APROBADO — sin bloqueos; sin correcciones
documents_reviewed:
  - operations/task-specs/TS-0a-005-panel-a-recursos-agrupados.md
  - operations/task-specs/TS-0a-006-panel-c-siguientes-pasos.md
reference_normativo:
  - operations/architecture-notes/arch-note-phase-0a.md
  - Project-docs/decisions-log.md (D1, D8, D9, D12)
  - Project-docs/risk-register.md (R9, R11, R12)
  - operations/backlogs/backlog-phase-0a.md (T-0a-005, T-0a-006)
  - operations/architecture-reviews/AR-0a-003-grouper-review.md
  - operations/task-specs/TS-0a-004-basic-similarity-grouper.md
precede_a: QA Auditor (QA-REVIEW-TS-0a-005-006) → gate de salida de Fase 0a

---

## Resultado Global

| Documento | Resultado arquitectónico | Bloqueos | Correcciones |
| --- | --- | --- | --- |
| TS-0a-005 Panel A | APROBADO | ninguno | ninguna |
| TS-0a-006 Panel C | APROBADO | ninguno | ninguna |

Ambos documentos son coherentes con arch-note-phase-0a.md, con los contratos
de módulo definidos en ese documento y con el marco normativo de Fase 0a.
No se requiere ninguna corrección antes de que el QA Auditor complete su
revisión.

---

## A. Verificación Del Contrato De Módulo

### A.1 Panel A (TS-0a-005)

El arch-note define el contrato de Panel A así:

```
input:  clusters del Grouper
output: lista visual de recursos agrupados [título, favicon, dominio, subtema]
restricciones duras:
  sin resumen de contenido (Panel B — Fase 1)
  sin red
  sin LLM
```

Verificación punto a punto contra TS-0a-005:

| Atributo del contrato | Requerido por arch-note | Declarado en TS-0a-005 | Coherente |
| --- | --- | --- | --- |
| input: clusters del Grouper | sí | "Panel A recibe la lista de clusters producida por el Grouper (T-0a-004). El contrato de input es exactamente el contrato de output del Grouper." | ✅ |
| output: lista visual [título, favicon, dominio, subtema] | sí | encabezado de grupo (domain · category · sub_label) + por recurso: favicon?, título, domain | ✅ — "subtema" del arch-note corresponde a sub_label del cluster |
| sin resumen de contenido — Panel B | sí | tabla de exclusiones; sección "Qué No Renderiza"; criterio de aceptación 9 | ✅ |
| sin red | sí | "favicon del recurso, si está disponible en caché local del perfil del navegador exportado"; criterio de aceptación 7 | ✅ |
| sin LLM | sí | tabla de exclusiones; criterio de aceptación 8 | ✅ |

**Veredicto: contrato de módulo de Panel A alineado con arch-note sin desviaciones.**

### A.2 Panel C (TS-0a-006)

El arch-note define el contrato de Panel C así:

```
input:  clusters + tipo de contenido (del Classifier)
output: checklist de 3-5 acciones por plantilla según tipo de contenido
restricciones duras:
  baseline siempre por plantilla, sin LLM (D8)
  LLM es mejora opcional solo si el hardware lo permite y no añade latencia
  sin dependencia de Panel B para funcionar
```

Verificación punto a punto contra TS-0a-006:

| Atributo del contrato | Requerido por arch-note | Declarado en TS-0a-006 | Coherente |
| --- | --- | --- | --- |
| input: clusters + tipo de contenido | sí | "Panel C recibe el mismo payload de clusters que Panel A [...] el campo que Panel C usa para seleccionar la plantilla es `category` del cluster" | ✅ — "tipo de contenido" del arch-note es el campo `category` del Classifier, transportado en el cluster |
| output: checklist 3-5 acciones por plantilla | sí | "Panel C muestra una plantilla de acciones por cada categoría distinta [...] checklist de 3-5 acciones" | ✅ |
| baseline por plantilla sin LLM | sí | "las plantillas estáticas son la implementación de referencia [...] Panel C renderiza sus plantillas correctamente en un entorno sin modelo local disponible" | ✅ |
| LLM es mejora opcional | sí | "si Panel C deja de funcionar cuando el LLM no está disponible, el LLM se ha convertido en una dependencia — se activa R9"; sección "Nota Sobre D8" | ✅ |
| sin dependencia de Panel B | sí | "Panel C de 0a no espera a Panel B"; tabla de exclusiones; criterio de aceptación 9 | ✅ |

**Veredicto: contrato de módulo de Panel C alineado con arch-note sin desviaciones.**

---

## B. Verificación De Entrada Y Salida

### B.1 Entrada de Panel A

Panel A recibe el payload de clusters del Grouper, entregado por el Shell al
arrancar el workspace. El contrato de input es exactamente el contrato de
output de TS-0a-004, verificado en AR-0a-003.

El campo `title` del recurso en el payload del Grouper es el título descifrado
localmente por el Grouper (AR-0a-003 sección B.1 observación). TS-0a-005 lo
confirma explícitamente: "título del recurso (campo title, descifrado localmente
desde SQLCipher a través del payload del Grouper)." Esto cierra la observación
de precisión registrada en AR-0a-003 a nivel de Panel A.

El favicon no forma parte del contrato de output del Grouper. TS-0a-005 lo
trata correctamente: se obtiene del caché local del navegador exportado si
está disponible, y se omite si no. No se requiere campo adicional al Grouper
para favicon. La lógica de obtención de favicon es responsabilidad de Panel A
sobre el perfil de exportación de bookmarks, no del Grouper. **Esto es
arquitectónicamente correcto.**

Panel A consume el payload exactamente una vez por sesión de demo. No re-invoca
al Grouper durante el renderizado. Correcto.

### B.2 Salida de Panel A

El output de Panel A es exclusivamente visual: no hay output programático. Panel A
no devuelve datos a ningún módulo. Correcto.

La estructura de renderizado declarada (encabezado de grupo → lista de recursos)
es coherente con el contrato del arch-note y con lo que el Grouper entrega.

### B.3 Entrada de Panel C

Panel C recibe el mismo payload de clusters que Panel A, en la misma entrega
del Shell. Extrae el conjunto de categorías distintas del payload y selecciona
una plantilla por categoría.

La decisión de **deduplicar por categoría** (un template por categoría distinta,
no por cluster) es una decisión de diseño de Panel C, no declarada en el arch-note.
Es arquitectónicamente correcta porque:
- el arch-note dice "tipo de contenido" (singular por tipo, no por instancia de grupo)
- mostrar la plantilla `development` dos veces para dos clusters `development` distintos
  sería redundante y degradaría la legibilidad del workspace
- la deduplicación es determinística y no introduce lógica de inferencia

**Decisión de deduplicación registrada como correcta por el Technical Architect.**

### B.4 Salida de Panel C

El output de Panel C es exclusivamente visual: checklist de acciones por
categoría. No hay output programático. Panel C no devuelve datos a ningún
módulo. Correcto.

Si la implementación permite marcar ítems como completados dentro de la sesión
(estado efímero en memoria), TS-0a-006 declara explícitamente que ese estado
no se persiste en SQLCipher. Correcto con el schema mínimo de TS-0a-007.

**Veredicto: inputs y outputs de Panel A y Panel C correctamente delimitados.**

---

## C. Verificación De Separación Con Módulos Adyacentes

### C.1 Panel A

| Módulo | Separación declarada en TS-0a-005 | Coherente |
| --- | --- | --- |
| Basic Similarity Grouper (T-0a-004) | "Panel A no invoca al Grouper durante el renderizado. El Grouper no conoce la estructura visual de Panel A." Relación unidireccional. | ✅ |
| Panel C (T-0a-006) | "Panel C recibe el mismo payload de clusters que Panel A [...] Panel A no invoca a Panel C ni Panel C invoca a Panel A." Coordinados por el Shell. | ✅ |
| Desktop Workspace Shell (T-0a-001) | "El Shell le entrega el payload de clusters al arrancar el workspace. Panel A no conoce los detalles del contenedor." | ✅ |
| SQLCipher (T-0a-007) | "Panel A no lee directamente de SQLCipher." Recibe los datos a través del payload del Grouper. | ✅ |
| Classifier (T-0a-003) e Importer (T-0a-002) | "Panel A no invoca al Classifier ni al Importer en ningún momento del flujo de renderizado." | ✅ |

### C.2 Panel C

| Módulo | Separación declarada en TS-0a-006 | Coherente |
| --- | --- | --- |
| Basic Similarity Grouper (T-0a-004) | "Panel C no invoca al Grouper durante el renderizado." Relación unidireccional. | ✅ |
| Panel A (T-0a-005) | "Panel A no invoca a Panel C ni Panel C invoca a Panel A." Coordinados por el Shell. | ✅ |
| Desktop Workspace Shell (T-0a-001) | "Panel C no conoce los detalles del contenedor; solo recibe los clusters y renderiza las plantillas." | ✅ |
| SQLCipher (T-0a-007) | "Panel C no lee directamente de SQLCipher." Estado efímero de demo no persiste. | ✅ |
| Classifier (T-0a-003) | "Panel C no invoca al Classifier directamente; lee el campo ya persistido en el payload del Grouper." | ✅ |

No se detecta solapamiento de responsabilidades entre ningún módulo. La cadena
Importer → Classifier → Grouper → Panel A + Panel C está correctamente trazada
en ambos documentos y es coherente con la cadena descrita en los AR anteriores.

**Veredicto: separación de módulos limpia en todos los puntos de contacto.**

---

## D. Verificación De Decisiones Cerradas

### D.1 — Privacy Level 1

PASS para ambos documentos.

Panel A: no accede a contenido completo de páginas; favicon desde caché local
únicamente; título descifrado localmente. Sin violación de D1. ✅

Panel C: opera únicamente sobre el campo `category`; las plantillas son texto
estático no derivado del contenido de los recursos. Sin violación de D1. ✅

### D.8 — LLM no es requisito funcional

PASS para ambos documentos.

Panel A: no usa LLM. El renderizado de metadatos (título, dominio, favicon) es
puramente presentacional y no requiere generación de texto. ✅

Panel C: el baseline de plantillas estáticas no requiere LLM. El LLM está
documentado como mejora opcional con la condición explícita de que su ausencia
no puede degradar el baseline. La activación de R9 si el LLM se convierte en
dependencia está correctamente definida. D8 aplicado con mayor precisión en
TS-0a-006 que en cualquier documento previo de la cadena. ✅

### D.9 — Observer activo prohibido

PASS para ambos documentos.

Panel A: renderizado estático al arrancar el workspace; sin polling, sin push,
sin proceso en fondo que actualice el panel. ✅

Panel C: renderizado estático de plantillas; sin captura activa, sin detección
de intención, sin actualización automática. ✅

### D.12 — Bookmarks como bootstrap/cold start, no como caso núcleo

PASS para ambos documentos.

Panel A: renderiza datos de bootstrap. No los presenta como validación del
producto ni como caso de uso núcleo. ✅

Panel C: "Panel C no valida PMF. No valida el Episode Detector de 0b. No valida
el puente móvil→desktop." ✅

---

## E. Verificación De Invariantes Arquitectónicas (arch-note)

| Invariante | Panel A (TS-0a-005) | Panel C (TS-0a-006) |
| --- | --- | --- |
| 1. El desktop no observa activamente (D9) | Renderizado estático; sin polling ni fondo | Renderizado estático; sin detección activa | ✅ ✅ |
| 2. Sin conexión de red | Favicon desde caché local; criterio de aceptación explícito | Plantillas estáticas; sin actualización desde red | ✅ ✅ |
| 3. Única fuente de datos = import local | Recibe datos del Grouper, derivados de bookmarks importados | Recibe campo `category` del cluster, derivado del Classifier → Importer | ✅ ✅ |
| 4. LLM no es requisito (D8) | No usa LLM | Plantillas son el baseline; LLM es mejora opcional no bloqueante | ✅ ✅ |
| 5. Panel B no existe en 0a | Excluido en tabla, "Qué No Renderiza", criterio 9 | Excluido como dependencia; "sin dependencia de Panel B para funcionar" | ✅ ✅ |
| 6. Schema SQLCipher sin tablas de 0b | Sin acceso directo a SQLCipher | Sin acceso directo; estado de demo no persiste en SQLCipher | ✅ ✅ |
| 7. Grouper ≠ Episode Detector 0b | Cita tabla de diferenciación de TS-0a-004 | Cita tabla de diferenciación de TS-0a-004 | ✅ ✅ |
| 8. Ningún componente de 0a = validación del puente | "no valida PMF [...] valida que el contenedor workspace tiene una capa de presentación comprensible" | "no valida PMF [...] no valida el Episode Detector de 0b [...] no valida el puente" | ✅ ✅ |
| 9. Bookmarks = bootstrap y cold start (D12) | Renderiza datos de bootstrap sin presentarlos como caso núcleo | "opera sobre categorías de recursos de bootstrap; no implica validación de PMF" | ✅ ✅ |

**Todas las invariantes satisfechas en ambos documentos.**

---

## F. Verificación De La Condición 2 De Contención De R12

La condición 2 de la contención operativa de R12 (definida en TS-0a-004)
establece que la tabla de diferenciación Grouper 0a vs Episode Detector 0b
debe citarse en cualquier entregable de 0a o de 0b que mencione el Grouper
o la agrupación de recursos.

### F.1 Panel A (TS-0a-005)

La condición 2 está operativa en dos puntos:

1. **Sección "Con Basic Similarity Grouper"**: "Condición 2 de contención de
   R12: cualquier entregable de 0a o de 0b que mencione Panel A en relación
   con la agrupación de recursos debe citar la tabla de diferenciación Grouper
   0a vs Episode Detector 0b de TS-0a-004."
2. **Criterio de aceptación 12**: "R12 — CONTROL EXPLÍCITO (condición 2 de
   contención): este documento cita la tabla de diferenciación Grouper 0a vs
   Episode Detector 0b de TS-0a-004."

Ambas citas son trazables. La condición 2 queda activa como criterio de
aceptación verificable externamente. **Operativa.** ✅

### F.2 Panel C (TS-0a-006)

La condición 2 está operativa en dos puntos:

1. **Sección "Con Basic Similarity Grouper"**: "Condición 2 de contención de
   R12: cualquier entregable de 0a o de 0b que mencione Panel C en relación
   con la agrupación de recursos o la selección de plantillas debe citar la
   tabla de diferenciación Grouper 0a vs Episode Detector 0b de TS-0a-004."
2. **Criterio de aceptación 12**: "R12 — CONTROL EXPLÍCITO (condición 2 de
   contención): este documento cita la tabla de diferenciación Grouper 0a vs
   Episode Detector 0b de TS-0a-004."

**Operativa.** ✅

---

## G. Correcciones

**Ninguna.**

Ambos documentos son precisos en sus contratos, coherentes con el arch-note
y con los documentos anteriores de la cadena, y no requieren corrección antes
de que el QA Auditor complete su revisión.

La observación de precisión de AR-0a-003 sobre `resources[].title` como título
descifrado queda cerrada: TS-0a-005 lo declara explícitamente en el contrato
de input de Panel A.

---

## H. Hallazgos

| Tipo | Descripción | Documento | Acción |
| --- | --- | --- | --- |
| PASS | Contrato de módulo alineado con arch-note punto a punto | TS-0a-005 y TS-0a-006 | ninguna |
| PASS | Inputs y outputs correctamente delimitados; sin escritura en SQLCipher; sin red | TS-0a-005 y TS-0a-006 | ninguna |
| PASS | Separación de módulos limpia en todos los puntos de contacto | TS-0a-005 y TS-0a-006 | ninguna |
| PASS | D1, D8, D9, D12 verificados sin desviaciones en ambos documentos | TS-0a-005 y TS-0a-006 | ninguna |
| PASS | 9 invariantes arquitectónicas del arch-note satisfechas en ambos documentos | TS-0a-005 y TS-0a-006 | ninguna |
| PASS | Condición 2 de R12 operativa y trazable en dos puntos de cada documento | TS-0a-005 y TS-0a-006 | ninguna |
| PASS | Decisión de deduplicación por categoría en Panel C registrada como correcta | TS-0a-006 | ninguna |
| OBSERVACIÓN | Favicon correctamente resuelto como responsabilidad de Panel A sobre el perfil exportado, no del Grouper | TS-0a-005 | no requiere corrección |
| CIERRE DE OBSERVACIÓN | `resources[].title` como título descifrado: observación de AR-0a-003 queda cerrada por TS-0a-005 | TS-0a-005 | ninguna |

---

## I. Bloqueos

**Ninguno.**

TS-0a-005 y TS-0a-006 son arquitectónicamente coherentes con el arch-note y
con el marco normativo de Fase 0a. Con estos dos documentos aprobados, el
ciclo de especificación de Fase 0a está completo desde el punto de vista
arquitectónico.

---

## J. Siguiente Agente Responsable

**QA Auditor**

Razón: la revisión arquitectónica cierra sin bloqueos y sin correcciones.
Conforme a HO-003, el QA Auditor debe completar su revisión de TS-0a-005 y
TS-0a-006 antes de que ambos documentos puedan cerrarse con status APROBADO.

Tras el QA Auditor: si no hay bloqueos, el ciclo de especificación de Fase 0a
queda formalmente cerrado y la cadena avanza hacia la preparación del gate de
salida de 0a.

---

## K. Trazabilidad De Entregable

| Acción | Archivo | Estado |
| --- | --- | --- |
| Revisado | operations/task-specs/TS-0a-005-panel-a-recursos-agrupados.md | pendiente de QA review |
| Revisado | operations/task-specs/TS-0a-006-panel-c-siguientes-pasos.md | pendiente de QA review |
| Creado | operations/architecture-reviews/AR-0a-004-panel-a-panel-c-review.md | este documento |
