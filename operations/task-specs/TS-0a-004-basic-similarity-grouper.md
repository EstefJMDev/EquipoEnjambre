# Especificación Operativa — T-0a-004

owner_agent: Desktop Tauri Shell Specialist
document_id: TS-0a-004
task_id: T-0a-004
phase: 0a
date: 2026-04-22
status: APROBADO — revisión conjunta AR-0a-003 + QA-REVIEW-0a-003 cerrada sin bloqueos; corrección menor aplicada (2026-04-22)
referenced_backlog: operations/backlogs/backlog-phase-0a.md
referenced_arch_note: operations/architecture-notes/arch-note-phase-0a.md
referenced_decisions: D2 (Episode Detector timing), D3 (Precisión del Episode Detector), D8 (Motor de resumen)
referenced_risk: R12 (Confusión Grouper 0a vs Episode Detector 0b — WATCH ACTIVO)
required_review: Technical Architect (límite de módulo, diferenciación con Episode Detector) + QA Auditor (verificación R12, criterios de aceptación)
depends_on: TS-0a-003 (Domain/Category Classifier — APROBADO)
precede_a: TS-0a-005 (Panel A) + TS-0a-006 (Panel C)

---

## Propósito En Fase 0a

### Por Qué Existe El Grouper En 0a

El Basic Similarity Grouper existe en 0a para un único propósito:
producir clusters de recursos que Panel A pueda renderizar con estructura
visible y que den al observador la sensación de estar viendo un espacio
de trabajo organizado.

Sin el Grouper, Panel A recibiría una lista plana de URLs con título y
dominio. Con el Grouper, Panel A recibe grupos con semántica: recursos de
`github.com` en categoría `development` y título similar quedan juntos;
recursos de `medium.com` en categoría `articles` forman otro grupo.
El Grouper transforma una lista plana en un contenedor de trabajo legible.

Su rol en 0a es estrictamente instrumental y orientado a la demo:
produce la estructura mínima que hace el workspace comprensible
para un observador externo. No detecta intención del usuario. No genera
episodios accionables. No evalúa si los recursos forman una sesión de
trabajo. Es un agrupador de catálogo, no un detector de episodios.

### Qué Valor Aporta A La Validación Del Formato Workspace

La hipótesis que 0a valida es: *¿el formato workspace genera valor?*
Para que un observador pueda responder esa pregunta, los recursos deben
aparecer organizados de manera comprensible. El Grouper es el paso que
convierte la importación de bookmarks en un workspace con estructura:

- sin el Grouper, la demo no puede mostrar agrupación visual
- sin agrupación visual, Panel A es una lista plana sin semántica
- sin semántica en Panel A, no es posible evaluar si el contenedor
  workspace es comprensible o valioso

El Grouper de 0a es, en ese sentido, el módulo que hace posible la demo.
No valida PMF. No valida el puente móvil→desktop. Valida que el contenedor
workspace puede presentar recursos agrupados de manera comprensible.

### Por Qué Este Grouper No Equivale Al Episode Detector De 0b

El Grouper de 0a opera sobre bookmarks ya importados, aplica heurística
simple sobre dominio, categoría y similitud de título, y produce clusters
estáticos para Panel A. No hay ventana temporal. No hay captura activa.
No hay decisión de "accionable o no accionable".

El Episode Detector dual-mode de 0b detecta si un conjunto de URLs
capturadas en tiempo real por la Share Extension forma un episodio de
trabajo accionable. Usa similitud de Jaccard para el modo preciso,
categoría como fallback en el modo broad, y trabaja sobre señales
capturadas en ventanas temporales de menos de 24 horas.

**El Grouper de 0a y el Episode Detector de 0b no son el mismo módulo en
fases distintas. Son módulos con funciones distintas, algoritmos distintos,
inputs distintos y outputs distintos. El Grouper de 0a no crece hasta
convertirse en el Episode Detector de 0b. El Episode Detector de 0b se
implementa como módulo nuevo en 0b, independientemente del Grouper de 0a.**

Ver tabla completa de diferenciación en la sección "Tabla De Diferenciación
Obligatoria: Grouper 0a vs Episode Detector 0b".

---

## Alcance Exacto Del Grouper En 0a

### Qué Entrada Recibe

El Grouper lee de SQLCipher los recursos ya persistidos por el Importer
tras la invocación al Classifier. Cada recurso llega con los campos:

```
{id, uuid, url (cifrada), title (cifrado), domain, category}
```

