> **NOTA HISTÓRICA — 2026-05-12.** Este archivo es el prompt original que
> disparó la sesión de revisión de producto del 2026-05-12. Su análisis
> derivó en OD-008 (`operations/orchestration-decisions/OD-008-reorientacion-pre-beta-validacion.md`).
> OD-008 DESCARTA explícitamente: (1) la nomenclatura "Fase A-G" propuesta
> aquí, (2) cualquier reescritura inmediata de framing/positioning sin
> validación con usuarios reales primero, (3) cualquier promesa pública de
> "anticipación autónoma" o "agente local" como funcionalidad actual.
> Este documento se conserva como historial de pensamiento, NO como
> referencia operativa. No usar como input para Task Specs ni decisiones.

---

Quiero que actúes como arquitecto senior de producto + ingeniería para revisar y evolucionar FlowWeaver.

Contexto del producto:
FlowWeaver es un motor de workspaces anticipados. La idea principal NO es solo que el usuario guarde manualmente enlaces o recursos, sino que la app pueda observar señales de intención en segundo plano, calcular patrones, decidir cuándo hay una intención suficientemente clara y preparar un workspace útil antes de que el usuario lo pida.

La visión:
“FlowWeaver detecta intención a partir de señales dispersas y convierte esa intención en espacios de trabajo útiles, tanto si el usuario trabaja solo desde móvil como si salta entre móvil y ordenador.”

El producto debe funcionar en varios modos:
1. Mobile-first:
   - Usuario usa principalmente el móvil.
   - FlowWeaver observa/captura señales del uso móvil cuando sea posible.
   - También acepta señales manuales vía Share Intent.
   - Prepara mini-workspaces móviles: comparativas, viajes, trámites, estudio, compras, investigación cotidiana.

2. Cross-device:
   - Usuario empieza en móvil y continúa en desktop.
   - FlowWeaver detecta investigación/intención en móvil.
   - Al abrir desktop, encuentra un workspace preparado.
   - Este es el “wow moment” principal.

3. Power/advanced:
   - Usuario avanzado conecta carpetas, filesystem watcher, reglas, patrones, síntesis IA opcional y diagnósticos.
   - FlowWeaver puede convertirse en un sistema personal de contexto privado.

Principio clave:
FlowWeaver no debe venderse como bookmark manager, read-it-later ni gestor de links. Eso es solo una fuente de señales. La categoría deseada es:
“motor de workspaces anticipados”
o
“de señales dispersas a espacio de trabajo preparado”.

Estado actual del repo:
- Tauri 2 + React/TypeScript + Rust.
- Android/Kotlin para captura móvil, Share Intent, relay y cifrado.
- Hay lógica de relay Android/Desktop, Drive relay, crypto, pattern detection, trust state, privacy dashboard, synthesis, mobile gallery, FS watcher y workspace anticipation.
- Ya se han validado manualmente o con checklist los flujos críticos:
  - tiempo captura → desktop visible,
  - duplicados,
  - fallo sin red,
  - token expirado,
  - app desktop abierta,
  - app desktop cerrada,
  - 3 URLs mismo tema,
  - 3 URLs temas distintos,
  - borrado local y no reimportación inesperada.

Lo que quiero ahora:
Quiero que me ayudes a decidir cómo seguir para que el producto gane diferenciación real y avance hacia un agente local que observe, trabaje, calcule y prepare workspaces sin que el usuario tenga que guardar todo manualmente.

Necesito que abordes estas áreas:

1. Producto y diferenciación
- Cómo convertir FlowWeaver en algo claramente distinto a Raindrop, Readwise Reader, Matter, Notion, Mymind, Fabric, etc.
- Cómo explicar el producto sin que parezca un bookmark manager.
- Cómo comunicar la observación en segundo plano sin que suene invasiva.
- Qué promesa principal debería tener.
- Qué casos de uso iniciales elegir para usuarios normales y para usuarios avanzados.
- Cómo equilibrar mobile-first, cross-device y modo avanzado sin dispersar el producto.

2. UX principal
Diseña la experiencia ideal para:
- usuario que guarda o busca varias cosas sobre una compra;
- usuario que investiga un tema técnico;
- usuario que prepara un viaje;
- usuario que empieza en móvil y continúa en desktop;
- usuario que no quiere configurar nada.

Quiero que propongas:
- home principal;
- tarjetas de workspace anticipado;
- explicación “why this workspace?”;
- controles de confianza;
- controles para pausar, borrar, rechazar o corregir;
- estados cuando la app está observando en segundo plano;
- estados cuando hay baja confianza.

3. Modelo conceptual
Ayúdame a definir entidades internas y externas:
- capture/signal;
- episode;
- pattern;
- workspace;
- workspace recipe;
- trust state;
- evidence;
- decision;
- action next step;
- local event log.

Quiero que distingas:
- nombres internos para código;
- nombres visibles para usuario;
- qué debería mostrarse y qué debería quedar oculto.

