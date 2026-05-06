# HO-033 — Cierre: HO-3-synthesis-coverage

**Estado:** CLOSED  
**Fecha cierre:** 2026-05-06  
**Agente implementador:** Claude Code (claude-sonnet-4-6)  
**Orchestrator:** Estef (EstefJMDev)

---

## Resumen de ejecución

Handoff de cobertura completa de categorías de síntesis LLM. Mapa ampliado de 12 → 23 entradas con normalización NFD de tildes. 8 prompts nuevos creados con disclaimers legales en salud y finanzas. Auto-síntesis en estado Autonomous con cooldown 90s. Indicador discreto de auto-generación.

---

## Commits incluidos

### Repo: `flowweaver-proxy`

| Commit | Tarea | Descripción |
|---|---|---|
| `dda3ea0` | T-3-coverage-1 | 8 prompts nuevos: gaming musica ciencia viajes salud deportes finanzas educacion |
| `ca8b367` | T-3-coverage-3 | VALID_TYPES + PROMPTS ampliados a 12 tipos en proxy |
| `1723d0e` | (T-3-quality-10) | Entorno preview en wrangler.toml — deploy previo a este HO |

### Repo: `FlowWeaver` (desktop)

| Commit | Tarea | Descripción |
|---|---|---|
| `0337a05` | T-3-coverage-2 | normalizeCategory NFD + mapa ampliado a 23 entradas + mapCategoryToSynthesisType null |
| `55acb00` | T-3-coverage-4+5 | Auto-síntesis Autonomous cooldown 90s + useSynthesis levantado + indicador discreto |

---

## Tests añadidos

### `src/utils/synthesisCategory.test.ts` (11 tests nuevos)
- `mapCategoryToSynthesisType('música')` → `'musica'`
- `mapCategoryToSynthesisType('tecnología')` → `'tecnologia'`
- `mapCategoryToSynthesisType('diseño')` → `'tecnologia'`
- `mapCategoryToSynthesisType('comercio')` → `null`
- `mapCategoryToSynthesisType('educación')` → `'educacion'`
- `mapCategoryToSynthesisType('vídeo')` → `'entretenimiento'`
- `canSynthesize('música')` → `true`
- `canSynthesize('comercio')` → `false`
- `canSynthesize('otro')` → `false`
- `canSynthesize('gaming')` → `true`
- `canSynthesize('salud')` → `true`

---

## Métricas de latencia (preview, con streaming activo)

| Tipo | Latencia bruta | Chars | Primer chunk |
|---|---|---|---|
| gaming | 18.2s | 2159 | ~3s |
| musica | 23.2s | 2602 | ~3s |
| ciencia | 20.6s | 3173 | ~3s |
| viajes | 12.0s | 1531 | ~3s |
| salud | 5.9s | 780 | ~2s |
| deportes | 5.2s | 590 | ~2s |
| finanzas | 7.3s | 736 | ~2s |
| educacion | 11.7s | 1680 | ~3s |

Salud/deportes/finanzas rápidos por diseño (agrupación de titulares + disclaimers, sin generar contenido extenso).

---

## Decisiones de arquitectura aplicadas

**normalizeCategory NFD**: función única en `synthesisCategory.ts` que normaliza antes del lookup. Claves del mapa siempre ASCII. Evita duplicar entradas por variantes con tilde.

**mapCategoryToSynthesisType retorna null**: eliminado el fallback a `'noticias'`. Categorías sin síntesis (`social`, `comercio`, `inmobiliario`, `artículos`, `notas`, `otro`) → `canSynthesize = false` → sin botón. Bug previo: episodios de "comercio" mostraban síntesis ridícula de noticias.

**useSynthesis levantado a AnticipatedWorkspace**: permite que el cooldown tenga acceso directo a `generateIfIdle`. `SynthesisView` se convierte en componente controlado (recibe state/generate como props). `EpisodePanel` no afectado — mantiene su propio hook.

**BD load reactivo a anchorKey**: el `useEffect` del BD load ahora depende de `[anchorKey]` en lugar de `[]`. Reset inmediato al cambiar de episodio. Evita mostrar síntesis del episodio anterior cuando llega un nuevo episodio.

**generateIfIdle**: usa `stateRef` (no closure) para leer el estado actual antes de generar. Si el episodio ya tiene síntesis en BD, no genera de nuevo.

---

## Disclaimers legales verificados por Orchestrator

- **salud.txt**: disclaimer absoluto al inicio + cierre "Consulta a un profesional sanitario". Modelo NO sugirió tratamientos ni medicamentos. ✅
- **finanzas.txt**: disclaimer absoluto al inicio + cierre "Las decisiones financieras requieren asesoramiento profesional". Modelo NO recomendó inversiones. ✅

---

## Hallazgos colaterales

1. **Quirk de formato en listas cortas de fuentes** — Llama 3.3 70B no inserta saltos de línea consistentes en listas cortas de dominios (ej. `redaccionmedica.com: 1 elmundosalud.es: 1` en la misma línea en salud/finanzas). El renderer Markdown del desktop lo procesa parcialmente. Candidato a retoque de prompt en iteración futura: añadir instrucción "cada dominio en una línea separada con guión al inicio". No bloquea producción.

2. **`generate_and_persist` dead code en synthesis_engine.rs** — función marcada como dead code desde HO-3-quality. Candidata a eliminación en sprint de limpieza.

---

## Estado al cierre

- **Proxy producción**: `https://flowweaver-proxy.bananasplitsound.workers.dev` — 12 tipos activos
- **Categorías con síntesis**: cocina, entretenimiento, noticias, tecnologia, gaming, musica, ciencia, viajes, salud, deportes, finanzas, educacion
- **Categorías sin síntesis (sin botón)**: social, comercio, inmobiliario, artículos, notas, otro
- **Auto-síntesis Autonomous**: activa con cooldown 90s, indicador discreto "Generada automáticamente"
- **Mapa SYNTHESIS_CATEGORY_MAP**: 23 entradas, normalización NFD, retorna null (no fallback)

---

## Próximo handoff sugerido

**HO-3-synthesis-variants** — síntesis alternativas para el mismo episodio (Receta completa / Lista de la compra / Versión rápida). Pre-requisito: validar con usuarios beta que la cobertura actual de categorías es suficiente. Handoff condicional según feedback de Orchestrator.
