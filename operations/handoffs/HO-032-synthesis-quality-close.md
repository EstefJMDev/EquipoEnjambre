# HO-032 — Cierre: HO-3-synthesis-quality

**Estado:** CLOSED  
**Fecha cierre:** 2026-05-06  
**Agente implementador:** Claude Code (claude-sonnet-4-6)  
**Orchestrator:** Estef (EstefJMDev)

---

## Resumen de ejecución

Handoff de mejora de calidad de síntesis LLM. Cambio de modelo Llama 3.1 8B → Llama 3.3 70B instruct-fp8-fast en Cloudflare Workers AI. Reescritura completa de los 4 prompts. Deploy a producción verificado end-to-end.

---

## Commits incluidos

### Repo: `flowweaver-proxy`

| Commit | Tarea | Descripción |
|---|---|---|
| `531a307` | T-3-quality-1 | Llama 3.3 70B instruct-fp8-fast + timeout 12s |
| `5d416e4` | T-3-quality-2 | max_tokens Haiku 2048 |
| `f724768` | T-3-quality-7 | Guard titles vacío → INVALID_BODY |
| `e42dd92` | T-3-quality-3 | Prompt cocina — 5 secciones completas |
| `677a22d` | T-3-quality-4 | Prompt entretenimiento — entrada completa por título |
| `065242b` | T-3-quality-5 | Prompt tecnología — tabla comparativa + riesgos |
| `ba3c866` | T-3-quality-6 | Prompt noticias — estructura mejorada, prudencia HO-3 preservada |
| `9e044f6` | T-3-quality-8 | Entorno preview en wrangler.toml |
| `c8198d3` | T-3-quality-9 | Fix max_tokens 2048 + String(chunk) en cloudflare_ai |
| `1723d0e` | T-3-quality-10 | Norma anti-ambigüedad en prompt entretenimiento |

### Repo: `FlowWeaver` (desktop)

| Commit | Tarea | Descripción |
|---|---|---|
| `997980c` | T-3-quality-9 | Fix parse_sse_chunk acepta chunks numéricos/booleanos de Cloudflare AI |
| `11126b1` | T-3-quality-11 | Disclaimer IA en SynthesisView + CSS + revertir PROXY_URL a producción |

---

## Hallazgo crítico durante ejecución: fix de producto

**Bug encontrado:** `parse_sse_chunk` en `synthesis_engine.rs` solo aceptaba `chunk` como string JSON. Cloudflare AI emite chunks numéricos (`{"chunk": 30}`) para cantidades en recetas. El resultado visible: cantidades de ingredientes y tiempos aparecían vacíos en la app desktop.

**Fix aplicado:** match exhaustivo sobre `serde_json::Value` — String, Number, Bool. Test añadido: `test_parse_sse_chunk_handles_numeric`. Este fix afecta al producto final (no solo al script de prueba).

---

## Métricas finales (producción, streaming activo)

| Categoría | Latencia bruta | Chars output | Primer chunk |
|---|---|---|---|
| Cocina | ~34s | ~5000 | ~3-4s |
| Entretenimiento | ~25s | ~3000 | ~3-4s |
| Tecnología | ~46s | ~6500 | ~3-4s |
| Noticias | ~10s | ~1300 | ~3-4s |

**Nota latencia:** el primer chunk llega en 3-4s para todas las categorías. La latencia bruta es alta pero el streaming hace la espera perceptualmente razonable. Decisión del Orchestrator: mantener Llama 3.3 70B, no bajar max_tokens.

---

## Calidad observada en preview/producción

- **Cocina:** 3 recetas independientes con 5 secciones completas, cantidades reales (60g, 200g), temperaturas exactas (180°C, 160°C, 220°C), 9-10 pasos. ✅
- **Entretenimiento:** todos los títulos listados, IMDb: N/D honesto, "consultar JustWatch" cuando no sabe. Norma anti-ambigüedad añadida (T-3-quality-10) para reducir errores tipo "Civil War". ✅
- **Tecnología:** tabla comparativa Markdown válida, sección "Cuándo elegir cada una", URLs de docs oficiales, sección de riesgos. ✅
- **Noticias:** agrupación literal de titulares, tabla de fuentes, cero contexto inventado. ✅

---

## Alucinaciones detectadas en testing

| Caso | Descripción | Mitigación aplicada |
|---|---|---|
| Civil War (2024) | Modelo identificó como película Marvel en lugar de thriller de Alex Garland (título ambiguo) | Norma anti-ambigüedad añadida a entretenimiento.txt (T-3-quality-10) |

---

## Hallazgos colaterales para próximo handoff

1. **Latencia tecnología/cocina > 15s:** output largo (~6000 chars) con 2048 max_tokens y modelo 70B produce latencias brutas altas. Aceptado por ahora (streaming). Candidato a optimización en HO-3-coverage si hay feedback de usuarios.
2. **`synthesis_engine.rs::generate_and_persist` dead code:** función marcada como `#[warn(dead_code)]`. No bloquea. Candidata a eliminación en sprint de limpieza.
3. **Wrangler 3.114 desactualizado:** aviso en cada deploy. Actualización a wrangler@4 recomendada pero no urgente.
4. **Categorías no cubiertas:** `otro`, `deportes`, `educacion`, `finanzas`, etc. no tienen prompt → fallback a `noticias`. Pending: HO-3-synthesis-coverage.

---

## Estado de producción al cierre

- **URL producción:** `https://flowweaver-proxy.bananasplitsound.workers.dev`
- **Modelo activo:** `@cf/meta/llama-3.3-70b-instruct-fp8-fast`
- **max_tokens:** 2048
- **prompt_version activa:** v1 (sobrescrita, sin v2)
- **Token de acceso beta:** `fw-beta-463be222-f54e-438e-b61d-cb0f82eab909` (en KV producción)
- **Verificación E2E:** ✅ 4 categorías respondiendo en producción

---

## Próximo handoff sugerido

**HO-3-synthesis-coverage** — mapping completo de categorías y auto-síntesis en modo Autonomous.
