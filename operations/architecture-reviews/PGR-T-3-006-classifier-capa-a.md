# Privacy Review — Classifier Capa A (T-3-006)

```
document_id: PGR-T-3-006-classifier-capa-a
owner_agent: Privacy Guardian
phase: 3
date: 2026-05-04
status: APROBADO — los controles PG-A1..PG-A5 declarados en PGR-CR-004
        están materializados como AC ejecutables en TS-3-006. R-A7
        (title recibido en claro upstream del cifrado) está
        documentado en cabecera y comentarios. La implementación de
        T-3-006 puede comenzar una vez la TS sea aceptada por el
        owner de implementación.
precede_a: implementación de Capa A en src-tauri/src/classifier.rs
           (Rust) y ShareIntentActivity.kt (Kotlin).
triggered_by: TS-3-006 emitida por Technical Architect (commit bf7f67e,
              2026-05-04). Re-auditoría requerida por PGR-CR-004 §8 y
              por AC-A7 de TS-3-006.
reference_normativo:
  - Project-docs/decisions-log.md (D1, D8, D14)
  - operations/architecture-reviews/PGR-CR-004-classifier-enrichment.md
  - operations/task-specs/TS-3-006-classifier-capa-a.md
  - operations/task-specs/TS-0a-003-domain-category-classifier.md
    §"Capa A — Inferencia Determinística (Extensión Aprobada por CR-004)"
```

---

## Propósito de Este Documento

PGR-CR-004 aprobó la **extensión de scope** del Classifier
condicionando la implementación a que la TS ejecutable materialice los
controles PG-A1..PG-A5 como AC verificables. TS-3-006 (commit
`bf7f67e`) es esa TS ejecutable. Esta PGR ratifica una a una las
condiciones de privacidad antes de habilitar la implementación.

El alcance es estricto:

1. ¿Los 5 controles PG-A1..PG-A5 están reflejados en TS-3-006 como
   restricciones activas o AC ejecutables?
2. ¿El input de Capa A.3 (`path_tokens`, `title_tokens`) opera
   exclusivamente sobre datos en claro recibidos upstream del
   cifrado de SQLCipher?
3. ¿El diccionario mínimo viable propuesto cumple PG-A2 (sin nombres
   propios, marcas asociadas a identidad ni términos médicos
   específicos)?
4. ¿Los riesgos R-A5 y R-A7 de TS-3-006 §"Riesgos" tienen owner
   declarado y mitigación operativa?

---

## 1. Verificación de Controles PG-A1..PG-A5

### PG-A1 — Diccionario estático en código, no aprendido

**Materializado en TS-3-006:**

- Sección "Capa A.3 — Keyword Inference" declara
  `const KEYWORD_INFERENCE: &[(&'static str, &[&'static str])]` — la
  declaración `const` impone almacenamiento en sección `.rodata`
  inmutable.
- AC-A5 prohíbe estado mutable, IO de sistema y red en `classifier.rs`.
- AC-A3 fija cota dura ≤ 200 entradas y test estructural verificable.
- §"Out of Scope" prohíbe explícitamente "aprendizaje automático del
  diccionario" y "persistencia del diccionario en SQLCipher o config
  externa".

**Veredicto:** PG-A1 RATIFICADO.

### PG-A2 — Exclusión de nombres propios, marcas asociadas a identidad y términos médicos específicos

**Materializado en TS-3-006:**

- Diccionario mínimo viable (sección Capa A.3) declara 5 categorías
  con keywords genéricos:
  - cocina: receta, ingredientes, cocinar, plato, horno, guiso,
    postre, tapa, menu — términos genéricos de actividad.
  - deportes: partido, gol, liga, futbol, baloncesto, tenis,
    formula1, motogp, marcador, resultado — términos genéricos de
    deporte (no nombres de equipo, club ni atleta).
  - entretenimiento: pelicula, peliculas, serie, series, episodio,
    temporada, capitulo, reparto, estreno, sinopsis — términos
    genéricos del medio.
  - gobierno: ley, decreto, boe, resolucion, tramite, expediente,
    boja, doe — términos administrativos públicos.
  - salud: sintoma, tratamiento, consulta, clinica, diagnostico,
    farmacia, vacuna — términos genéricos. **Nota Privacy
    Guardian:** este conjunto cumple PG-A2 porque `clinica`,
    `farmacia` y `vacuna` son sustantivos de servicio sanitario, no
    términos de especialidad médica (psiquiatría, oncología, etc.).
    El nivel de granularidad permitido es la categoría temática
    general "salud", no la sub-especialización clínica.

