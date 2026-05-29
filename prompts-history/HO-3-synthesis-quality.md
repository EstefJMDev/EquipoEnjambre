# HO-3-synthesis-quality — mejora de calidad de síntesis

## Contexto

El Orchestrator ha validado en uso real que las síntesis del proxy salen
escuetas: pocas películas listadas en entretenimiento, recetas sin tiempo
ni temperatura, listas que se quedan a la mitad. El proveedor primario
(Cloudflare AI con Llama 3.1 8B) está respondiendo correctamente, pero la
combinación de modelo pequeño + prompts limitantes da resultados pobres.

Este handoff aborda el problema en dos frentes:

1. Cambio de modelo en Cloudflare AI: Llama 3.1 8B → Llama 3.3 70B Instruct.
   Mismo provider, mismo binding `env.AI`, sin coste extra (ambos en free
   tier de Workers AI). Mejora sustancial de calidad sin cambiar arquitectura.
2. Reescritura de los cuatro prompts (`cocina`, `entretenimiento`, `noticias`,
   `tecnologia`) para pedir explícitamente más contenido, más estructura, y
   honestidad sobre datos que el modelo no conoce.

## Decisiones que NO se tocan

- **D25**: payload sigue siendo los 5 campos canónicos. No añadas campos.
  No accedas a URL ni a contenido de páginas. Lo único que cambia es el
  prompt al que se inyectan `{titles}` y `{domains}`.
- **D8**: el baseline determinístico no se toca. Esta tarea solo afecta al
  proxy LLM, que es opcional por D8.
- **D23**: los providers (Cloudflare AI primario, Claude Haiku fallback)
  no cambian. Solo se actualiza el modelo dentro de Cloudflare AI.
- **Proxy zero-retention**: no se persiste nada nuevo en el proxy. KV se
  usa como hasta ahora.
- **Prompt de noticias hardened en HO-3 tarea 11**: no lo deshagas. La línea
  de "no inventes contexto, trabaja solo con titulares" se mantiene. Lo que
  cambia es la estructura del output, no la prudencia del modelo.

## Tareas

### 1. Cambio de modelo en `cloudflare_ai.ts`

**Archivo**: `flowweaver-proxy/src/providers/cloudflare_ai.ts`

**Cambio**:

```ts
const MODEL = "@cf/meta/llama-3.3-70b-instruct-fp8-fast";
const TIMEOUT_MS = 12000;
```

Sustituye los dos valores actuales (`@cf/meta/llama-3.1-8b-instruct` y
`8000`). El timeout sube a 12s porque el modelo más grande responde algo
más lento, especialmente en el primer token.

**Validación**: el resto del archivo no cambia. La API de `env.AI.run()`
es idéntica para ambos modelos. El parsing SSE tampoco cambia.

### 2. Subir `max_tokens` del fallback Haiku

**Archivo**: `flowweaver-proxy/src/providers/claude_haiku.ts`

**Cambio**:

```ts
const MAX_TOKENS = 2500;
```

Sustituye `1000`. Razón: cuando Haiku entra como fallback, las síntesis
nuevas (más largas y detalladas) van a cortarse a 1000 tokens. 2500 es un
margen seguro para los nuevos prompts sin disparar coste — Haiku solo se
usa si Cloudflare AI cae.

### 3. Reescritura del prompt `cocina.txt`

**Archivo**: `flowweaver-proxy/src/prompts/v1/cocina.txt`

Sustituye el contenido completo por:

```
Eres un asistente de cocina experto que ayuda a organizar recetas que el
usuario ha guardado. El usuario ha consultado estos recursos:
Títulos: {titles}
Dominios: {domains}

NORMAS:
- Sé generoso en detalle. Una receta útil tiene tiempo, temperatura,
  cantidades concretas y pasos claros.
- Si reconoces el plato exacto, da la versión clásica con cantidades
  precisas.
- Si los títulos sugieren varias recetas distintas, crea una sección
  completa para cada una. No las fusiones.
- No inventes recetas que no existen. Si un título no te dice nada
  reconocible, dilo.

Genera un resumen detallado en español con este formato Markdown exacto:

## Plato identificado

[Nombre del plato. Si hay varios, lista los nombres aquí. Una frase de
contexto: origen, tipo de plato (entrante/principal/postre), nivel de
dificultad (fácil/medio/avanzado).]

## Tiempo y rendimiento

[Tiempo de preparación activa, tiempo total incluyendo reposos/horneado,
y cuántas raciones salen. Formato:
- Preparación: X min
- Cocción/horno: X min
- Total: X min
- Raciones: para X personas]

## Ingredientes

[Lista completa con cantidades concretas para 4 personas. Agrupa por
secciones si tiene sentido (masa, relleno, salsa). Incluye ingredientes
opcionales marcándolos con "(opcional)".]

## Preparación paso a paso

[Entre 8 y 12 pasos numerados. Cada paso describe una acción concreta,
no varias. Incluye:
- Temperaturas exactas del horno (ej. "180 °C calor arriba y abajo")
- Tiempos de cocción ("hornear 25 minutos")
- Tiempos de reposo si aplican
- Indicadores visuales para saber cuándo el paso está listo
  ("hasta que dore", "cuando burbujee en los bordes")]

## Trucos y variaciones

[3 a 5 consejos prácticos. Pueden ser:
- Trucos para que salga mejor
- Sustituciones habituales de ingredientes
- Variaciones regionales o creativas
- Errores comunes a evitar
- Cómo conservarlo o recalentarlo]

Si los títulos contienen varias recetas distintas, repite las cinco
secciones para cada una con un encabezado `# Receta: [Nombre]` arriba
para separarlas.
```

### 4. Reescritura del prompt `entretenimiento.txt`

**Archivo**: `flowweaver-proxy/src/prompts/v1/entretenimiento.txt`

Sustituye el contenido completo por:

```
Eres un asistente que ayuda a organizar contenido de entretenimiento
(películas, series, documentales, juegos) que el usuario ha guardado.
El usuario ha consultado estos recursos:
Títulos: {titles}
Dominios: {domains}

NORMAS:
- Lista TODO el contenido identificable de los títulos, no solo los más
  conocidos. Si hay 8 películas en los títulos, lista las 8.
- Para cada título, da la mayor cantidad de información que conozcas con
  seguridad razonable. Si dudas, indícalo con "(aprox.)".
- Sobre puntuaciones: si conoces la nota IMDb con seguridad razonable,
  inclúyela como "IMDb: 7.8". Si no la conoces, escribe "IMDb: N/D".
  NO inventes notas. Es preferible "N/D" que un número falso.
- Sobre disponibilidad en plataformas: di solo plataformas donde sepas
  con seguridad razonable que está disponible en España. Si dudas,
  escribe "Plataforma: consultar JustWatch".

Genera un resumen detallado en español con este formato Markdown exacto:

## Contenido identificado

