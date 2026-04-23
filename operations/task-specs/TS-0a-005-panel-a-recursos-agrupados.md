# Especificación Operativa — T-0a-005

owner_agent: Desktop Tauri Shell Specialist
document_id: TS-0a-005
task_id: T-0a-005
phase: 0a
date: 2026-04-23
status: APROBADO — revisión conjunta AR-0a-004 + QA-REVIEW-0a-004 cerrada sin bloqueos (2026-04-23)
referenced_backlog: operations/backlogs/backlog-phase-0a.md
referenced_arch_note: operations/architecture-notes/arch-note-phase-0a.md
referenced_decisions: D1 (Privacy Level 1), D8 (Motor de resumen), D9 (Observer activo prohibido), D12 (Bookmarks = bootstrap)
referenced_risk: R12 (Confusión Grouper 0a vs Episode Detector 0b — WATCH ACTIVO)
required_review: Technical Architect (coherencia con arch-note, contrato de módulo) + QA Auditor (criterios de aceptación, criterio de gate, control de R12)
depends_on: TS-0a-004 (Basic Similarity Grouper — APROBADO con corrección menor)
precede_a: TS-0a-001 (Desktop Workspace Shell — cierre de cadena de 0a)

---

## Propósito En Fase 0a

### Por Qué Existe Panel A En 0a

Panel A existe en 0a para un único propósito: renderizar de forma visible y
comprensible los clusters de recursos que el Grouper produce, de modo que un
observador externo pueda entender la organización del workspace sin explicación
previa.

Este criterio — "un observador externo entiende la organización del workspace
sin explicación previa" — es el gate de salida de 0a. Panel A es el componente
que lo hace posible en términos visuales. Sin Panel A, el Grouper produce
clusters en memoria que nadie puede ver. Con Panel A, esos clusters se
convierten en una estructura visual navegable.

Su rol es estrictamente presentacional: recibe clusters del Grouper, los
organiza visualmente en grupos con encabezado y lista de recursos, y los pone
ante el observador. Panel A no interpreta, no infiere, no decide. Es el
componente de visualización del extremo final de la cadena
Importer → Classifier → Grouper → Panel A.

### Qué Valor Aporta A La Validación Del Formato Workspace

La hipótesis que 0a valida es: *¿el formato workspace genera valor?* Para que
un observador pueda responder esa pregunta, los recursos agrupados por el
Grouper deben aparecer en pantalla de manera que la organización sea evidente.
Panel A es la interfaz entre los datos en memoria y la percepción del
observador:

- sin Panel A, la cadena de módulos de 0a produce datos en memoria que no
  son visibles al observador
- con Panel A, los clusters del Grouper se convierten en grupos con encabezado
  (dominio, categoría, subtema) y listas de recursos (título, favicon, dominio)
- la visibilidad de la organización es el requisito necesario para que el gate
  de 0a pueda evaluarse

Panel A valida que el formato workspace tiene una capa de presentación
comprensible para un observador externo. No valida PMF. No valida el puente
móvil→desktop. No valida el Episode Detector de 0b. Valida que el contenedor
workspace puede mostrar recursos organizados de manera que la organización
sea autoevidente.

### Por Qué Panel A No Es Panel B

Panel B es el componente que muestra resúmenes de contenido: bullets, abstracts,
síntesis de lo más relevante de cada recurso. Panel B requiere acceso al
contenido completo de las páginas (prohibido por D1 — Privacy Level 1
permanente) o un motor de resumen (LLM — prohibido como requisito por D8).
Panel B entra en Fase 1.

Panel A muestra únicamente los metadatos del recurso ya disponibles en los
clusters del Grouper: título, favicon, dominio, subtema. No muestra contenido
de páginas. No genera resúmenes. No necesita LLM ni red.

**Cualquier entregable que mezcle elementos de Panel A con elementos de Panel B
debe bloquearse. Son componentes distintos con alcances distintos en fases
distintas.**

---

## Alcance Exacto De Panel A En 0a

### Qué Renderiza

Panel A renderiza los clusters de recursos producidos por el Grouper. Para
cada cluster, muestra:

**Encabezado de grupo**

