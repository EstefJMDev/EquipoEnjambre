# Especificación Operativa — T-0a-001

owner_agent: Desktop Tauri Shell Specialist
document_id: TS-0a-001
task_id: T-0a-001
phase: 0a
date: 2026-04-22
status: DRAFT — pendiente de revisión por Technical Architect y QA Auditor
referenced_backlog: operations/backlogs/backlog-phase-0a.md
referenced_arch_note: operations/architecture-notes/arch-note-phase-0a.md
referenced_decision: OD-001
required_review: Technical Architect (coherencia con arch-note); QA Auditor (criterios de aceptación)

---

## Objetivo

Definir con precisión el contrato del contenedor desktop de Fase 0a:
qué es el shell, qué paneles aloja, qué está prohibido dentro de él y qué
condiciones debe cumplir para superar la revisión de 0a.

El shell desktop es el contenedor, no los componentes. Su responsabilidad en
0a es alojar Panel A y Panel C con los datos producidos por el Grouper.
Nada más.

---

## Qué Valida T-0a-001 Dentro De 0a

Esta tarea contribuye a validar que:

- el contenedor Tauri 2 corre en macOS sin errores
- Panel A y Panel C se renderizan con datos reales del Grouper (T-0a-004)
- la app no inicia ningún proceso de red ni de observación activa
- el formato visual del workspace es comprensible para un observador externo

### Qué NO valida esta tarea

| Lo que no valida | Por qué |
| --- | --- |
| que el puente móvil→desktop funciona | hipótesis de Fase 0b, no de 0a |
| que el producto tiene PMF | 0a valida solo el formato workspace |
| que el Episode Detector entrega valor | ese módulo no existe en 0a |
| que los bookmarks son un caso de uso central | son bootstrap y cold start (D12) |
| que la sync funciona | PROHIBIDA en 0a (D6) |

---

## Alcance Exacto Del Shell Desktop En 0a

### Incluye

- ventana Tauri 2 corriendo en macOS sin errores de compilación ni de runtime
- layout con dos zonas diferenciadas: Panel A y Panel C
- renderizado de los clusters de recursos provistos por el Grouper (T-0a-004)
- invocación del Bookmark Importer (T-0a-002) como operación discreta al abrir
  la app (no como proceso continuo)
- cierre limpio de la app sin errores ni procesos residuales
- lectura de datos desde SQLCipher (T-0a-007)

### No Incluye

| Elemento excluido | Primera fase permitida | Regla que lo bloquea |
| --- | --- | --- |
| Panel B (resumen de recursos) | Fase 1 | scope-boundaries.md, phase-definition.md |
| Background watcher de cualquier tipo | MVP: no existe | D9, invariante 1 de arch-note |
| FS Watcher | Fase 1 | D9 |
| Share Extension iOS | 0b | D9, iOS Specialist LOCKED en 0a |
| Conexiones de red iniciadas por la app | MVP: prohibidas | invariante 2 de arch-note |
| Sync de ningún tipo | 0b | D6 |
| Accessibility APIs | Fase 1+ | D9 |
| Privacy Dashboard | 0b (mínimo) | D14 |
| Notificaciones del sistema | fuera del scope de 0a | no en backlog |
| Indicadores de conectividad o sync | 0b | D6 |
| Cualquier proceso en background | MVP: prohibido | invariante 1 de arch-note |
| LLM local como requisito | nunca como requisito | D8 |

---

## Límites De UI Y Comportamiento

### Permitido en la UI de 0a

- lista de recursos agrupados por subtema con título, dominio y favicon opcional
- panel de siguientes pasos (Panel C) con acciones generadas por plantilla
- importación manual de bookmarks como única acción de captura (T-0a-002)
- visualización estática suficiente para la demo de 0a

### Prohibido en la UI de 0a

