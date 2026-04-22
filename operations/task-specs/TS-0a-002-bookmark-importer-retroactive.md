# Especificación Operativa — T-0a-002

owner_agent: Desktop Tauri Shell Specialist
document_id: TS-0a-002
task_id: T-0a-002
phase: 0a
date: 2026-04-22
status: DRAFT — pendiente de revisión por QA Auditor
referenced_backlog: operations/backlogs/backlog-phase-0a.md
referenced_arch_note: operations/architecture-notes/arch-note-phase-0a.md
referenced_decisions: D1 (Privacidad Nivel 1), D9 (Observer MVP), D12 (Foco MVP)
required_review: QA Auditor (D1 y D12)

---

## Propósito En Fase 0a

El Bookmark Importer Retroactive existe en 0a por una razón funcional concreta:
la demo de Fase 0a necesita datos reales del usuario para mostrar que el formato
workspace es comprensible y tiene valor. Sin datos, el workspace es una pantalla
vacía y el gate de 0a no puede cerrarse.

El importer resuelve ese problema de la manera más simple posible: lee bookmarks
que el usuario ya tiene en su máquina, los normaliza y los persiste en SQLCipher
para que el Classifier, el Grouper y los paneles puedan operar.

No genera valor de producto por sí mismo. Su valor es instrumental: permite que
la cadena de módulos de 0a funcione sobre datos reales sin introducir captura
activa, sync ni ningún componente de fases posteriores.

### Por Qué Pertenece A Onboarding Y No Al Caso Núcleo

El caso núcleo del producto es el puente móvil→desktop: capturar URLs en
el móvil mediante Share Extension y entregarlas al desktop en tiempo real para
que el usuario encuentre su workspace preparado. Ese caso pertenece a Fase 0b.

Los bookmarks no son URLs capturadas en el momento de navegación. Son un
historial retrospectivo que el usuario guardó manualmente. Por eso D12 los
define como **bootstrap y cold start**, no como señales del producto.

En la narrativa de producto, los bookmarks son los datos de arranque que
permiten al usuario entender el workspace antes de que el flujo real móvil→
desktop esté disponible. Son el equivalente funcional de los datos de demo:
útiles para validar el formato, no para validar la hipótesis núcleo.

**Cualquier entregable que presente los bookmarks como validación del producto
real debe bloquearse. Esta tarea no valida PMF.**

---

## Alcance Exacto Del Importer En 0a

### Qué Hace

- lee el archivo de bookmarks del navegador desde el filesystem local
  (Safari: `~/Library/Safari/Bookmarks.plist`; Chrome: perfil local; sin red)
- extrae de cada bookmark: URL, título y dominio
- invoca al Classifier (T-0a-003) para que asigne la categoría determinística
- persiste cada recurso normalizado en SQLCipher (T-0a-007) con:
  - URL cifrada (D1)
  - título cifrado (D1)
  - dominio en claro (D1 — nivel de abstracción aceptado)
  - categoría en claro (derivada del dominio por el Classifier; no revela contenido)
- opera como una sola pasada discreta al abrir la app; no monitorea
- no duplica recursos si se ejecuta más de una vez (idempotencia básica por UUID)

### Qué Fuentes Toca En 0a

| Fuente | Estado en 0a | Justificación |
| --- | --- | --- |
| Archivo local de bookmarks Safari | PERMITIDA | Filesystem local, sin red, sin observer |
| Archivo local de bookmarks Chrome | PERMITIDA | Idem |
| Clipboard del sistema | PROHIBIDA | Observer activo — D9 |
| Share Extension iOS | PROHIBIDA | Módulo de 0b — D9 |
| Historial de navegación del browser | PROHIBIDA | No está en scope; distinción con bookmarks |
| Cualquier API de red para enriquecer metadatos | PROHIBIDA | Invariante 2 de arch-note, D6 |
| Accesibilidad o ventanas del sistema | PROHIBIDA | D9 |

### Datos Mínimos Que Necesita

De cada bookmark del archivo local:

| Dato | Obligatorio | Procesamiento |
| --- | --- | --- |
| URL | sí | extraída del archivo; cifrada antes de persistir (D1) |
| Título | sí | extraído del archivo; cifrado antes de persistir (D1) |
| Dominio | derivado de URL | calculado localmente; en claro (D1) |
| Categoría | derivado del dominio | asignada por el Classifier (T-0a-003); en claro |

No se extrae ni se almacena contenido completo de páginas en ningún caso (D1).

### Qué Entrega Al Resto Del Flujo

output: registros en la tabla `resources` de SQLCipher (T-0a-007)

