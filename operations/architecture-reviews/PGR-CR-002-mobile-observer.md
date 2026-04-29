# Privacy Review — Observer Semi-Pasivo Android (CR-002)

```
document_id: PGR-CR-002-mobile-observer
owner_agent: Privacy Guardian
phase: 2 (track paralelo Android)
date: 2026-04-27
status: CONDICIONADO — compatible con Nivel 1 bajo las condiciones declaradas en
        secciones 4 y 5; 5 bloqueos concretos (B1–B5) deben resolverse en
        implementación antes de que la extensión de D9 sea válida
precede_a: extensión formal de D9 + AR del Technical Architect
triggered_by: CR-002 (aprobado en intención por Orchestrator, 2026-04-24) — D22 cerrada
              con Opción B (2026-04-24)
reference_normativo:
  - Project-docs/decisions-log.md (D1, D4, D9, D14, D19, D22)
  - Project-docs/vision.md
  - Project-docs/scope-boundaries.md
  - operating-system/review-checklists.md
  - operations/architecture-reviews/AR-CR-002-mobile-observer.md
```

---

## Propósito de Este Documento

Esta revisión valida desde el punto de vista de privacidad las opciones de observer
semi-pasivo Android consideradas en CR-002 y establece las condiciones mínimas que
deben cumplirse antes de que D9 pueda extenderse formalmente. No aprueba ninguna
implementación por sí sola. Es prerequisito de la extensión textual de D9 junto
con la AR del Technical Architect (AR-CR-002-mobile-observer.md).

---

## 1. Inventario de Datos Afectados

### 1.1 Datos que captura el observer

| Dato | Clasificación D1 | Tránsito | Persistencia |
|---|---|---|---|
| URL completa de la página navegada | SENSIBLE — cifrar | RAM del proceso local (máx. 500 ms) | SQLCipher Android (AES-256) |
| Título de la página | SENSIBLE — cifrar | RAM del proceso local (máx. 500 ms) | SQLCipher Android (AES-256) |
| Timestamp de captura | Neutro | RAM del proceso local | SQLCipher en claro |
| Domain extraído | EN CLARO (D1 autoriza) | Procesamiento local | SQLCipher en claro |
| Category inferida | EN CLARO (D1 autoriza) | Procesamiento local | SQLCipher en claro |

### 1.2 Datos que el observer NO debe capturar bajo ninguna circunstancia

- Contenido completo de páginas (texto, HTML, imágenes)
- Datos de otras apps abiertas durante la sesión
- Credenciales, formularios o campos de entrada del usuario
- Historial de navegación previo a la activación del observer
- Metadatos de red (IP de destino, cabeceras HTTP)
- Identificadores de dispositivo o de usuario más allá del scope estrictamente local

### 1.3 Flujo de datos del observer (secuencia local)

```
ACTIVACIÓN CONSCIENTE DEL USUARIO (tile ON)
         │
         ▼
Observer recibe evento de navegación (ACTION_SEND o portapapeles)
         │
         ▼
Extracción local: URL + título en RAM — no persistidos aún
         │
         ▼
Cifrado inmediato ≤ 500 ms: url + título → SQLCipher (AES-256)
         │
         ▼
Domain (en claro) + category (Classifier.rs) → SQLCipher en claro
         │
         ▼
Episode Detector mobile → Session Builder mobile
         │
         ▼
Pattern Detector (NDK) → Trust Scorer (NDK) → State Machine (NDK)
         │
         ▼
Privacy Dashboard mobile (visibilidad local)
         │
         ▼
Sync relay Google Drive (cifrado E2E — D6/D21) → desktop
```

El flujo es completamente local en todas sus etapas de procesamiento. La URL real
y el título nunca salen del dispositivo en claro.

---

## 2. Evaluación de Compatibilidad con Nivel 1

### 2.1 Condiciones de Nivel 1 en FlowWeaver

