# Privacy Review — Classifier Enrichment Capas A y B (CR-004)

```
document_id: PGR-CR-004-classifier-enrichment
owner_agent: Privacy Guardian
phase: 3 (T-3-006 nueva + scope extension de T-3-005)
date: 2026-05-04
status: APROBADO CON CONDICIONES — Capa A compatible con D1 sin
        controles adicionales más allá de la auditoría del diccionario;
        Capa B compatible con D1 bajo las 4 condiciones declaradas en
        sección 5; sección de Privacy Dashboard requerida (D14) cuando
        Capa B esté activa.
precede_a: aprobación final del Orchestrator de CR-004 + handoff al
           Functional Analyst.
triggered_by: CR-004 (2026-05-04) + AR-CR-004 (Technical Architect,
              2026-05-04, APROBADO CON CONDICIONES) — esta PGR ratifica
              los inputs declarados por el Technical Architect.
reference_normativo:
  - Project-docs/decisions-log.md (D1, D8, D14)
  - Project-docs/scope-boundaries.md
  - operations/architecture-reviews/PGR-CR-002-mobile-observer.md
    (precedente de PGR sobre extensión de D9)
  - operations/change-requests/CR-004-classifier-enrichment.md
  - operations/architecture-reviews/AR-CR-004-classifier-enrichment.md
```

---

## Propósito de Este Documento

Validar desde privacidad la extensión propuesta del Classifier (CR-004
+ AR-CR-004). Esta revisión no aprueba la implementación por sí sola
— es prerrequisito de la aprobación final del Orchestrator junto con
la AR del Technical Architect.

El alcance de esta revisión es estricto:

1. ¿La Capa A (TLD + subdominio + keyword) opera exclusivamente sobre
   datos en claro autorizados por D1?
2. ¿El diccionario de keywords es público sin que ello permita
   reconstruir inversamente `title` cifrado?
3. ¿El input del LLM en Capa B es exactamente `domain` + `path_tokens`,
   sin URL completa ni título?
4. ¿Capa B requiere control visible en Privacy Dashboard (D14)?

---

## 1. Inventario de Datos Afectados

### 1.1 Datos que el Classifier ya recibe hoy (sin cambios)

| Dato | Clasificación D1 | Origen | Acceso del Classifier |
|---|---|---|---|
| URL completa | SENSIBLE — cifrada en SQLCipher | Bookmark importer; Share Intent Android; `add_capture` desktop | RECIBIDA en claro como argumento de `classify(url)`. **El Classifier es upstream del cifrado** — opera antes de que el Importer persista. |
| Título | SENSIBLE — cifrado en SQLCipher | Bookmark importer (en HTML); Share Intent Android (EXTRA_SUBJECT) | RECIBIDO en claro como argumento de `import_resource` y `add_capture`. Mismo razonamiento upstream. |
| Domain extraído | EN CLARO (D1 autoriza) | Derivado por `extract_domain(url)` | Procesado por `lookup_category` |
| Category inferida | EN CLARO (D1 autoriza) | Output del Classifier | Devuelta al Importer |

**Punto clave:** el Classifier **ya** opera sobre URL y título en claro
hoy. No es una nueva capa de exposición — es la misma capa que se
amplía con tres pasos adicionales. El cifrado D1 ocurre **después** del
Classifier, en el Importer (`crypto::encrypt_aes` antes del `INSERT`).

### 1.2 Datos que la Capa A introduce como input adicional

| Dato | Clasificación D1 | Origen | Uso en Capa A |
|---|---|---|---|
| `path_tokens` | EN CLARO (subset del path de URL ya en claro) | Tokenización de `url.split('/')` con filtros (longitud, alfabeto, stopwords) | Capa A.3 — comparados contra diccionario estático |
| `title_tokens` | EN CLARO (subset del título ya en claro) | Tokenización del título recibido (EXTRA_SUBJECT en mobile, `<title>` del bookmark en desktop) | Capa A.3 — comparados contra diccionario estático |

Ambos derivan de datos que **ya circulan en claro hoy** en el flujo
upstream del Classifier. No se accede a ningún campo cifrado de
SQLCipher para construirlos.

### 1.3 Datos que el LLM (Capa B) recibiría

