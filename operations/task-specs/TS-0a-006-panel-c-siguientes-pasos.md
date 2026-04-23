# Especificación Operativa — T-0a-006

owner_agent: Desktop Tauri Shell Specialist
document_id: TS-0a-006
task_id: T-0a-006
phase: 0a
date: 2026-04-23
status: APROBADO — revisión conjunta AR-0a-004 + QA-REVIEW-0a-004 cerrada sin bloqueos (2026-04-23)
referenced_backlog: operations/backlogs/backlog-phase-0a.md
referenced_arch_note: operations/architecture-notes/arch-note-phase-0a.md
referenced_decisions: D1 (Privacy Level 1), D8 (Motor de resumen — plantillas como baseline), D9 (Observer activo prohibido), D12 (Bookmarks = bootstrap)
referenced_risk: R12 (Confusión Grouper 0a vs Episode Detector 0b — WATCH ACTIVO)
required_review: Technical Architect (coherencia con arch-note, contrato de módulo, correcta aplicación de D8) + QA Auditor (criterios de aceptación, baseline sin LLM verificable, control de R12)
depends_on: TS-0a-004 (Basic Similarity Grouper — APROBADO con corrección menor) + TS-0a-003 (Domain/Category Classifier — APROBADO con corrección menor)
precede_a: TS-0a-001 (Desktop Workspace Shell — cierre de cadena de 0a)

---

## Propósito En Fase 0a

### Por Qué Existe Panel C En 0a

Panel C existe en 0a para un único propósito: mostrar al observador un
checklist de siguientes pasos por tipo de contenido, generado por plantilla
estática a partir de la categoría de los clusters del Grouper.

Su presencia en el workspace cumple dos funciones en la demo de 0a:

1. **Completar el contenedor workspace:** Panel A muestra los recursos
   organizados; Panel C muestra qué hacer con ellos. Juntos dan al
   observador una imagen completa de un espacio de trabajo con estructura
   y con dirección. Sin Panel C, Panel A es una lista organizada sin
   siguiente paso visible.

2. **Contribuir al criterio de gate:** el gate de 0a requiere que un
   observador externo entienda la organización del workspace sin explicación
   previa. Las acciones de Panel C hacen explícita la utilidad de los grupos:
   un observador que ve "revisar el código en los recursos · ejecutar tests
   pendientes" asociado a un grupo `development/github.com` entiende de
   inmediato para qué sirve ese grupo.

Su rol es estrictamente presentacional y basado en plantillas: no detecta
intención, no personaliza por el usuario, no requiere LLM como prerequisito
y no depende de Panel B para funcionar.

### Qué Valor Aporta A La Validación Del Formato Workspace

La hipótesis que 0a valida es: *¿el formato workspace genera valor?* Panel C
contribuye a esa validación añadiendo la dimensión accionable al workspace:
no es solo un contenedor de recursos organizados, es un contenedor con
sugerencia de qué hacer a continuación. Esta combinación — recursos agrupados
(Panel A) + siguientes pasos por tipo de contenido (Panel C) — es la unidad
mínima que hace comprensible el valor del formato workspace para un observador
externo.

Panel C no valida PMF. No valida el Episode Detector de 0b. No valida el puente
móvil→desktop. Valida que el contenedor workspace puede acompañar la
organización visual de recursos con sugerencias accionables mínimas.

### Por Qué Panel C No Depende De Panel B

Panel B produciría resúmenes del contenido de cada recurso, lo que permitiría
que Panel C generase acciones más específicas y contextualizadas. Pero Panel B
requiere contenido completo de páginas (prohibido por D1) o un motor de resumen
(LLM como requisito — prohibido por D8 como dependencia dura) y entra en
Fase 1.

Panel C de 0a no espera a Panel B. Sus plantillas se activan únicamente por
el campo `category` del cluster: conocer la categoría es suficiente para
sugerir los 3-5 pasos más relevantes para ese tipo de contenido. La ausencia
de Panel B no degrada Panel C: Panel C en 0a está diseñado para funcionar
solo con la categoría, sin resúmenes, sin contenido completo.