1. Procesamiento local (sin servidores externos que reciban datos del usuario en claro)
2. Datos mínimos (solo lo necesario para el caso de uso declarado)
3. Cifrado local con SQLCipher para datos sensibles
4. Cifrado E2E entre dispositivos para el relay

### 2.2 Compatibilidad del observer semi-pasivo (Tile)

| Condición Nivel 1 | Evaluación | Notas |
|---|---|---|
| Procesamiento local | Compatible | El Intent recibe y procesa en el dispositivo antes de cualquier acción |
| Datos mínimos | Compatible con condiciones | Solo durante ventana activa explícita; no captura fuera de la sesión del tile |
| Cifrado local (SQLCipher) | Compatible si se implementa correctamente | El cifrado debe ocurrir antes de persistir (control C4) |
| Cifrado E2E en relay | Compatible | Heredado de D6/D21 — sin cambios |

**Veredicto de Nivel 1:** compatible bajo condiciones. La compatibilidad no es automática:
depende de que el tiempo entre captura y cifrado sea ≤ 500 ms y de que el scope de
captura esté delimitado por el estado del tile.

---

## 3. Diferencia de Riesgo: Opción C Pura vs Tile de Sesión

### 3.1 Opción C pura — Intent handler siempre registrado

**Riesgos identificados:**

| Riesgo | Severidad |
|---|---|
| Captura de URLs sensibles (banca, salud) fuera del episodio de intención | MEDIO-ALTO |
| Handler persistente en el sistema sin sesión activa explícita | MEDIO |
| Necesidad de foreground service continuo | MEDIO |
| Percepción de vigilancia permanente — daño narrativo | ALTO |

**Valoración: RIESGO MEDIO. Rechazada** como mecanismo de sesión continua.
No compatible con el principio de activación consciente de D9.

### 3.2 Tile de sesión (handler dinámico activado por tile)

**Riesgos identificados:**

| Riesgo | Severidad |
|---|---|
| Captura de URLs sensibles durante sesión activa | BAJO (el usuario eligió estar en modo captura) |
| Sesión olvidada activa | BAJO-MEDIO (mitigado por timeout + notificación visible) |

**Valoración: RIESGO BAJO. Aprobada condicionalmente.**

### 3.3 Veredicto comparativo

**El Tile de sesión es el mecanismo más conservador desde privacidad** por tres razones:

1. La captura tiene scope temporal definido y explícito (activación/desactivación consciente).
2. Elimina la captura persistente de sistema entre sesiones.
3. La narrativa "el usuario eligió estar en modo captura ahora" es verificable.

**Recomendación de diseño:** si el mecanismo técnico es un Intent handler (Opción C),
debe registrarse dinámicamente al activar el tile y desregistrarse al desactivarlo.
El handler solo existe en el sistema Android mientras el tile está activo.

---

## 4. Controles Mínimos Obligatorios

Los siguientes controles son **BLOQUEANTES**. Ningún código del observer puede
desplegarse sin que estén implementados y verificables.

### C1 — Consentimiento explícito antes de activar el observer

Antes de que el usuario active el tile por primera vez, FlowWeaver debe mostrar
una pantalla de consentimiento informado que declare:

- Qué captura el observer (URLs visitadas durante la sesión activa)
- Qué hace con esos datos (clasificar por dominio/categoría, detectar episodio de intención)
- Qué no captura (contenido completo de páginas, datos fuera de la sesión)
- Dónde se almacenan (localmente, cifrados con SQLCipher)
- Cómo se pueden borrar (desde Privacy Dashboard)
- Que este mecanismo es parte del tier paid y puede desactivarse en cualquier momento

**El consentimiento debe ser explícito (tap afirmativo), no implícito.**
No se acepta consentimiento embebido en los términos de uso generales del producto.
El tile no debe ser activable hasta que el usuario complete el flujo de consentimiento.

### C2 — Visibilidad en Privacy Dashboard