| Dato | ¿Llega al LLM? | Justificación |
|---|---|---|
| `domain` | SÍ | D1 lo autoriza en claro. Es la entrada mínima para clasificar. |
| `path_tokens` | SÍ | Ya derivados en Capa A.3 con filtros aplicados. Sin URL completa, sin parámetros. |
| `url` completa | NO | Revela el path con todos sus parámetros (query strings, fragmentos). Excluido. |
| `title` | NO | Aunque el Classifier lo tiene en claro, la política conservadora del Technical Architect (AR-CR-004 §4) lo excluye del LLM. |
| `title_tokens` | NO | Política conservadora idéntica al título. La Capa A.3 los usa internamente con diccionario público; el LLM no los recibe. |
| Cualquier otro campo | NO | No hay otros campos en el contrato del Classifier. |

**El input del LLM es estrictamente `(domain, path_tokens)`.** PGR
ratifica esta restricción.

---

## 2. Evaluación de Compatibilidad con D1

### 2.1 Capa A — Compatible sin controles nuevos

| Verificación | Estado |
|---|---|
| ¿El Classifier accede a algún campo cifrado de SQLCipher? | NO. Opera upstream del cifrado, sobre `url` y `title` recibidos como argumentos. |
| ¿La Capa A introduce nuevas lecturas de SQLCipher? | NO. Tres pasos nuevos (TLD, subdominio, keyword) operan sobre `domain`, `path` y `title` en claro ya disponibles en el flujo. |
| ¿El diccionario de keywords se almacena en algún lugar persistente con datos del usuario? | NO. Es estático en código, idéntico para todos los usuarios, idéntico a través del tiempo. |
| ¿La salida (categoría) introduce un campo nuevo en SQLCipher? | NO. Es la misma columna `category` ya existente. |
| ¿La paridad Rust ↔ Kotlin introduce nuevos canales de transporte de datos? | NO. La paridad es de lógica (mismo diccionario en código), no de datos. |

**Veredicto Capa A:** compatible con D1 sin controles nuevos. El único
control vivo es la auditoría del diccionario (sección 3).

### 2.2 Capa B — Compatible bajo condiciones

| Verificación | Estado |
|---|---|
| ¿El input del LLM contiene URL completa o título? | NO según AR-CR-004 §4. PGR ratifica. |
| ¿El LLM persiste el input o el output en algún storage del usuario? | Por diseño: NO. El LLM opera en memoria; su salida es la categoría que entra a SQLCipher como cualquier otra. Verificación delegada a la TS de T-3-005 ampliada. |
| ¿Ollama envía datos a servidores externos? | NO. Ollama es un proceso local. La AR-CR-004 §4 declara que cualquier modelo que requiera red externa queda fuera de scope (D8 lo refuerza). |
| ¿El LLM se invoca con la URL en logs de debug? | Por política: NO. La TS de T-3-005 debe declarar que las instrucciones de log no contienen `url`, `title` ni `path_tokens`. Auditoría con test estructural. |
| ¿El usuario tiene control visible sobre la activación del LLM? | Requiere control en Privacy Dashboard. Ver sección 5 condición 4. |

**Veredicto Capa B:** compatible con D1 bajo las 4 condiciones de
sección 5.

---

## 3. Auditoría del Diccionario de Keywords

### 3.1 ¿Puede el diccionario revelar `title` cifrado?

**No.** El razonamiento:

1. El diccionario es **público** (versionado en código, abierto en
   GitHub).
2. El diccionario opera sobre **tokens recibidos en claro** (path de
   URL + EXTRA_SUBJECT del Share Intent + título de bookmark importado).
3. La salida es **categoría** — un valor de cardinalidad muy baja
   (~24 categorías). Esa cardinalidad no permite reconstruir el
   título: la función `tokens → categoría` es masivamente *many-to-one*.
4. El título cifrado en SQLCipher **no se descifra para el Classifier**.
   El Classifier opera upstream, antes del cifrado.

Conclusión: la categoría inferida no es un "leak" del título. Es una
abstracción semántica que D1 autoriza explícitamente.

### 3.2 Reglas de auditoría del diccionario

Privacy Guardian impone los siguientes controles sobre el contenido
del diccionario:

| Control | Regla |
|---|---|
| PG-A1 | El diccionario es estático en código, no aprendido. Cualquier proceso que añada keywords automáticamente queda prohibido. |
| PG-A2 | No se admiten keywords que sean nombres propios de personas, marcas concretas asociadas a identidad personal, ni términos médicos específicos (cardiología, psiquiatría, etc.). El nivel de granularidad permitido es la categoría temática general. |
| PG-A3 | No se admiten keywords en idiomas no documentados en TS-0a-003. La revisión de Functional Analyst documenta los idiomas soportados (mínimo viable: español + inglés). |
| PG-A4 | Cualquier ampliación del diccionario requiere PR + revisión por Privacy Guardian si introduce categoría nueva o si aporta keywords con potencial de identificación (lista de exclusión PG-A2). |
| PG-A5 | El diccionario se publica como parte del código abierto del proyecto. La auditoría de la comunidad es un control adicional (no sustituye los anteriores). |

