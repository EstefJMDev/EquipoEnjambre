# FlowWeaver Project Framework - AGENTS.md

Este repositorio no contiene implementacion del producto FlowWeaver.

Existe solo para construir, definir, mantener y gobernar el sistema
multiagente que guiara el desarrollo futuro de FlowWeaver: agentes, reglas
operativas, limites de fase, coordinacion, trazabilidad, handoffs, control de
cambios, criterios de revision y proteccion de scope.

## 1. Proposito Del Repositorio

Este repositorio debe construir un sistema operativo de proyecto multiagente que
permita desarrollar FlowWeaver de forma rigurosa, trazable, controlada y segura
por fases.

Este repositorio debe producir:

* agentes especializados
* contratos operativos por agente
* reglas de activacion por fase
* protocolos de colaboracion
* reglas de escalado
* control de cambios
* plantillas operativas
* matrices de responsabilidad
* criterios de revision y cierre
* proteccion de decisiones cerradas
* mecanismos de trazabilidad entre sesiones y agentes
* reglas de creatividad controlada para resolver bloqueos sin romper el producto

Este repositorio no debe producir:

* implementacion del producto
* scaffolding tecnico de la app
* codigo funcional de desktop/mobile/sync
* contratos API del producto
* modulos de base de datos del producto
* arquitectura de implementacion lista para build
* prototipos funcionales del producto
* pruebas del producto real
* paquetes, apps, servicios o librerias del producto

## 2. Regla Central

La especificacion del producto puede usarse aqui solo como:

1. fuente de restricciones
2. fuente de decisiones cerradas
3. fuente de definicion de fases
4. fuente de limites de scope
5. fuente de contexto para diseniar bien el enjambre
6. fuente de hipotesis a proteger
7. fuente de limites de validacion por fase

No debe usarse para empezar a construir el producto.

Si un problema puede resolverse mediante:

* reglas del enjambre
* limites de fase
* activacion de agentes
* control documental
* plantillas
* handoffs
* revision
* escalado

entonces no debe resolverse creando estructura prematura del producto.

## 3. Que Debe Hacer Codex Aqui

Cuando trabajes aqui, debes:

1. leer primero este archivo
2. leer despues los docs normativos relevantes en:
   * `/project-docs`
   * `/operating-system`
   * `/agents`
   * `/operating-system/templates` cuando aplique
3. construir o modificar solo el sistema multiagente del proyecto
4. traducir detalle de producto a:
   * reglas
   * restricciones
   * activaciones
   * handoffs
   * controles documentales
   * criterios de revision
   * matrices de responsabilidad
5. mantener coherencia entre vision, tesis, decisiones cerradas, limites de
   scope, definiciones de fase, activacion de agentes, protocolos de
   colaboracion y control de cambios
6. dejar trazabilidad documental explicita
7. cerrar trabajo importante con update documental, handoff explicito o
   changelog
8. proteger la diferencia entre diseniar el sistema operativo del proyecto e
   implementar el producto
9. preferir fallbacks compatibles antes que cambios estructurales

Si dos documentos chocan sobre activacion u ownership, la matriz correspondiente
debe volver a ser la autoridad unica.

## 4. Que No Debe Hacer Codex

Codex no debe:

* convertir este repositorio en el inicio de la implementacion real del producto
* crear apps, paquetes, servicios o modulos del producto
* inventar features fuera del roadmap
* adelantar trabajo de una fase futura a una anterior sin proceso formal
* redefinir el caso de uso nucleo
* introducir backend propia en MVP
* tratar el LLM local como requisito
* convertir bookmarks retroactivos en el caso de uso nucleo
* tratar Fase 0a como validacion de PMF
* usar creatividad para saltarse restricciones del producto
* crear arquitectura de implementacion del producto cuando el problema puede
  resolverse a nivel de sistema operativo del enjambre
* debilitar la narrativa de privacidad verificable
* convertir fallbacks en redisenio del producto
* usar este repositorio para "dejar avanzada" la implementacion real del
  producto

## 5. Verdad Central Del Producto Que Este Enjambre Debe Proteger

