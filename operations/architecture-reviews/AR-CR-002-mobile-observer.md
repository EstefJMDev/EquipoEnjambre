# Revisión Arquitectónica — Observer Semi-Pasivo Android (CR-002)

```
document_id: AR-CR-002-mobile-observer
owner_agent: Technical Architect
phase: 2 (track paralelo Android)
date: 2026-04-27
status: APROBADO CON CONDICIONES — decisión sobre mecanismo emitida; extensión de D9
        requerida antes de implementar; delegación a Privacy Guardian para verificación
        de constraints de privacidad (ver PGR-CR-002-mobile-observer.md)
precede_a: extensión formal de D9 + kickoff de implementación del observer mobile
documents_reviewed:
  - Project-docs/decisions-log.md (D1, D4, D5, D8, D9, D14, D17, D19, D22)
  - Project-docs/architecture-overview.md
  - Project-docs/module-map.md
  - Project-docs/scope-boundaries.md
  - operations/architecture-reviews/AR-2-003-pattern-detector-review.md
  - src-tauri/src/session_builder.rs (GAP_SECS = 10_800, MAX_WINDOW_SECS = 86_400)
  - src-tauri/src/episode_detector.rs (PRECISE_MIN = 3, JACCARD_THRESHOLD = 0.20)
reference_normativo:
  - Project-docs/decisions-log.md (D1, D8, D9, D22)
  - operations/orchestration-decisions/OD-004-phase-2-activation.md
  - CR-002 (aprobado en intención por Orchestrator 2026-04-24)
  - operations/architecture-reviews/PGR-CR-002-mobile-observer.md
```

---

## Objetivo de Esta Revisión

CR-002, aprobado en intención por el Orchestrator (2026-04-24), autoriza el concepto
de observer semi-pasivo en Android como tier paid de FlowWeaver Mobile. Antes de que
ningún implementador toque código, el Technical Architect debe resolver cuatro preguntas
abiertas que CR-002 dejó sin especificar:

1. Qué mecanismo concreto implementa el observer (Opción C — Intent handler vs Tile de sesión).
2. Cuáles son los umbrales correctos del Episode Detector en mobile (GAP_SECS, PRECISE_MIN, modo dominante).
3. Si se necesita foreground service y bajo qué condiciones.
4. Cómo se articula el observer mobile con los módulos Rust existentes (Episode Detector,
   Pattern Detector, Trust Scorer, State Machine).

Esta AR también produce la redacción exacta de la extensión que D9 requiere para
autorizar el mecanismo elegido.

---

## 1. Decisión sobre Mecanismo — Tile de Sesión

### Veredicto

**El observer mobile usará el mecanismo Tile de sesión (Quick Settings tile de Android).**
La Opción C (Intent handler como mecanismo único y continuo, siempre registrado en el
sistema) queda descartada. La Opción C puede ser el sustrato técnico del Tile, pero solo
si el handler se registra dinámicamente al activar el Tile y se desregistra al desactivarlo.

### Evaluación comparativa

| Dimensión | Opción C pura (handler siempre registrado) | Tile de sesión |
|---|---|---|
| Gesto de activación | Acción de compartir URL (consciente pero puntual) | Activar/desactivar tile en Quick Settings (consciente y explícito) |
| Período de observación | Indefinido (el handler está siempre en el sistema) | Acotado: el usuario decide cuándo empieza y cuándo termina |
| Foreground service | Sí, continuo | Solo durante sesión activa |
| Control de privacidad | Bajo — no hay señal visual de "modo captura" | Alto — tile visible en Quick Settings en todo momento |
| Compatibilidad con D9 (extensión) | Requiere extensión que autorice observación continua | Extensión más acotada: sesión activa = tile ON |
| Narrativa verificable | "La app registra mis shares siempre" | "La app observa mientras yo la activo" — verificable |
| Compatibilidad con D22 | Compatible | Compatible — y más vendible como feature de control |
| Riesgo de sobrecaptura | Alto (captura URLs sensibles fuera del contexto de intención) | Reducido (ventana acotada por decisión explícita del usuario) |