4. Observación en segundo plano
Quiero explorar cómo puede funcionar la captura automática o semiautomática de señales respetando privacidad y limitaciones del sistema operativo.

Ten en cuenta:
- Android limita mucho la observación global.
- iOS será todavía más restrictivo.
- Desktop permite más opciones con filesystem watcher, navegador/extensión, clipboard opcional, carpeta vigilada, historial local si el usuario lo autoriza, etc.
- No quiero spyware ni captura oscura. Quiero consentimiento, transparencia y control.

Propón una estrategia por niveles:
Nivel 0: manual share intent.
Nivel 1: carpeta/espacio vigilado.
Nivel 2: browser extension opcional.
Nivel 3: clipboard/active window/url observation con consentimiento.
Nivel 4: automatizaciones avanzadas para power users.

Para cada nivel, indica:
- valor para usuario;
- riesgo de privacidad;
- dificultad técnica;
- limitaciones por plataforma;
- cómo explicarlo de forma confiable;
- si debe entrar en MVP, beta o futuro.

5. Privacidad y confianza
FlowWeaver debe ser privacy-first. Quiero que propongas:
- modelo de permisos progresivo;
- modo local-only;
- modo IA opcional;
- modo mobile-only;
- modo cross-device;
- modo avanzado;
- logs locales auditables;
- botón de pausa;
- botón de borrar episodio;
- “por qué apareció esto”;
- “qué datos se usaron”;
- “qué datos salieron del dispositivo”;
- cómo evitar que el usuario sienta vigilancia.

Importante:
La app puede observar, pero debe sentirse como un asistente privado, no como un tracker.

6. IA y síntesis
No quiero que FlowWeaver se diferencie simplemente por “resúmenes IA”.
Quiero que la IA, si existe, ayude a:
- clasificar intención;
- detectar tipo de workspace;
- crear próximos pasos;
- preparar comparativas;
- extraer tareas;
- explicar evidencia;
- generar workspace recipes.

Propón:
- qué debe funcionar sin IA;
- qué puede mejorar con IA;
- qué debe ser opcional;
- qué puede ser local;
- qué puede usar proxy/remoto con consentimiento explícito;
- cómo comunicarlo.

7. Arquitectura técnica
Revisa la arquitectura ideal:
- core engine independiente;
- app desktop;
- app Android;
- futuro browser extension;
- relay/sync;
- event log local;
- episode detector;
- workspace planner;
- privacy policy engine;
- trust scorer;
- synthesis layer;
- storage encrypted.

Quiero una propuesta concreta de módulos, responsabilidades y límites.

También quiero que revises estas preocupaciones:
- lógica Android custom dentro de src-tauri/gen/android;
- CSP actualmente laxa;
- key management y cifrado;
- compatibilidad legacy XOR;
- separación entre local encryption y transit encryption;
- reproducibilidad de build Android/Rust;
- scripts de quality gate;
- tests de regresión.

8. Roadmap
Propón un roadmap en fases:
Fase A: hardening técnico y calidad.
Fase B: UX del workspace anticipado.
Fase C: mobile-first real.
Fase D: observación opcional en segundo plano.
Fase E: browser extension / desktop observers.
Fase F: IA opcional y workspace recipes.
Fase G: beta cerrada.

Para cada fase, dime:
- objetivo;
- entregables;
- riesgos;
- qué NO hacer;
- criterio de salida.

9. Métricas
No quiero medir “número de links guardados”.
Quiero medir si FlowWeaver anticipa bien.

Propón métricas como:
- useful anticipation rate;
- workspaces abiertos / sugeridos;
- workspaces confirmados útiles;
- workspaces rechazados;
- falsos positivos;
- tiempo hasta primer click;
- tiempo captura/señal → workspace;
- porcentaje de workspaces que llevan a acción;
- confianza percibida;
- uso mobile-only vs cross-device.

10. Decisiones difíciles
Ayúdame a decidir:
- ¿Debo priorizar mobile-first o cross-device?
- ¿Debo ocultar features avanzadas al principio?
- ¿Qué formas de observación en segundo plano son aceptables?
- ¿Hasta dónde llegar sin parecer invasivo?
- ¿Qué debe ser manual, semiautomático o automático?
- ¿Qué debe ser local-only por defecto?
- ¿Qué claims de privacidad puedo hacer sin sobreprometer?
- ¿Qué casos de uso debería NO perseguir todavía?

Formato de respuesta deseado:
1. Diagnóstico directo.
2. Riesgos principales.
3. Cambios recomendados.
4. Arquitectura propuesta.
5. UX propuesta.
6. Roadmap por fases.
7. Lista de tareas concretas para implementar.
8. Preguntas críticas que debo responder antes de beta.

No me des una respuesta genérica. Quiero una opinión fuerte, práctica y accionable. Si ves contradicciones en la visión, señálalas. Si crees que alguna parte debe eliminarse, esconderse o posponerse, dilo claramente.