El Grouper no llama al Classifier directamente. No invoca al Importer.
Lee los campos `domain` y `category` desde la capa de persistencia.
El campo `title` cifrado puede ser descifrado localmente para la heurística
de similitud de título (operación local, sin red).

### Qué Salida Produce

El Grouper produce clusters de recursos en memoria para ser consumidos
por Panel A y Panel C:

```
cluster {
  group_key: string      -- identificador del grupo (e.g., "development/github.com")
  domain: string         -- dominio compartido del grupo
  category: string       -- categoría compartida del grupo
  sub_label: string      -- etiqueta de sub-agrupación por título (opcional)
  resources: [           -- lista de recursos del grupo
    {uuid, title, domain, category}
  ]
}
```

Los clusters se entregan como lista ordenable. El Grouper no escribe
clusters en SQLCipher. Su output es una estructura en memoria que
Panel A y Panel C consumen directamente.

### Qué Agrupación Permite

La agrupación opera en dos niveles:

**Nivel 1 — Agrupación por dominio y categoría**

El criterio primario de agrupación es la combinación `domain + category`.
Recursos con el mismo dominio y la misma categoría forman un grupo.
Esto garantiza que todos los recursos de `github.com/development` queden
juntos, todos los de `notion.so/notes` queden juntos, etc.

Este nivel de agrupación es determinístico: depende únicamente de los
campos ya asignados por el Classifier.

**Nivel 2 — Sub-agrupación por similitud básica de título**

Dentro de un grupo de dominio+categoría, el Grouper puede producir
sub-grupos por similitud básica de título mediante heurística simple:
coincidencia de palabras clave entre títulos de recursos del mismo grupo.

La heurística opera así:
- tokeniza los títulos (split por espacios, eliminación de stopwords)
- identifica si dos o más recursos del mismo grupo comparten al menos
  N tokens relevantes (umbral configurable para la demo; valor de
  referencia: N ≥ 2 tokens no stopword)
- recursos que comparten tokens forman un sub-grupo con etiqueta
  derivada de los tokens comunes

La heurística es local, sin red, sin embeddings, sin LLM. No aplica
similitud de Jaccard entre conjuntos: la comparación es por token
compartido, no por coeficiente de similitud entre sets de n-gramas.

### Qué Límites Tiene

- el Grouper no interpreta si un grupo forma una sesión de trabajo
- el Grouper no asigna relevancia temporal a los grupos
- el Grouper no decide si un grupo es "accionable" o "no accionable"
- el Grouper no ranquea grupos por importancia ni urgencia
- el Grouper no activa ningún flujo de trabajo ni trigger de workspace
- el Grouper no evalúa patrones de uso del usuario
- el Grouper no tiene memoria entre ejecuciones: cada ejecución procesa
  el conjunto completo de recursos disponibles en SQLCipher

### Qué No Interpreta

El Grouper no interpreta:
- la intención del usuario al guardar esos recursos
- si los recursos fueron guardados en la misma sesión de trabajo
- si los recursos forman un episodio de trabajo accionable
- si el usuario está actualmente trabajando en ese tema
- si algún grupo requiere atención urgente
- si hay un patrón longitudinal de comportamiento

Estas interpretaciones pertenecen a módulos de 0b y fases posteriores.

---

## Exclusiones Explícitas

| Elemento excluido | Primera fase permitida | Regla que lo bloquea |
| --- | --- | --- |
| Detección de episodios | 0b | D2: Episode Detector dual-mode entra en 0b |
| Detección de intención del usuario | 0b | D9, D12 |
| Ventanas temporales tipo episodio (< 24h, sesión, burst) | 0b | Session Builder + Detection Layer PROHIBIDA en 0a |
| Similitud de Jaccard entre sets de n-gramas | 0b | D3: pertenece al Episode Detector preciso |
| Clustering semántico con embeddings o LLM | nunca como requisito | D8 |
| Lógica cross-device (agrupación de señales de múltiples dispositivos) | 0b | Sync Layer PROHIBIDA en 0a |
| Trigger de workspace anticipatorio | 0b | Observer activo PROHIBIDO en 0a (D9) |
| Sync de ningún tipo | 0b | D6 |
| Share Extension iOS | 0b | D9 |
| Observer activo de cualquier tipo | MVP prohibido | D9, invariante 1 de arch-note |
| Pattern Detector | Fase 2 | D2, D17 |
| Trust Scorer | Fase 2 | D4 |
| State Machine | Fase 2 | D4 |
| Lógica de wow moment de 0b (sorpresa + cruce de dispositivo) | 0b | el wow moment del producto pertenece al caso núcleo de 0b |
| Panel B (resumen de recursos) | Fase 1 | scope-boundaries.md, phase-definition.md |
| Aprendizaje longitudinal de agrupaciones | Fase 2 | D2, D17: Pattern Detector |
| Ranqueo de grupos por relevancia o urgencia | fuera de contrato | introduce inferencia de valor que pertenece a capas superiores |
| Agrupación basada en contenido completo de página | nunca | D1: Privacy Level 1 permanente |