| Comportamiento prohibido | Motivo |
| --- | --- |
| Detectar o capturar URLs activas del navegador | D9: desktop no observa en MVP |
| Escuchar cambios del filesystem | D9, FS Watcher es Fase 1 |
| Iniciar cualquier conexión de red | invariante 2 de arch-note |
| Mostrar resúmenes de contenido (bullets, abstracts, síntesis) | Panel B es Fase 1 |
| Mostrar interfaz de Share Extension | iOS Specialist LOCKED en 0a |
| Acceder a metadatos de sesión del navegador | fuera de 0a |
| Presentar el workspace como "detectó lo que estabas haciendo" | viola D9 y la narrativa de 0b |
| Mostrar indicadores de sync o conectividad | D6 |
| Añadir placeholder "reservado para Panel B" | contamina Fase 1 |

---

## Dependencias

| Dependencia | Qué provee | Relación con el shell |
| --- | --- | --- |
| T-0a-007 (SQLCipher) | motor de persistencia | el shell lee datos de SQLCipher para renderizar |
| T-0a-004 (Grouper) | clusters de recursos con subtema | input de Panel A |
| T-0a-005 (Panel A) | componente visual de recursos agrupados | alojado en el shell |
| T-0a-006 (Panel C) | componente visual de siguientes pasos | alojado en el shell |
| T-0a-002 (Bookmark Importer) | fuente de datos inicial | invocado por el shell al arrancar |

El shell es el último en la cadena de dependencias de ejecución. Sin embargo,
su especificación documental puede producirse en paralelo con T-0a-007 porque
ambas son contratos documentales, no implementaciones secuenciales.

---

## Criterios De Aceptación

- [ ] el contenedor Tauri 2 corre en macOS sin errores de compilación ni de runtime
- [ ] Panel A y Panel C se renderizan con los datos del Grouper (T-0a-004)
- [ ] Panel B no existe en ninguna parte de la UI (ni componente ni placeholder)
- [ ] no se inicia ninguna conexión de red durante la sesión de demo
- [ ] no se usa ninguna API de observación activa (Accessibility, FS Watcher,
  clipboard, etc.)
- [ ] el Bookmark Importer se invoca como operación discreta, no como proceso
  continuo
- [ ] el shell se cierra sin procesos residuales ni errores
- [ ] un observador externo entiende la organización del workspace sin
  explicación previa

El último criterio requiere evidencia de demo real y no es verificable
automáticamente. Es prerrequisito para el gate de salida de 0a.

---

## Señales De Contaminación De Fase

El Phase Guardian bloqueará cualquier entregable que contenga estas señales:

| Señal | Acción |
| --- | --- |
| "añadimos Panel B para mejorar la demo" | BLOQUEAR — Panel B es Fase 1 |
| "un watcher en background para capturar URLs" | BLOQUEAR — viola D9, MVP |
| "dejamos un endpoint preparado para el sync" | BLOQUEAR — viola D6 |
| "conectamos con la Share Extension de iOS" | BLOQUEAR — iOS Specialist LOCKED en 0a |
| "el shell podría observar el clipboard" | BLOQUEAR — observer activo prohibido en MVP |
| "añadimos indicador de conectividad para el futuro sync" | BLOQUEAR — viola D6 |
| "el Grouper podría usar el Episode Detector de 0b" | ESCALAR — R12 activo |
| "dejamos el layout preparado para Panel B" | BLOQUEAR — viola phase-definition |

---

## Handoff Esperado

1. Desktop Tauri Shell Specialist produce este documento (completado).
2. Technical Architect confirma coherencia con `arch-note-phase-0a.md`,
   en especial los contratos de módulo de Desktop Workspace Shell y de Panel A
   y Panel C.
3. QA Auditor revisa los criterios de aceptación contra los phase gates de 0a
   y los checklist normativos.
4. Si hay correcciones, vuelve al Desktop Tauri Shell Specialist antes de
   cerrar este ciclo de especificación.
5. Handoff Manager registra el cierre del ciclo cuando todos los TS de 0a
   estén revisados.

---

## Nota De Gobernanza

Esta especificación no autoriza implementación en el repo de producto.
Define el contrato que la implementación debe respetar cuando el equipo
construya la app de demo de 0a.

El gate de salida de 0a exige que un observador externo entienda el workspace.
Ese criterio no puede cumplirse solo con este documento: requiere una sesión
de demo real.