- dominio del grupo (e.g., `github.com`)
- categoría del grupo (e.g., `development`)
- sub_label si está presente en el cluster (e.g., derivado de tokens comunes
  en títulos, como `authentication` o `testing`)
- número de recursos en el grupo (opcional, como dato de contexto)

**Lista de recursos dentro del grupo**

Por cada recurso del cluster:

- título del recurso (campo `title`, descifrado localmente desde SQLCipher
  a través del payload del Grouper)
- dominio del recurso (campo `domain`, en claro en SQLCipher)
- favicon del recurso, si está disponible en caché local del perfil del
  navegador exportado; si no está disponible localmente, el espacio se omite
  sin bloquear el renderizado ni producir error visible

Panel A no aplica ningún filtro sobre los clusters recibidos: renderiza todos
los grupos y todos los recursos del payload del Grouper. No ranquea grupos por
relevancia. No oculta grupos con pocos recursos. No reordena recursos dentro
de un grupo más allá del orden entregado por el Grouper.

### Qué No Renderiza

Panel A no renderiza ninguno de los siguientes elementos, independientemente
de si los datos estuvieran disponibles:

- resúmenes de contenido de recursos (bullets, abstracts, síntesis) — Panel B
- extractos del cuerpo del texto de los recursos
- indicadores de relevancia, urgencia o prioridad de grupos
- timestamps de captura o de última visita
- indicadores de sesión o de episodio de trabajo
- acciones sugeridas por recurso individual (Panel C gestiona las acciones
  del workspace completo, no por recurso)
- indicadores de sync o conectividad
- placeholders "reservados para Panel B" o para funcionalidades de fases
  posteriores
- cualquier campo derivado de contenido completo de página

### Qué Acción Puede Hacer El Observador Desde Panel A

En la demo de 0a, Panel A es una vista estática. El observador puede:

- visualizar los grupos de recursos y sus encabezados
- leer los títulos y dominios de los recursos dentro de cada grupo

Panel A no requiere interacción para cumplir el gate de 0a. Si la
implementación añade la capacidad de hacer clic para abrir un recurso en el
navegador (acción discreta que delega al sistema operativo la apertura del
vínculo), esa acción es compatible con 0a siempre que no requiera red desde
la propia app ni active ningún proceso de observación o captura en Panel A.

---

## Contrato De Input/Output

### Input: Clusters Del Grouper

Panel A recibe la lista de clusters producida por el Grouper (T-0a-004).
El contrato de input es exactamente el contrato de output del Grouper:

```
Lista de clusters [
  cluster {
    group_key: string      -- identificador del grupo (e.g., "development/github.com")
    domain: string         -- dominio compartido del grupo
    category: string       -- categoría compartida del grupo
    sub_label: string      -- etiqueta de sub-agrupación por título (puede ser cadena vacía)
    resources: [
      {uuid, title, domain, category}
    ]
  }
]
```

Panel A no solicita campos adicionales al Grouper. El contrato de input queda
fijo por TS-0a-004. Si algún campo del cluster está vacío o ausente, Panel A
lo omite sin error:

- `sub_label` vacío → el encabezado muestra solo dominio y categoría
- `resources` vacío en un cluster → el grupo no se renderiza

Panel A consume este payload exactamente una vez por sesión de demo. No vuelve
a invocar al Grouper ni a ningún módulo upstream durante el ciclo de vida del
panel.

### Output: Renderizado Visual

El output de Panel A es la representación visual de los clusters en la UI del
Desktop Workspace Shell. No hay output programático: Panel A no devuelve datos
a ningún módulo. Su output es exclusivamente visual.

La estructura de renderizado esperada es:

```
[Encabezado de grupo: domain · category · sub_label?]
  [Recurso 1: favicon? | título | domain]
  [Recurso 2: favicon? | título | domain]
  ...

[Encabezado de grupo: domain · category · sub_label?]
  [Recurso N: favicon? | título | domain]
  ...
```

El renderizado es estático durante la demo: el contenido de Panel A no cambia
sin una nueva carga del workspace.

---

## Contratos Con Módulos Adyacentes

### Con Basic Similarity Grouper (T-0a-004)