Cada registro entregado tiene el schema mínimo de 0a:
```
id       — clave técnica (INTEGER PRIMARY KEY, D16)
uuid     — identificador portable (TEXT NOT NULL, D16)
url      — URL cifrada (TEXT NOT NULL, D1)
title    — título cifrado (TEXT NOT NULL, D1)
domain   — dominio en claro (TEXT NOT NULL, D1)
category — categoría en claro (TEXT NOT NULL, derivada del Classifier)
```

El Importer no entrega directamente al Grouper ni al Shell. Su output es la
capa de persistencia (SQLCipher). El Grouper lee de SQLCipher cuando el shell
inicia la cadena de presentación.

---

## Qué NO Hace

### Exclusiones Explícitas

| Elemento excluido | Primera fase permitida | Regla que lo bloquea |
| --- | --- | --- |
| Share Extension iOS | 0b | D9: único observer activo = Share Extension |
| Sync de cualquier tipo | 0b | D6 |
| Detección de episodios real (Session Builder) | 0b | arch-note: Session Layer PROHIBIDA |
| Observación continua de nuevos bookmarks | MVP: nunca | D9: el desktop no observa activamente |
| Monitoring de cambios en el archivo de bookmarks | MVP: nunca | D9, invariante 1 de arch-note |
| Captura activa de URLs del navegador en tiempo real | 0b | D9 |
| Panel B (resumen de recursos) | Fase 1 | scope-boundaries, phase-definition |
| Lógica de ventanas temporales de sesión | 0b | Session Builder es de 0b |
| Pattern Detector | Fase 2 | D2, D17 |
| Trust Scorer | Fase 2 | D4 |
| State Machine | Fase 2 | D4 |
| Scraping de contenido completo de páginas | nunca | D1 permanente |
| Llamadas a red de ningún tipo | MVP: prohibidas | invariante 2 de arch-note |
| LLM para enriquecer metadatos | nunca como requisito | D8 |
| Presentarse como "captura activa de la intención del usuario" | siempre | D12, D9 |
| Historial completo del navegador (no solo bookmarks) | fuera de 0a | no en backlog |

### Distinción Crítica: Importer Vs Observer

El Bookmark Importer **no es un observer**. Un observer detecta actividad
del usuario en tiempo real. El Importer lee datos históricos ya guardados.

| Atributo | Bookmark Importer (T-0a-002) | Share Extension Observer (0b) |
| --- | --- | --- |
| Cuándo actúa | Una vez al abrir la app | Cuando el usuario comparte una URL |
| Qué captura | Bookmarks ya guardados manualmente | URL activa en el momento de captura |
| Señal que representa | Historial retrospectivo (bootstrap) | Intención de uso actual |
| Modo | Operación discreta de una pasada | Observer continuo activo |
| Fase | 0a | 0b |
| Valida | Formato workspace | Hipótesis del puente |

Esta distinción debe quedar explícita en cualquier comunicación interna o
documento de 0a que mencione el Importer.

---

## Contrato Con Otros Módulos De 0a

### Con SQLCipher Local Storage (T-0a-007)

El Importer es el único escritor de SQLCipher en 0a. Antes de persistir,
invoca al Classifier para obtener la categoría. Todo campo sensible (URL,
título) se cifra antes del INSERT. El Importer no lee de SQLCipher; solo escribe.

```
Importer (T-0a-002) → [normaliza + clasifica vía T-0a-003] → INSERT en SQLCipher (T-0a-007)
```

Contrato de entrega: cada recurso persiste con el schema mínimo definido en
TS-0a-007. Ningún campo extra. Ningún campo de fases futuras.

### Con Domain/Category Classifier (T-0a-003)

El Importer invoca al Classifier para cada recurso antes de persistirlo.
El Classifier asigna dominio y categoría por reglas determinísticas. Esta
invocación es síncrona y local: sin red, sin LLM, sin bloqueo del INSERT si el
Classifier tardara (D8: si LLM fuera mejora opcional, no debe bloquear el INSERT).

```
recurso normalizado → Classifier (T-0a-003) → recurso con dominio + categoría
```

El Importer no implementa lógica de clasificación propia. Delega íntegramente
en T-0a-003.

### Con Basic Similarity Grouper (T-0a-004)

El Importer no entrega directamente al Grouper. La relación es indirecta:
el Grouper lee de SQLCipher los recursos que el Importer previamente almacenó.
El Importer no conoce ni depende del Grouper; su responsabilidad termina en el
INSERT cifrado.

### Con Desktop Workspace Shell (T-0a-001)

El Shell invoca al Importer como operación discreta al arrancar la app. Esta
invocación es de una sola pasada: el Shell llama al Importer, el Importer
normaliza, clasifica y persiste, y devuelve el control. El Shell no depende del
Importer para renderizar; depende del Grouper y de los paneles. El Importer es
un paso de inicialización, no un proceso continuo.

