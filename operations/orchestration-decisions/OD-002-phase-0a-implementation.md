# Orchestration Decision

## OD-002 — Apertura Del Repo Del Producto E Inicio De Implementación De Fase 0a

date: 2026-04-23
issued_by: Orchestrator
status: APPROVED
referenced_pir: PIR-002-phase-0a-spec-close.md
referenced_handoff: HO-004-phase-0a-spec-cycle-close.md

---

## issue

El ciclo de especificación de Fase 0a está formalmente cerrado. Los siete task
specs (TS-0a-001 a TS-0a-007) están aprobados sin correcciones pendientes. PIR-002
declara el ciclo íntegro y apto para implementación. No hay bloqueos en ninguna
revisión de la cadena.

El enjambre ha completado su trabajo de gobernanza previa a la implementación.
El siguiente paso lógico es abrir el repo del producto y comenzar a construir
los módulos especificados, en el orden que impone la cadena de dependencias.

El repo del producto no se había abierto hasta este momento por diseño: ningún
agente debe implementar antes de que los contratos estén aprobados y el ciclo
de especificación esté revisado por el Phase Guardian. Ambas condiciones están
satisfechas.

## affected_phase

0a

## agents_involved

| Agente | Rol en la implementación de 0a |
| --- | --- |
| Orchestrator | Emite esta OD; coordina el inicio del trabajo de implementación |
| Desktop Tauri Shell Specialist | Owner de implementación — lidera todos los módulos de 0a |
| Technical Architect | Revisa decisiones de implementación que desvíen de los task specs |
| QA Auditor | Verifica que la implementación satisface los criterios de aceptación de cada TS |
| Phase Guardian | Vigilancia activa de R9 y R12 durante la implementación; activa el gate de salida cuando exista evidencia de demo |
| Privacy Guardian | LISTENING — alerta si la implementación viola D1 o introduce acceso a contenido completo |
| Handoff Manager | Produce HO-005 cuando la implementación esté lista para la demo de gate |
| Context Guardian | Actualiza risk-register.md según evolución de riesgos durante la implementación |
| iOS Share Extension Specialist | LOCKED — no participa en 0a |
| Session & Episode Engine Specialist | LOCKED — no participa en 0a |
| Sync & Pairing Specialist | LOCKED — no participa en 0a |

## decision

1. El repo del producto (`c:\Users\pinnovacion\Desktop\FlowWeaver`) queda
   autorizado para apertura e implementación a partir de esta decisión.

2. La implementación se ejecuta en el orden que impone la cadena de dependencias
   declarada en los task specs aprobados:

   ```
   T-0a-007  SQLCipher Local Storage          ← primero (almacenamiento base)
       └── T-0a-002  Bookmark Importer        ← segundo
               └── T-0a-003  Classifier       ← tercero
                       └── T-0a-004  Grouper  ← cuarto (R12 crítico aquí)
                               ├── T-0a-005  Panel A  ← quinto (paralelo)
                               └── T-0a-006  Panel C  ← quinto (paralelo)
                                       └── T-0a-001  Shell  ← sexto (integrador)
   ```

3. Cada módulo debe implementarse contra el criterio de aceptación de su task
   spec correspondiente. Ninguna desviación del contrato especificado está
   autorizada sin revisión previa del Technical Architect.

4. El criterio de gate de 0a — "un observador externo entiende la organización
   del workspace sin explicación previa" — requiere demo real con Panel A y
   Panel C renderizados con datos de bookmarks importados reales. La demo no
   puede simularse con datos hardcoded ni con capturas de pantalla.

5. El Phase Guardian mantiene vigilancia activa durante toda la implementación.
   R9 y R12 son los riesgos de mayor probabilidad de activación durante la
   fase de código.

6. El repo de gobernanza (`c:\Users\pinnovacion\Desktop\EquipoEnjambre`)
   sigue siendo el único repositorio de decisiones, specs y revisiones. Ningún
   documento de gobernanza se escribe en el repo del producto.

## rationale

PIR-002 aprueba sin bloqueos el ciclo de especificación completo. Los contratos
de los siete módulos son coherentes entre sí y con el arch-note. Los riesgos
activos tienen controles operativos verificados en la especificación.

Continuar en el ciclo de gobernanza sin iniciar la implementación no agrega
valor: el objetivo de 0a es validar que el formato workspace genera valor
ante un observador externo, y esa validación requiere software funcionando.

La apertura del repo del producto no modifica los contratos aprobados ni exime
a la implementación de cumplir los criterios de aceptación de cada task spec.

## constraints_respected

- D1: Privacy Level 1 activo. La implementación no puede acceder a contenido
  completo de páginas. URL y título deben cifrarse en SQLCipher. Dominio y
  categoría en claro.
- D6: Sin sync de ningún tipo en 0a. Ningún módulo implementado puede
  introducir relay, sincronización ni preparación de sync.
- D8: LLM no es requisito en ningún módulo. Panel C debe funcionar sin modelo
  local disponible. Criterio de aceptación 3 de TS-0a-006 es obligatorio.
- D9: Desktop no observa activamente. Ningún módulo puede introducir FS Watcher,
  Accessibility API, polling ni proceso de fondo.
- D12: Bookmarks son bootstrap y cold start. La demo de gate no presenta los
  bookmarks como el caso de uso núcleo del producto.
- D16: Schema SQLCipher con INTEGER PRIMARY KEY + UUID indexado conforme a
  TS-0a-007.
- AGENTS.md §3: El repo de gobernanza produce solo documentos de gobernanza,
  no código del producto. Sigue vigente.
- Panel B: Prohibido en 0a bajo cualquier nombre. Ningún componente
  implementado puede introducirlo como placeholder, como zona vacía reservada
  ni como comentario en el código.
- R12 WATCH ACTIVO: La narrativa de la demo de gate no puede presentar el
  Grouper como un componente de detección de patrones temporales ni como
  precursor del Episode Detector de 0b.

## next_agent

Desktop Tauri Shell Specialist → comenzar implementación de T-0a-007
(SQLCipher Local Storage) en el repo del producto, tomando TS-0a-007 como
contrato de referencia.

## documentation_updates_required

| Archivo | Acción | Urgencia | Estado |
| --- | --- | --- | --- |
| `project-docs/risk-register.md` | Context Guardian actualiza R11 → MITIGADO; R7 → BAJO CONTROL | BAJA | PENDIENTE |
| `operations/handoffs/HO-005-phase-0a-impl-to-gate.md` | Handoff Manager produce cuando la implementación esté lista para demo de gate | CUANDO LA IMPLEMENTACIÓN ESTÉ COMPLETA | PENDIENTE |