**Cualquier entregable que establezca una dependencia de Panel C sobre Panel B
para producir sugerencias accionables debe bloquearse. Panel C es independiente
de Panel B en 0a y en las condiciones de su diseño en 0a.**

### Nota Sobre D8: LLM Como Mejora Opcional, No Como Requisito

D8 establece que el baseline de Panel C son siempre las plantillas estáticas
y que el LLM es una mejora opcional, no una dependencia. Esto significa:

- **Requisito duro:** Panel C funciona con plantillas sin LLM en cualquier
  entorno de demo, independientemente de si hay modelo local disponible
- **Mejora opcional permitida:** si el hardware lo permite y la latencia es
  aceptable, el LLM puede personalizar o enriquecer las sugerencias de la
  plantilla; pero esta mejora no puede romper el contrato si no está disponible
- **Señal de riesgo:** si Panel C deja de funcionar cuando el LLM no está
  disponible, el LLM se ha convertido en una dependencia — se activa R9
  (dependencia prematura del LLM)

Este documento especifica únicamente el baseline de plantillas. Si se
implementa la mejora opcional de LLM, debe quedar documentada como capa
adicional que no altera el contrato.

---

## Alcance Exacto De Panel C En 0a

### Qué Muestra

Panel C muestra un checklist de siguientes pasos por cada categoría distinta
presente en los clusters del workspace. Para cada categoría representada en
el payload del Grouper, Panel C selecciona la plantilla correspondiente y
muestra las acciones asociadas.

**Encabezado de sección por categoría**

- nombre de la categoría (e.g., `development`, `articles`)
- las acciones de la plantilla para esa categoría (3 a 5 ítems en formato
  checklist)

**Plantillas de referencia para la demo de 0a**

Las siguientes plantillas son la implementación de referencia para los tipos
de contenido producidos por el Classifier (T-0a-003). Cubren todas las
categorías posibles del Classifier.

| Categoría | Acciones de la plantilla (baseline) |
| --- | --- |
| `development` | Revisar el código en los recursos · Ejecutar tests pendientes · Abrir o actualizar issues relevantes · Crear o revisar un PR · Actualizar la documentación |
| `articles` | Leer los artículos marcados · Anotar los puntos clave · Compartir con el equipo si aplica · Crear una nota de síntesis |
| `notes` | Revisar y consolidar las notas · Actualizar enlaces internos · Crear elementos de acción · Archivar notas ya procesadas |
| `design` | Revisar los diseños del grupo · Añadir comentarios de feedback · Compartir para revisión · Comprobar accesibilidad básica |
| `video` | Ver los vídeos marcados · Tomar notas de momentos clave · Crear resumen para el equipo |
| `productivity` | Revisar tareas pendientes del grupo · Actualizar el estado de los ítems · Priorizar los próximos pasos |
| `research` | Sintetizar los hallazgos del grupo · Identificar brechas en la investigación · Crear notas bibliográficas · Planificar siguientes pasos de investigación |
| `social` | Revisar actualizaciones del grupo · Responder a hilos pendientes · Guardar contenido relevante para referencia |
| `commerce` | Revisar productos o servicios marcados · Comparar opciones disponibles · Crear lista de evaluación o compra |
| `other` | Revisar el contenido del grupo · Organizar en notas propias · Identificar próximas acciones |

Estas plantillas son la referencia de diseño para la demo. El número exacto
de acciones por plantilla es ajustable (dentro del rango 3-5) sin cambio de
contrato, siempre que el criterio de aceptación de completitud de categorías
se mantenga.

**Deduplicación por categoría**

Si el payload del Grouper contiene múltiples clusters con la misma categoría
(e.g., dos grupos de categoría `development` con dominios distintos), Panel C
muestra la plantilla de esa categoría una sola vez. Panel C no duplica
plantillas: opera sobre el conjunto de categorías distintas presentes en el
workspace, no sobre el conjunto de clusters.

