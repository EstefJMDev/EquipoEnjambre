# Orchestration Decision

## OD-007 — Aplazamiento de D22 y Reafirmación del Caso Núcleo Único

date: 2026-04-29
issued_by: Orchestrator
status: APPROVED
supersedes_partial: D22 (aplazada, no revocada)
referenced_decisions: D9, D12, D19, D20, D21, D22

---

## Issue

D22 (aprobada 2026-04-24) introdujo la línea "FlowWeaver Mobile como producto
standalone con tier paid": Pattern Detector móvil, observer semi-pasivo Android,
detección de intención sobre comportamiento de navegación, anticipación
proactiva mobile.

Una revisión cruzada de los documentos fundacionales (vision.md, product-thesis.md,
scope-boundaries.md, product-spec.md) frente a D22 identifica una inconsistencia
estructural: los documentos fundacionales declaran que el caso núcleo del MVP es
"exclusivamente el puente móvil → desktop", mientras que D22 abre una segunda
línea de producto con segmentación distinta (mobile-only power user que "no
necesita ni usa el desktop").

Esta inconsistencia activa una violación de la regla operativa del decisions-log:

> "Si un documento posterior contradice este registro y no existe una propuesta
> formal aprobada, el documento posterior debe corregirse."

El conflicto no se resolvió porque D22 se aprobó como decisión nueva sin que se
abriera un CR formal para actualizar los documentos fundacionales. El proyecto
ha estado operando con dos visiones de producto coexistentes.

Riesgos detectados:
- doble hipótesis de validación sin recursos para validar ambas
- dispersión de esfuerzo entre puente cross-device y galería mobile standalone
- entrada en mercado saturado (galería mobile) antes de validar diferenciación
  real (puente cross-device)
- D22 introduce features (observer semi-pasivo, Pattern Detector móvil) que son
  un producto entero, no una mejora del MVP

---

## Decision

1. **D22 queda APLAZADA, no revocada.** La oportunidad de mobile standalone con
   tier paid sigue siendo válida como exploración de V1 o posterior. No se
   trabaja en ella durante el MVP.

2. **El caso núcleo único del MVP queda reafirmado:** puente móvil → desktop,
   tal como lo declaran vision.md, product-thesis.md, scope-boundaries.md y
   product-spec.md.

3. **El móvil queda redefinido como soporte del caso núcleo, no como producto
   independiente.** La galería organizada de Fase 0c sigue existiendo (D20
   permanece válida) pero deja de tratarse como "cliente completo standalone".
   Su función operativa es: permitir al Usuario A (multi-dispositivo) revisar
   rápidamente lo que ha capturado antes de llegar al desktop.

4. **D22 se marca como APLAZADA en decisions-log.md.**

5. **Trabajo bloqueado a partir de hoy:**
   - Pattern Detector compilado para Android (más allá de la base técnica
     existente)
   - Observer semi-pasivo Android (Tile de sesión / Quick Settings tile)
   - Detección de intención sobre comportamiento de navegación móvil
   - Anticipación proactiva en móvil (notificaciones contextuales)
   - Resumen / agrupación de episodios de búsqueda en móvil
   - Cualquier feature etiquetada como "tier paid mobile"

6. **CR-002 (mobile observer) queda en estado SUSPENDED** hasta nueva orden.
   Las extensiones de D9 aprobadas en AR-CR-002-mobile-observer y
   PGR-CR-002-mobile-observer se conservan como referencia técnica pero no
   autorizan implementación.

7. **D9 vuelve a su redacción original** en lo relativo a observers:
   - único observer activo en MVP: Share Intent Android (primario) + Share
     Extension iOS (track paralelo secundario)
   - desktop no observa activamente en MVP (FS Watcher entra en Fase 1, sigue
     siendo válido — la revisión background-persistent se conserva)
   - sin observer semi-pasivo móvil hasta validar el wow del puente

8. **D20 y D21 permanecen válidas.** El móvil sigue teniendo SQLCipher local,
   Classifier y Grouper. El relay sigue siendo bidireccional. Esto es
   infraestructura del Usuario A, no producto B.

---

## Rationale

El MVP necesita validar una hipótesis, no dos. La hipótesis del puente
móvil → desktop es la que diferencia FlowWeaver del mercado actual; la hipótesis
mobile-standalone compite en mercado rojo (Pocket, Raindrop, Google Keep).

Validar dos hipótesis en paralelo con recursos de un solo desarrollador produce
dos productos mediocres en lugar de uno sólido. La validación secuencial
(primero el puente, después explorar mobile standalone si procede) preserva la
opcionalidad sin dispersar esfuerzo.

D22 no se revoca porque la oportunidad sigue siendo real: si el puente se
valida en Fase 3 y aparece demanda explícita de uso mobile-only, la base
técnica (D20, D21, infraestructura Rust+NDK) está lista para reactivar D22
con bajo coste.

---

## Constraints respected

- vision.md y product-thesis.md: sin cambios; el puente sigue siendo el caso
  núcleo
- scope-boundaries.md: sin cambios
- D12: caso núcleo único; reforzado
- D6: sync MVP por relay cifrado; sin cambios
- D9: vuelve a redacción original (sin observer semi-pasivo)
- D17: Pattern Detector completo en Fase 2; sigue siendo desktop-only en MVP
- D19: plataforma primaria Windows + Android; sin cambios
- D20, D21: infraestructura mobile preservada; redefinida como soporte

---

## Reactivation conditions

D22 puede reactivarse si y solo si todas las condiciones siguientes se cumplen:

1. el wow del puente móvil → desktop se valida en Fase 3 con métricas
   declaradas (precision Episode Detector > 60%, ACK < 60s P95, > 3 momentos
   de magia/semana en > 40% de usuarios)
2. aparece demanda explícita de uso mobile-only de al menos 30% de usuarios
   beta
3. se abre CR formal nuevo (no se reutiliza CR-002) con re-evaluación completa
   del scope, las extensiones de D9 necesarias y el modelo freemium

Sin estas tres condiciones, D22 permanece APLAZADA indefinidamente.

---

## Next agent

Context Guardian, para:
1. actualizar decisions-log.md marcando D22 como APLAZADA con referencia a OD-007
2. añadir nota en roadmap.md Fase 0c reformulando "cliente completo" como
   "soporte de captura del Usuario A"
3. actualizar agent-activation-matrix.md si algún especialista pasa a LOCKED
   por esta decisión

---

## Documentation updates required

- [ ] decisions-log.md: D22 marcada como APLAZADA + nota detallada
- [ ] roadmap.md Fase 0c: redefinir alcance del móvil como soporte
- [ ] CLAUDE.md (FlowWeaver): añadir línea en "Qué no implementar sin TS aprobada"
- [ ] backlog-phase-0c.md: revisar si hay items que dependen de D22 y bloquearlos

---

## Risk acknowledged

Aplazar D22 implica que un segmento de usuarios mobile-only no será objetivo del
MVP. Si ese segmento resulta ser el mercado dominante real, el proyecto habrá
gastado el ciclo MVP validando la hipótesis equivocada. Este riesgo se acepta
explícitamente porque:

- la hipótesis del puente es más diferenciada y más difícil de copiar
- el coste de cambiar de A a B post-validación es bajo (infraestructura ya existe)
- el coste de validar B sin haber validado A es alto (mercado saturado)
- no hay evidencia de que el segmento mobile-only sea el dominante; D22 fue
  hipótesis del product owner, no resultado de research
