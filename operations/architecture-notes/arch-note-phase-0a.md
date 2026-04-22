# Nota De Límites De Arquitectura — Fase 0a

date: 2026-04-22
owner_agent: Technical Architect
phase: 0a
status: APPROVED — primer ciclo operativo
referenced_decision: OD-001

---

## Capas Activas Y Prohibidas En Fase 0a

| Capa | Estado | Rol en 0a |
| --- | --- | --- |
| Bootstrap Import Layer | ACTIVA | Única fuente de recursos. Import local de bookmarks. No es observer. |
| Workspace Layer | ACTIVA | Panel A + Panel C. Contenedor de presentación. |
| Capture Layer | PROHIBIDA | No hay Share Extension ni observer activo de ningún tipo. |
| Session Layer | PROHIBIDA | No hay Session Builder. No hay ventanas temporales de sesión. |
| Detection Layer | PROHIBIDA | No hay Episode Detector real. El Grouper de 0a es distinto y más simple. |
| Sync Layer | PROHIBIDA | No hay sync de ningún tipo (iCloud, Google Drive, QR, LAN, P2P). |
| Privacy And Control Layer | PROHIBIDA | No hay Privacy Dashboard en 0a. |
| Longitudinal Intelligence Layer | PROHIBIDA | No hay Pattern Detector, Trust Scorer, State Machine ni Explainability Log. |

---

## Módulos Activos En Fase 0a

| Módulo | Estado | Owner documental | Restricción dura |
| --- | --- | --- | --- |
| Desktop Workspace Shell | ACTIVO | Desktop Tauri Shell Specialist | Sin network. Sin observer. Sin background. |
| Bookmark Importer Retroactive | ACTIVO | Desktop Tauri Shell Specialist | Solo bootstrap. No es observer. No es caso núcleo. |
| Domain/Category Classifier | ACTIVO | Desktop Tauri Shell Specialist | Determinístico. Sin red. Sin LLM. Sin aprendizaje. |
| Basic Similarity Grouper | ACTIVO | Desktop Tauri Shell Specialist | Heurística simple. Distinto del Episode Detector. |
| Panel A | ACTIVO | Desktop Tauri Shell Specialist | Recursos agrupados. Sin resumen (Panel B). Sin red. |
| Panel C | ACTIVO | Desktop Tauri Shell Specialist | Plantillas como baseline. LLM no es requisito (D8). |
| SQLCipher Local Storage | ACTIVO | Technical Architect | D1 + D16. Schema mínimo de 0a. Sin tablas futuras. |

---

## Módulos Prohibidos En Fase 0a

| Módulo | Primera fase permitida | Regla que lo bloquea |
| --- | --- | --- |
| Share Extension iOS | 0b | D9: único observer activo = Share Extension iOS, que entra en 0b. |
| Session Builder | 0b | No hay señales de captura activa en 0a. |
| Episode Detector Dual-Mode | 0b | D2: el detector dual-mode entra en 0b. |
| Sync Relay MVP | 0b | D6: sync MVP entra en 0b. |
| Privacy Dashboard mínimo | 0b | D14: mínimo en 0b, completo en Fase 2. |
| Panel B | Fase 1 | scope-boundaries.md, phase-definition.md (clausurado en primer ciclo). |
| FS Watcher | Fase 1 | D9 + scope-boundaries.md. |
| Pattern Detector | Fase 2 | D2, D17. |
| Trust Scorer | Fase 2 | D4. |
| State Machine | Fase 2 | D4. |
| Explainability Log | Fase 2 | D14. |
| LLM local (como requisito) | nunca como requisito | D8: plantillas son baseline; LLM es mejora opcional. |

---

## Contratos De Módulo Activos

### Desktop Workspace Shell

input: recursos agrupados (del Grouper)
output: ventana Tauri con Panel A + Panel C renderizados
restricciones duras:
- sin conexión de red iniciada por la app
- sin proceso de observación activa
- sin background watcher de ningún tipo
- sin Panel B
- sin Share Extension
- sin sync

---

### Bookmark Importer Retroactive

input: archivo local de bookmarks (Safari o Chrome)
output: recursos normalizados almacenados en SQLCipher
  [URL cifrada, título cifrado, dominio en claro, categoría]
restricciones duras:
- sin scraping de contenido completo de páginas (D1)
- sin llamadas a red
- operación discreta; no monitoring continuo (D9)
- los bookmarks son datos de arranque, no señales de captura (D12)

---

### Domain/Category Classifier

input: recursos normalizados del Importer
output: recursos con dominio y categoría asignados por reglas determinísticas
restricciones duras:
- sin red
- sin LLM
- sin aprendizaje longitudinal
- sin ventanas temporales
- clasificación determinística: mismo input → mismo output
- no es el Episode Detector de 0b (ver diferenciación abajo)