### Qué No Muestra

Panel C no muestra ninguno de los siguientes elementos:

- resúmenes del contenido de los recursos (Panel B — Fase 1)
- acciones personalizadas por recurso individual (las plantillas son por
  categoría de workspace, no por recurso)
- acciones derivadas del historial de sesiones anteriores del usuario
- indicadores de relevancia o urgencia por acción o por categoría
- progreso de acciones pasadas ni registro de qué acciones se completaron
- acciones generadas por LLM si el LLM no está disponible (el baseline de
  plantillas reemplaza al LLM en cualquier circunstancia)
- indicadores de sync o conectividad
- placeholders "reservados para fases futuras"
- contenido derivado del cuerpo completo de los recursos

---

## Contrato De Input/Output

### Input: Clusters Del Grouper (Campo `category`)

Panel C recibe el mismo payload de clusters que Panel A, entregado por el
Shell en la misma operación. El campo que Panel C usa para seleccionar la
plantilla es `category` del cluster:

```
Lista de clusters [
  cluster {
    group_key: string
    domain: string
    category: string      -- Panel C usa este campo para seleccionar la plantilla
    sub_label: string
    resources: [...]
  }
]
```

Panel C extrae el conjunto de categorías distintas del payload y selecciona
una plantilla por categoría. No lee el campo `sub_label` ni el array
`resources` para determinar las acciones: la categoría es el único criterio
de selección de plantilla.

Panel C consume este payload exactamente una vez por sesión de demo. No vuelve
a invocar al Grouper ni a ningún módulo upstream durante el ciclo de vida del
panel.

### Output: Checklist Visual Por Categoría

El output de Panel C es la representación visual del conjunto de plantillas
activadas. No hay output programático: Panel C no devuelve datos a ningún
módulo. Su output es exclusivamente visual.

La estructura de renderizado esperada es:

```
[Encabezado de categoría: category]
  [ ] Acción 1 de la plantilla para esa categoría
  [ ] Acción 2
  [ ] Acción 3
  ...

[Encabezado de categoría: category]
  [ ] Acción 1
  ...
```

Los ítems del checklist son estáticos en la demo de 0a: el observador puede
verlos; si la implementación permite marcarlos como completados dentro de la
sesión de demo, esa interacción es compatible con 0a siempre que no introduzca
persistencia de estado entre sesiones ni memoria de acciones pasadas.

---

## Contratos Con Módulos Adyacentes

### Con Basic Similarity Grouper (T-0a-004)

Panel C consume los clusters del Grouper para extraer el conjunto de categorías
distintas. La relación es unidireccional: el Grouper produce, Panel C consume.
Panel C no invoca al Grouper durante el renderizado. El Grouper no conoce la
estructura de Panel C.

```
Grouper → [lista de clusters en memoria] → Panel C → [plantillas por categoría]
```

**Condición 2 de contención de R12:** cualquier entregable de 0a o de 0b
que mencione Panel C en relación con la agrupación de recursos o la selección
de plantillas debe citar la tabla de diferenciación Grouper 0a vs Episode
Detector 0b de TS-0a-004. Panel C es consumidor del Grouper de 0a; no tiene
relación con el Episode Detector de 0b ni con la detección de intención de
sesión de trabajo.

### Con Domain/Category Classifier (T-0a-003)

Panel C usa el campo `category` del cluster, que es el resultado de la
clasificación del Classifier. La relación es indirecta: Panel C no invoca al
Classifier; lee el campo ya persistido en el payload del Grouper. Las
categorías que Panel C puede recibir son exactamente las categorías que el
Classifier puede producir (ver tabla de plantillas de referencia).

Si el Classifier asigna la categoría `other` a un recurso, Panel C mostrará
la plantilla `other` para ese grupo. El contrato no se rompe con dominios
no reconocidos: la plantilla `other` es el fallback explícito de Panel C,
igual que `other` es el fallback explícito del Classifier.