```
Shell arranca → invoca Importer (T-0a-002) → [normaliza, clasifica, persiste] → Shell continúa
```

---

## Criterios De Aceptación

- [ ] los bookmarks se leen desde el filesystem local sin ninguna llamada de red
- [ ] la operación se ejecuta como una sola pasada discreta al abrir la app;
  no persiste como proceso en background
- [ ] cada recurso persiste en SQLCipher con URL cifrada, título cifrado,
  dominio en claro y categoría en claro (D1)
- [ ] no se almacena contenido completo de páginas en ningún campo (D1)
- [ ] si se ejecuta más de una vez, no duplica recursos ya existentes (UUID)
- [ ] el Importer no inicia ninguna conexión de red en ningún momento del proceso
- [ ] el Importer no usa ninguna API de observación activa (Accessibility, clipboard,
  FS Watcher, etc.)
- [ ] la clasificación de categoría se delega íntegramente al Classifier (T-0a-003);
  el Importer no implementa lógica de clasificación propia
- [ ] el documento no describe los bookmarks como señales de la intención del
  usuario en el sentido de captura activa de 0b (D12)
- [ ] un observador externo que lea este documento entiende que los bookmarks
  son datos de arranque y no el caso de uso núcleo del producto

---

## Señales De Contaminación De Fase Y Riesgos

El Phase Guardian bloqueará o escalará cualquier entregable que contenga estas
señales:

| Señal | Acción | Regla violada |
| --- | --- | --- |
| "el importer observa nuevos bookmarks en tiempo real" | BLOQUEAR | D9, invariante 1 de arch-note |
| "podemos enriquecer las URLs con metadatos desde la red" | BLOQUEAR | invariante 2 de arch-note |
| "los bookmarks demuestran que el flujo móvil→desktop funciona" | ESCALAR | D12, R1 — confusión de 0a con validación de producto |
| "añadimos historial del navegador para mejorar la demo" | BLOQUEAR | fuera de scope; puede violar D1 |
| "dejamos preparado el formato para que sync lo recoja en 0b" | BLOQUEAR | D6; schema mínimo de 0a |
| "el importer puede detectar sesiones de trabajo del usuario" | BLOQUEAR | Session Builder es de 0b; D9 |
| "usamos LLM para enriquecer el título o la categoría antes del INSERT" | ADVERTIR | D8; si bloquea el INSERT, escalar |
| "los bookmarks ya validan que el producto funciona" | ESCALAR | D12, R1 |
| "añadimos más fuentes: historial, pestañas abiertas, recientes" | BLOQUEAR | observer activo; D9 |

### Riesgo Principal: Reinterpretación Como Puente Real

El mayor riesgo de este módulo no es técnico sino narrativo. Si el equipo
o cualquier stakeholder interpreta que "los bookmarks ya demuestran que el
producto funciona", 0a se convierte en una validación de PMF prematura.

Contención operativa:

1. Cualquier texto que describa el Importer debe incluir la aclaración de que
   los bookmarks son bootstrap, no el caso de uso núcleo.
2. El gate de salida de 0a no puede cerrarse si la evidencia de demo usa
   lenguaje de validación de producto ("los usuarios sienten que el sistema
   los conoce", "el flujo demuestra que el puente funciona").
3. El Phase Guardian bloquea cualquier entregable de 0a que derive de esta
   interpretación.

---

## Handoff Esperado

1. Desktop Tauri Shell Specialist produce este documento (completado).
2. QA Auditor revisa cumplimiento de D1 y D12 y confirma que el documento
   no viola las restricciones de observación activa (D9) ni introduce datos
   de fases futuras.
3. Si hay correcciones, vuelve al Desktop Tauri Shell Specialist antes de cerrar.
4. Tras aprobación: Desktop Tauri Shell Specialist produce **TS-0a-003**
   (Domain/Category Classifier), siguiente en la cadena de dependencias
   marcada por HO-002.

Cadena pendiente tras este documento:

```
TS-0a-002 [este documento] → TS-0a-003 → TS-0a-004 → TS-0a-005 + TS-0a-006
```

---

## Nota De Gobernanza

Esta especificación no autoriza implementación en el repo de producto.
Define el contrato documental que la implementación debe respetar cuando el
equipo construya el Bookmark Importer en el contexto de la demo de 0a.

El Importer es un mecanismo de inicialización de datos para la demo. No es
un módulo de producto en producción. Su existencia en el repo de producto
debe etiquetarse siempre como "bootstrap de demo", no como funcionalidad núcleo.