- R-A5 declara explícitamente el control PG-A2 como mitigación con
  owner Privacy Guardian.

**Veredicto:** PG-A2 RATIFICADO sobre el diccionario mínimo viable.
Cualquier ampliación posterior pasa por revisión adicional (PG-A4).

### PG-A3 — Idiomas soportados documentados

**Materializado en TS-0a-003 §"Capa A — Reglas de Auditoría":**

- "Idiomas soportados en mínimo viable: español + inglés. Ampliaciones
  posteriores requieren PR + revisión."

**Materializado en TS-3-006:**

- El diccionario propuesto contiene exclusivamente términos en
  español. La función `tokenize_title` reutilizada de
  `episode_detector.rs::tokenize` ya filtra stopwords ES + EN.
  Cualquier diccionario en otro idioma debe pasar por PR + revisión
  (PG-A4).

**Veredicto:** PG-A3 RATIFICADO. Idiomas activos (ES) declarados.

### PG-A4 — Cualquier ampliación pasa por PR + revisión

**Materializado en TS-3-006:**

- §"Out of Scope" + R-A1 documentan el flujo de PR + revisión.
- TS-0a-003 §"Capa A — Reglas de Auditoría" duplica la regla.

**Materializado operativamente:**

- El campo `KEYWORD_INFERENCE` es un símbolo público del módulo;
  cualquier modificación requiere modificar el archivo y entra a
  revisión normal de PR.
- La cota dura ≤ 200 entradas obliga a revisar en cuanto el
  diccionario crezca.

**Veredicto:** PG-A4 RATIFICADO. Recomendación adicional al QA
Auditor: en CI, fallar la build si `count_keywords()` excede 200.

### PG-A5 — Auditoría comunitaria por publicación abierta

**Materializado:**

- El repo FlowWeaver es público (constraint de gobernanza del proyecto).
- El diccionario está en `src-tauri/src/classifier.rs` y se publica
  con cada commit.

**Veredicto:** PG-A5 RATIFICADO. Control informativo, complementario
a PG-A1..PG-A4.

---

## 2. Input de Capa A.3 — Datos en Claro Upstream del Cifrado

### Verificación del flujo

TS-3-006 declara que `classify(url, title)` recibe `url` y `title`
como **argumentos de entrada en claro**. El Classifier es upstream
del cifrado AES-GCM que ocurre en `import_resource` y `add_capture`
**antes del INSERT en SQLCipher**:

```
[Importer / add_capture]
     │
     ▼  url, title en claro (argumentos de la función)
[classify(url, title)]
     │
     ▼  domain, category devueltos
[Importer]
     │
     ▼  url, title cifrados con AES-GCM (crypto::encrypt_aes)
[INSERT en SQLCipher]
```

El Classifier **nunca lee `title` ni `url` desde SQLCipher**. Sus
argumentos siempre vienen en claro desde el código que invoca
`classify`. Esta operación está autorizada por D1 — **el cifrado D1
opera al persistir, no al procesar en memoria upstream**.

### Tokenización

- `extract_path_tokens(url)` opera sobre `url` recibida en claro.
  Reutiliza `episode_detector.rs::extract_url_tokens` con `pub(crate)`.
  Filtra noise, stopwords, prefijos UTM, tokens numéricos.
- `tokenize_title(title)` opera sobre `title` recibido en claro.
  Reutiliza `episode_detector.rs::tokenize` con stopwords ES + EN +
  TLDs (filtrado añadido en H-004, commit `f509697`).

Ningún token se persiste — viven en stack durante la invocación de
`classify` y se descartan al retornar.

### R-A7 — Documentación obligatoria

TS-3-006 §"Riesgos" R-A7 obliga a documentar explícitamente en
cabecera de `classifier.rs` y en `tokenize_title` que el Classifier
opera upstream del cifrado y los tokens nunca se descifran de
SQLCipher. Esta documentación es bloqueante: la implementación no
puede mergear sin esa cabecera (verificable por QA Auditor en
revisión de PR).

**Veredicto:** input de Capa A.3 CONFORME con D1.

---

## 3. Diccionario Mínimo Viable — Análisis de Identidad

Análisis token a token del diccionario propuesto:

