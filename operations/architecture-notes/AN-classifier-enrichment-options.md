# AN-classifier-enrichment-options — Opciones de enriquecimiento del Classifier post-MVP

**Status:** NOTA DE FUTURO — sin ejecutar  
**Owner:** Functional Analyst + Privacy Guardian  
**Fecha:** 2026-04-30  
**Contexto:** Nivel 3 identificado durante H-002/H-003. El Classifier actual (Nivel 1) asigna categorías por dominio exacto. Estas opciones amplían la señal disponible sin modificar D1 ni D8.

---

## 3a — Metadata del Share Intent Android

**Qué gana:** Acceso a `Intent.EXTRA_SUBJECT`, `Intent.EXTRA_TEXT`, `Intent.EXTRA_TITLE` en el momento de la captura. Sin red. Sin inferencia. Datos en el dispositivo en el instante del share.

**Qué pierde:** Solo disponible en el path Android (Share Extension). No aplica a bookmarks importados desde Chrome/Edge. Cobertura parcial.

**Decisiones que requiere:**
- D1: `EXTRA_TEXT` puede contener la URL completa — debe cifrarse igual que `url`. `EXTRA_SUBJECT` y `EXTRA_TITLE` son equivalentes a `title` — mismo régimen. No se puede almacenar en claro.
- D8: No introduce LLM. Compatible si se usa solo para clasificación local determinística.
- Requiere decisión nueva: definir qué campos de Share Intent se procesan, cuáles se cifran, cuáles se descartan.

---

## 3b — HEAD request / primeros 4KB para og:tags

**Qué gana:** `og:title`, `og:description`, `og:type` permiten clasificar URLs de dominios no conocidos. Mejora cobertura de `otro`.

**Qué pierde:** Requiere llamada de red en el momento de la captura. Introduce latencia. Falla si el dispositivo está offline. Puede exponer el historial de navegación a servidores de destino.

**Decisiones que requiere:**
- D1: El servidor de destino ve la petición — esto es emisión de datos de navegación. Rompe D1 en espíritu si se hace automáticamente. Requiere revisión Privacy Guardian.
- D8: Determinístico en el resultado, pero introduce dependencia de red. Requiere definición de "sin red" en D8.
- Requiere: gate de consentimiento explícito del usuario antes de activar cualquier fetch, no opt-out.

---

## 3c — oEmbed APIs para dominios conocidos

**Qué gana:** Para dominios con endpoint oEmbed público (YouTube, Vimeo, Twitter/X, etc.) se puede obtener título canónico, thumbnail, tipo de contenido. Mejora el label del episodio y la legibilidad en PanelA.

**Qué pierde:** Requiere llamada de red. Lista de endpoints debe mantenerse. Respuestas varían entre dominios. YouTube oEmbed no requiere API key; otros sí.

**Decisiones que requiere:**
- D1: El endpoint oEmbed ve la URL — misma exposición que 3b. Requiere mismo gate de consentimiento.
- D8: Dependencia de API externa rompe "baseline determinístico". Debe declararse como mejora opcional con fallback explícito al resultado sin oEmbed.
- Requiere: whitelist de dominios con oEmbed aprobados, versionada y auditable.

---

## Resumen de restricciones comunes

| Opción | Red | D1 riesgo | D8 impacto | Gate necesario |
|--------|-----|-----------|------------|----------------|
| 3a     | No  | Alto (EXTRA_TEXT = URL) | Nulo | Decisión sobre campos Share Intent |
| 3b     | Sí  | Alto (fetch revela URL) | Medio | Consentimiento explícito + revisión Privacy Guardian |
| 3c     | Sí  | Alto (fetch revela URL) | Medio | Consentimiento explícito + whitelist dominios |

Ninguna de estas opciones debe ejecutarse sin backlog aprobado y gate de fase.
