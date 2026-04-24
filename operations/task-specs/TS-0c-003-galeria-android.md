# Especificación Operativa — T-0c-003

document_id: TS-0c-003
task_id: T-0c-003
phase: 0c
date: 2026-04-24
status: APROBADO — OD-005 define el scope y el wireframe; sin bloqueantes arquitectónicos
owner_agent: Android Share Intent Specialist
referenced_decisions: D1, D8, D9, D19, D20
referenced_backlog: operations/backlogs/backlog-phase-0c.md (sección T-0c-003)
depends_on:
  - T-0c-001 (get_mobile_resources operativo — datos locales del dispositivo)
  - T-0c-002 (parcial — galería funciona sin T-0c-002; el criterio "recursos del desktop
    aparecen en galería" requiere T-0c-002 completo)
blocks: T-0c-004 (Privacy Dashboard mínimo móvil — depende de galería operativa)
nota_r12: la galería muestra categorías → recursos (Grouper). No implementa ni invoca
          Episode Detector, Pattern Detector ni nada que se parezca a Panel B.
          R12 WATCH activo — declarar explícitamente en código y documentación.

---

## Propósito en Fase 0c

La galería es la primera superficie de valor visible en el móvil: el usuario
puede ver sus recursos capturados organizados por categoría sin abrir el desktop.

Es deliberadamente simple. El valor no está en la complejidad de la UI sino en
que los datos del usuario estén disponibles en su teléfono, organizados,
sin conexión a internet cuando sea necesario.

---

## Declaración Explícita R12

**La galería no implementa Episode Detector, Pattern Detector, Session Builder
ni ningún equivalente funcional.**

La vista "Por categoría" consume la salida del Grouper (T-0c-001 → `get_mobile_resources`).
El Grouper agrupa por categoría asignada por el Classifier. No hay agrupación
temporal, no hay detección de patrones, no hay construcción de sesiones o episodios.

La galería es: categorías → recursos → tap → navegador. Nada más.

---

## Estructura de Pantallas

### Pantalla principal

```
┌─────────────────────────────────────┐
│  FlowWeaver                    [⟳]  │
│                                     │
│  Recientes                          │
│  ├── [ig]  "Eminem – Lose Yourself" │  ← hace 2 min
│  ├── [yt]  "Pizza napolitana"       │  ← hace 1h
│  └── [gh]  "rust-lang/rust"         │  ← hace 3h
│                                     │
│  Por categoría                      │
│  ├── entertainment      8  →        │
│  ├── research          12  →        │
│  ├── shopping           3  →        │
│  └── ...                            │
└─────────────────────────────────────┘
```

- **[⟳]** en el header: icono de estado del sync. Animado si el DriveRelayWorker
  está en ejecución; estático si el último sync fue exitoso; indicador de error
  si el último sync falló (sin red, sin cuenta Drive vinculada).
- **Recientes**: últimos 10 recursos en orden `captured_at` DESC,
  independientemente de categoría. Incluye recursos propios y del desktop vía relay.
- **Por categoría**: lista de categorías con recuento. Solo aparecen categorías
  con al menos un recurso. Ordenadas por recuento DESC.

### Pantalla de categoría

Al tap en una categoría:

```
┌─────────────────────────────────────┐
│  ← entertainment (8)               │
│                                     │
│  [ig]  instagram.com                │
│        "Eminem – Lose Yourself"     │
│        hace 2 min                   │
│                                     │
│  [yt]  youtube.com                  │
│        "Pizza napolitana"           │
│        hace 1h                      │
│  ...                                │
└─────────────────────────────────────┘
```

- Recursos ordenados por `captured_at` DESC (más recientes primero)
- Cada recurso: favicon del dominio + dominio + título descifrado + tiempo relativo
- Tap en recurso: abre URL en el navegador del sistema (Chrome, Firefox o el
  que el usuario tenga por defecto). Sin vista embebida, sin WebView. OD-005.
- El botón `←` navega de vuelta a la pantalla principal

### Estado vacío

```
┌─────────────────────────────────────┐
│  FlowWeaver                         │
│                                     │
│  Comparte algo desde Instagram,     │
│  YouTube o cualquier app para       │
│  empezar.                           │
│                                     │
│  [Cómo compartir →]                 │
└─────────────────────────────────────┘
```

El botón "Cómo compartir" abre una pantalla de onboarding mínima que muestra
los pasos: "1. Abre cualquier enlace · 2. Pulsa Compartir · 3. Elige FlowWeaver".

---

## Fuente de Datos

### Comando Tauri

La galería consume el comando `get_mobile_resources` implementado en T-0c-001:

```typescript
// Llamada desde el frontend Android (TypeScript/React o WebView de Tauri)
const groups: CategoryGroup[] = await invoke('get_mobile_resources');
```

`CategoryGroup`:
```typescript
interface MobileResource {
  uuid: string;
  domain: string;
  category: string;
  title: string;       // descifrado — nunca bytes cifrados al frontend
  captured_at: number; // timestamp Unix ms
}

interface CategoryGroup {
  category: string;
  resources: MobileResource[];
}
```

### Lógica de "Recientes"

Los últimos 10 recursos se obtienen aplanando los `CategoryGroup[]` y ordenando
por `captured_at` DESC, tomando los primeros 10:

```typescript
const recent = groups
  .flatMap(g => g.resources)
  .sort((a, b) => b.captured_at - a.captured_at)
  .slice(0, 10);
```

Este procesamiento ocurre en el frontend — no requiere un nuevo comando Tauri.

### Offline-first

La galería lee de SQLite Android local (via `get_mobile_resources`). No requiere
conexión a internet para mostrar los recursos ya capturados. El sync (T-0c-002)
opera en background y actualiza los datos cuando hay red. D9 operativo —
la galería no introduce ningún proceso de observación activa.

---

## Pull-to-Refresh

Al hacer pull-to-refresh:

1. Se lanza un `OneTimeWorkRequest` del `DriveRelayWorker` (ejecuta un ciclo
   de sync inmediato independiente del período de 15 min)
2. Se muestra el icono [⟳] animado mientras el Worker está activo
3. Al completar, se llama a `get_mobile_resources` y se actualiza la UI

Pull-to-refresh no bloquea la visualización de los datos ya cargados.

---

## Favicon del Dominio

Para cada recurso se muestra un favicon representativo del dominio.

Implementación: la URL estándar de favicon de Google es suficiente para la
gran mayoría de dominios conocidos:

```
https://www.google.com/s2/favicons?domain=<domain>&sz=32
```

**Fallback offline**: si no hay red, se muestra un placeholder genérico
(inicial del dominio en un círculo de color determinístico por hash del dominio).
La galería sigue siendo funcional sin favicons — son decorativos.

El favicon se carga de forma lazy y no bloquea el render de la lista.

---

## Tiempo Relativo

Los timestamps `captured_at` se muestran como tiempo relativo ("hace 2 min",
"hace 1h", "ayer", "hace 3 días"). Implementación con lógica estándar
(no requiere librería externa):

| Delta | Texto |
| --- | --- |
| < 60 s | "hace un momento" |
| < 60 min | "hace N min" |
| < 24 h | "hace Nh" |
| < 7 días | "hace N días" |
| ≥ 7 días | fecha local (dd/mm/aaaa) |

---

## Qué NO Hace Esta Pantalla

| Elemento excluido | Regla |
| --- | --- |
| Búsqueda dentro de la galería | Fase posterior |
| Ordenación manual ni etiquetas | Fase posterior |
| Vista previa de contenido embebido (Reels, videos) | OD-005 prohibición explícita |
| Edición de categoría asignada | Fase posterior |
| Panel B, resumen de categoría, episodios, anticipación | OD-005 prohibición explícita / R12 |
| Pattern Detector para mejorar la galería | D17 / OD-005 — Fase 2 desktop primero |
| Observer activo (polling, Accessibility, FS Watcher) | D9 |

---

## Criterios de Aceptación

Los mismos que el backlog-phase-0c.md más las condiciones de esta TS:

- [ ] la galería muestra todos los recursos capturados agrupados por categoría
      con recuento correcto
- [ ] la sección "Recientes" muestra los últimos 10 recursos en orden cronológico
      inverso, independientemente de categoría
- [ ] al tap en un recurso se abre la URL en el navegador del sistema
- [ ] el título que se muestra está descifrado localmente — no aparece como bytes
- [ ] si el usuario no tiene capturas, se muestra el estado vacío con instrucción
- [ ] pull-to-refresh lanza un ciclo de sync inmediato y actualiza la galería
- [ ] la galería es funcional sin conexión (lee de SQLite local — offline-first)
- [ ] los recursos recibidos del desktop vía relay (T-0c-002) aparecen en la
      galería con el mismo tratamiento que los capturados en móvil
- [ ] el icono [⟳] del header refleja correctamente el estado del DriveRelayWorker
      (en progreso / ok / error)
- [ ] favicon offline: si no hay red, se muestra placeholder sin que la galería
      se rompa ni se quede cargando indefinidamente
- [ ] ningún componente de la galería accede a `resources[].url` directamente —
      solo al campo `title` (descifrado por el backend) y a `domain` (en claro)
- [ ] `tsc --noEmit` limpio sobre los nuevos componentes TypeScript
- [ ] 14/14 tests Rust existentes siguen en verde (la galería es solo frontend;
      no modifica el backend Rust)

---

## Dependencias de Implementación

| Dependencia | Estado | Impacto |
| --- | --- | --- |
| `get_mobile_resources` (T-0c-001) | COMPLETADO | La galería puede implementarse y probarse con datos locales |
| DriveRelayWorker bidireccional (T-0c-002) | EN PROGRESO | Pull-to-refresh y recursos del desktop requieren T-0c-002; la galería puede desarrollarse en paralelo |
| AES-256-GCM en SQLite Android (R-0c-001) | EN RESOLUCIÓN en T-0c-002 | La galería no depende del cifrado — lee el title ya descifrado por el comando |

T-0c-003 puede desarrollarse en paralelo con T-0c-002. El criterio de
aceptación "recursos del desktop aparecen en galería" se verifica en la QA
Review conjunta una vez ambos módulos estén completos.

---

## Riesgos

| Riesgo | Mitigación |
| --- | --- |
| Scope creep: añadir Panel B "para dar más contexto" | R12 WATCH activo — la galería es categorías → recursos, no resumen narrativo |
| Scope creep: añadir búsqueda "porque es fácil" | OD-005 prohíbe features no definidas en el backlog de Fase 0c |
| Favicon de Google no disponible offline | Placeholder determinístico por dominio — galería no depende del favicon para funcionar |
| `get_mobile_resources` lento con muchos recursos | El comando opera sobre SQLite local; aceptable hasta ~10K recursos sin paginación |

---

## Trazabilidad

| Documento | Estado |
| --- | --- |
| OD-005 — scope y wireframe de T-0c-003 | APROBADO |
| backlog-phase-0c.md sección T-0c-003 | REFERENCIA |
| TS-0c-001 (T-0c-001 — get_mobile_resources) | COMPLETADO |
| HO-007 — T-0c-003 abierta | REFERENCIA |
| TS-0c-003 (este documento) | APROBADO |