El Privacy Dashboard mobile (prerequisito de beta per D14) debe incluir una sección
específica del observer semi-pasivo que muestre:

- Estado actual del observer (activo / inactivo)
- Número de URLs capturadas en los últimos N días
- Categorías/dominios capturados (en claro — D1)
- Historial de activaciones del tile (inicio y fin de cada sesión)
- Botón de purga de datos capturados por el observer

La sección del observer debe ser visualmente distinguible de la sección de captura
explícita (Share Intent). El usuario debe ver qué capturó cada mecanismo por separado.

### C3 — Desactivación accesible desde tres puntos

El usuario debe poder pausar o desactivar el observer desde:

1. **Tile de Quick Settings** — desactivación inmediata sin abrir la app
2. **Privacy Dashboard** — toggle con confirmación
3. **Notificación persistente del foreground service** — acción directa "Pausar captura"

La desactivación desde cualquier punto debe: detener la captura inmediatamente,
no borrar datos ya capturados (eso lo decide el usuario explícitamente), y reflejarse
en el Privacy Dashboard en menos de 1 segundo.

La notificación del foreground service debe ser no dismissable mientras el observer
esté activo (requisito de Android y control de privacidad simultáneamente).

### C4 — Retención máxima de datos raw en RAM antes de cifrar

El tiempo máximo entre la recepción de una URL por el observer y su cifrado o
destrucción es de **500 milisegundos** en condiciones normales de dispositivo.

Si el Classifier no puede procesar la URL en ese tiempo (device bajo carga), la URL
debe descartarse en lugar de retenerse en RAM sin cifrar.

Los logs de debug del observer deben excluir URLs y títulos **por diseño** (no por
política): los campos `url` y `title` no pueden pasarse a ninguna instrucción de log.

### C5 — Timeout automático de sesión

El observer debe tener un timeout automático: si el tile está activo y el usuario no
interactúa con el dispositivo durante el período configurado, el observer se desactiva
automáticamente.

- Valor por defecto: **30 minutos** (conservador)
- Rango configurable: 5 minutos a 4 horas (configurable en Privacy Dashboard)

El Technical Architect define los timeouts de sesión del Episode Detector mobile
(GAP_SECS = 2_700 s). El timeout de inactividad del Privacy Guardian (30 min) es
un control de privacidad adicional que puede disparar el cierre de sesión antes de
que GAP_SECS se alcance. Ambos controles coexisten — el que expire antes cierra
la sesión.

---

## 5. Condiciones para que D9 Pueda Extenderse

Para que la extensión de D9 sea compatible con la narrativa verificable del producto,
las siguientes condiciones deben ser verdad en la implementación:

### Condición 1 — Activación siempre consciente y reversible

El observer no puede activarse de forma automática, por actualización de la app, ni
como estado por defecto del tier paid. El usuario debe activarlo explícitamente en cada
sesión (tile) o haber dado consentimiento granular revocable.

### Condición 2 — El handler no persiste entre sesiones sin tile activo

Si el mecanismo técnico es un Intent handler, debe registrarse dinámicamente al activar
el tile y desregistrarse al desactivarlo. Un handler declarado estáticamente en
AndroidManifest que recibe intents con el tile inactivo viola esta condición.

### Condición 3 — Scope de captura declarado y delimitado

La extensión de D9 debe declarar explícitamente qué URLs captura el observer. Alguna
delimitación explícita debe existir — no puede quedar abierta a "cualquier URL que el
SO entregue". La delimitación exacta la determina el Technical Architect en el Task Spec.

### Condición 4 — D1 operativo desde el momento de captura

El observer no puede persistir URLs ni títulos en texto plano en ningún estado
intermedio (caché de disco, logs de debug, bases de datos auxiliares). D1 es operativo
desde el momento de captura, no solo en la base de datos final.

### Condición 5 — Separación en storage entre tier free y tier paid