Estos controles se incorporan a TS-0a-003 (sección Capa A nueva) y a
la TS de T-3-006 cuando se emita.

---

## 4. Auditoría del Input del LLM (Capa B)

### 4.1 Input declarado

```rust
fn llm_classify(domain: &str, path_tokens: &[&str]) -> Option<&'static str>
```

- `domain`: en claro (D1 autoriza)
- `path_tokens`: subset filtrado del path de URL en claro

**Este es el contrato exclusivo.** Cualquier ampliación requiere CR
nuevo y PGR nueva.

### 4.2 Verificaciones requeridas

| Control | Regla | Verificación |
|---|---|---|
| PG-B1 | Test estructural sobre la signatura de `llm_classify`: solo dos argumentos, ambos del tipo declarado. | Test que falla si la signatura cambia (incluye más argumentos o tipos distintos). |
| PG-B2 | Test estructural sobre los logs de la implementación: ningún `log::*` o `eprintln!` en la ruta del LLM contiene los identificadores `url`, `title`, `path_tokens`, `domain` como contenido de mensaje. | grep + test estructural en la TS. |
| PG-B3 | El path_tokens se filtra por longitud (≥ 3 chars), alfabeto (alfanumérico solo) y stopwords (lista en TS-0a-003) **antes** de pasar al LLM. Mitigación de prompt injection. | Test unitario con vectores de inyección conocidos. |
| PG-B4 | La salida del LLM se valida contra el set fijo de categorías existentes. Sugerencias fuera de set → `otro`. | Test unitario. |
| PG-B5 | Si el LLM no responde en 200 ms, el Classifier devuelve `otro` sin error y sin reintentar. | Test de timeout simulado (igual que AC-B3 de AR-CR-004). |

### 4.3 Prompt injection — análisis específico

El path de la URL puede contener contenido controlado por un atacante
(p.ej. `https://atacante.com/path?prompt=ignore-previous-instructions`).
El control PG-B3 mitiga esto:

1. La función `extract_path_tokens` **filtra**: longitud mínima 3,
   alfanumérico, sin caracteres especiales.
2. Tokens como `ignore-previous-instructions` se segmentan por
   caracteres no-alfanuméricos: `ignore`, `previous`, `instructions`.
   Cada uno entra al LLM como token aislado.
3. El LLM recibe tokens **sueltos**, no una frase coherente. La
   capacidad de inyección se reduce significativamente.
4. La salida se valida contra el set fijo (PG-B4): aunque el LLM
   intentara devolver una categoría inventada, el Classifier la
   rechaza.

Privacy Guardian considera el riesgo residual ACEPTABLE bajo estas
condiciones. La TS de T-3-005 ampliada debe declarar las cinco
verificaciones PG-B1..PG-B5 como AC ejecutables.

---

## 5. Condiciones para que CR-004 sea Aprobable

Para que la aprobación final del Orchestrator sea válida desde el
punto de vista de privacidad, las siguientes condiciones deben ser
verdad en la TS de T-3-006 y en la TS ampliada de T-3-005.

### Condición 1 — Diccionario auditable (Capa A)

El diccionario de keywords está versionado en código, sin carga
externa, sin aprendizaje. Cumple PG-A1..PG-A5. Cualquier ampliación
con potencial de identificación pasa por revisión de Privacy
Guardian.

### Condición 2 — Tokens en claro (Capa A.3)

Capa A.3 opera exclusivamente sobre `path_tokens` derivados de la URL
recibida en claro y `title_tokens` derivados del título recibido en
claro (EXTRA_SUBJECT, bookmark `<title>`, etc.). Ningún token se
deriva de un campo cifrado de SQLCipher. La función de extracción
de tokens se documenta en TS-0a-003 con su filtro completo.

### Condición 3 — Input del LLM restringido (Capa B)

`llm_classify` recibe exclusivamente `(domain, path_tokens)`. Tests
estructurales PG-B1..PG-B5 declarados como AC ejecutables. Logs sin
campos sensibles.

### Condición 4 — Control en Privacy Dashboard (Capa B)

D14 exige Privacy Dashboard completo antes de beta. Cuando Capa B
esté activa (decisión del Orchestrator), el Privacy Dashboard debe
incluir una sección "Modelo local — clasificador" con:

- Estado del LLM (activo / inactivo / no instalado)
- Modelo en uso (versión, tamaño, origen) — para que el usuario
  pueda verificar qué procesa sus datos