### Con Panel A (T-0a-005)

Panel A y Panel C reciben el mismo payload de clusters en la misma entrega del
Shell. Panel C no invoca a Panel A ni Panel A invoca a Panel C. Son componentes
separados coordinados por el Shell. Panel C no conoce el contenido de Panel A
ni depende de que Panel A haya renderizado primero.

La separación visual entre Panel A y Panel C es responsabilidad del Shell
(T-0a-001).

### Con Desktop Workspace Shell (T-0a-001)

El Shell aloja a Panel C. El Shell le entrega el payload de clusters al arrancar
el workspace. Panel C no conoce los detalles del contenedor; solo recibe los
clusters, extrae las categorías distintas y renderiza las plantillas.

### Con SQLCipher Local Storage (T-0a-007)

Panel C no lee directamente de SQLCipher. Recibe los datos a través del payload
del Grouper. Si la implementación permite marcar ítems como completados en la
sesión de demo (estado efímero en memoria), ese estado no se persiste en
SQLCipher: el schema mínimo de 0a no incluye tablas de progreso de acciones.

---

## Exclusiones Explícitas

| Elemento excluido | Primera fase permitida | Regla que lo bloquea |
| --- | --- | --- |
| LLM como requisito para generar acciones | nunca como requisito | D8: plantillas son el baseline; LLM es mejora opcional |
| Dependencia de Panel B para contextualizar las acciones | Fase 1 | Panel B es Fase 1; Panel C debe funcionar sin Panel B |
| Resumen de recursos en Panel C (bullets, abstracts) | Fase 1 | Panel B — scope-boundaries.md, phase-definition.md |
| Personalización de acciones por historial del usuario | Fase 2 | D2, D17: Pattern Detector |
| Memoria de qué acciones se completaron en sesiones anteriores | Fase 2 | Pattern Detector; schema mínimo de 0a no incluye tablas de progreso |
| Detección de intención para generar acciones más específicas | 0b | Detection Layer PROHIBIDA en 0a; D9, D12 |
| Acciones por recurso individual (distinto de acciones por categoría) | fuera de contrato | Panel C opera por categoría de workspace, no por recurso |
| Indicadores de urgencia o prioridad de acciones | Fase 2 | inferencia de valor pertenece a Pattern Detector (D2, D17) |
| Actualización de plantillas desde red | MVP: prohibida | invariante 2 de arch-note |
| Acciones que activan flujos automatizados | fuera de contrato | Panel C es presentacional; no activa flujos de trabajo |
| Indicadores de sync o conectividad | 0b | D6; Sync Layer PROHIBIDA en 0a |
| Placeholders para funcionalidades de fases posteriores | bloqueado siempre | contamina fases; arch-note invariante 5 |
| Acciones derivadas de contenido completo de páginas | nunca | D1 permanente: Privacy Level 1 |
| Aprendizaje longitudinal de qué plantillas son más útiles | Fase 2 | D2, D17: Pattern Detector |
| Panel B bajo cualquier nombre o como dependencia de Panel C | Fase 1 | scope-boundaries.md; phase-definition.md |

---

## Criterios De Aceptación

Los siguientes criterios son verificables externamente por el Technical
Architect y el QA Auditor. Ninguno puede considerarse satisfecho sin
evidencia documental en la revisión.

- [ ] Panel C muestra una plantilla de acciones por cada categoría distinta
      presente en los clusters del workspace; si el workspace tiene tres
      categorías distintas, Panel C muestra tres secciones de plantilla
- [ ] cada plantilla muestra entre 3 y 5 acciones; ninguna categoría reconocida
      produce una lista vacía de acciones
- [ ] las acciones se generan por plantilla estática sin LLM; Panel C renderiza
      sus plantillas correctamente en un entorno sin modelo local disponible
- [ ] la categoría `other` produce la plantilla `other`; Panel C no falla ni
      produce sección vacía cuando el Classifier asignó `other` a algún recurso
