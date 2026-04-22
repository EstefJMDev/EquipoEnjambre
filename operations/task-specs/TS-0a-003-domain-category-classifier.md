# Especificación Operativa — T-0a-003

owner_agent: Desktop Tauri Shell Specialist
document_id: TS-0a-003
task_id: T-0a-003
phase: 0a
date: 2026-04-22
status: DRAFT — pendiente de revisión por Technical Architect
referenced_backlog: operations/backlogs/backlog-phase-0a.md
referenced_arch_note: operations/architecture-notes/arch-note-phase-0a.md
referenced_decisions: D2 (Episode Detector timing), D3 (Precisión del Episode Detector), D8 (Motor de resumen)
required_review: Technical Architect (límite de módulo y diferenciación con Episode Detector)

---

## Propósito En Fase 0a

El Domain/Category Classifier existe en 0a para un único propósito:
asignar dominio y categoría a cada recurso que el Importer entrega,
de modo que el Grouper (T-0a-004) tenga los atributos mínimos necesarios
para agrupar recursos y que Panel A y Panel C puedan renderizarse con
significado.

Sin clasificación, todos los recursos son URLs con título. Con clasificación,
el workspace puede mostrar agrupaciones por tema y sugerir acciones por tipo
de contenido. El Classifier convierte URLs planas en recursos con semántica
mínima navegable.

Su rol es estrictamente instrumental: no detecta patrones, no infiere
intención del usuario, no evalúa si los recursos forman una sesión de
trabajo. Es un clasificador de catálogo, no un detector de episodios.

### Por Qué Este Módulo No Es El Episode Detector

El Episode Detector dual-mode de Fase 0b detecta si un conjunto de URLs
capturadas en tiempo real por la Share Extension forma un episodio de trabajo
accionable. Usa similitud de Jaccard para el modo preciso, categoría como
fallback en el modo broad, y trabaja sobre señales capturadas en ventanas
temporales de menos de 24 horas.

El Classifier de 0a no hace ninguna de esas cosas. Recibe una URL ya
importada y devuelve un dominio y una categoría. La operación es atómica,
local, determinística y no acumulativa. No hay ventana temporal. No hay
umbral de similitud. No hay decisión de "accionable o no accionable".

**Cualquier entregable que presente el Classifier de 0a como una versión
simplificada del Episode Detector debe bloquearse. Son módulos distintos
con funciones distintas en fases distintas.**

---

## Alcance Exacto Del Classifier En 0a

### Qué Hace

- recibe un recurso normalizado del Importer con URL y título
- extrae el dominio de la URL (e.g., `github.com`, `notion.so`, `youtube.com`)
- asigna una categoría al recurso mediante tabla de correspondencia dominio → categoría
- devuelve el recurso enriquecido con dominio y categoría al Importer
- opera de manera síncrona y local: sin red, sin proceso externo, sin LLM
- la clasificación es determinística: el mismo dominio siempre produce la misma categoría

### Mecanismo De Clasificación

La clasificación opera en dos pasos:

**Paso 1 — Extracción de dominio**

El dominio se extrae de la URL por parsing de hostname:

```
https://github.com/usuario/repo  →  github.com
https://mail.google.com/...      →  google.com  (subdominio normalizado)
https://www.notion.so/...        →  notion.so   (www eliminado)
```

El dominio queda en claro en SQLCipher (D1: el dominio no revela contenido,
es el nivel de abstracción aceptado).

**Paso 2 — Asignación de categoría por tabla**

La categoría se asigna por una tabla de correspondencia estática:

| Grupo de dominios (ejemplos) | Categoría asignada |
| --- | --- |
| github.com, gitlab.com, bitbucket.org, stackoverflow.com | `development` |
| notion.so, obsidian.md, roamresearch.com, craft.do | `notes` |
| figma.com, dribbble.com, behance.net | `design` |
| youtube.com, vimeo.com, twitch.tv | `video` |
| docs.google.com, sheets.google.com, slides.google.com | `productivity` |
| medium.com, substack.com, dev.to, hashnode.com | `articles` |
| twitter.com, x.com, linkedin.com, reddit.com | `social` |
| amazon.com, gumroad.com, stripe.com | `commerce` |
| arxiv.org, scholar.google.com, pubmed.ncbi.nlm.nih.gov | `research` |
| cualquier dominio sin correspondencia en tabla | `other` |

La categoría `other` es el fallback explícito. No hay inferencia ni llamada
a red para dominios sin correspondencia. El Classifier no bloquea si no
reconoce el dominio: asigna `other` y devuelve el control al Importer.

