# FlowWeaver - Decisions Log

Este documento contiene decisiones cerradas del producto y del proyecto marco.

Ninguna decisión aquí registrada puede cambiarse sin:

* propuesta formal de cambio
* justificación
* impacto en fases
* impacto en arquitectura conceptual
* validación del Orchestrator

## Uso en este repositorio

Estas decisiones no son instrucciones de implementación. Son restricciones
normativas que el enjambre debe preservar.

## Registro de decisiones cerradas

| ID | Área | Elección | Justificación |
| --- | --- | --- | --- |
| D1 | Privacidad | Nivel 1: títulos + meta-tags cifrados. Narrativa "verificable", no "radical". | Sin títulos no hay workspace útil. Sigue siendo gran diferencial frente a competencia. |
| D2 | Motores de detección | Episode Detector dual-mode inmediato; Pattern Detector completo solo en Fase 2. | Fase 1 usa Episode Detector adaptado para descargas. Pattern Detector no se divide entre fases. |
| D3 | Precisión del Episode Detector | Dual-mode: preciso con Jaccard + ecosistemas, con fallback amplio por categoría. | Evita ser demasiado conservador sin sacrificar precisión. Umbrales configurables en beta. |
| D4 | Autoridad de confianza | La máquina de estados manda; `trust_score` es input con doble condición. | Elimina divergencia entre score y transiciones. |
| D5 | Estabilidad | Slot concentration score con entropía normalizada. | Se mantiene acotado entre 0 y 1 y funciona con pocos datos. |
| D6 | Sync MVP | Relay cifrado por iCloud/Google Drive con ACK, idempotencia y reintentos. | Fiable, sin infraestructura propia y robusto ante race conditions. |
| D7 | Migración de sync | LAN añade canal en V1; P2P requiere nuevo emparejamiento en V2+. | No se promete transparencia total. Los cambios se comunican. |
| D8 | Motor de resumen | Plantillas como baseline; LLM como mejora opcional. | El baseline debe funcionar en cualquier hardware. |
| D9 | Observer MVP | Único observer activo: Share Intent Android (primario); Share Extension iOS (track paralelo secundario). Desktop no observa en MVP. | Es el mínimo necesario para el caso dorado. FS Watcher entra en Fase 1. Plataforma primaria cambia a Android per D19. |
| D10 | Roadmap | Fase 0 se divide en 0a workspace y 0b puente. Desktop nativo Tauri. | 0a valida formato; 0b valida el puente. Reduce riesgo. |
| D11 | Plataforma | ~~macOS + iOS first.~~ **SUPERSEDIDA por D19.** | Supersedida por decisión estratégica de mercado. |
| D12 | Foco MVP | Único caso: puente móvil -> desktop. Bookmarks son onboarding, no caso de uso núcleo. | Obliga a proteger un solo caso excepcional antes de ampliar. |
| D13 | Narrativa | "Detecta y anticipa, sin reglas manuales" en lugar de "aprende observando". | Es más honesto con el MVP actual y deja el aprendizaje para fases posteriores. |
| D14 | Privacy Dashboard | Mínimo en 0b; completo en Fase 2 y obligatorio antes de beta. | Se despliega progresivamente según el alcance real de cada fase. |
| D15 | Monetización | Beta con free generoso; límites definidos con datos reales en V1. | Optimizar pricing antes de PMF es prematuro. |
| D16 | Esquema BD | `INTEGER PRIMARY KEY` más UUID indexado. | Evita fragmentación de B-tree. |
| D17 | Pattern Detector timing | Completo en Fase 2. Fase 1 reutiliza Episode Detector para descargas. | Evita tener un Pattern Detector a medias entre fases. |
| D18 | Buffer de sync | Fase 0b incluye semana 8 de buffer; escape QR si iCloud falla en semana 6. | Se reconoce el riesgo real del sync sin retrasar toda la validación. |

