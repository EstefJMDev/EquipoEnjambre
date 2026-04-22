# FlowWeaver Project Framework — AGENTS.md

Este repositorio **NO contiene la implementación del producto FlowWeaver**.

Este repositorio existe exclusivamente para **construir, definir, mantener y gobernar el sistema multiagente** que dirigirá el desarrollo futuro de FlowWeaver: sus agentes, reglas operativas, límites de fase, mecanismos de coordinación, trazabilidad, handoffs, control de cambios, criterios de revisión y mecanismos de protección de scope.

---

## 1. Propósito del repositorio

Este repositorio debe construir un **sistema operativo de proyecto multiagente** que permita desarrollar FlowWeaver de forma rigurosa, trazable, controlada y evolutiva en fases posteriores.

Este repositorio debe producir:

* agentes especializados
* contratos operativos por agente
* reglas de activación por fase
* protocolos de colaboración
* reglas de escalado
* control de cambios
* plantillas operativas
* matrices de responsabilidad
* criterios de revisión y cierre
* protección de decisiones cerradas
* mecanismos de trazabilidad entre sesiones y agentes
* reglas de creatividad controlada para resolver bloqueos sin romper el producto

Este repositorio **NO** debe producir:

* la implementación del producto
* scaffolding técnico de la app
* código funcional de desktop/mobile/sync
* contratos API del producto
* módulos de base de datos del producto
* arquitectura de implementación lista para build
* prototipos funcionales del producto
* pruebas del producto real
* paquetes, apps, servicios o librerías del producto

---

## 2. Regla central

La especificación del producto se usa en este repositorio solo como:

1. fuente de restricciones
2. fuente de decisiones cerradas
3. fuente de definición de fases
4. fuente de límites de scope
5. fuente de contexto para diseñar correctamente el enjambre
6. fuente de hipótesis a proteger
7. fuente de validaciones que cada fase debe o no debe realizar

**No debe usarse para comenzar a implementar el producto.**

Si un problema puede resolverse a nivel de:

* reglas del enjambre
* límites de fase
* activación de agentes
* control documental
* plantillas
* handoffs
* revisión
* escalado

entonces **no debe resolverse creando estructura técnica prematura del producto**.

---

## 3. Qué debe hacer Codex en este repositorio

Cuando trabajes aquí, debes:

1. Leer primero este archivo completo.
2. Leer después todos los documentos normativos en:

   * `/project-docs`
   * `/operating-system`
   * `/agents`
   * `/operating-system/templates` si existen
3. Construir o modificar **únicamente** el sistema multiagente del proyecto.
4. Traducir cualquier detalle técnico del producto a:

   * reglas
   * restricciones
   * activaciones
   * handoffs
   * controles documentales
   * criterios de revisión
   * matrices de responsabilidad
5. Mantener coherencia total entre:

   * visión
   * tesis de producto
   * decisiones cerradas
   * límites de scope
   * definición de fases
   * activación de agentes
   * protocolos de colaboración
   * control de cambios
6. Dejar siempre trazabilidad documental explícita.
7. Cerrar cada trabajo importante con:

   * actualización documental, o
   * handoff explícito, o
   * changelog breve de correcciones
8. Proteger la diferencia entre:

   * diseñar el sistema operativo del proyecto
   * implementar el producto
9. Cuando aparezca un bloqueo real, buscar primero una solución compatible con el marco antes de proponer alteraciones estructurales.

---

## 4. Qué NO debe hacer Codex

Codex no debe:

* convertir este repositorio en el inicio de la implementación real del producto
* crear apps, paquetes, servicios o módulos del producto
* inventar features fuera del roadmap
* adelantar elementos de una fase futura a una fase anterior sin proceso formal
* redefinir el caso de uso núcleo
* introducir backend propia en el MVP
* tratar el LLM local como dependencia obligatoria
* mezclar bookmarks retroactivos con el caso de uso núcleo
* tratar la Fase 0a como validación de product-market fit
* usar la creatividad para saltarse restricciones del producto
* crear arquitectura técnica del producto cuando el problema puede resolverse a nivel del sistema operativo del enjambre
* debilitar la narrativa de privacidad verificable
* convertir fallbacks en rediseño del producto
* usar este repositorio para “dejar avanzada” la implementación real del producto

---

## 5. Verdad central del producto que este enjambre debe proteger

FlowWeaver es un asistente que detecta intención de trabajo a partir de señales reales del usuario y prepara el siguiente paso antes de que el usuario lo pida.

### Caso de uso núcleo del MVP