| Categoría | Token | ¿Puede revelar identidad de persona? | Decisión PG-A2 |
|---|---|---|---|
| cocina | receta, ingredientes, cocinar, plato, horno, guiso, postre, tapa, menu | NO — todos son sustantivos comunes de actividad | RATIFICADO |
| deportes | partido, gol, liga, futbol, baloncesto, tenis, formula1, motogp, marcador, resultado | NO — términos genéricos (no nombres de club, equipo, atleta) | RATIFICADO |
| entretenimiento | pelicula, peliculas, serie, series, episodio, temporada, capitulo, reparto, estreno, sinopsis | NO — términos genéricos del medio audiovisual | RATIFICADO |
| gobierno | ley, decreto, boe, resolucion, tramite, expediente, boja, doe | NO — `boe`, `boja`, `doe` son siglas de boletines oficiales públicos (Boletín Oficial del Estado, Junta de Andalucía, Diario Oficial de Extremadura) | RATIFICADO |
| salud | sintoma, tratamiento, consulta, clinica, diagnostico, farmacia, vacuna | Análisis cuidadoso: ningún token es una especialidad médica concreta. `clinica`, `farmacia` y `vacuna` son sustantivos de servicio sanitario público. **No** se admiten términos como `psiquiatría`, `oncología`, `vih`, etc. en futuras ampliaciones sin revisión PG-A4 explícita. | RATIFICADO con nota |

**Veredicto general:** el diccionario mínimo viable de TS-3-006
cumple PG-A2. Privacy Guardian declara explícitamente que la
ampliación a 200 entradas debe respetar la misma regla — cualquier
sub-especialización clínica, marca comercial individualizada o
nombre propio se rechaza en PR.

---

## 4. Verificación de R-A5 y R-A7

### R-A5 — Diccionario con potencial de identificación

- **Probabilidad:** Baja
- **Impacto:** Alto
- **Mitigación documentada en TS-3-006:** PG-A2 + auditoría del
  Privacy Guardian.
- **Owner:** Privacy Guardian + Functional Analyst.
- **Verificable:** sí — el diccionario es estático en código y
  auditable por inspección directa.

**Veredicto:** R-A5 con mitigación operativa. PGR ratifica el owner
y el control.

### R-A7 — Title recibido en claro upstream interpretado como violación de D1 por inspección superficial

- **Probabilidad:** Media
- **Impacto:** Bajo
- **Mitigación documentada en TS-3-006:** documentar explícitamente
  en cabecera de `classifier.rs` y en `tokenize_title` que el
  Classifier opera upstream del cifrado.
- **Owner:** Privacy Guardian (re-auditoría) — **resuelto en este
  documento**.

**Veredicto:** R-A7 cerrado en parte por esta PGR. La cabecera del
módulo en código sigue siendo bloqueante en PR — el implementador
debe materializar el comentario antes de mergear.

---

## 5. Verificación Adicional — Logs de Debug

Aunque no es PG-A explícito, Privacy Guardian añade el siguiente
control vivo para Capa A:

### PG-A6 (nuevo) — Logs sin campos sensibles

Las instrucciones de log (`log::*`, `eprintln!`, `println!`) en la
ruta de Capa A no pueden contener:

- la URL completa
- el `title` recibido en claro
- los `path_tokens` o `title_tokens` como contenido del mensaje

Sí pueden contener:

- el `domain` (D1 lo autoriza)
- la `category` resultante
- contadores agregados (count de keywords, paso del orden de
  resolución que devolvió la categoría)

**Verificable:** test estructural — grep de `url`, `title`,
`path_tokens` en líneas de log de `classifier.rs`. El QA Auditor
ejecuta este grep antes de aprobar la implementación.

PG-A6 se incorpora a TS-0a-003 §"Capa A — Reglas de Auditoría" en
una actualización menor (commit posterior si se considera
necesario; en cualquier caso es vinculante a partir de esta PGR).

---

## 6. Veredicto

### 6.1 ¿La TS ejecutable materializa los controles de privacidad?

**Sí.** Los 5 controles PG-A1..PG-A5 declarados en PGR-CR-004 están
reflejados en TS-3-006 (sección Capa A.3, AC-A3, AC-A5, AC-A7,
§"Out of Scope" y §"Riesgos"). El input de Capa A.3 opera
exclusivamente sobre datos en claro upstream del cifrado. El
diccionario mínimo viable cumple PG-A2.

### 6.2 ¿La implementación de T-3-006 puede comenzar?