- Toggle de desactivación con efecto inmediato (al desactivar, el
  Classifier deja de invocar al LLM en la siguiente captura)
- Texto explicativo: "FlowWeaver puede usar un modelo local de IA
  para clasificar dominios desconocidos. El modelo recibe solo el
  dominio y palabras del path de la URL — nunca la URL completa,
  nunca el título de la página."

Esta sección se agrega a `PrivacyDashboard.tsx` como subcomponente
nuevo (`LlmClassifierSection.tsx`), siguiendo el patrón de
`FsWatcherSection.tsx`.

---

## 6. Riesgos de Privacidad y Mitigaciones

| ID | Riesgo | Prob. | Impacto | Mitigación | Owner |
|---|---|---|---|---|---|
| PGR-R1 | El diccionario contiene keywords con potencial de identificación personal. | Baja | Alto | Control PG-A2 — exclusión de nombres propios, marcas asociadas a identidad y términos médicos específicos. | Functional Analyst (mantiene diccionario) + Privacy Guardian (audita) |
| PGR-R2 | Implementador añade campos al input del LLM (Capa B) sin pasar por CR. | Baja | Alto | PG-B1 (test estructural sobre signatura). El test falla en CI si la signatura cambia. | Implementador + QA Auditor |
| PGR-R3 | Logs de debug del LLM contienen URL o título. | Media | Alto | PG-B2 (grep en código). Política explícita en TS de T-3-005 ampliada. | Implementador |
| PGR-R4 | Prompt injection desde el path de URL controlado por atacante. | Baja | Alto | PG-B3 (filtro de tokens) + PG-B4 (validación de salida contra set fijo). Riesgo residual aceptable. | Implementador + Privacy Guardian |
| PGR-R5 | Ollama envía datos a servidores externos sin que el usuario lo sepa. | Baja | Crítico | Ollama es local por construcción. Cualquier modelo que requiera red externa queda fuera de scope (D8 + AR-CR-004 §4). Verificación: documentar el binario y origen de Ollama en la TS. | Technical Architect |
| PGR-R6 | Privacy Dashboard no muestra el LLM cuando Capa B está activa. | Baja | Alto | Condición 4 obligatoria. AC en TS de T-3-005 ampliada. | Implementador + QA Auditor |
| PGR-R7 | Capa B se activa por defecto en una actualización futura sin consentimiento del usuario. | Baja | Alto | Capa B es CONDICIONAL en backlog-phase-3.md. Solo se activa por OD explícita del Orchestrator. La instalación inicial debe llevar Capa B en **off** por defecto, requiriendo activación manual del usuario. | Orchestrator + Implementador |
| PGR-R8 | El usuario que desactiva Capa B desde Privacy Dashboard ve recursos clasificados como `otro` que antes tenían categoría útil. | Media | Bajo | Esto es comportamiento correcto: la desactivación es efectiva. Documentar en el texto del Privacy Dashboard. | UX |

---

## 7. Veredicto

### 7.1 ¿Capa A es compatible con D1?

**Sí, sin condiciones nuevas más allá de la auditoría del diccionario.**

El Classifier opera upstream del cifrado y ya tiene acceso a URL y
título en claro. Capa A añade tres pasos nuevos sobre datos ya
disponibles en el mismo flujo. El diccionario es público y de
cardinalidad baja — la categoría inferida no permite reconstruir el
título. Los controles PG-A1..PG-A5 acotan el contenido del
diccionario.

### 7.2 ¿Capa B es compatible con D1?

**Sí, bajo las 4 condiciones declaradas en sección 5.**

El input del LLM se restringe a `domain` + `path_tokens`. La
implementación cumple con D8 (degradación graceful sin Ollama). El
Privacy Dashboard incluye sección de control y transparencia.
Activación condicional a OD explícita del Orchestrator.

### 7.3 Posición del Privacy Guardian sobre cada capa

| Capa | Veredicto | Condición |
|---|---|---|
| Capa A.1 (TLD inference) | APROBADO | Sin condiciones — opera sobre `domain` en claro autorizado por D1 |
| Capa A.2 (subdominio inference) | APROBADO | Sin condiciones — idem |
| Capa A.3 (keyword inference) | APROBADO CONDICIONADO | Cumplir PG-A1..PG-A5 (auditoría del diccionario) |
| Capa B (LLM) | APROBADO CONDICIONADO | Cumplir Condiciones 3 y 4 + PG-B1..PG-B5 + activación por OD explícita |

### 7.4 Narrativa verificable — qué puede y no puede decir el producto

**Puede decir:**

