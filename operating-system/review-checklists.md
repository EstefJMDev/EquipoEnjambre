# FlowWeaver - Review Checklists

## Regla De Cumplimiento

Estas checklists son bloqueantes, no orientativas.

Si falla cualquier punto bloqueante:

* QA Auditor marca el entregable como `cannot_proceed`
* el owner actual debe corregir el archivo antes de handoff o cierre
* Orchestrator decide si el trabajo vuelve al owner o escala

## Owners De Revision

| Checklist | Owner bloqueante principal | Roles consultados obligatorios |
| --- | --- | --- |
| Global | QA Auditor | Orchestrator |
| Scope y fase | Phase Guardian | Functional Analyst, QA Auditor |
| Privacidad | Privacy Guardian | QA Auditor, Technical Architect |
| Continuidad | Handoff Manager | Context Guardian |

## Checklist Global

Antes de validar cualquier entregable, confirmar:

* protege el caso de uso nucleo
* pertenece a la fase activa
* respeta decisiones cerradas
* no introduce implementacion funcional del producto
* declara inputs, outputs y limites duros
* deja trazabilidad y un siguiente paso claro

## Checklist De Scope Y Fase

* 0a no se describe como validacion de PMF
* 0b sigue siendo el puente movil -> desktop
* bookmarks siguen siendo solo onboarding/cold start
* desktop no aparece como observer activo en MVP
* FS Watcher no aparece antes de Fase 1
* Pattern Detector, Trust Scorer y State Machine no aparecen antes de Fase 2
* V1/V2+ no contaminan la ejecucion del MVP

## Checklist De Privacidad

* el texto no promete mas privacidad de la que el sistema puede defender
* no se introduce captura de contenido completo
* el LLM no se vuelve obligatorio
* sync MVP sigue leyendose como relay cifrado con fallback QR
* sync MVP no se presenta como backend propia ni como P2P
* dashboard minimo y dashboard completo no se confunden

## Checklist De Continuidad

* el handoff esta completo
* el siguiente owner esta nombrado
* los documentos afectados estan listados
* los riesgos abiertos siguen visibles
* la transferencia deja claro si el item es para ejecucion, revision o decision

## Regla De Cierre

Ningun entregable puede marcarse como hecho hasta que:

* el owner de checklist relevante aprueba su seccion
* QA Auditor no tiene hallazgos bloqueantes
* Context Guardian o Handoff Manager han registrado la continuidad si aplica