[Para CADA título reconocido, una entrada con esta estructura:

### {Nombre original} ({Año})
- Tipo: película / serie / documental / juego / otro
- Género: {géneros principales}
- Duración: {minutos para películas | temporadas y episodios para series}
- Director / showrunner: {nombre, si lo conoces}
- Reparto principal: {2-4 nombres si los conoces}
- Sinopsis: {2-3 líneas de qué va sin spoilers}
- IMDb: {nota o N/D}
- Plataforma en España: {Netflix / HBO Max / Filmin / Prime Video / etc o
  "consultar JustWatch"}

Si un título no lo reconoces, lístalo igualmente bajo "### {Título}
(no identificado)" con una nota: "No tengo información fiable sobre este
título."]

## Orden sugerido

[Si hay varios títulos relacionados (saga, mismo director, mismo género):
sugiere un orden con justificación. Si son independientes: agrúpalos por
afinidad (ej. "Para una sesión de terror clásico", "Para maratón de los
años 80") con 2-3 grupos.]

## Recomendación destacada

[De los títulos listados, cuál destacarías y por qué. Una frase concreta
del tipo "Si solo vas a ver una, esta porque..."]

Sé exhaustivo. Es preferible una entrada larga con honestidad sobre lo
que no sabes que una lista corta de los títulos más fáciles.
```

### 5. Reescritura del prompt `tecnologia.txt`

**Archivo**: `flowweaver-proxy/src/prompts/v1/tecnologia.txt`

Sustituye el contenido completo por:

```
Eres un asistente técnico experto que ayuda a evaluar herramientas,
frameworks y tecnologías. El usuario ha investigado estos recursos:
Títulos: {titles}
Dominios: {domains}

NORMAS:
- Identifica todas las herramientas/tecnologías mencionadas, no solo
  las principales.
- Para comparativas, sé específico: versiones, fechas de release, casos
  de uso reales. Evita generalidades.
- Si una herramienta es muy nueva o muy nicho y no tienes información
  fiable, dilo: "No tengo información actualizada sobre {nombre}".
- No inventes características, benchmarks ni adopciones que no conozcas.

Genera un resumen detallado en español con este formato Markdown exacto:

## Herramientas identificadas

[Para CADA herramienta/tecnología/framework reconocido, una entrada con
esta estructura:

### {Nombre}
- Categoría: {framework / lenguaje / librería / SaaS / CLI / etc}
- Para qué sirve: {descripción concreta de 2-3 líneas}
- Lenguaje/stack: {si aplica}
- Modelo: {open source / comercial / freemium con detalles si los conoces}
- Madurez: {experimental / estable / battle-tested / en declive}
- Comunidad: {tamaño relativo, actividad reciente si la conoces}]

## Comparativa

[Tabla en Markdown con las herramientas listadas, columnas:
| Herramienta | Punto fuerte | Limitación principal | Mejor caso de uso |

Si solo hay una herramienta, omite esta sección.]

## Cuándo elegir cada una

[Para cada herramienta, una frase de cuándo es la decisión correcta y
cuándo no. Si son complementarias entre sí, di cómo se combinan.]

## Cómo empezar

[Para cada herramienta principal:
- Documentación oficial: {URL del dominio raíz si la conoces}
- Recurso para arrancar: {tutorial, getting started, ejemplo mínimo}
- Tiempo estimado para tener algo funcionando: {ej. "30 min", "una tarde"}]

## Riesgos y consideraciones

[2-4 puntos sobre:
- Lock-in vendor si aplica
- Coste real en producción si no es obvio
- Curva de aprendizaje
- Compatibilidad con stacks comunes
- Cualquier "trampa" conocida que un evaluador debería conocer antes
  de comprometerse]

Sé técnico y concreto. El usuario está evaluando para una decisión real,
no quiere generalidades de marketing.
```

### 6. Mantener `noticias.txt` con la prudencia del HO-3

**Archivo**: `flowweaver-proxy/src/prompts/v1/noticias.txt`

**No reescribas este prompt desde cero.** El HO-3 tarea 11 endureció este
prompt para evitar alucinaciones de eventos posteriores al cutoff. Esa
decisión sigue siendo correcta — noticias es la categoría de mayor riesgo
reputacional.

Lo único que ajustamos aquí es ampliar la sección "Temas detectados" para
que dé más estructura. Sustituye el contenido por:

```
Eres un asistente que organiza titulares de noticias guardados por el
usuario. El usuario ha guardado estos titulares:
Títulos: {titles}
Dominios: {domains}

NORMAS ABSOLUTAS:
- No describas eventos. No expliques contexto. No conjeturas sobre lo
  que pasó. Trabaja solo con lo que dicen literalmente los titulares.
- Si no reconoces un titular, no lo expliques. Lístalo.
- No menciones fechas de eventos. No inventes datos.
- No tomes posición política ni editorial.

Genera un resumen en español con este formato Markdown exacto:

## Temas detectados

[Agrupa los titulares por tema general. Para cada tema:

### {Tema en una frase corta}
- Titulares ({N}):
  1. "{titular literal}" — {dominio}
  2. "{titular literal}" — {dominio}
  ...
- Encuadre detectado: {de los titulares, qué ángulo predomina:
  análisis / opinión / breaking / longread / entrevista / etc.
  Sin valorar el ángulo, solo describirlo.}

Si un titular no encaja en ningún tema con otros, agrúpalo bajo
"### Otros titulares".]

## Fuentes consultadas

[Tabla con dominios distintos:
| Dominio | Titulares | Encuadre dominante |

Una fila por dominio, contando cuántos titulares tienes de cada uno.]

## Sugerencia

[Una sola frase que diga: "Tienes {N} titulares sobre {tema dominante}
de {N} fuentes — puede que quieras ponerte al día." Sin más contenido,
sin opinión.]

Recuerda: tu trabajo es organizar, no informar. El usuario ya leyó (o
leerá) los titulares. Tú solo le ayudas a ver el bosque.
```

### 7. Pequeño retoque en validación de input del proxy

**Archivo**: `flowweaver-proxy/src/index.ts`

**Problema**: el `buildPrompt` actual filtra `[`\\]` para mitigar prompt
injection, pero si los títulos están vacíos (`titles: []`), inyecta un
string vacío en `{titles}` y el modelo se confunde.

**Fix**: añadir guard al inicio de la función, antes de llamar a `cloudflareAi.stream`:

```ts
if (body.titles.length === 0 || body.titles.every(t => !t || typeof t !== "string")) {
  return jsonError(400, "INVALID_BODY");
}
```

Sitúa este chequeo justo después de validar `synthesis_type` y antes de
cargar el prompt template.

### 8. Verificación del payload con `prompt_version`

**Archivo**: `flowweaver-proxy/src/index.ts`

El parámetro `prompt_version` sigue siendo `"v1"` por defecto. **No crees
una v2.** Mantenemos v1 y reescribimos su contenido. Razón: la coherencia
del cliente desktop, que envía `prompt_version: "v1"` hardcoded en
`build_synthesis_payload`, no necesita cambios. Si en el futuro se quiere
A/B testing, ahí sí se introduce v2 — fuera de scope de este handoff.

## Deploy

**Despliegue por etapas:**

1. **Preview environment** primero. Ejecuta:
   ```bash
   cd flowweaver-proxy
   wrangler deploy --env preview
   ```
   Si no tienes entorno preview configurado, créalo en `wrangler.toml`
   con su propio KV namespace de tokens (puede ser el mismo, no es
   necesario duplicar).

2. **Validación con 3-4 síntesis reales** desde el desktop, apuntando al
   preview. Para eso, cambia temporalmente `PROXY_URL` en
   `src-tauri/src/commands.rs::generate_synthesis` a la URL del preview,
   o expón el URL como variable de entorno (recomendado).

3. **Si las síntesis salen como debe** (sin truncado, con estructura
   completa, con N/D donde corresponda en lugar de inventar):

   ```bash
   wrangler deploy
   ```

   Y revierte el `PROXY_URL` del desktop a producción.

**No despliegues a producción sin validación previa.** El cambio de
modelo es bajo en riesgo técnico (misma API) pero alto en riesgo de
comportamiento (output completamente diferente). Quieres ver con tus
ojos cómo sale antes de exponerlo a otros beta testers.

## Verificación final

Tras el deploy a preview:

1. Generar síntesis de cocina con 3 recetas distintas → comprobar que
   cada una tiene sus 5 secciones completas, 8-12 pasos, temperaturas y
   tiempos concretos.
2. Generar síntesis de entretenimiento con una lista de películas →
   comprobar que aparecen TODAS las películas con su año, sinopsis,
   IMDb (o N/D), plataforma.
3. Generar síntesis de tecnología con 2-3 herramientas → comprobar
   tabla comparativa.
4. Generar síntesis de noticias con 5+ titulares de fuentes distintas
   → comprobar que NO inventa contexto, solo agrupa.
5. Latencia total por síntesis: medir y reportar. Debería estar entre
   3 y 8 segundos para Llama 3.3 70B. Si supera 15s consistentemente,
   considera bajar el modelo a `@cf/meta/llama-3.1-70b-instruct` (sin
   variante fp8-fast) y reportar.

## Lo que NO debes hacer

- No introduzcas dependencias nuevas en el proxy (no `axios`, no
  `node-fetch`, no librerías de scraping). Solo cambios de string en
  los `.txt` y dos constantes en los `.ts`.
- No toques el desktop. Esta tarea es 100% en el repo `flowweaver-proxy`.
- No despliegues a producción sin validación en preview.
- No crees `v2` de prompts. Sobrescribe `v1`.
- No añadas campos al payload del proxy. D25 sigue siendo los 5 campos.
- No metas FilmAffinity scraping. Eso es T-3-enrichment-001, futuro.

## Entregables

1. Commits por tarea: cambio de modelo, max_tokens Haiku, cada prompt
   reescrito por separado, guard de input vacío. Mensaje:
   `[T-3-quality-N] Descripción`.
2. Resumen final con:
   - Output de `wrangler deploy --env preview` (URL del preview).
   - Las 4 síntesis de prueba pegadas literal en el resumen, una por
     categoría, para que el Orchestrator las inspeccione antes de
     aprobar deploy a producción.
   - Latencia media observada.
3. **Stop point antes de deploy a producción**: pásame las 4 síntesis y
   espera mi OK explícito antes de hacer `wrangler deploy` (sin `--env`).

## Hallazgos colaterales esperados

Es posible que tras el cambio de modelo descubras que Llama 3.3 70B está
rate-limited en el plan free de Workers AI (10000 requests/día compartidos).
Si te encuentras un 429 desde Cloudflare AI, no es bug del proxy: es el
límite del plan. Reporta y decidimos si subimos a paid plan o no.

También es posible que algunos prompts den salida que rompe Markdown (ej.
tablas mal formadas con Llama 3.3). Si lo detectas, repórtalo: el fix
suele ser ajustar la instrucción de tabla en el prompt, no cambiar el
modelo otra vez.