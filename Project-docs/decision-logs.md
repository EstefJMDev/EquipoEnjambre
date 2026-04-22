# FlowWeaver — Decisions Log

Este documento contiene decisiones cerradas del producto y del proyecto marco.

Ninguna decisión aquí registrada puede cambiarse sin:
- propuesta formal de cambio
- justificación
- impacto en fases
- impacto en arquitectura conceptual
- validación del Orchestrator

## Uso en este repositorio

Estas decisiones no son instrucciones de implementación.
Son restricciones normativas que el enjambre debe preservar.

14. Registro de Decisiones Cerradas
#	Decisión	Elección	Justificación
D1	Privacidad	Nivel 1 (títulos + meta-tags cifrados). Narrativa "verificable", no "radical".	Sin títulos no hay workspace útil. Sigue siendo gran diferencial vs competencia.
D2	Motores de detección	Episode Detector dual-mode (inmediato) + Pattern Detector completo solo en Fase 2	Fase 1 usa Episode Detector adaptado para descargas. Pattern Detector no se divide entre fases.
D3	Precisión Episode Detector	Dual-mode: preciso (Jaccard + ecosistemas) con fallback amplio (categoría)	Evita ser demasiado conservador sin sacrificar precisión. Umbrales configurables en beta.
D4	Autoridad de confianza	Máquina de estados manda, trust_score es input con doble condición	Elimina divergencia entre score y transiciones.
D5	Estabilidad	Slot concentration score (entropía normalizada)	Acotada 0-1, funciona con pocos datos.
D6	Sync MVP	iCloud/Google Drive con protocolo ACK + idempotencia + reintentos	Fiable, cero infra, robusto ante race conditions.
D7	Migración sync	LAN añade canal (V1), P2P requiere nuevo emparejamiento (V2+)	No se promete transparencia total. Cambios comunicados.
D8	Motor resumen	Plantillas principal, LLM upgrade opcional	Funciona en todo hardware.
D9	Observer MVP	1 adaptador: Share Extension iOS. Desktop no observa.	Mínimo para caso dorado. FS Watcher en Fase 1.
D10	Roadmap	Fase 0 dividida en 0a (workspace) y 0b (puente). App nativa Tauri.	0a valida formato, 0b valida puente. Reduce riesgo.
D11	Plataforma	macOS + iOS first	iCloud, AX API madura, knowledge workers.
D12	Foco MVP	Único caso: puente móvil → desktop. Bookmarks = onboarding, no caso de uso.	Un solo caso, excepcional.
D13	Narrativa	"Detecta y anticipa, sin reglas manuales" en vez de "aprende observando"	Más honesto: MVP detecta, futuro anticipa.
D14	Privacy Dashboard	Progresivo: mínimo en Fase 0b, completo en Fase 2 (obligatorio antes de beta)	No es monolítico. Mínimo viable para cada fase.
D15	Monetización	Free generoso en beta. Límites definidos con datos reales en V1.	Prematuro optimizar paywall sin product-market fit.
D16	Esquema BD	INTEGER PRIMARY KEY + UUID como columna indexada	Evita fragmentación B-tree.
D17	Pattern Detector timing	Completo en Fase 2. Fase 1 reutiliza Episode Detector para descargas.	Evita tener el Pattern Detector a medias entre dos fases. Concentra complejidad.
D18	Buffer sync	Fase 0b incluye semana 8 de buffer. Escape: sync manual QR si iCloud falla en semana 6.	iCloud tiene edge cases reales. Mejor prever margen que retrasar.