---

### Basic Similarity Grouper

input: recursos clasificados (con dominio y categoría)
output: clusters de recursos [dominio, categoría, sub-agrupación por título]
restricciones duras:
- heurística simple sobre título (no Jaccard del Episode Detector preciso)
- sin clustering semántico con embeddings o LLM
- sin ventanas temporales de sesión (Session Builder es de 0b)
- no es el Episode Detector dual-mode de 0b (ver diferenciación abajo)

---

### Panel A

input: clusters del Grouper
output: lista visual de recursos agrupados [título, favicon, dominio, subtema]
restricciones duras:
- sin resumen de contenido (Panel B — Fase 1)
- sin red
- sin LLM

---

### Panel C

input: clusters + tipo de contenido (del Classifier)
output: checklist de 3-5 acciones por plantilla según tipo de contenido
restricciones duras:
- baseline siempre por plantilla, sin LLM (D8)
- LLM es mejora opcional solo si el hardware lo permite y no añade latencia
- sin dependencia de Panel B para funcionar

---

### SQLCipher Local Storage

input: recursos del Importer
output: persistencia cifrada local

schema mínimo de 0a:
```
resources (
  id       INTEGER PRIMARY KEY,
  uuid     TEXT NOT NULL,          -- indexado
  url      TEXT NOT NULL,          -- cifrado (D1)
  title    TEXT NOT NULL,          -- cifrado (D1)
  domain   TEXT NOT NULL,          -- en claro (D1)
  category TEXT NOT NULL
)
```

restricciones duras:
- sin contenido completo de páginas (D1)
- sin tablas de sesiones, episodios, patrones o trust score
- INTEGER PRIMARY KEY + UUID indexado (D16)
- Privacy Level 1: solo URL, título, metadatos (D1)

---

## Diferenciación Crítica: Grouper 0a vs Episode Detector 0b

Esta distinción debe quedar explícita en todos los entregables de 0a porque
su confusión es el principal riesgo de contaminación de fase detectado (R10).

| Atributo | Grouper 0a | Episode Detector Dual-Mode 0b |
| --- | --- | --- |
| Función | Agrupar recursos para la demo | Detectar episodio accionable |
| Input | Bookmarks importados (locales) | Señales capturadas por Share Extension |
| Ventana temporal | No aplica | Menos de 24 horas |
| Algoritmo | Heurística simple sobre título | Precise mode (Jaccard + ecosistemas) + Broad mode (categoría) |
| Modo dual | No existe | Sí: precise + broad fallback (D3) |
| Output | Clusters para Panel A | Episodio accionable o no accionable |
| Fase | 0a | 0b |
| Owner documental | Desktop Tauri Shell Specialist | Session & Episode Engine Specialist |

---

## Invariantes Arquitectónicas De Fase 0a

Estas invariantes no pueden violarse en ningún entregable de 0a:

1. El desktop no observa activamente en ningún momento (D9).
2. No se inicia ninguna conexión de red desde la app.
3. La única fuente de datos es el import local de bookmarks.
4. El LLM no es requisito funcional en ningún componente (D8).
5. Panel B no existe en 0a (scope-boundaries + phase-definition).
6. El schema de SQLCipher no incluye tablas de 0b ni de fases posteriores.
7. El Grouper de 0a no es el Episode Detector dual-mode de 0b.
8. Ningún componente de 0a se presenta como validación del puente móvil→desktop.
9. Los bookmarks se presentan siempre como bootstrap y cold start, nunca como
   caso núcleo del producto (D12).

---

## Señales De Contaminación De Fase A Vigilar

Las siguientes formulaciones deben bloquearse o escalarse al Phase Guardian:

| Señal | Regla violada | Acción |
| --- | --- | --- |
| "añadir un endpoint por si acaso" | D6, D9 | bloquear: no hay sync en 0a |
| "el Grouper podría usar Jaccard" | D3, R10 | escalar a Phase Guardian |
| "Panel B mejora la demo de 0a" | scope-boundaries, phase-definition | bloquear: Panel B es Fase 1 |
| "podríamos observar nuevos bookmarks en tiempo real" | D9 | bloquear: observer activo prohibido en MVP |
| "dejamos el schema preparado para el sync" | D6, D16 | bloquear: schema de 0a es mínimo |
| "el LLM mejora mucho las sugerencias de Panel C" | D8 | advertir: LLM es opcional; plantilla debe funcionar sola |
| "los bookmarks ya demuestran que el producto funciona" | D12, R1 | escalar: eso es PMF prematuro |