---

## Tabla De Diferenciación Obligatoria: Grouper 0a vs Episode Detector 0b

Esta tabla es el control principal para R12 en este módulo. Debe citarse
en cualquier entregable de 0a que mencione el Grouper o la agrupación de
recursos.

| Atributo | Basic Similarity Grouper (T-0a-004) | Episode Detector Dual-Mode (0b) |
| --- | --- | --- |
| **Objetivo** | Producir clusters estáticos para que Panel A los renderice con estructura visible | Detectar si un conjunto de señales capturadas forma un episodio de trabajo accionable |
| **Tipo de input** | Recursos ya importados desde bookmarks locales (histórico, retroactivo) | Señales capturadas en tiempo real por la Share Extension iOS (activo) |
| **Temporalidad** | Sin ventana temporal: opera sobre el conjunto completo disponible sin referencia al momento de captura | Ventana temporal activa: menos de 24 horas; el tiempo de captura de cada señal es criterio de inclusión |
| **Criterio de agrupación / detección** | Dominio + categoría (nivel 1) + similitud de tokens en título (nivel 2, heurística simple) | Modo preciso: similitud de Jaccard + ecosistemas de URLs; Modo broad: categoría como fallback (D3) |
| **Output** | Lista de clusters {group_key, domain, category, sub_label, resources} en memoria para Panel A | Veredicto binario: episodio accionable / no accionable; payload para activar workspace anticipatorio |
| **Relación con el caso núcleo** | Sin relación directa con el caso núcleo del producto: es bootstrap / cold start (D12) | El caso núcleo del producto: el puente móvil→desktop empieza cuando el Episode Detector activa el workspace |
| **Capacidad de detectar intención** | Ninguna: el Grouper no infiere intención del usuario; agrupa por atributos de los recursos | Sí (modo broad): la categoría es un proxy de intención de trabajo; el modo preciso refina con ecosistemas |
| **Capacidad de activar flujo cross-device** | Ninguna: el Grouper no activa ningún flujo; produce clusters estáticos en memoria | Sí: la detección de episodio accionable es el trigger que activa el workspace anticipatorio en desktop |
| **Relación con el wow moment** | Sin relación: el wow moment no ocurre en 0a (D12, backlog does_not_validate) | El wow moment del producto es la consecuencia del Episode Detector: el workspace aparece en desktop en el momento correcto |
| **Algoritmo de similitud** | Heurística de tokens compartidos en título (sin Jaccard, sin embeddings) | Jaccard entre n-gramas de URLs + boost por ecosistema de servicios (D3) |
| **Modo dual** | No existe modo dual: un solo nivel de agrupación + un nivel de sub-agrupación | Sí: precise mode (Jaccard) + broad mode (categoría) según señales disponibles (D3) |
| **Determinismo** | Sí: mismo conjunto de recursos + misma heurística → mismos clusters | No: depende de señales acumuladas en ventana temporal; dos ejecuciones con distinto timing producen resultados distintos |
| **Aprendizaje** | No: sin memoria entre ejecuciones | No en 0b; Pattern Detector en Fase 2 (D2, D17) |
| **Owner documental** | Desktop Tauri Shell Specialist | Session & Episode Engine Specialist |
| **Fase** | 0a | 0b |

---

## Contrato Con Otros Módulos De 0a

### Con Domain/Category Classifier (T-0a-003)

El Grouper no invoca al Classifier directamente. Lee los campos `domain`
y `category` ya persistidos en SQLCipher por el flujo Importer → Classifier
→ Importer → INSERT. La relación es unidireccional y mediada por la capa
de persistencia:

```
Classifier → [produce domain + category] → Importer → SQLCipher
                                                         ↓
                                               Grouper ← lee domain + category
```

### Con SQLCipher Local Storage (T-0a-007)

El Grouper lee de SQLCipher. No escribe en SQLCipher. El campo `title`
cifrado puede descifrarse localmente para la heurística de título. El
Grouper no modifica el schema de 0a ni añade tablas.

### Con Panel A (T-0a-005)

Panel A consume los clusters producidos por el Grouper. El contrato es:

```
Grouper → [lista de clusters] → Panel A → [renderizado de recursos agrupados]
```

Panel A no invoca al Grouper más de una vez por sesión de demo. El Grouper
no conoce la estructura visual de Panel A; entrega clusters y su
responsabilidad termina.

### Con Panel C (T-0a-006)

Panel C recibe el mismo payload de clusters que Panel A. Usa el campo
`category` del cluster para seleccionar la plantilla de siguientes pasos.
Panel C no invoca al Grouper independientemente del flujo de Panel A:
ambos paneles reciben los clusters en la misma entrega.

### Con Desktop Workspace Shell (T-0a-001)

El Shell no invoca al Grouper directamente. El Shell recibe los clusters
ya procesados a través de Panel A y Panel C. El Grouper es transparente
para el Shell.

---

## Criterios De Aceptación

Los siguientes criterios son verificables externamente por el Technical
Architect y el QA Auditor. Ninguno puede considerarse satisfecho sin
evidencia documental en la revisión.

- [ ] los recursos importados se agrupan por dominio y categoría (nivel 1)
      como criterio primario; el agrupador no inventa grupos que no existen
      en los datos del Classifier
- [ ] la sub-agrupación por similitud de título (nivel 2) opera por
      coincidencia de tokens, no por coeficiente de Jaccard ni por embeddings;
      el método de similitud queda descrito con suficiente detalle en la
      implementación como para ser auditado
- [ ] el Grouper no inicia ninguna conexión de red en ningún punto del proceso
- [ ] el Grouper no usa LLM en ninguna variante del flujo nominal
- [ ] el Grouper no mantiene estado entre ejecuciones: cada ejecución opera
      sobre el conjunto completo de recursos disponibles en SQLCipher sin
      memoria de agrupaciones anteriores
- [ ] el Grouper no implementa ninguna forma de ventana temporal ni de
      acumulación de señales con referencia al momento de captura
- [ ] el Grouper no produce un veredicto de "accionable / no accionable"
      sobre ningún grupo ni recurso
- [ ] el Grouper no activa ningún flujo de workspace, ningún trigger de
      cross-device ni ninguna notificación
- [ ] R12 — CONTROL EXPLÍCITO: un observador externo que lea este documento
      y la tabla de diferenciación comprende sin ambigüedad que el Grouper
      de 0a no es el Episode Detector de 0b, no es una versión simplificada
      del Episode Detector de 0b, y no puede crecer hasta convertirse en él
- [ ] la tabla Grouper vs Episode Detector de este documento cubre los 15
      atributos enumerados en la sección correspondiente
- [ ] Panel A puede renderizar los clusters producidos por el Grouper sin
      requerir ningún campo adicional no especificado en el contrato de output

---

## Señales De Contaminación De Fase

Las siguientes señales indican que el documento o la implementación se están
acercando indebidamente al Episode Detector de 0b. Cualquiera de ellas debe
bloquearse o escalarse inmediatamente.

| Señal | Diagnóstico | Acción | Regla violada |
| --- | --- | --- | --- |
| "usamos Jaccard para ver si los bookmarks son similares" | El Grouper está adoptando el algoritmo del Episode Detector preciso | BLOQUEAR | D3; Episode Detector preciso de 0b |
| "añadimos una ventana de 24 horas para ver los bookmarks más recientes" | El Grouper está adoptando la temporalidad del Episode Detector | BLOQUEAR | Session Layer PROHIBIDA en 0a; D2 |
| "el Grouper detecta si el usuario está trabajando en un tema ahora mismo" | El Grouper está adoptando la función de detección de intención | BLOQUEAR | D9, D12; Detection Layer PROHIBIDA en 0a |
| "el Grouper es el Episode Detector básico de 0a" | Confusión directa de R12 | ESCALAR al Phase Guardian | R12; arch-note invariante 7 |
| "el Grouper podría convertirse en el Episode Detector si añadimos Jaccard" | Interpretación de que el Grouper es un proto-Episode-Detector | ESCALAR al Phase Guardian | R12; son módulos distintos |
| "el Grouper activa el workspace cuando detecta un grupo relevante" | El Grouper está adoptando la función de trigger del Episode Detector | BLOQUEAR | Observer activo PROHIBIDO; D9 |
| "añadimos agrupación cross-device para cuando llegue el sync" | Lógica de Sync Layer en un módulo de 0a | BLOQUEAR | Sync Layer PROHIBIDA en 0a; D6 |
| "el Grouper genera el wow moment de la demo" | El wow moment pertenece al caso núcleo de 0b, no a 0a | ESCALAR | D12; backlog does_not_validate |
| "con embeddings mejoraría mucho la agrupación" | Clustering semántico adelantando la capa de inteligencia | ADVERTIR — si se convierte en requisito: BLOQUEAR | D8; nunca como requisito |
| "el Grouper distingue sesiones de trabajo distintas" | El Grouper está adoptando la función del Session Builder | BLOQUEAR | Session Layer PROHIBIDA en 0a |
| "ranqueamos los grupos por relevancia para el usuario" | Inferencia de valor que pertenece a capas superiores | BLOQUEAR | Pattern Detector es Fase 2; D2, D17 |
| "guardamos los clusters en SQLCipher para que persistan entre sesiones" | El Grouper introduciría tablas fuera del schema mínimo de 0a | BLOQUEAR | schema mínimo de TS-0a-007; D16 |