* el usuario guarda 3 o más recursos sobre un tema similar en menos de 24 horas desde el móvil
* FlowWeaver detecta el episodio
* sincroniza la señal al escritorio
* prepara un workspace
* el usuario abre el desktop y encuentra el trabajo ya preparado

Este es el **único caso de uso núcleo del MVP** y todo el enjambre debe protegerlo frente a expansiones prematuras o reinterpretaciones.

---

## 6. Restricciones no negociables que el enjambre debe preservar

* MVP = único caso de uso núcleo: puente móvil → desktop
* Desktop **NO** observa activamente en MVP
* No hay FS Watcher ni Accessibility APIs en MVP
* Único observer activo del MVP = Share Extension iOS
* Sync MVP = iCloud Drive / Google Drive relay cifrado + fallback QR
* No hay backend propia en el MVP
* Pattern Detector, Trust Scorer, State Machine y Explainability Log entran en Fase 2
* Bookmarks retroactivos = onboarding/cold start, no caso de uso núcleo
* Plantillas = baseline funcional del resumen
* LLM local = mejora opcional, no requisito
* Privacidad Nivel 1 por defecto
* 0a valida el contenedor workspace, no PMF
* 0b valida el wow del puente real móvil → desktop
* Fase 1 introduce FS Watcher
* Fase 2 introduce aprendizaje longitudinal y escalera de confianza
* Fases V1/V2+ no deben contaminar la ejecución del MVP

---

## 7. Jerarquía de autoridad documental

Si dos documentos parecen tensionarse, prevalece este orden:

1. `project-docs/decisions-log.md`
2. `project-docs/phase-definition.md`
3. `project-docs/scope-boundaries.md`
4. `project-docs/roadmap.md`
5. `project-docs/vision.md`
6. `project-docs/product-thesis.md`

Además:

* Los documentos de `/operating-system` gobiernan la operación del enjambre.
* Los documentos de `/agents` gobiernan la conducta y mandato de cada agente.
* Las plantillas gobiernan el formato de salida operativa.
* `AGENTS.md` gobierna el comportamiento global del repositorio.

---

## 8. Agentes actualmente definidos en este repositorio

Los agentes actuales del núcleo operativo son:

* `00_orchestrator.md`
* `01_functional_analyst.md`
* `02_technical_architect.md`
* `03_qa_auditor.md`
* `04_context_guardian.md`
* `05_privacy_guardian.md`
* `06_phase_guardian.md`
* `07_handoff_manager.md`

### Lectura funcional de estos roles

#### 00_orchestrator

Autoridad operativa del sistema.
Activa agentes, secuencia trabajo, bloquea desvíos y protege coherencia global.

#### 01_functional_analyst

Convierte visión y especificación en alcance, backlog, criterios de aceptación y límites funcionales por fase.

#### 02_technical_architect

Traduce restricciones del producto a estructura modular, límites técnicos y guardrails de arquitectura conceptual, sin implementar el producto.

#### 03_qa_auditor

Verifica calidad, fidelidad al scope, validez de fase, definition of done y no contaminación del MVP.

#### 04_context_guardian

Protege memoria, trazabilidad, consistencia documental y continuidad entre sesiones.

#### 05_privacy_guardian

Protege privacidad Nivel 1, narrativa verificable, minimización de datos, dashboard y límites de captura/retención.

#### 06_phase_guardian

Protege el orden del roadmap, la pureza de cada fase y los phase gates.

#### 07_handoff_manager

Protege la calidad de las transferencias entre agentes y evita pérdida de contexto en la continuidad operativa.

---

## 9. Estados operativos de agentes

Estados permitidos:

* ACTIVE
* LISTENING
* LOCKED
* ARCHIVAL

### Definición

* **ACTIVE**: puede liderar trabajo y producir entregables
* **LISTENING**: puede leer, revisar y opinar de forma limitada, pero no lidera
* **LOCKED**: existe en el sistema, pero no participa activamente en la fase
* **ARCHIVAL**: uso histórico o de referencia, sin mandato operativo actual

### Regla

Ningún agente puede actuar por encima de su estado operativo.

---

## 10. Reglas maestras del enjambre

* Ningún agente puede cambiar una decisión cerrada sin proceso formal de cambio.
* Ningún agente puede adelantar una fase futura sin escalado.
* Ningún agente puede invadir el dominio de otro sin handoff o escalado.
* Toda salida importante debe quedar reflejada en archivos reales del repositorio.
* Toda propuesta creativa debe respetar:

  * caso de uso núcleo
  * fase actual
  * restricciones del MVP
  * decisiones cerradas
  * privacidad