> "FlowWeaver clasifica los recursos que guardas usando una tabla
> pública de dominios y, cuando el dominio no está en la tabla,
> aplica reglas determinísticas sobre el path de la URL y el título
> que tu navegador o app comparte. Las reglas son públicas y están
> en el código del producto. No leemos el contenido de las páginas
> que visitas."

**Cuando Capa B esté activa, puede añadir:**

> "Si tienes el modelo local de IA activo, FlowWeaver puede pedirle
> que sugiera una categoría para dominios que no reconoce. El modelo
> recibe solo el nombre del dominio y palabras del path de la URL —
> nunca la URL completa, nunca el título. Puedes desactivar esta
> opción en cualquier momento desde el Privacy Dashboard."

**No puede decir (sin evidencia técnica verificable):**

- "FlowWeaver no procesa las URLs que guardas" — el sistema sí las
  procesa para extraer dominio y categoría; las almacena cifradas
  pero las procesa.
- "Tu título nunca se procesa" — el título sí se tokeniza para Capa
  A.3 (sin cifrar previamente porque el Classifier es upstream del
  cifrado).
- "El modelo de IA es completamente externo a FlowWeaver" — el LLM
  es un proceso local invocado por FlowWeaver con un input
  controlado.

---

## 8. Siguiente Agente Responsable

1. **Orchestrator** — aprobación final de CR-004 + AR-CR-004 +
   PGR-CR-004. Emisión de handoff al Functional Analyst para
   actualizar TS-0a-003 y backlog-phase-3.md.
2. **Functional Analyst** — actualización de TS-0a-003 (sección
   Capa A nueva con diccionario mínimo viable, exclusiones
   matizadas) y backlog-phase-3.md (T-3-006 nueva, T-3-005 con
   scope ampliado).
3. **Technical Architect** — emisión de TS de T-3-006 con AC-A1..AC-A8
   (AR-CR-004 §6) desglosados en pasos ejecutables. Implementación
   bloqueada hasta TS aprobada.
4. **Privacy Guardian** — re-auditoría cuando se emita la TS de
   T-3-006 y la TS ampliada de T-3-005 para verificar que las
   condiciones de esta PGR están materializadas en AC ejecutables.

---

## 9. Trazabilidad

| Acción | Archivo | Estado |
|---|---|---|
| Revisado | operations/change-requests/CR-004-classifier-enrichment.md | LEÍDO — propuesta evaluada |
| Revisado | operations/architecture-reviews/AR-CR-004-classifier-enrichment.md | LEÍDO — input del LLM ratificado |
| Revisado | Project-docs/decisions-log.md | LEÍDO — D1, D8, D14 vigentes |
| Revisado | Project-docs/scope-boundaries.md | LEÍDO |
| Revisado | operations/architecture-reviews/PGR-CR-002-mobile-observer.md | REFERENCIA de formato |
| Creado | operations/architecture-reviews/PGR-CR-004-classifier-enrichment.md | este documento |

---

## Firma

```
reviewed_by: Privacy Guardian
review_date: 2026-05-04
status_detail: |
  APROBADO CON CONDICIONES. Capa A (TLD + subdominio + keyword) es
  compatible con D1 sin controles nuevos más allá de la auditoría del
  diccionario (PG-A1..PG-A5). El Classifier opera upstream del cifrado
  — todos los datos que recibe ya circulan en claro en el flujo
  original; Capa A no introduce nueva exposición. La categoría inferida
  no permite reconstruir el título cifrado por el cardinalidad baja
  del set de categorías. Capa B (LLM) es compatible con D1 bajo las 4
  condiciones declaradas en sección 5: diccionario auditable, tokens
  en claro autorizados, input del LLM restringido a (domain,
  path_tokens), control en Privacy Dashboard cuando esté activa. Los
  tests estructurales PG-B1..PG-B5 garantizan que la signatura de
  llm_classify no se amplíe sin CR. Prompt injection: riesgo residual
  ACEPTABLE bajo PG-B3 (filtro de tokens) + PG-B4 (validación de
  salida). Capa B se instala con valor por defecto OFF — activación
  manual del usuario. Privacy Dashboard mostrará "Modelo local —
  clasificador" como subcomponente cuando Capa B esté activa, con
  estado, modelo, toggle y texto explicativo. La narrativa verificable
  queda acotada — el producto puede declarar el procesamiento
  determinístico de path/título y, si Capa B está activa, el input
  exacto del LLM. PGR delega al Privacy Guardian la re-auditoría
  cuando se emitan las TS de T-3-006 y T-3-005 ampliada.
```
