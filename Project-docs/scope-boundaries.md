# FlowWeaver — Scope Boundaries

## Regla principal

El proyecto debe proteger el foco del MVP.
El caso de uso núcleo es exclusivamente el puente móvil → desktop.

Este repositorio protege ese foco a nivel de sistema multiagente.
No implementa el producto.

## Qué está en scope de este repo

- definición de agentes
- activación de agentes por fase
- contratos operativos
- handoffs
- escalado
- control de cambios
- revisión y auditoría
- trazabilidad
- plantillas operativas
- matrices de responsabilidad y activación

## Qué NO está en scope de este repo

- implementación del producto
- estructura de apps del producto
- módulos desktop/mobile/sync
- código de Episode Detector
- código de workspace
- código de sync
- modelos de datos ejecutables del producto
- contratos de build, deploy o runtime del producto

## Contexto de producto por fase

### Fase 0a
Incluye, a nivel de producto:
- desktop standalone
- lectura local de bookmarks
- agrupación básica
- Panel A + C
- almacenamiento local cifrado

No incluye:
- móvil
- sync
- Episode Detector real
- Pattern Detector
- Trust Scorer
- LLM local
- Privacy Dashboard completo

### Fase 0b
Incluye, a nivel de producto:
- Share Extension iOS
- captura explícita de URLs
- Session Builder
- Episode Detector dual-mode
- sync cifrada con ACK
- fallback QR
- Privacy Dashboard mínimo
- testing E2E del momento mágico

No incluye:
- FS Watcher
- Pattern Detector
- Trust Scorer
- Explainability Log
- backend propia

### Fase 1
Incluye:
- FS Watcher
- adaptación del Episode Detector
- Panel B con plantillas

### Fase 2
Incluye:
- Pattern Detector
- Trust Scorer
- máquina de estados
- Privacy Dashboard completo
- lógica longitudinal de confianza

### Fase 3
Incluye:
- beta pública
- métricas
- calibración
- LLM local opcional

## Prohibiciones fuertes

- no tratar bookmarks como caso núcleo
- no decir que 0a valida PMF
- no introducir observación activa en desktop durante MVP
- no introducir backend propia en MVP
- no introducir P2P como sync MVP
- no adelantar Pattern Detector o Trust antes de Fase 2
- no convertir LLM local en requisito del sistema

## Error de interpretación a bloquear en este repo

Que los agentes conviertan documentación de contexto en implementación prematura del producto.