Panel A consume los clusters del Grouper. La relación es unidireccional:
el Grouper produce, Panel A consume. Panel A no invoca al Grouper durante
el renderizado. El Grouper no conoce la estructura visual de Panel A;
entrega la lista de clusters y su responsabilidad termina.

```
Grouper → [lista de clusters en memoria] → Panel A → [renderizado visual]
```

**Condición 2 de contención de R12:** cualquier entregable de 0a o de 0b
que mencione Panel A en relación con la agrupación de recursos debe citar la
tabla de diferenciación Grouper 0a vs Episode Detector 0b de TS-0a-004.
Panel A es consumidor del Grouper de 0a y no tiene relación con el Episode
Detector de 0b.

### Con Panel C (T-0a-006)

Panel A y Panel C son componentes separados del Desktop Workspace Shell.
Panel C recibe el mismo payload de clusters que Panel A; ambos reciben el
payload en la misma entrega del Shell. Panel A no invoca a Panel C ni Panel C
invoca a Panel A. La coordinación entre ambos paneles ocurre en el nivel del
Shell (T-0a-001).

Panel A no gestiona la zona de Panel C ni controla su renderizado. La
separación visual entre Panel A y Panel C es responsabilidad del Shell.

### Con Desktop Workspace Shell (T-0a-001)

El Shell aloja a Panel A. El Shell le entrega el payload de clusters al
arrancar el workspace. Panel A no conoce los detalles del contenedor; solo
recibe los clusters y los renderiza.

El Shell no invoca al Grouper directamente: recibe los clusters ya procesados
y los distribuye a Panel A y Panel C.

### Con SQLCipher Local Storage (T-0a-007)

Panel A no lee directamente de SQLCipher. Recibe los datos del recurso
(título, dominio) a través del payload del Grouper, que ya leyó y desencriptó
los campos necesarios localmente. Panel A no tiene acceso directo a la capa
de persistencia.

### Con Domain/Category Classifier (T-0a-003) e Importer (T-0a-002)

Panel A no invoca al Classifier ni al Importer en ningún momento del flujo
de renderizado. La relación es exclusivamente a través del payload del
Grouper: los campos `domain`, `category` y `sub_label` de los clusters son
el resultado indirecto del trabajo del Classifier, pero Panel A los recibe
como campos del cluster, no como invocaciones a módulos upstream.

---

## Exclusiones Explícitas

| Elemento excluido | Primera fase permitida | Regla que lo bloquea |
| --- | --- | --- |
| Resumen de contenido de recursos (bullets, abstracts, síntesis) | Fase 1 | Panel B — scope-boundaries.md, phase-definition.md |
| Panel B bajo cualquier nombre o variante | Fase 1 | scope-boundaries.md; phase-definition.md |
| Generación de texto con LLM en el renderizado | nunca como requisito | D8 |
| Carga de favicons desde red | MVP: prohibida | invariante 2 de arch-note |
| Ordenación de grupos por relevancia, urgencia o frecuencia de uso | Fase 2 | inferencia de valor pertenece a Pattern Detector (D2, D17) |
| Indicadores de sesión, episodio o temporalidad | 0b | Session Layer PROHIBIDA en 0a; Detection Layer PROHIBIDA en 0a |
| Timestamps de captura o de última visita visibles | 0b | temporalidad de recursos pertenece al Session Builder de 0b |
| Actualización en tiempo real del panel (polling o push) | MVP: prohibido | invariante 1 de arch-note; observer activo PROHIBIDO (D9) |
| Interacción con Share Extension iOS | 0b | D9; iOS Specialist LOCKED en 0a |
| Indicadores de sync o conectividad | 0b | D6; Sync Layer PROHIBIDA en 0a |
| Placeholders para Panel B o para funcionalidades de fases posteriores | bloqueado siempre | contamina fases; arch-note invariante 5 |
| Renderizado de contenido completo de páginas | nunca | D1 permanente: Privacy Level 1 |
| Acciones sugeridas por recurso individual | fuera de contrato | acciones del workspace pertenecen a Panel C (T-0a-006) |
| Ranqueo de recursos por frecuencia de uso o patrón longitudinal | Fase 2 | D2, D17: Pattern Detector |
| Background watcher que actualice Panel A | MVP: prohibido | D9; invariante 1 de arch-note |
| Inferencia de intención del usuario por patrones de visualización | 0b | D9, D12; Detection Layer PROHIBIDA en 0a |