### Justificación arquitectónica

**La narrativa de privacidad verificable es el criterio arquitectónico prioritario.**
D1 establece que la narrativa es "verificable, no radical". Un Intent handler siempre
registrado no permite que el usuario vea en todo momento si la app está o no observando.
El Tile ofrece una señal visual persistente en Quick Settings que el usuario puede leer
y controlar. Esto es superiormente verificable.

**La Opción C no queda rechazada como mecanismo de captura puntual** (capturar una URL
vía share sigue siendo el tier free). Lo que se descarta es el handler registrado
permanentemente como mecanismo de sesión del tier paid. El handler puede ser el
mecanismo técnico interno del Tile si y solo si opera de forma dinámica (registrado al
activar el tile, desregistrado al desactivarlo).

**Opciones rechazadas permanentemente (reconfirmación):** Accessibility Service y acceso
a historial del navegador. Esta AR no los reconsideró.

---

## 2. Umbrales del Episode Detector en Mobile

### Problema con los valores desktop actuales

Los valores actuales en `session_builder.rs` y `episode_detector.rs`:

```rust
// session_builder.rs
const GAP_SECS: i64 = 10_800;         // 3 horas — umbral de sesión desktop
const MAX_WINDOW_SECS: i64 = 86_400;  // 24 horas — ventana máxima desktop

// episode_detector.rs
const PRECISE_MIN: usize = 3;          // mínimo recursos para modo preciso
```

Son correctos para desktop. En mobile el patrón de uso es radicalmente distinto:
el usuario navega en ráfagas cortas durante la sesión del tile; una pausa de 3 horas
no indica continuidad de la misma sesión de intención.

### Umbrales aprobados para mobile

| Parámetro | Valor desktop | Valor mobile aprobado | Justificación |
|---|---|---|---|
| `GAP_SECS` | 10_800 (3 h) | **2_700 (45 min)** | En mobile, 45 min sin capturas indica abandono de la sesión de navegación. Dentro del rango razonable [30-60 min]. |
| `MAX_WINDOW_SECS` | 86_400 (24 h) | **7_200 (2 h)** | Una sesión de intención mobile raramente supera 2 horas. Actúa como guardia ante tiles olvidados (junto al timeout de Privacy Guardian — ver PGR-CR-002, C5). |
| `PRECISE_MIN` | 3 | **2** | En mobile, el usuario puede compartir 2-3 URLs coherentes en 15 minutos. Bajar a 2 hace viable el modo preciso en sesiones cortas sin sacrificar coherencia: `JACCARD_THRESHOLD = 0.20` sigue filtrando pares no coherentes. |
| `BROAD_MIN` | 3 | **2** | Coherente con `PRECISE_MIN` mobile. |
| `JACCARD_THRESHOLD` | 0.20 | **0.20** (sin cambio) | El threshold de coherencia es correcto en ambos contextos. |
| Modo dominante | Preciso con ≥ 3 recursos; broad como fallback | **Broad como modo primario en sesiones cortas (< 3 capturas); preciso con ≥ 3** | Sesiones de 2 URLs del mismo dominio son frecuentes en mobile y son episodios válidos de intención. |

### Implicación arquitectónica — módulo separado obligatorio

El Episode Detector mobile **NO es una modificación de `episode_detector.rs` desktop**.
Debe ser un módulo separado (`episode_detector_mobile.rs` o configuración parametrizada)
compilado para Android con sus propios umbrales. Los módulos desktop y mobile no pueden
compartir constantes ni lógica condicional de plataforma dentro de `episode_detector.rs`.

El implementador debe declarar explícitamente esta separación en el Task Spec antes de
tocar código. La AR de revisión post-implementación verificará que no hay
`#[cfg(target_os = "android")]` en `episode_detector.rs` desktop.

---

