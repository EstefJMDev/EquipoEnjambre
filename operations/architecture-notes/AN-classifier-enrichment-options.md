# Architecture Note — Opciones de enriquecimiento del Classifier

date: 2026-04-30
owner_agents: Functional Analyst, Privacy Guardian
status: PLAN — inventario para evaluación post-prueba-7-días
referenced: H-002, H-003, D1, D8

## Contexto

El Classifier actual (classifier.rs) clasifica por tabla estática de
dominios. No analiza contenido de la URL ni hace fetch de metadata.
Detectado como limitación en validación E2E del 2026-04-30: 5
películas de terror de dominios distintos no se agrupaban.

Se aplicaron mejoras parciales (categorías ampliadas a 14 en español,
Episode Detector con tokens de URL). Estas mejoras cubren Broad mode
y casos básicos de Precise mode, pero no resuelven clasificación
semántica ni subcategorías temáticas.

## Opciones de enriquecimiento para evaluación futura

### Opción 3a — Metadata del Share Intent Android

Qué es: Android Share Intents pueden incluir EXTRA_SUBJECT (título
de la página), EXTRA_TEXT (URL), y ocasionalmente metadata adicional
según la app que comparte (Chrome, Instagram, etc.).

Qué gana: títulos reales sin hacer fetch. Chrome casi siempre envía
EXTRA_SUBJECT con el <title> de la página.

Qué pierde: depende de cada app. Instagram no envía título. YouTube
a veces sí, a veces no.

Impacto en D1: ninguno — la info ya está en el dispositivo, no sale.
Impacto en D8: ninguno — es determinístico.
Coste estimado: 1-2 horas (mejorar parsing de ShareIntentActivity.kt).

### Opción 3b — Fetch ligero de headers (HEAD + og:tags)

Qué es: GET con Range: bytes=0-4096 para leer solo los primeros
4KB de la página (donde suelen estar las meta tags og:title,
og:description, keywords).

Qué gana: metadata real de cualquier URL, independiente de la app
que compartió.

Qué pierde: latencia (1-5s por fetch), dependencia de red, funciona
distinto offline.

Impacto en D1: MEDIO — el dispositivo visita la URL y revela su IP
al servidor. Requiere consentimiento del usuario o al menos
transparencia ("FlowWeaver visitará brevemente la URL para obtener
su título").

Impacto en D8: ninguno si no se usa LLM para procesar el contenido.
Coste estimado: 3-5 horas (fetch + parsing HTML + manejo offline +
UI de consentimiento).

Requiere: CR formal (impacta D1).

### Opción 3c — oEmbed APIs para dominios conocidos

Qué es: APIs ligeras que devuelven título + thumbnail + metadata
en JSON. YouTube, Vimeo, Twitter/X, Instagram las soportan.

Qué gana: metadata estructurada y fiable para dominios populares.
No requiere parsear HTML.

Qué pierde: solo funciona para dominios con soporte oEmbed (no es
universal). Requiere red.

Impacto en D1: BAJO — la llamada va a la API del dominio, no a un
tercero. El dominio ya sabe que el contenido existe (es público).

Impacto en D8: ninguno.
Coste estimado: 2-3 horas (implementar para YouTube + Vimeo +
Twitter como MVP, extensible).

Requiere: decisión sobre qué pasa cuando la API no está disponible
(fallback a título del Share Intent o a "sin título").

### Opción 3d — NLP ligero sobre tokens existentes

Qué es: sin fetch, sin red. Usar los tokens que ya tiene el
Episode Detector (del título + URL) y aplicar heurísticas de
agrupación semántica: sinónimos básicos, detección de n-grams
comunes, categorización por vocabulario.

Qué gana: mejor agrupación sin dependencia externa.

Qué pierde: precisión limitada sin datos reales del contenido.
Vocabulario fijo que hay que mantener manualmente.

Impacto en D1: ninguno.
Impacto en D8: compatible si es reglas, no compatible si requiere
modelo ML.
Coste estimado: 4-8 horas (vocabulario + heurísticas + tests).

## Recomendación

Evaluar después de la prueba de 7 días. Orden sugerido de
implementación si se decide proceder:

1. 3a (metadata Share Intent) — coste bajo, impacto alto, sin
   riesgo de privacidad.
2. 3c (oEmbed para YouTube/Vimeo) — coste bajo-medio, impacto
   alto para los dominios más comunes.
3. 3d (NLP ligero) — si 3a+3c no son suficientes.
4. 3b (fetch HEAD) — último recurso, requiere CR por impacto en D1.

## Anti-objetivos

- NO introducir LLM obligatorio (D8).
- NO hacer scraping completo de páginas (excesivo para MVP).
- NO crear dependencia de servicio externo que no sea el propio
  dominio del contenido.
- NO almacenar metadata que identifique al usuario más allá de
  lo que D1 permite.