---

## Criterios De Aceptación

Los siguientes criterios son verificables externamente por el Technical
Architect y el QA Auditor. Ninguno puede considerarse satisfecho sin
evidencia documental en la revisión.

- [ ] Panel A renderiza todos los clusters producidos por el Grouper sin
      filtrar, reordenar ni ocultar ningún grupo; el número de grupos visibles
      en Panel A coincide con el número de clusters en el payload del Grouper
- [ ] cada encabezado de grupo muestra dominio, categoría y sub_label si el
      cluster lo incluye; si sub_label está vacío, el encabezado muestra solo
      dominio y categoría sin error ni espacio vacío visible
- [ ] cada recurso dentro de un grupo muestra el título (descifrado localmente)
      y el dominio; si el favicon no está disponible localmente, su ausencia no
      bloquea el renderizado ni genera error visible al observador
- [ ] Panel A no muestra resumen, abstract, bullets ni ningún texto derivado del
      contenido completo de los recursos en ningún elemento de la UI
- [ ] Panel A no invoca al Grouper más de una vez durante el ciclo de vida de la
      sesión de demo; el payload se recibe una sola vez al arrancar el workspace
- [ ] Panel A no invoca al Classifier ni al Importer en ningún momento del flujo
      de renderizado
- [ ] Panel A no inicia ninguna conexión de red en ningún punto del renderizado,
      incluida la carga de favicons
- [ ] Panel A no usa LLM en ninguna variante del flujo nominal de renderizado
- [ ] Panel A no contiene ningún elemento perteneciente a Panel B, ni como
      componente activo ni como placeholder, bajo ningún nombre
- [ ] Panel A es visualmente distinguible de Panel C: el observador puede
      identificar sin instrucción previa cuál es la zona de recursos agrupados
      y cuál es la zona de siguientes pasos
- [ ] el criterio de gate de 0a — "un observador externo entiende la organización
      del workspace sin explicación previa" — puede evaluarse positivamente con
      Panel A renderizado; este criterio requiere evidencia de demo real y no es
      verificable automáticamente
- [ ] R12 — CONTROL EXPLÍCITO (condición 2 de contención): este documento cita
      la tabla de diferenciación Grouper 0a vs Episode Detector 0b de TS-0a-004;
      un observador que lea este documento comprende que Panel A es consumidor
      del Grouper de 0a y no tiene relación con el Episode Detector de 0b

---

## Señales De Contaminación De Fase

Las siguientes señales indican que el documento o la implementación están
incorporando elementos que no pertenecen a Panel A en 0a. Cualquiera debe
bloquearse o escalarse inmediatamente.

| Señal | Diagnóstico | Acción | Regla violada |
| --- | --- | --- | --- |
| "añadimos un resumen de cada recurso para hacer la demo más rica" | Panel B introduciéndose en Panel A | BLOQUEAR | Panel B es Fase 1; scope-boundaries.md |
| "añadimos bullets con lo más importante de cada recurso" | Panel B bajo otro nombre | BLOQUEAR | Panel B es Fase 1; D1 permanente |
| "Panel A carga los favicons desde internet si no están en local" | conexión de red desde la app | BLOQUEAR | invariante 2 de arch-note |
| "Panel A se actualiza automáticamente cuando llegan nuevos bookmarks" | observer activo en la UI | BLOQUEAR | invariante 1 de arch-note; D9 |
| "dejamos un espacio reservado para Panel B cuando esté listo" | contaminación de Fase 1 explícita | BLOQUEAR | arch-note invariante 5; phase-definition |
| "ordenamos los grupos por los más relevantes para el usuario" | inferencia de relevancia sin base en datos | BLOQUEAR | Pattern Detector es Fase 2; D2, D17 |
| "Panel A muestra cuándo se guardó cada recurso" | temporalidad de sesión en 0a | BLOQUEAR | Session Layer PROHIBIDA en 0a |
| "Panel A detecta si hay un grupo en el que el usuario está trabajando ahora" | detección de intención en la capa visual | BLOQUEAR | Detection Layer PROHIBIDA en 0a; D9 |
| "usamos LLM para generar etiquetas de grupo más inteligentes" | LLM como requisito de renderizado | BLOQUEAR | D8 |
| "Panel A podría conectar con la Share Extension para actualizarse en tiempo real" | Share Extension en 0a | BLOQUEAR | D9; iOS Specialist LOCKED en 0a |
| "el Grouper que usa Panel A es el mismo que el Episode Detector básico" | confusión R12 en el contexto de Panel A | ESCALAR al Phase Guardian | R12; TS-0a-004 tabla de diferenciación |
| "Panel A muestra acciones sugeridas para cada recurso" | Panel A asumiendo rol de Panel C | BLOQUEAR | Panel C (T-0a-006) es el propietario de las acciones del workspace |
| "añadimos indicador de sync para saber cuándo llegaron los recursos" | Sync Layer en 0a | BLOQUEAR | D6; Sync Layer PROHIBIDA en 0a |
| "Panel A ranquea automáticamente los recursos más importantes de la sesión" | inferencia de importancia con temporalidad | BLOQUEAR | Session Layer + Detection Layer PROHIBIDAS en 0a |
| "añadimos un Panel A mejorado con resumen IA para el observador" | Panel B con nombre alternativo y LLM | BLOQUEAR | Panel B es Fase 1; D8 |