Esta tabla es una implementación de referencia para la demo de 0a.
Su extensión es evolutiva y no requiere cambio de contrato.

### Qué Entrega Al Resto Del Flujo

output: recurso con dominio y categoría, devuelto al Importer para INSERT en SQLCipher

```
recurso_normalizado {url, title}
    → Classifier (T-0a-003)
    → recurso_clasificado {url, title, domain, category}
    → Importer (T-0a-002)
    → INSERT en SQLCipher (T-0a-007)
```

El Classifier no escribe en SQLCipher directamente. No lee de SQLCipher.
Su contrato comienza y termina en la invocación del Importer.

---

## Qué NO Hace

### Exclusiones Explícitas

| Elemento excluido | Primera fase permitida | Regla que lo bloquea |
| --- | --- | --- |
| Similitud de Jaccard | 0b | D3: modo preciso del Episode Detector dual-mode |
| Clustering semántico con embeddings o LLM | nunca como requisito | D8 |
| Ventanas temporales de sesión | 0b | Session Builder; Detection Layer PROHIBIDA en 0a |
| Aprendizaje longitudinal de categorías | Fase 2 | D2, D17: Pattern Detector |
| Inferencia de intención del usuario | 0b | D9, D12 |
| Decisión de "episodio accionable" | 0b | Episode Detector dual-mode |
| Llamadas a red para enriquecer categoría | MVP: prohibidas | invariante 2 de arch-note |
| Acceso a contenido completo de páginas | nunca | D1 permanente |
| Clasificación por título (sin dominio) | fuera de contrato | rompe determinismo por dependencia de texto libre |
| Persistencia propia de categorías o dominios aprendidos | Fase 2 | Pattern Detector |
| Fallback a LLM si dominio no está en tabla | nunca como requisito | D8 |

### Distinción Crítica: Classifier 0a vs Episode Detector 0b

| Atributo | Classifier (T-0a-003) | Episode Detector Dual-Mode (0b) |
| --- | --- | --- |
| Función | Asignar categoría a un recurso individual | Detectar episodio accionable en un conjunto de recursos |
| Input | Una URL ya importada | URLs capturadas en tiempo real por Share Extension |
| Algoritmo | Tabla de correspondencia dominio → categoría | Jaccard (modo preciso) + categoría fallback (broad) |
| Ventana temporal | No aplica | Menos de 24 horas |
| Resultado por recurso | Dominio + categoría (siempre) | Episodio accionable / no accionable |
| Modo dual | No existe | Sí: precise + broad (D3) |
| Determinismo | Sí: mismo dominio → misma categoría | No: depende de señales acumuladas |
| Aprendizaje | No | No en 0b; Pattern Detector en Fase 2 |
| Fase | 0a | 0b |
| Owner documental | Desktop Tauri Shell Specialist | Session & Episode Engine Specialist |

Esta distinción debe quedar explícita en cualquier comunicación interna
o entregable de 0a que mencione el Classifier.

---

## Contrato Con Otros Módulos De 0a

### Con Bookmark Importer Retroactive (T-0a-002)

El Importer invoca al Classifier de manera síncrona para cada recurso
antes de persistirlo en SQLCipher. El Classifier recibe URL y título,
devuelve dominio y categoría. La invocación no puede bloquear el INSERT:

- si el Classifier responde (siempre lo hace, porque es local y determinístico),
  el INSERT ocurre con dominio y categoría asignados
- si por algún error de parsing la URL no produce dominio válido, el Classifier
  asigna el literal `"unknown"` como dominio y la categoría `other`; el INSERT
  no se cancela

El Classifier no conoce SQLCipher ni el schema de 0a. Su responsabilidad
termina en el valor de retorno.

```
Importer invoca → Classifier devuelve {domain, category} → Importer persiste
```

### Con Basic Similarity Grouper (T-0a-004)

El Classifier no interactúa directamente con el Grouper. La relación es
indirecta: el Grouper lee de SQLCipher los campos `domain` y `category`
que el Importer escribió tras la invocación al Classifier. El Grouper
no llama al Classifier; el Classifier no conoce al Grouper.

### Con Panel C (T-0a-006)

Panel C usa el campo `category` del recurso para seleccionar la plantilla
de siguientes pasos correcta (e.g., categoría `development` → plantilla de
revisión de código; categoría `articles` → plantilla de lectura). Panel C
no invoca al Classifier directamente; lee el campo `category` ya persistido
en SQLCipher.

---

## Criterios De Aceptación

- [ ] cada recurso importado recibe un dominio y una categoría antes de persistirse
- [ ] el dominio se extrae por parsing de hostname de la URL; ningún campo de texto
  libre del título se usa para derivar el dominio