## 3. Foreground Service — Decisión

### Veredicto

**El foreground service es necesario durante la sesión activa del tile, y solo durante ella.**

| Estado del tile | Foreground service | Razón |
|---|---|---|
| Tile OFF | No activo | Sin sesión. La app no observa nada. |
| Tile ON (sesión activa) | Sí, obligatorio | Android puede terminar procesos en background sin aviso. El foreground service es el único mecanismo que garantiza continuidad de captura durante la sesión. La notificación actúa también como señal de privacidad visible. |
| Tile apagado por timeout (GAP_SECS o MAX_WINDOW_SECS) | El servicio se termina | El timeout cierra la sesión. Nada queda en background. |

### Constraints de la notificación del foreground service (no negociables)

- Debe indicar que FlowWeaver está en modo de captura activa.
- Debe incluir acción de cierre de sesión directamente accesible sin necesidad de abrir la app.
- No puede ocultarse ni reducirse a notificación silenciosa.
- Debe mostrar el tiempo transcurrido de la sesión activa.

Su cumplimiento se delega al Privacy Guardian para verificación en QA
(ver PGR-CR-002-mobile-observer.md, Control C3).

---

## 4. Relación con Módulos Existentes

### Flujo del observer mobile

```
Usuario activa tile (Quick Settings)
         │
         ▼
[TileService Android] ── inicia ──► [Foreground Service + notificación visible]
         │
         ▼  (tile ON — sesión activa)
Usuario navega; el handler dinámico recibe ACTION_SEND o portapapeles
         │
         ▼
[Observer Mobile — Capture Layer]
  · Extrae url (→ cifrada, D1), domain (→ en claro), category (→ en claro)
  · Cifrado en RAM ≤ 500 ms antes de persistir (control C4 del Privacy Guardian)
  · Emite raw_event con timestamp
         │
         ▼
[Session Builder Mobile]
  · GAP_SECS = 2_700 (45 min), MAX_WINDOW_SECS = 7_200 (2 h)
  · Agrupa raw_events de la sesión activa del tile
         │
         ▼
[Episode Detector Mobile — módulo separado]
  · PRECISE_MIN = 2, BROAD_MIN = 2, JACCARD_THRESHOLD = 0.20
  · Modo broad primario para sesiones < 3 capturas
  · Declara en cabecera distinción con Pattern Detector (R12 aplicada a mobile)
         │
         ▼
[Pattern Detector — compilado para Android via NDK sin cambios]
  · Lee domain, category, captured_at de SQLCipher Android (D1)
  · Produce Vec<DetectedPattern> — mismo contrato que desktop
         │
         ▼
[Trust Scorer — compilado para Android via NDK sin cambios]
  · Produce Vec<TrustScore> — mismo contrato que desktop
         │
         ▼
[State Machine — compilado para Android via NDK sin cambios]
  · Produce TrustState — mismo contrato que desktop
         │
         ▼
[Privacy Dashboard Mobile] ── renderiza TrustState + Vec<DetectedPattern>
         │
         ▼
[Notificación de anticipación] ── solo si TrustState = Trusted / Autonomous
```

### Contratos entre módulos mobile

| Módulo emisor | Tipo producido | Módulo receptor | Cambio de lógica |
|---|---|---|---|
| Observer mobile (TileService) | `RawEvent { url_encrypted, domain, category, captured_at }` | Session Builder mobile | Ninguno — mismo contrato que raw_event Android existente |
| Session Builder mobile | `Session { resources: Vec<SessionResource> }` | Episode Detector mobile | Ninguno en contrato; sí en umbrales (sección 2) |
| Pattern Detector (NDK) | `Vec<DetectedPattern>` | Trust Scorer (NDK) | Ninguno — misma interfaz que desktop |
| Trust Scorer (NDK) | `Vec<TrustScore>` | State Machine (NDK) | Ninguno — misma interfaz que desktop |
| State Machine (NDK) | `TrustState` | Privacy Dashboard mobile | Ninguno — mismo contrato que desktop |