- [ ] las plantillas cubren las 10 categorías posibles del Classifier (incluida
      `other`); no hay categoría que el Classifier pueda producir para la que
      Panel C no tenga plantilla de fallback
- [ ] Panel C no muestra resumen, abstract, bullets ni ningún texto derivado del
      contenido completo de los recursos
- [ ] Panel C no invoca al Grouper, al Classifier ni al Importer en ningún
      momento del flujo de renderizado
- [ ] Panel C no inicia ninguna conexión de red en ningún punto del renderizado
- [ ] Panel C no depende de Panel B para funcionar; el renderizado de Panel C
      es completo en ausencia de Panel B
- [ ] Panel C es visualmente distinguible de Panel A: el observador puede
      identificar sin instrucción previa cuál es la zona de recursos agrupados
      y cuál es la zona de siguientes pasos
- [ ] el criterio de gate de 0a — "un observador externo entiende la organización
      del workspace sin explicación previa" — puede evaluarse positivamente con
      Panel A y Panel C renderizados juntos; Panel C contribuye a ese criterio
      haciendo visible la dimensión accionable del workspace
- [ ] R12 — CONTROL EXPLÍCITO (condición 2 de contención): este documento cita
      la tabla de diferenciación Grouper 0a vs Episode Detector 0b de TS-0a-004;
      un observador que lea este documento comprende que Panel C selecciona
      plantillas a partir de la categoría del Grouper de 0a y no tiene relación
      con el Episode Detector de 0b ni con la detección de intención de sesión

---

## Señales De Contaminación De Fase

Las siguientes señales indican que el documento o la implementación están
incorporando elementos que no pertenecen a Panel C en 0a. Cualquiera debe
bloquearse o escalarse inmediatamente.

| Señal | Diagnóstico | Acción | Regla violada |
| --- | --- | --- | --- |
| "Panel C necesita Panel B para mostrar acciones contextuales" | dependencia prematura de Panel B | BLOQUEAR | Panel B es Fase 1; Panel C debe funcionar sin Panel B |
| "añadimos LLM para que las acciones sean más específicas al contenido" | LLM convirtiéndose en requisito | BLOQUEAR si es dependencia dura; ADVERTIR si es mejora opcional documentada | D8 |
| "Panel C aprende qué acciones ejecuta más el usuario para mejorar las plantillas" | aprendizaje longitudinal en 0a | BLOQUEAR | Pattern Detector es Fase 2; D2, D17 |
| "Panel C muestra un resumen de los recursos para contextualizar las acciones" | Panel B bajo el nombre de Panel C | BLOQUEAR | Panel B es Fase 1; D1 permanente |
| "Panel C detecta si el usuario está trabajando en un tema para sugerir acciones específicas" | detección de intención en la capa visual | BLOQUEAR | Detection Layer PROHIBIDA en 0a; D9 |
| "actualizamos las plantillas desde un servidor de configuración" | red desde la app | BLOQUEAR | invariante 2 de arch-note |
| "Panel C guarda qué acciones completó el usuario para la próxima sesión" | persistencia fuera del schema de 0a | BLOQUEAR | schema mínimo de TS-0a-007; sin tablas de progreso |
| "Panel C activa automáticamente el flujo de trabajo cuando el usuario hace clic" | Panel C como activador de flujos | BLOQUEAR | Panel C es presentacional; no activa flujos en 0a |
| "Panel C podría usar el Episode Detector para sugerir acciones más relevantes" | confusión R12 en el contexto de Panel C | ESCALAR al Phase Guardian | R12; TS-0a-004 tabla de diferenciación |
| "Panel C sugiere acciones ordenadas por las más urgentes para el usuario" | inferencia de urgencia sin base | BLOQUEAR | Pattern Detector es Fase 2; D2, D17 |
| "dejamos un espacio para Panel B cuando esté listo, para que Panel C mejore" | contaminación de Fase 1 explícita | BLOQUEAR | arch-note invariante 5; phase-definition |
| "Panel C muestra acciones distintas para cada recurso del grupo" | Panel C asumiendo granularidad por recurso | BLOQUEAR — fuera de contrato | Panel C opera por categoría, no por recurso |
| "si no hay LLM, Panel C no muestra nada en esa sección" | LLM como requisito duro de facto | BLOQUEAR | D8: el baseline de plantillas no puede depender del LLM |