**Sí**, una vez:

1. Esta PGR (PGR-T-3-006) está commiteada en main de EquipoEnjambre.
2. AC-A7 de TS-3-006 queda satisfecho por este documento.
3. El owner de implementación (Desktop Tauri Shell Specialist + Android
   Share Intent Specialist) acepta el plan de implementación.

### 6.3 Controles activos durante la implementación

| Control | Cuándo se verifica | Quién |
|---|---|---|
| PG-A1 | Code review del PR de Capa A | Privacy Guardian + QA Auditor |
| PG-A2 | Code review del diccionario | Privacy Guardian (cualquier ampliación posterior) |
| PG-A3 | Code review del idioma de los keywords | Privacy Guardian |
| PG-A4 | Cualquier PR que toque `KEYWORD_INFERENCE` | Privacy Guardian |
| PG-A5 | Continuo (publicación) | Comunidad + Project Owner |
| PG-A6 (nuevo) | Code review de logs en `classifier.rs` | QA Auditor |
| R-A7 | Verificación de cabecera del módulo | QA Auditor |

### 6.4 Narrativa verificable post-implementación

Cuando Capa A esté implementada y desplegada, el producto puede
declarar lo siguiente con respaldo de auditoría pública:

> "FlowWeaver clasifica los recursos que guardas en categorías
> generales como cocina, deportes o gobierno. Lo hace con una tabla
> pública de dominios y, cuando el dominio no está en la tabla, con
> reglas determinísticas que comparan el path de la URL y el título
> contra una lista de palabras clave generales. La tabla, las reglas
> y la lista están en el código abierto de FlowWeaver. No leemos el
> contenido de las páginas que visitas; el título que utilizamos
> solo es el que tu navegador o app comparte con FlowWeaver al
> guardar el recurso, y nunca abandona tu dispositivo en claro: lo
> ciframos antes de almacenarlo."

---

## 7. Siguiente Agente Responsable

1. **Desktop Tauri Shell Specialist** — implementación Rust
   siguiendo el plan de implementación de TS-3-006 §"Plan de
   Implementación". El AC-A7 queda satisfecho por este documento.
2. **Android Share Intent Specialist** — implementación Kotlin
   paralela con paridad estricta de las tres tablas (TLD,
   subdominio, keyword).
3. **QA Auditor** — verificación de AC-A1..AC-A8 + PG-A6 + R-A7
   sobre el código antes de merge.
4. **Privacy Guardian** — re-auditoría puntual cuando el
   diccionario se amplíe más allá del mínimo viable (PG-A4).

---

## 8. Trazabilidad

| Acción | Archivo | Estado |
|---|---|---|
| Revisado | operations/task-specs/TS-3-006-classifier-capa-a.md | LEÍDO — controles PG-A1..PG-A5 ratificados |
| Revisado | operations/architecture-reviews/PGR-CR-004-classifier-enrichment.md | LEÍDO — controles base |
| Revisado | operations/task-specs/TS-0a-003-domain-category-classifier.md | LEÍDO — sección Capa A coherente con TS-3-006 |
| Revisado | Project-docs/decisions-log.md | LEÍDO — D1 autoriza operación upstream del cifrado |
| Creado | operations/architecture-reviews/PGR-T-3-006-classifier-capa-a.md | este documento |

---

## Firma

```
reviewed_by: Privacy Guardian
review_date: 2026-05-04
status_detail: |
  APROBADO. Los 5 controles PG-A1..PG-A5 declarados en PGR-CR-004 están
  materializados en TS-3-006 como AC verificables y restricciones de
  scope. El input de Capa A.3 opera exclusivamente sobre `path_tokens`
  y `title_tokens` derivados de `url` y `title` recibidos en claro
  upstream del cifrado de SQLCipher — no hay acceso a campos cifrados.
  El diccionario mínimo viable (5 categorías × 8-10 keywords) cumple
  PG-A2 sin excepciones; cualquier ampliación posterior pasa por
  PG-A4. Se añade un sexto control PG-A6 (logs sin campos sensibles)
  como control vivo durante la implementación. R-A7 (riesgo de
  malinterpretación) queda cerrado por la documentación obligatoria
  de cabecera en `classifier.rs` que TS-3-006 ya impone como
  bloqueante de PR. AC-A7 de TS-3-006 satisfecho por este documento.
  La implementación de T-3-006 puede comenzar tras commit de esta
  PGR.
```
