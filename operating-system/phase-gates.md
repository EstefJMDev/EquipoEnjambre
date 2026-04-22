# FlowWeaver - Phase Gates

## Autoridad Del Gate

Los phase gates solo tienen fuerza operativa si se sigue esta secuencia:

1. Phase Guardian redacta la revision del gate.
2. QA Auditor valida evidencia y fallos bloqueantes.
3. Orchestrator emite la decision go/no-go.
4. Context Guardian registra el resultado y actualiza trazabilidad.

Ningun agente puede cerrar una fase por si solo.

## Evidencia Minima Para Cualquier Gate

Toda revision de gate debe citar:

* documentos revisados
* hipotesis de fase que se valida
* lo que la fase explicitamente no valida
* fallos bloqueantes, si existen
* siguiente owner nombrado tras la decision

## Regla General

Una fase no pasa porque parezca completa.
Solo pasa si la hipotesis de esa fase tiene evidencia suficiente y no queda
ninguna contradiccion bloqueante activa.

## Gate De Salida De Fase 0a

### Condiciones minimas

* el workspace se entiende
* la agrupacion se entiende
* el contenedor genera interes
* el equipo distingue claramente 0a de 0b
* la evidencia sigue describiendo bookmarks como bootstrap/onboarding

### Condiciones de no-paso

* el workspace no se entiende
* la agrupacion no genera valor percibido
* 0a se interpreta como validacion de PMF
* el equipo no distingue 0a de 0b
* la importacion de bookmarks se reinterpreta como caso nucleo del producto

## Gate De Salida De Fase 0b

### Condiciones minimas

* contrato de Share Extension completo
* contratos de Session Builder y Episode Detector dual-mode completos
* protocolo de sync MVP definido con ACK, idempotencia y retries
* fallback QR definido como contingencia, no como redisenio
* Privacy Dashboard minimo definido
* recorrido documental completo de validacion del wow moment

### Condiciones de no-paso

* sync MVP es ambiguo o depende de backend propia
* sync MVP se reinterpreta como P2P
* la narrativa hacia el usuario no preserva el wow moment
* el sistema se lee como vigilancia
* broad mode reemplaza a precise mode como promesa principal
* la experiencia depende de un LLM local

## Gate De Salida De Fase 1

### Condiciones minimas

* FS Watcher esta delimitado como segundo caso de uso local, no como reescritura
  del MVP
* Panel B queda definido sin contaminar retroactivamente 0a o 0b
* el detector adaptado sigue separado de Pattern Detector

### Condiciones de no-paso

* FS Watcher se usa para sugerir que desktop siempre podia observar
* Panel B se convierte en dependencia retroactiva del MVP
* se adelanta aprendizaje longitudinal

## Gate De Salida De Fase 2

### Condiciones minimas

* Pattern Detector, Trust Scorer y State Machine quedan unidos al roadmap de
  confianza progresiva
* el Privacy Dashboard completo esta definido antes de beta
* la logica longitudinal no rompe la narrativa de privacidad

### Condiciones de no-paso

* aparece aprendizaje longitudinal sin control del usuario
* se diluye la autoridad de la State Machine
* el dashboard completo sigue incompleto

## Gate De Salida De Fase 3

### Condiciones minimas

* beta y metricas quedan definidas sin reescribir el caso nucleo
* los objetivos de calibracion de umbrales son explicitos
* el LLM sigue siendo opcional

### Condiciones de no-paso

* beta depende de componentes aun no aceptados
* la medicion exige telemetria fuera del marco de privacidad aprobado

## Regla Para Este Repositorio

Estos gates gobiernan documentacion y comportamiento de agentes en este
repositorio.
No autorizan implementacion del producto aqui.