- [ ] la categoría se asigna por tabla de correspondencia estática dominio → categoría
- [ ] la clasificación es determinística: el mismo dominio produce la misma categoría
  en cualquier ejecución
- [ ] dominios sin correspondencia en la tabla reciben la categoría `other`; el
  proceso no se interrumpe ni hace llamadas externas para resolver el dominio
- [ ] el Classifier no inicia ninguna conexión de red en ningún punto del proceso
- [ ] el Classifier no usa LLM en ninguna variante del flujo nominal
- [ ] el Classifier no mantiene estado entre invocaciones: cada llamada es
  atómica e independiente
- [ ] el Classifier no implementa ninguna forma de ventana temporal ni de
  acumulación de señales entre recursos
- [ ] un observador externo que lea este documento entiende que este Classifier
  no es el Episode Detector de 0b

---

## Señales De Contaminación De Fase Y Riesgos

| Señal | Acción | Regla violada |
| --- | --- | --- |
| "usamos Jaccard para ver si los bookmarks son similares" | BLOQUEAR | D3; Episode Detector preciso de 0b |
| "añadimos LLM para clasificar dominios que no están en la tabla" | ADVERTIR — si bloquea el INSERT: ESCALAR | D8 |
| "el Classifier aprende qué categorías usa más el usuario" | BLOQUEAR | D2, D17: Pattern Detector es de Fase 2 |
| "el Classifier detecta si los bookmarks forman una sesión de trabajo" | BLOQUEAR | Session Builder + Episode Detector son de 0b |
| "enriquecemos la categoría con metadatos de la página" | BLOQUEAR | invariante 2 de arch-note; D1 |
| "el Classifier es el Episode Detector simplificado de 0a" | ESCALAR | son módulos distintos en fases distintas |
| "añadimos similitud de título al Classifier" | ESCALAR | ese es el dominio del Grouper, no del Classifier |
| "el Classifier puede inferir la intención del usuario por el dominio" | ESCALAR | D12, D9: inferencia de intención pertenece al Observer de 0b |

### Riesgo Principal: Contaminación Con El Episode Detector

El riesgo principal de este módulo es que alguien interprete que el Classifier
de 0a puede crecer hasta convertirse en el Episode Detector de 0b añadiendo
Jaccard, LLM o ventanas temporales. Esta interpretación es incorrecta:

- el Classifier de 0a es un módulo de catálogo; el Episode Detector de 0b
  es un módulo de detección de episodios con algoritmos distintos
- el crecimiento del Classifier no lleva al Episode Detector; el Episode
  Detector es un módulo nuevo que se implementa en 0b independientemente
- confundir los dos módulos lleva a contaminar 0a con lógica de 0b y a
  adelantar el Episode Detector de manera fragmentada

Contención operativa:

1. Cualquier propuesta que añada Jaccard, embeddings, LLM de clasificación
   o ventanas temporales al Classifier de 0a debe bloquearse.
2. La tabla Classifier vs Episode Detector de este documento debe citarse
   en cualquier entregable de 0a que mencione la clasificación de recursos.
3. Technical Architect confirma el límite de módulo antes de que este
   documento cierre.

---

## Handoff Esperado

1. Desktop Tauri Shell Specialist produce este documento (completado).
2. Technical Architect revisa:
   - que el Classifier de 0a es determinístico y no anticipa el Episode Detector
   - que el contrato de módulo (input/output/restricciones) es coherente con
     arch-note-phase-0a.md
   - que la tabla Classifier vs Episode Detector contiene el riesgo de confusión
3. Si hay correcciones, vuelven al Desktop Tauri Shell Specialist antes de cerrar.
4. Tras aprobación: Desktop Tauri Shell Specialist produce **TS-0a-004**
   (Basic Similarity Grouper), siguiente en la cadena de dependencias
   marcada por HO-002.

Cadena pendiente tras este documento:

```
TS-0a-003 [este documento] → TS-0a-004 → TS-0a-005 + TS-0a-006
```

---

## Nota De Gobernanza

Esta especificación no autoriza implementación en el repo de producto.
Define el contrato documental que la implementación debe respetar cuando el
equipo construya el Domain/Category Classifier en el contexto de la demo de 0a.

La tabla de correspondencia dominio → categoría es una referencia de diseño
para la demo. No es un catálogo exhaustivo ni un sistema de taxonomía del
producto. Su extensión futura no requiere revisión de este documento; sí
requiere que los nuevos dominios sigan siendo asignables por regla estática
sin introducir aprendizaje ni red.