Los datos capturados por el observer (tier paid) deben estar etiquetados en SQLCipher
de forma que sea posible purgarlos sin afectar los datos de captura explícita (Share
Intent, tier free). El usuario que cancela el tier paid debe poder retener sus datos
de captura explícita.

### Condición 6 — Privacy Dashboard completo antes de producción

El observer no puede desplegarse en producción sin que el Privacy Dashboard completo
(T-2-004, D14) esté implementado e incluya la sección específica del observer (C2).

---

## 6. Riesgos de Privacidad y Mitigaciones

| ID | Riesgo | Prob. | Impacto | Mitigación | Owner |
|---|---|---|---|---|---|
| PGR-R1 | Sobrecaptura: URLs sensibles (banca, salud) dentro de la sesión activa | Media | Alto | Lista de exclusión de dominios sensibles aplicada antes de persistir | Technical Architect |
| PGR-R2 | URL en texto plano en RAM durante > 500 ms | Baja | Alto | Control C4 — timeout de cifrado; si falla, descartar | Implementador Android |
| PGR-R3 | Sesión olvidada activa indefinidamente | Alta | Medio | Control C5 — timeout 30 min; notificación visible | Implementador Android |
| PGR-R4 | Logs de debug almacenan URLs en claro | Media | Alto | Instrucciones de log sin campos url/title por diseño | Implementador Android |
| PGR-R5 | Privacy Dashboard no distingue datos del observer de captura explícita | Media | Medio | Control C2 — sección específica del observer en dashboard | Technical Architect + T-2-004 |
| PGR-R6 | Narrativa de marketing "captura pasiva" contradice "privacidad verificable" | Media | Alto | El producto debe decir "captura consciente por sesión activada", nunca "observación pasiva permanente" | Product Owner |
| PGR-R7 | Datos del tier paid contaminan storage del tier free | Baja | Alto | Condición 5: etiquetado en SQLCipher + purga independiente | Implementador Android |
| PGR-R8 | Handler registrado en AndroidManifest opera aunque el tile esté inactivo | Media | Alto | Condición 2: registro dinámico; verificable en análisis del AndroidManifest | Technical Architect |
| PGR-R9 | Consentimiento implícito embebido en ToS generales | Baja | Alto | Control C1: pantalla de consentimiento explícita y separada | Product Owner + Implementador |

---

## 7. Veredicto

### 7.1 ¿La extensión de D9 es compatible con Nivel 1?

**Sí, con condiciones.**

El mecanismo de Tile de sesión (con handler dinámico activado por el tile) es
técnicamente compatible con la promesa de privacidad verificable de FlowWeaver
bajo las condiciones declaradas en secciones 4 y 5. El procesamiento es local,
los datos sensibles se cifran antes de persistir (D1), y el relay existente
(D6/D21) transporta los datos cifrados E2E sin modificar.

La compatibilidad NO es automática. Depende de que los controles C1–C5 y las
condiciones 1–6 sean implementados y verificables.

### 7.2 Bloqueos concretos (deben resolverse antes de que D9 sea válido)

| # | Bloqueo | Cómo desbloquearlo |
|---|---|---|
| B1 | Ausencia de pantalla de consentimiento explícito (C1) | Implementar onboarding de consentimiento antes de primer uso del tile |
| B2 | Handler persistente en AndroidManifest sin control de tile (Condición 2) | Verificar registro dinámico; rechazar si el handler es estático |
| B3 | URL en texto plano en persistencia o logs (D1, C4) | Instrucciones de log sin campos url/title; timeout de cifrado 500 ms |
| B4 | Privacy Dashboard incompleto o sin sección del observer (C2, Condición 6) | T-2-004 mobile completo con sección observable antes de producción |
| B5 | Ausencia de timeout automático de sesión (C5) | Implementar timeout configurable; valor por defecto 30 minutos |