| D19 | Plataforma | Windows + Android first. iOS como track paralelo secundario cuando haya entorno macOS disponible. | El primer frente de clientes a abordar es Android + Windows. El entorno de desarrollo actual (Windows 10) permite compilar Tauri Android sin Mac. Tauri 2 soporta Android nativamente — el mismo backend Rust compila para ambas plataformas sin reescritura. |
| D20 | Mobile como cliente completo | Desde Fase 0c, la app Android es un cliente completo: captura, procesa localmente (Classifier + Grouper + SQLCipher propio) y muestra galería organizada por categoría. El móvil no depende del desktop para entregar valor. Aprobado en CR-001 / OD-005. | El valor del producto debe estar disponible en el dispositivo donde ocurre la captura. Sin galería móvil, el usuario necesita el desktop para ver lo que guardó — rozamiento inaceptable para un producto de captura cotidiana. |
| D21 | Sync bidireccional | Desde Fase 0c, el relay Google Drive es bidireccional: móvil → desktop (ya existe en 0b) + desktop → móvil (nuevo). Cada dispositivo tiene su propio SQLCipher y procesa de forma independiente. El relay transporta raw_events en ambas direcciones. No hay merge de bases de datos ni fuente de verdad única. Aprobado en CR-001 / OD-005. | El modelo local-first requiere que cada dispositivo sea soberano. El relay bidireccional sobre Google Drive (mecanismo ya probado en 0b) es la extensión más simple y coherente con D6. El merge de BD se evalúa en V1 si es necesario. |

## Decisiones pendientes

Estas decisiones están abiertas. Deben cerrarse antes de abrir la fase indicada. No pueden implementarse hasta que el Orchestrator las cierre formalmente.

| ID | Área | Pregunta abierta | Cierre requerido antes de |
|---|---|---|---|
| D22 | Producto / Monetización | ¿Es FlowWeaver mobile un producto standalone con tier de pago? ¿Qué features incluye? ¿Qué es "workspace anticipado" en mobile? | Fase 3 |

### D22 — Mobile standalone como tier de pago

**Estado:** PENDIENTE  
**Abierta:** 2026-04-24  
**Cierre requerido antes de:** Fase 3 (beta pública)

**Pregunta:**  
¿Puede FlowWeaver funcionar como producto completo en mobile sin necesitar el desktop, ofrecido como tier de pago?

**Contexto:**  
Habrá usuarios que no tengan o no quieran el desktop. La app Android ya es un cliente completo desde Fase 0c (D20): captura, organiza y muestra galería. La pregunta es si el tier paid añade Pattern Detector + State Machine + Trust Scorer corriendo en el propio dispositivo, con una versión mobile del "workspace anticipado".

**Opciones en discusión:**

- **Opción A:** Mobile-only es solo organizador (free). El workspace anticipado requiere desktop siempre.
- **Opción B:** Mobile-only tiene tier paid con Pattern Detector portado a Android (via NDK) + notificaciones proactivas como equivalente móvil del workspace anticipado.

**Implicaciones si se elige Opción B:**
- Pattern Detector, State Machine y Trust Scorer deben compilar para Android (la arquitectura Rust+NDK ya lo permite)
- "Workspace anticipado" en mobile = notificaciones proactivas + agrupación contextual + deep links a apps relevantes
- Modelo freemium: free (captura + organización) / paid (patrones + anticipación)
- FS Watcher (D9) no aplica en mobile — no es una limitación, es un concepto de desktop irrelevante en este contexto
- Añade un segmento de usuario nuevo: mobile-only power user
- Google Drive sync sigue siendo el relay (D6) — no cambia

**Agentes que deben preparar propuesta:** Functional Analyst + Technical Architect  
**Decisor final:** Orchestrator

---

## Regla operativa

Si un documento posterior contradice este registro y no existe una propuesta
formal aprobada, el documento posterior debe corregirse.