FlowWeaver es un asistente que detecta intencion de trabajo a partir de seniales
reales del usuario y prepara el siguiente paso antes de que el usuario lo pida.

### Caso De Uso Nucleo Del MVP

* el usuario guarda 3 o mas recursos sobre un tema similar en menos de 24 horas
  desde movil
* FlowWeaver detecta el episodio
* sincroniza la senial al escritorio
* prepara un workspace
* el usuario abre desktop y encuentra el trabajo ya preparado

Este es el unico caso de uso nucleo del MVP y todo el enjambre debe protegerlo
frente a expansiones prematuras o reinterpretaciones.

## 6. Restricciones No Negociables

* MVP = un solo caso de uso nucleo: puente movil -> desktop
* desktop no observa activamente en MVP
* no hay FS Watcher ni Accessibility APIs en MVP
* el unico observer activo del MVP es Share Extension iOS
* sync MVP = relay cifrado por iCloud Drive / Google Drive mas fallback QR
* no hay backend propia en MVP
* Pattern Detector, Trust Scorer, State Machine y Explainability Log entran en
  Fase 2
* bookmarks retroactivos son onboarding/cold start, no caso de uso nucleo
* templates son el baseline funcional del resumen
* LLM local es mejora opcional, no requisito
* Privacy Level 1 es el default
* 0a valida el contenedor workspace, no PMF
* 0b valida el wow real del puente movil -> desktop
* Fase 1 introduce FS Watcher
* Fase 2 introduce aprendizaje longitudinal y confianza progresiva
* V1/V2+ no deben contaminar la ejecucion del MVP

## 7. Jerarquia De Autoridad Documental

Si dos documentos parecen chocar, prevalece este orden:

1. `project-docs/decisions-log.md`
2. `project-docs/phase-definition.md`
3. `project-docs/scope-boundaries.md`
4. `project-docs/roadmap.md`
5. `project-docs/vision.md`
6. `project-docs/product-thesis.md`

Reglas adicionales:

* `/operating-system` gobierna la operacion del enjambre
* `/agents` gobierna el mandato de cada agente
* las plantillas gobiernan el formato de salida
* `project-docs/agent-activation-matrix.md` manda sobre cualquier
  `default_state` individual
* `project-docs/agent-responsibility-matrix.md` manda sobre cualquier
  implicacion de solape de ownership
* `AGENTS.md` gobierna el comportamiento global del repo

## 8. Agentes Definidos En Este Repositorio

### Nucleo Operativo

* `agents/00_orchestrator.md`
* `agents/01_functional_analyst.md`
* `agents/02_technical_architect.md`
* `agents/03_qa_auditor.md`
* `agents/04_context_guardian.md`
* `agents/05_privacy_guardian.md`
* `agents/06_phase_guardian.md`
* `agents/07_handoff_manager.md`

### Especialistas Activables

* `agents/08_constraint_solving_fallback_specialist.md`
* `agents/09_desktop_tauri_shell_specialist.md`
* `agents/10_ios_share_extension_specialist.md`
* `agents/11_session_episode_engine_specialist.md`
* `agents/12_sync_pairing_specialist.md`
* `agents/14_cross_repo_consistency_specialist.md`

## 9. Estados Operativos De Agente

Estados permitidos:

* ACTIVE
* LISTENING
* LOCKED
* ARCHIVAL

Definiciones:

* ACTIVE: puede liderar trabajo y producir entregables
* LISTENING: puede revisar o asesorar, pero no liderar
* LOCKED: existe en el sistema, pero todavia no puede participar
* ARCHIVAL: solo referencia historica

Ningun agente puede actuar por encima de su estado actual.

## 10. Reglas Maestras Del Enjambre

* ningun agente cambia una decision cerrada sin change control formal
* ningun agente adelanta una fase futura sin escalado
* ningun agente invade otro dominio sin handoff o escalado
* toda salida importante debe reflejarse en archivos reales del repo
* toda propuesta creativa debe respetar caso nucleo, fase activa, restricciones
  del MVP, decisiones cerradas y privacidad
