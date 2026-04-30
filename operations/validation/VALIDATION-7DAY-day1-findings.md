# VALIDATION-7DAY — Day 1 Findings

date: 2026-04-30
session: prueba de 7 días, día 0 efectivo (primer ciclo completo)
validated_by: Product Owner (Orchestrator)
bridge_status: OPERATIVO — latencia ~30s, 5/5 URLs recibidas

---

## Resultado del puente

- Latencia observada: ~30 segundos captura→aparición en desktop.
- Umbral P95 < 60s: SATISFECHO.
- Consistencia: 5 URLs compartidas, 5 recibidas. 0 pérdidas.
- R14 desktop: MITIGADO — desktop se actualizó solo sin acción del usuario.
- R15: MITIGADO — latencia medida, dentro de umbral.

---

## H-001 — YouTube no guarda título

**Severidad:** media
**Afecta:** wow directo — el usuario ve URL cruda en lugar del nombre del vídeo.

**Descripción:**
Al compartir un enlace de YouTube desde la tablet, el recurso llega al desktop sin título. Solo la URL está presente.

**Causa probable:**
`ShareIntentActivity.kt` lee el título del intent desde `Intent.EXTRA_TEXT` (el URL) pero no lee `Intent.EXTRA_SUBJECT` (donde YouTube y otras apps colocan el título del contenido al compartir). Cuando `EXTRA_SUBJECT` es null o vacío, el título queda vacío y se cifra como string vacío.

**¿Fix antes de cerrar los 7 días?** SÍ — decidido por PO.
**Razón:** impacto directo en wow. Fix rápido (leer `EXTRA_SUBJECT` en ShareIntentActivity). Sin riesgo arquitectural.

**Archivo afectado:**
`FlowWeaver/src-tauri/gen/android/app/src/main/java/com/flowweaver/app/ShareIntentActivity.kt`

---

## H-002 — Categorías demasiado genéricas

**Severidad:** media
**Afecta:** legibilidad del workspace anticipado.

**Descripción:**
5 películas de terror compartidas, todas categorizadas igual pero con categoría genérica (p.ej. "entretenimiento" o "other"). El usuario espera ver "cine" o "terror". La taxonomía actual del Classifier no distingue contenido cinematográfico con suficiente granularidad.

**Causa probable:**
El Classifier usa una taxonomía de dominios (domain→category) que agrupa todo el entretenimiento bajo una categoría amplia. No tiene señales de path/título para subdistinguir subgéneros.

**¿Fix antes de cerrar los 7 días?** NO — decidido por PO.
**Razón:** la revisión de taxonomía es trabajo mayor. No impide la validación del puente. Se evalúa post-7-días.

---

## H-003 — 5 películas de terror no se agrupan como episodio

**Severidad:** alta — mata el wow del workspace anticipado.

**Descripción:**
5 URLs de películas de terror compartidas dentro de la misma ventana temporal (sesión de ~30 minutos). El Episode Detector no las agrupa como un episodio de trabajo. El desktop las muestra como recursos sueltos o en clusters distintos.

**Causas posibles (por diagnosticar):**
1. **H-002 como upstream:** si el Classifier dispersa en categorías distintas, el Episode Detector no las ve como sesión coherente (usa category/domain como clave de agrupación nivel 1).
2. **Jaccard threshold demasiado alto:** si los tokens de los títulos no comparten suficiente vocabulario (distintos dominios, títulos distintos), el threshold de similitud no agrupa.
3. **Dominios distintos:** 5 películas en 5 dominios diferentes → el grouper crea 5 clusters, el Episode Detector los trata como recursos independientes.
4. **Ventana temporal insuficiente para el detector:** si el gap entre capturas supera el umbral de gap del Session Builder, se crean sesiones separadas.

**¿Fix antes de cerrar los 7 días?** SÍ — decidido por PO.
**Razón:** sin agrupación el wow no dispara. H-003 es la hipótesis core de FlowWeaver. Si no se valida en los 7 días, el resultado de la prueba pierde valor.

**Diagnóstico pendiente:**
- Ver qué categorías asignó el Classifier a los 5 recursos.
- Ver qué sesiones creó el Session Builder.
- Ver si el Episode Detector los juntó o separó.
- Ajustar threshold o lógica de agrupación según hallazgo.

---

## Acciones para próxima sesión

| Prioridad | Hallazgo | Acción |
|---|---|---|
| 1 | H-001 | Fix `ShareIntentActivity.kt`: leer `EXTRA_SUBJECT` como `titleRaw`. Rebuild APK. |
| 2 | H-003 | Diagnosticar: consultar DB desktop para ver categorías y sesiones de los 5 recursos. Ajustar Episode Detector o Session Builder. |
| 3 | H-002 | Defer post-7-días. |