### Aclaración R12 aplicada a mobile

El Pattern Detector Android **no recibe Episodes como input directo**. Lee `domain`,
`category` y `captured_at` de SQLCipher Android, exactamente como en desktop. Los
Episodes del Episode Detector mobile alimentan la experiencia inmediata de agrupación
visible al usuario; el Pattern Detector consume el historial longitudinal acumulado en
SQLCipher Android. Esta distinción debe declararse explícitamente en el comentario de
cabecera del Episode Detector mobile.

---

## 5. Extensión Requerida de D9

### Redacción actual de D9

> D9 | Observer MVP | Único observer activo: Share Intent Android (primario); Share
> Extension iOS (track paralelo secundario). Desktop no observa en MVP.

### Extensión aprobada por esta AR

La siguiente redacción debe añadirse a la entrada D9 en `decisions-log.md`,
precedida por la nota de extensión:

---

**[EXTENSIÓN — aprobada por AR-CR-002-mobile-observer + PGR-CR-002-mobile-observer, 2026-04-27]**

**Observer semi-pasivo Android (tier paid):** Además del Share Intent (que permanece
como mecanismo free), el tier paid autoriza un segundo observer en Android basado en
**Tile de sesión (Quick Settings tile)**. El observer semi-pasivo solo está activo
mientras el tile esté encendido (sesión explícitamente iniciada por el usuario). Requiere
foreground service con notificación visible durante la sesión activa. El foreground
service se termina automáticamente al apagar el tile o al superar los timeouts de sesión
mobile (`GAP_SECS = 2_700 s`, `MAX_WINDOW_SECS = 7_200 s`). El observer NO puede
funcionar en background sin que el usuario haya activado la sesión explícitamente
mediante el tile. Si el mecanismo técnico subyacente es un Intent handler (Opción C),
el handler debe registrarse dinámicamente al activar el tile y desregistrarse al
desactivarlo — nunca declarado estáticamente en AndroidManifest sin control de
activación. Opciones permanentemente excluidas: Accessibility Service, historial del
navegador, Intent handler siempre registrado sin control de inicio/fin de sesión.
Referencia: AR-CR-002-mobile-observer.md, PGR-CR-002-mobile-observer.md.

---

### Condiciones previas a actualizar D9

1. El Orchestrator aprueba esta AR.
2. El Context Guardian actualiza `decisions-log.md` con la extensión exacta.
3. Solo tras el commit de D9 actualizado puede el implementador iniciar el Task Spec
   del observer mobile.

---

## 6. Constraints de Privacidad (delegados al Privacy Guardian)

Los siguientes constraints son no negociables. Verificación delegada al Privacy Guardian
(PGR-CR-002-mobile-observer.md) durante QA antes de Fase 3.

| ID | Constraint | Verificación |
|---|---|---|
| PV-M-001 | D1: url y title siempre cifrados. Solo domain y category en claro en SQLCipher Android. | Auditoría de queries SQLCipher Android. Test estructural equivalente al D1 de desktop. |
| PV-M-002 | Con tile OFF, no se produce ningún raw_event aunque el usuario envíe ACTION_SEND. | Test: verificar tabla `resources` en SQLCipher Android con tile OFF antes y después de ACTION_SEND. |
| PV-M-003 | Notificación del foreground service visible, persistente, con acción de cierre de sesión directamente accesible. | Inspección en dispositivo + test de cierre desde notificación. |
| PV-M-004 | El foreground service no se reanuda automáticamente si el usuario lo termina desde la notificación. | Test: terminar desde notificación → reiniciar dispositivo → verificar sin servicio activo. |
| PV-M-005 | El observer es tier paid. Con suscripción inactiva, el tile muestra paywall, no inicia sesión. | Test: sin suscripción → intentar activar tile → paywall, cero raw_events. |
| PV-M-006 | El Privacy Dashboard mobile incluye sección de observación: estado, capturas por sesión, historial de activaciones, botón de purga. | Criterio de aceptación de TS de Privacy Dashboard mobile. |
| PV-M-007 | No se almacena contenido completo de páginas. Solo url (cifrada), domain, category, captured_at. | Auditoría del contrato RawEvent. |