### Riesgo Principal: R12 — Watch Activo

El riesgo R12 establece que el Grouper de 0a puede ser descrito como
"proto-Episode-Detector" o reutilizado como base del Episode Detector de 0b.
Cualquiera de esas interpretaciones es incorrecta:

- el Grouper de 0a agrupa recursos históricos para hacer la demo legible;
  el Episode Detector detecta episodios en tiempo real para activar el
  caso núcleo del producto
- añadir Jaccard, ventanas temporales o modo dual al Grouper de 0a no produce
  el Episode Detector de 0b: produce un Grouper contaminado de 0a
- el Episode Detector de 0b es un módulo nuevo implementado por el
  Session & Episode Engine Specialist, con su propia especificación en 0b

Contención operativa:

1. Cualquier propuesta que añada Jaccard, embeddings, ventanas temporales o
   lógica de detección de episodios al Grouper de 0a debe bloquearse.
2. La tabla de diferenciación de este documento debe citarse en cualquier
   entregable de 0a o de 0b que mencione el Grouper.
3. Technical Architect y QA Auditor confirman el límite de módulo y el
   control de R12 antes de que este documento cierre.
4. El Phase Guardian bloquea cualquier entregable de 0b que reutilice el
   Grouper de 0a como punto de partida del Episode Detector.

---

## Handoff Esperado

Este documento requiere revisión obligatoria por dos agentes antes de
cerrarse. La revisión es conjunta conforme a HO-002.

### 1. Technical Architect

Debe verificar:
- que el Grouper de 0a es arquitectónicamente distinto del Episode Detector
  de 0b en función, algoritmo, input y output
- que el contrato de módulo (input/output/restricciones) es coherente con
  arch-note-phase-0a.md
- que la tabla de diferenciación Grouper vs Episode Detector cubre los 15
  atributos con suficiente precisión técnica
- que la heurística de similitud de título (nivel 2) no anticipa Jaccard
  ni introduce similitud de tipo Episode Detector
- que el output del Grouper (clusters en memoria) es coherente con el contrato
  de input de Panel A y Panel C

### 2. QA Auditor

Debe verificar:
- que los criterios de aceptación son verificables externamente
- que el control explícito de R12 en los criterios de aceptación es
  operativo (no solo declarativo)
- que la tabla de señales de contaminación cubre los vectores de riesgo
  más probables en la demo de 0a
- que ningún criterio de aceptación introduce ambigüedad que permita
  justificar Jaccard, LLM o ventanas temporales dentro de 0a

Si hay correcciones, ambos agentes las comunican al Desktop Tauri Shell
Specialist antes de cerrar. El documento no puede cerrarse con revisión
de solo uno de los dos agentes requeridos.

Cadena pendiente tras este documento:

```
TS-0a-004 [este documento] → TS-0a-005 (Panel A) + TS-0a-006 (Panel C)
                                    ↓
                              TS-0a-001 (Desktop Shell — cierre de cadena de 0a)
```

---

## Nota De Gobernanza

Esta especificación no autoriza implementación en el repo de producto.
Define el contrato documental que la implementación debe respetar cuando el
equipo construya el Basic Similarity Grouper en el contexto de la demo de 0a.

La heurística de similitud de título (nivel 2) es una referencia de diseño
para la demo. El umbral de tokens compartidos (N ≥ 2 como valor de referencia)
es ajustable durante la demo sin cambio de contrato, siempre que el método
de similitud no cambie de tokens a Jaccard, embeddings ni LLM.

El Episode Detector dual-mode de 0b (D2, D3) es un módulo independiente con
su propia especificación, su propio owner documental (Session & Episode Engine
Specialist) y su propia cadena de revisión. No es una extensión de este módulo.