---

## Handoff Esperado

Este documento requiere revisión por dos agentes antes de cerrarse.

### 1. Technical Architect

Debe verificar:
- que el contrato de input/output es coherente con arch-note-phase-0a.md
  (contrato de módulo Panel C: input clusters + tipo de contenido del Classifier;
  output checklist de 3-5 acciones por plantilla según tipo de contenido)
- que la aplicación de D8 es correcta: el baseline de plantillas funciona sin
  LLM y el LLM queda documentado como mejora opcional, no como dependencia
- que Panel C no introduce acceso directo a SQLCipher ni invocaciones a módulos
  upstream durante el renderizado
- que la relación Panel C → categoría del Grouper está correctamente especificada
  y no anticipa lógica del Episode Detector de 0b
- que la condición 2 de contención de R12 queda operativa en este documento
  (referencia a tabla de diferenciación de TS-0a-004)

### 2. QA Auditor

Debe verificar:
- que los criterios de aceptación son verificables externamente
- que el criterio de baseline sin LLM es verificable: existe un test o
  verificación de demo que confirme que Panel C funciona en ausencia de modelo
  local
- que el criterio de cobertura de categorías (todas las categorías del
  Classifier tienen plantilla de fallback) es auditable
- que ningún criterio de aceptación introduce ambigüedad que permita justificar
  LLM como dependencia, Panel B como prerequisito o temporalidad dentro de 0a
- que la tabla de señales de contaminación cubre los vectores de riesgo más
  probables para Panel C en la demo de 0a, incluido el riesgo R9 (LLM como
  dependencia prematura)
- que el control de R12 (condición 2) es operativo: la tabla de diferenciación
  de TS-0a-004 está citada de manera trazable

Si hay correcciones, ambos agentes las comunican al Desktop Tauri Shell
Specialist antes de cerrar. El documento no puede cerrarse con revisión de
solo uno de los dos agentes requeridos.

Cadena completada tras este documento:

```
TS-0a-005 (Panel A) + TS-0a-006 [este documento] (Panel C)
                              ↓
                    TS-0a-001 (Desktop Shell — cierre de cadena de 0a)
```

Con TS-0a-006 producido, todos los entregables de especificación de Fase 0a
están disponibles. El cierre de la cadena requiere que TS-0a-005 y TS-0a-006
superen revisión conjunta Technical Architect + QA Auditor antes de que
TS-0a-001 (Desktop Workspace Shell) pueda cerrarse como especificación
completa de 0a.

---

## Nota De Gobernanza

Esta especificación no autoriza implementación en el repo de producto.
Define el contrato documental que la implementación debe respetar cuando el
equipo construya Panel C en el contexto de la demo de 0a.

El baseline de plantillas de esta especificación es una referencia de diseño
para la demo. Las acciones específicas de cada plantilla son ajustables (dentro
del rango 3-5 por plantilla) sin cambio de contrato, siempre que:

1. cada categoría del Classifier tenga una plantilla no vacía
2. las acciones no deriven del contenido completo de los recursos (D1)
3. el LLM no sea la única forma de producir la plantilla (D8)

La mejora opcional de LLM, si se implementa, debe documentarse como capa
adicional sobre el baseline de plantillas. Si el LLM no está disponible en el
entorno de demo, Panel C debe renderizar el baseline de plantillas sin
degradación visible para el observador.

Panel B no existe en 0a. Panel C no puede establecer dependencias de Panel B
bajo ninguna formulación, ni directa ni como mejora planificada para la demo.