* si aparece un bloqueo, primero deben explorarse fallbacks compatibles antes de
  alterar vision, scope o arquitectura conceptual
* si un problema puede resolverse documentalmente, no debe resolverse creando
  estructura prematura del producto
* ningun agente puede convertir este repo marco en repo de implementacion

## 11. Creatividad Permitida

La creatividad esta permitida solo para:

* diseniar fallbacks compatibles
* resolver bloqueos reales sin alterar el nucleo
* proponer degradaciones elegantes
* mejorar trazabilidad, handoffs o revision
* reducir ambiguedad del sistema operativo del proyecto
* proponer rutas documentales o de control mas robustas
* contener riesgo sin expandir scope

La creatividad no esta permitida para:

* rediseniar el producto
* cambiar el caso de uso nucleo
* sustituir sync MVP por backend propia
* adelantar Pattern Detector o Trust antes de Fase 2
* convertir bookmarks en el centro del producto
* crear arquitectura de implementacion del producto en este repo
* mover trabajo futuro a la fase actual sin proceso formal

## 12. Lectura Obligatoria Antes De Trabajo Grande

Lee primero:

* `/project-docs/vision.md`
* `/project-docs/product-thesis.md`
* `/project-docs/scope-boundaries.md`
* `/project-docs/roadmap.md`
* `/project-docs/decisions-log.md`
* `/project-docs/phase-definition.md`
* `/project-docs/agent-activation-matrix.md`
* `/project-docs/agent-responsibility-matrix.md`
* `/project-docs/deliverable-map.md`
* `/operating-system/orchestration-rules.md`
* `/operating-system/phase-gates.md`
* `/operating-system/collaboration-protocol.md`
* `/operating-system/change-control.md`
* `/operating-system/escalation-policy.md`
* `/operating-system/definition-of-done.md`
* `/operating-system/review-checklists.md`
* `/operating-system/file-ownership-map.md`

Despues lee:

* los agentes relevantes en `/agents`
* cualquier handoff pendiente o salida reciente relacionada

## 13. Conducta Obligatoria De Trabajo

Antes de crear o modificar estructura del enjambre, preguntate:

1. esto pertenece al sistema operativo del proyecto o a la implementacion del
   producto?
2. esto protege una fase o la contamina?
3. esto preserva el caso nucleo o lo diluye?
4. esto reduce ambiguedad o introduce complejidad innecesaria?
5. esto debe resolverse con una regla, plantilla o rol, en vez de con
   estructura tecnica?
6. esto respeta privacidad y decisiones cerradas?
7. esto deja suficiente trazabilidad para la siguiente sesion?

## 14. Definition Of Done De Alto Nivel

El trabajo en este repositorio solo esta hecho si:

* respeta el roadmap
* respeta decisiones cerradas
* no contamina fases tempranas con trabajo futuro
* no convierte el repo marco en implementacion del producto
* mantiene coherencia con el caso de uso nucleo
* deja trazabilidad documental suficiente
* no introduce contradicciones entre agentes, fases, decisiones y scope
* produce archivos reales, concretos y operativos

## 15. Criterios De Bloqueo Inmediato

Debes frenar y escalar si aparece cualquiera de estas situaciones:

* empieza implementacion real del producto desde este repo
* un documento reinterpreta 0a como validacion de PMF
* bookmarks empiezan a leerse como caso nucleo
* aparece observacion activa en desktop en MVP
* aparece sync con backend propia en MVP
* Pattern Detector o Trust aparecen como trabajo de 0a o 0b
* el LLM aparece como requisito funcional
* una propuesta creativa altera nucleo, fases o privacidad
* un agente trabaja fuera de su dominio sin handoff ni escalado
* dos documentos normativos se contradicen en un punto critico

## 16. Regla Final

Este repositorio no existe para "hacer ya algo del producto".
Existe para que, cuando llegue el momento de desarrollar FlowWeaver, el equipo
multiagente tenga una estructura suficientemente robusta como para no
improvisar, no contaminar fases, no perder contexto y no traicionar el nucleo
del producto.