---

## 7. Riesgos Conocidos

| ID | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| R-M-001 | Tile olvidado activo indefinidamente. | Alta | Medio | `MAX_WINDOW_SECS = 7_200 s`. Notificación con tiempo transcurrido. Timeout configurable (PGR C5: default 30 min). |
| R-M-002 | Android OEM mata el foreground service (EMUI, MIUI). | Media-alta | Alto | Documentar limitación en onboarding. `onTaskRemoved` para cierre limpio. Narrativa: "captura las URLs que el sistema permite". |
| R-M-003 | El tile visible en Quick Settings percibido como vigilancia aunque esté OFF. | Baja | Medio | El tile debe estar invisible hasta que el usuario lo añada explícitamente. Onboarding requerido. |
| R-M-004 | Coherencia baja con PRECISE_MIN = 2 (episodios de baja calidad). | Medio | Bajo | `JACCARD_THRESHOLD = 0.20` operativo. Modo broad como seguridad. Pattern Detector absorbe ruido con `min_frequency ≥ 3`. |
| R-M-005 | El implementador reutiliza `episode_detector.rs` con parámetros modificados. | Medio | Alto | Task Spec declara: módulo mobile separado obligatorio. AR post-implementación verifica ausencia de `#[cfg(target_os = "android")]` en desktop. |
| R-M-006 | Pattern Detector NDK no validado en dispositivo real. | Alta (primera compilación) | Alto | Criterio de aceptación AC-7: `cargo test --target aarch64-linux-android` pasa antes de declarar implementación completa. |
| R-M-007 | Verificación de suscripción introduce llamada de red en flujo de activación del tile. | Medio | Medio | Estado de suscripción cacheado en SQLCipher Android. Validación con proveedor de pagos en background, no bloqueando el tile. |

---

## 8. Criterios de Aceptación

| # | Criterio | Verificable |
|---|---|---|
| AC-1 | Tile activa/desactiva la sesión. Con tile OFF, ACTION_SEND no produce raw_event. | Test en SQLCipher Android antes/después de ACTION_SEND con tile OFF. |
| AC-2 | Foreground service inicia con tile ON y termina con tile OFF o por `MAX_WINDOW_SECS`. | Test: activar tile → verificar notificación → timeout → verificar servicio terminado. |
| AC-3 | Notificación incluye acción de cierre de sesión. Cierre desde notificación apaga el tile. | Test en dispositivo: cierre desde notificación → tile OFF + sin servicio activo. |
| AC-4 | Session Builder mobile usa `GAP_SECS = 2_700` y `MAX_WINDOW_SECS = 7_200`. | Test unitario: capturas con gap > 2_700 s → dos sesiones distintas. |
| AC-5 | Episode Detector mobile usa `PRECISE_MIN = 2`, `BROAD_MIN = 2`. Con 2 URLs misma categoría → episodio en modo Broad. | Test unitario: 2 recursos, misma categoría → `Vec<Episode>` con 1 episodio Broad. |
| AC-6 | Sin condicionales de plataforma en `episode_detector.rs` desktop. | `cargo check` desktop: cero `#[cfg(target_os = "android")]` en `episode_detector.rs`. |
| AC-7 | Pattern Detector compilado para aarch64-linux-android pasa sus tests sin modificar `pattern_detector.rs`. | `cargo test --target aarch64-linux-android` — tests de T-2-001 pasan sin regresiones. |
| AC-8 | Ninguna query SQLCipher Android accede a `url` o `title` en claro (D1). | Test estructural equivalente al D1-guard de desktop. |
| AC-9 | Con suscripción inactiva, el tile muestra paywall y no inicia foreground service. | Test: sin suscripción → activar tile → paywall, cero raw_events. |
| AC-10 | Episode Detector mobile declara en cabecera distinción con Episode Detector desktop y con Pattern Detector (R12 aplicada a mobile). Tabla comparativa mínima de tres dimensiones. | Inspección de cabecera del módulo. |
| AC-11 | `cargo test` (suite desktop completa) sin regresiones. | 0 regresiones en tests desktop existentes. |
| AC-12 | `npx tsc --noEmit` limpio en frontend Android. | Confirmación del implementador antes de declarar implementación completa. |

