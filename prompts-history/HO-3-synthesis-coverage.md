Pre-requisito: HO-3-synthesis-quality cerrado y aprobado en
producción. Si las síntesis de las 4 categorías no convencen, primero
iteramos quality antes de abrir coverage.
Objetivo: que TODAS las categorías que el classifier puede producir
tengan una experiencia de síntesis adecuada, y que en estado Autonomous
las síntesis se disparen sin clic.
Tarea 1 — Mapping completo de categorías
Problema diagnosticado: el classifier produce 25 categorías pero el
mapa SYNTHESIS_CATEGORY_MAP solo cubre 12, y mal:

gaming, música, streaming, vídeo no están mapeadas → caen a
noticias (default), recibiendo el prompt prudente de noticias.
tecnología con tilde no está mapeada (el mapa usa tecnologia).
música con tilde no está mapeada (el mapa usa musica).
salud, viajes, finanzas, ciencia, educación, deportes,
desarrollo con la categoría literal no están todas cubiertas.

Decisión a tomar: cuántos prompts nuevos creamos vs cuántos
agrupamos a uno existente.
Mapping propuesto (ampliar SYNTHESIS_CATEGORY_MAP y crear nuevos
prompts):
Categoría classifierTipo síntesisPromptEstado promptcocinacocinacocina.txtexistente, hardenedcineentretenimientoentretenimiento.txtexistente, hardenedstreamingentretenimientoentretenimiento.txtexistentevídeoentretenimientoentretenimiento.txtexistentegaminggaminggaming.txt nuevoa crearmúsicamusicamusica.txt nuevoa crearnoticiasnoticiasnoticias.txtexistente, hardenedtecnologíatecnologiatecnologia.txtexistente, hardeneddesarrollotecnologiatecnologia.txtexistentecienciacienciaciencia.txt nuevoa crearviajesviajesviajes.txt nuevoa crearsaludsaludsalud.txt nuevoa creardeportesdeportesdeportes.txt nuevoa crearfinanzasfinanzasfinanzas.txt nuevoa creareducacióneducacioneducacion.txt nuevoa creardiseñotecnologiatecnologia.txt (recurre)existenteproductividadtecnologiatecnologia.txt (recurre)existentesocial(sin síntesis)—descartado por contenidocomercio(sin síntesis)—descartado por contenidoinmobiliario(sin síntesis)—descartado por contenidogobiernonoticiasnoticias.txt (recurre)existenteinvestigacióncienciaciencia.txt (compartido)nuevoartículos(sin síntesis)—demasiado genériconotas(sin síntesis)—demasiado genéricootro(sin síntesis)—descartado
8 prompts nuevos a crear: gaming, musica, ciencia, viajes, salud,
deportes, finanzas, educacion. Estructura común:

Sección de "Contenido identificado" exhaustiva (no escueta, ver
patrón de entretenimiento.txt).
Tabla o lista comparativa cuando aplique.
Recomendación destacada / siguiente paso.
Honestidad sobre lo que el modelo no sabe (regla N/D).

Categorías sin síntesis: el botón "Generar síntesis" no aparece en
estos episodios. UX limpia: si la app no tiene una buena síntesis para
ese contenido, no la promete.
Tarea 2 — Cambio en mapCategoryToSynthesisType
Archivo: src/utils/synthesisCategory.ts (creado en HO-3 tarea 14).
Sustituir:
tsexport function mapCategoryToSynthesisType(category: string): string {
  return SYNTHESIS_CATEGORY_MAP[category.toLowerCase()] ?? 'noticias';
}
por:
tsexport function mapCategoryToSynthesisType(category: string): string | null {
  return SYNTHESIS_CATEGORY_MAP[category.toLowerCase()] ?? null;
}

export function canSynthesize(category: string): boolean {
  return mapCategoryToSynthesisType(category) !== null;
}
Razón: hoy canSynthesize y mapCategoryToSynthesisType están
desacoplados. canSynthesize mira si la categoría está en el mapa,
pero mapCategoryToSynthesisType siempre devuelve algo (default
noticias). Acoplarlos elimina el bug actual: hoy un episodio de
"comercio" muestra botón de síntesis y manda al backend, que llama al
proxy con synthesis_type: "noticias", que da una síntesis ridícula.
Tarea 3 — Validación del proxy
Archivo: flowweaver-proxy/src/index.ts
Ampliar VALID_TYPES:
tsconst VALID_TYPES = [
  "entretenimiento", "cocina", "noticias", "tecnologia",
  "gaming", "musica", "ciencia", "viajes",
  "salud", "deportes", "finanzas", "educacion",
] as const;
Y añadir todos los prompts nuevos al objeto PROMPTS.
Tarea 4 — Síntesis automática en Autonomous
Archivos:

src/components/AnticipatedWorkspace.tsx
src/hooks/useSynthesis.ts
src/App.tsx

Comportamiento actual:

Trusted: botón visible, usuario pulsa, se genera.
Autonomous: SynthesisView auto-genera al montar (si onRequest
undefined). PERO solo al montar el componente. Si llega un nuevo
episodio mientras la app está abierta, no se dispara nada.

Cambio: en Autonomous, cuando llega un nuevo episodio (ya hay
listener relay-event-imported en App.tsx), si el episodio mostrado
en AnticipatedWorkspace cambia de id, resetear el hook
useSynthesis con el nuevo anchorKey y disparar generate()
automáticamente.
Patrón:
tsx// AnticipatedWorkspace.tsx
useEffect(() => {
  if (trustState === 'Autonomous' && ep && canSynthesize(category)) {
    // Solo si no hay ya una síntesis persistida (la lectura de BD del
    // hook lo detecta) — el hook decide si generar o usar la persistida.
    autoGenerateIfNeeded();
  }
}, [ep?.episode_id, trustState]);
Importante: en Trusted NO se dispara automáticamente. El botón
"Generar síntesis" sigue siendo manual. Esto está alineado con D4:
Autonomous es el único estado donde la app actúa sin clic.
Tarea 5 — Notificación visual de síntesis automática
Archivo: src/components/SynthesisView.tsx y CSS asociado.
Cuando una síntesis se genera automáticamente (sin clic), mostrar una
indicación sutil: ícono de varita mágica, mensaje "Síntesis generada
automáticamente" con la hora. El usuario debe saber que la app actuó
por su cuenta. Transparencia es parte del wow, no romperla.
HO-3-synthesis-variants — PENDIENTE (último)
Pre-requisito: HO-3-synthesis-coverage cerrado.
Decisión condicional: solo se ejecuta si tras coverage el
Orchestrator sigue sintiendo que las síntesis son "una sola foto" y
quiere ofrecer al usuario varias vistas del mismo episodio.
Idea: en cada SynthesisView, además de la síntesis principal, hay
2-3 botones secundarios que generan vistas alternativas del mismo
episodio. Ejemplos:

Cocina: "Receta completa" (default) | "Solo lista de la compra" |
"Versión rápida"
Entretenimiento: "Detalle completo" (default) | "Top 3
recomendaciones" | "Calendario de visionado"
Tecnología: "Comparativa completa" (default) | "Decisión rápida" |
"Riesgos a evaluar"

Implementación: nuevo campo synthesis_variant en el payload, que
selecciona un sub-prompt dentro del prompt principal. NO crear nuevos
tipos de síntesis: usar el mismo cocina.txt con secciones
condicionales según variant.
Riesgo: cada variante consume cuota del usuario (el rate limit
mensual). Hay que aclarar UX: ¿son "gratis" porque amplían lo que ya
generaste, o consumen 1 cada una? Sugerencia: 1ª síntesis consume,
variantes adicionales del mismo episodio en la misma sesión son
gratuitas (caché local de los inputs, llamada al proxy con variante,
no incrementa rate limit local pero sí en proxy).
Esto requiere cambio de contrato del proxy (rate limit por usuario
debería distinguir "primera síntesis" de "variante"). Es una
conversación más compleja. Por eso es el último handoff y opcional.
Rechazado: filtro de preguntas pre-síntesis
Idea original del Orchestrator: cuando se detecta un episodio
sintetizable, preguntar al usuario "¿quieres ingredientes, variantes,
pasos, resumen?" antes de generar.
Razón del rechazo: rompe la promesa del producto.

FlowWeaver vende "anticipa antes de que lo pidas". Un cuestionario
pre-síntesis convierte la app en chatbot.
Llama 3.3 70B con buen prompt da TODO en una sola síntesis (lista,
pasos, variantes, trucos). No hace falta segmentar.
El equivalente bien diseñado son las variantes a posteriori (HO-3
synthesis-variants): primero te doy la versión completa, después
te dejo pivotar a una vista distinta si quieres.

La diferencia es de timing: pregunta antes (lento, friction, anti-wow)
vs explora después (rápido, opcional, post-wow).
Lo que NO se hace en este roadmap

Síntesis con datos externos (FilmAffinity, TMDb, OMDb). Eso es
T-3-enrichment-001, futuro, post-validación de los 3 HO. Trae
problemas de privacidad, latencia y términos de servicio.
Síntesis multi-episodio ("hazme un resumen de todo lo que guardé
esta semana"). Requiere agregación cross-session, no es Phase 3.
Síntesis editables / comentables. La síntesis es read-only. Si
el usuario quiere editar, copia y edita fuera. Mantenemos simplicidad.