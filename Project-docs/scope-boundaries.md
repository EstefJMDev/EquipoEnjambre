# FlowWeaver — Scope Boundaries

## Regla principal

El proyecto debe proteger el foco del MVP.
El caso de uso núcleo es exclusivamente el puente móvil → desktop.

## In-scope por fase

### Fase 0a

Incluye:

* app desktop Tauri mínima
* lectura local de bookmarks Safari/Chrome
* clasificación por dominio/categoría
* agrupación por similitud básica
* Workspace UI con Panel A + Panel C
* SQLCipher para almacenamiento local
* demostración de valor del contenedor workspace

No incluye:

* móvil
* Share Extension
* sync
* Episode Detector real
* Pattern Detector
* Trust Scorer
* LLM local
* Privacy Dashboard completo
* validación de PMF

### Fase 0b

Incluye:

* Share Extension iOS
* captura explícita de URLs
* Session Builder
* Episode Detector dual-mode
* sync iCloud/Google Drive relay cifrado con ACK, retries e idempotencia
* fallback QR manual
* Privacy Dashboard mínimo
* testing E2E del momento mágico

No incluye:

* FS Watcher
* Pattern Detector
* Trust Scorer
* Explainability Log
* Privacy Dashboard completo
* backend propia

### Fase 1

Incluye:

* FS Watcher `~/Downloads`
* organización de descargas/screenshots
* adaptación del Episode Detector
* Panel B con plantillas

### Fase 2

Incluye:

* Pattern Detector
* Trust Scorer
* máquina de estados
* Privacy Dashboard completo
* lógica longitudinal de confianza

### Fase 3

Incluye:

* beta pública
* métricas
* calibración de umbrales
* LLM local opcional si aporta valor sin romper latencia o hardware

## Prohibiciones fuertes

* no tratar bookmarks como caso núcleo del producto
* no decir que Fase 0a valida PMF
* no introducir observación activa en desktop durante MVP
* no introducir backend propia en MVP
* no introducir P2P como sync MVP
* no adelantar Pattern Detector o Trust antes de Fase 2
* no convertir LLM local en requisito del sistema

## Errores de interpretación que deben evitarse

1. Pensar que 0a ya valida el producto completo
   Incorrecto: 0a valida solo el valor del formato workspace.

2. Pensar que bookmarks retroactivos son el centro del producto
   Incorrecto: son onboarding y cold start.

3. Pensar que si sync falla se puede rediseñar el producto
   Incorrecto: primero deben explorarse fallbacks compatibles.

4. Pensar que broad mode sustituye el valor del precise mode
   Incorrecto: broad mantiene utilidad, pero el wow depende del precise.

5. Pensar que el LLM define el valor central
   Incorrecto: el baseline funcional es con plantillas.