* Ante un bloqueo, primero deben explorarse fallbacks compatibles antes de alterar visión, scope o arquitectura conceptual.
* Si un problema puede resolverse documentalmente, no debe resolverse creando estructura técnica prematura del producto.
* Ningún agente puede convertir este repo marco en un repo de implementación.
* Ningún agente puede usar este repo para justificar decisiones del producto no registradas formalmente.
* Ningún agente puede presentar una solución temporal como arquitectura permanente sin escalado y registro.

---

## 11. Creatividad permitida

La creatividad está permitida solo para:

* diseñar fallbacks compatibles
* resolver bloqueos reales sin alterar el núcleo
* proponer degradaciones elegantes
* mejorar trazabilidad, handoffs o revisión
* reducir ambigüedad del sistema operativo del proyecto
* proponer rutas documentales o de control más robustas
* contener riesgos sin expandir el scope

### La creatividad NO está permitida para:

* rediseñar el producto
* cambiar el caso de uso núcleo
* sustituir el sync MVP por backend propia
* adelantar Pattern Detector o Trust antes de Fase 2
* convertir bookmarks en el centro del producto
* crear arquitectura de implementación del producto dentro de este repo
* mover trabajo de una fase futura a la actual sin proceso formal
* vaciar la hipótesis de una fase para “hacerla más fácil de pasar”

---

## 12. Instrucción obligatoria antes de cualquier trabajo grande

Lee primero:

* `/project-docs/vision.md`
* `/project-docs/product-thesis.md`
* `/project-docs/scope-boundaries.md`
* `/project-docs/roadmap.md`
* `/project-docs/decisions-log.md`
* `/project-docs/phase-definition.md`
* `/project-docs/agent-activation-matrix.md`
* `/project-docs/agent-responsibility-matrix.md`
* `/operating-system/orchestration-rules.md`
* `/operating-system/phase-gates.md`
* `/operating-system/collaboration-protocol.md`
* `/operating-system/change-control.md`
* `/operating-system/escalation-policy.md`

Y después:

* los agentes relevantes en `/agents`
* cualquier handoff pendiente o salida reciente relacionada con la tarea

---

## 13. Conducta obligatoria de trabajo

Antes de modificar o crear estructura del enjambre, debes preguntarte:

1. ¿Esto pertenece al sistema operativo del proyecto o a la implementación del producto?
2. ¿Esto protege una fase o la contamina?
3. ¿Esto preserva el caso núcleo o lo diluye?
4. ¿Esto reduce ambigüedad o introduce complejidad innecesaria?
5. ¿Esto debe resolverse con una regla, una plantilla o un rol, en vez de con estructura técnica?
6. ¿Estoy respetando la privacidad y las decisiones cerradas?
7. ¿Estoy dejando trazabilidad suficiente para el siguiente agente o la siguiente sesión?

Si no puedes responder claramente, debes frenar y revisar la documentación normativa antes de continuar.

---

## 14. Definition of done de alto nivel

Un trabajo en este repositorio solo está hecho si:

* respeta el roadmap
* respeta las decisiones cerradas
* no contamina fases tempranas con trabajo de fases futuras
* no convierte el repo marco en implementación del producto
* mantiene coherencia con el caso de uso núcleo
* deja trazabilidad documental suficiente
* no introduce contradicciones entre agentes, fases, decisiones y scope
* produce archivos reales, concretos y operativos
* deja claro si el resultado:

  * está cerrado
  * requiere handoff
  * requiere revisión
  * requiere escalado

---

## 15. Criterios de bloqueo inmediato

Debes frenar y escalar si detectas cualquiera de estas situaciones:

* se intenta comenzar implementación real del producto desde este repo
* un documento reinterpreta 0a como validación de PMF
* bookmarks empiezan a describirse como caso núcleo
* aparece observación activa en desktop en MVP
* aparece backend propia en MVP
* Pattern Detector o Trust aparecen como trabajo de 0a o 0b
* el LLM local aparece como requisito funcional
* una propuesta creativa altera núcleo, fases o privacidad
* un agente trabaja fuera de su dominio sin handoff ni escalado
* dos documentos normativos se contradicen en un punto crítico

---

## 16. Regla final

Este repositorio no existe para “hacer ya algo del producto”.
Existe para que, cuando llegue el momento de desarrollar FlowWeaver, el equipo multiagente tenga una estructura suficientemente robusta como para no improvisar, no contaminar fases, no perder contexto y no traicionar el núcleo del producto.

Cuando dudes, protege:

1. el caso de uso núcleo
2. la separación entre fases
3. la privacidad
4. la trazabilidad
5. la disciplina del sistema multiagente