---

## Correcciones Previas a Implementación

**Ninguna corrección al código existente.** Los módulos desktop (`episode_detector.rs`,
`session_builder.rs`, `pattern_detector.rs`, `trust_scorer.rs`, `state_machine.rs`)
no se tocan. Las condiciones de esta AR son:

1. El Context Guardian actualiza `decisions-log.md` con la extensión de D9 (sección 5).
2. El Orchestrator aprueba formalmente esta AR.
3. El Technical Architect emite el Task Spec del observer mobile que incluye la
   declaración de módulo mobile separado y los criterios AC-1 a AC-12.

---

## Siguiente Agente Responsable

**Orchestrator** — aprobación de esta AR y orden de actualización de D9 al Context Guardian.

**Context Guardian** — actualización de `decisions-log.md` con la extensión de D9.

**Technical Architect** — drafting del Task Spec de implementación del observer mobile
(track paralelo Android, separado de la cadena T-2-001..T-2-004 del desktop).

La implementación queda bloqueada hasta que D9 esté formalmente actualizado y el
Task Spec aprobado.

---

## Trazabilidad

| Acción | Archivo | Estado |
|---|---|---|
| Revisado | Project-docs/decisions-log.md | LEÍDO — extensión de D9 pendiente de commit |
| Revisado | Project-docs/architecture-overview.md | LEÍDO |
| Revisado | Project-docs/module-map.md | LEÍDO |
| Revisado | Project-docs/scope-boundaries.md | LEÍDO |
| Revisado | src-tauri/src/session_builder.rs | LEÍDO — umbrales desktop documentados |
| Revisado | src-tauri/src/episode_detector.rs | LEÍDO — PRECISE_MIN y JACCARD_THRESHOLD documentados |
| Revisado | operations/architecture-reviews/AR-2-003-pattern-detector-review.md | REFERENCIA de formato |
| Revisado | operations/architecture-reviews/PGR-CR-002-mobile-observer.md | LEÍDO — condiciones de privacidad incorporadas |
| Creado | operations/architecture-reviews/AR-CR-002-mobile-observer.md | este documento |

---

## Firma

```
approved_by: Technical Architect
approval_date: 2026-04-27
status_detail: |
  APROBADO CON CONDICIONES. Mecanismo elegido: Tile de sesión (el handler puede ser
  el sustrato técnico solo si opera dinámicamente — registrado al activar el tile,
  desregistrado al desactivarlo). Foreground service autorizado solo durante sesión
  activa con notificación visible obligatoria. Umbrales mobile aprobados:
  GAP_SECS=2_700, MAX_WINDOW_SECS=7_200, PRECISE_MIN=2, BROAD_MIN=2,
  JACCARD_THRESHOLD=0.20 sin cambio. Modo broad primario en sesiones < 3 capturas.
  Módulo Episode Detector mobile separado obligatorio — cero condicionales de
  plataforma en episode_detector.rs desktop. Pattern Detector, Trust Scorer y State
  Machine compilados para Android via NDK sin modificación de lógica Rust. Extensión
  de D9 redactada en sección 5 — pendiente de commit por Context Guardian tras
  aprobación del Orchestrator. 12 criterios de aceptación emitidos. Constraints de
  privacidad PV-M-001 a PV-M-007 delegados al Privacy Guardian. Implementación
  bloqueada hasta D9 actualizado y Task Spec aprobado.
```