### 7.3 Posición del Privacy Guardian sobre cada opción

| Opción | Veredicto | Condición |
|---|---|---|
| Tile de sesión con handler dinámico | APROBADO CONDICIONADO | Cumplir B1–B5 y Condiciones 1–6 |
| Opción C pura (handler siempre registrado) | RECHAZADO | Solo aprobable si es el mecanismo técnico del tile (dinámico) |
| Accessibility Service | RECHAZADO permanentemente | Incompatible con D1 y narrativa verificable |
| Historial del navegador | RECHAZADO permanentemente | Deprecado en Android 10+ y sobrecaptura masiva |

### 7.4 Narrativa verificable — qué puede y no puede decir el producto

**Puede decir:**
> "FlowWeaver captura tu navegación solo cuando tú lo activas. Mientras el modo de
> captura está activo, clasificamos las URLs por dominio y categoría — nunca el
> contenido de las páginas. Lo ciframos en tu dispositivo antes de guardarlo.
> Puedes ver, pausar y borrar lo que capturamos en cualquier momento desde el
> Privacy Dashboard."

**No puede decir (sin evidencia técnica verificable):**
- "Capturamos tu navegación de forma completamente transparente y sin interrupciones"
- "Observamos tu comportamiento de forma pasiva"
- "Nunca sabemos qué páginas visitas" — el sistema procesa las URLs, aunque no las almacene en claro

---

## 8. Siguiente Agente Responsable

1. **Technical Architect** — emitir AR formal del observer, definir mecanismo exacto
   (handler dinámico + tile), delimitar scope de captura (Condición 3), redactar
   extensión textual de D9. Ver AR-CR-002-mobile-observer.md.

2. **Orchestrator** — conocer condiciones y bloqueos desde privacidad antes de
   autorizar cualquier implementación del observer.

3. **Context Guardian** — registrar este documento en el índice de decisiones de
   privacidad; asegurar que la extensión de D9 referencia PGR-CR-002.

---

## 9. Trazabilidad

| Acción | Archivo | Estado |
|---|---|---|
| Revisado | Project-docs/decisions-log.md (D1, D9, D22) | LEÍDO — sin contradicción si se cumplen condiciones |
| Revisado | Project-docs/vision.md | LEÍDO — compatible bajo condiciones |
| Revisado | Project-docs/scope-boundaries.md | LEÍDO |
| Revisado | operating-system/review-checklists.md | LEÍDO |
| Revisado | operations/architecture-reviews/AR-CR-002-mobile-observer.md | LEÍDO — condiciones técnicas incorporadas |
| Creado | operations/architecture-reviews/PGR-CR-002-mobile-observer.md | este documento |
| Pendiente | Extensión formal de D9 | Requiere aprobación del Orchestrator + commit del Context Guardian |
| Pendiente | Task Spec del observer mobile | Prerequisito de implementación |

---

## Firma

```
reviewed_by: Privacy Guardian
review_date: 2026-04-27
status_detail: |
  CONDICIONADO. El mecanismo de Tile de sesión con handler dinámico es compatible
  con Nivel 1 bajo las 6 condiciones declaradas. 5 bloqueos concretos (B1–B5) son
  prerequisito para que la extensión de D9 sea válida: consentimiento explícito (B1),
  handler dinámico verificable en AndroidManifest (B2), D1 operativo en logs y
  persistencia (B3), Privacy Dashboard mobile completo con sección del observer (B4),
  timeout de sesión configurable con default de 30 minutos (B5). La Opción C pura
  (handler siempre registrado) queda rechazada como mecanismo de sesión. Accessibility
  Service e historial del navegador rechazados permanentemente. La narrativa verificable
  queda acotada: "captura consciente por sesión activada, cifrada localmente, visible
  en Privacy Dashboard". Qualquier enunciado de marketing que contradiga esta narrativa
  debe ser revisado por Privacy Guardian antes de publicarse.
```