---

## Handoff Esperado

Este documento requiere revisión por dos agentes antes de cerrarse.

### 1. Technical Architect

Debe verificar:
- que Panel A no adelanta ningún elemento de Panel B (scope-boundaries.md,
  phase-definition.md)
- que el contrato de input/output es coherente con arch-note-phase-0a.md
  (contrato de módulo Panel A: input clusters del Grouper; output lista visual
  de recursos agrupados con título, favicon, dominio, subtema)
- que la restricción de favicon sin red está correctamente especificada y es
  implementable con el perfil de exportación de bookmarks de 0a
- que Panel A no introduce acceso directo a SQLCipher ni invocaciones a módulos
  upstream durante el renderizado
- que la condición 2 de contención de R12 queda operativa en este documento
  (referencia a tabla de diferenciación de TS-0a-004)

### 2. QA Auditor

Debe verificar:
- que los criterios de aceptación son verificables externamente
- que el criterio de gate — "un observador externo entiende la organización
  del workspace sin explicación previa" — está correctamente incorporado como
  criterio de aceptación y que queda claro que requiere demo real
- que ningún criterio de aceptación introduce ambigüedad que permita justificar
  Panel B, LLM, red o temporalidad dentro de 0a
- que la tabla de señales de contaminación cubre los vectores de riesgo más
  probables para Panel A en la demo de 0a
- que el control de R12 (condición 2) es operativo: la tabla de diferenciación
  de TS-0a-004 está citada de manera que cualquier entregable que mencione
  Panel A en relación con la agrupación de recursos tenga una referencia
  trazable al límite Grouper 0a / Episode Detector 0b

Si hay correcciones, ambos agentes las comunican al Desktop Tauri Shell
Specialist antes de cerrar. El documento no puede cerrarse con revisión de
solo uno de los dos agentes requeridos.

Cadena pendiente tras este documento:

```
TS-0a-005 [este documento] → TS-0a-006 (Panel C)
                                    ↓
                              TS-0a-001 (Desktop Shell — cierre de cadena de 0a)
```

---

## Nota De Gobernanza

Esta especificación no autoriza implementación en el repo de producto.
Define el contrato documental que la implementación debe respetar cuando el
equipo construya Panel A en el contexto de la demo de 0a.

El criterio de gate de 0a — "un observador externo entiende la organización
del workspace sin explicación previa" — no puede satisfacerse solo con este
documento. Requiere una sesión de demo real en la que un observador externo
vea Panel A renderizado con datos del Grouper sin recibir explicación previa
de la estructura.

El tratamiento del favicon (mostrar si disponible localmente, omitir si no)
es una decisión de implementación compatible con las restricciones de 0a y
no requiere cambio de contrato.

Panel B no existe en 0a. Ninguna variante de Panel B — bajo ningún nombre,
como componente activo o como placeholder — puede añadirse a Panel A en 0a.
