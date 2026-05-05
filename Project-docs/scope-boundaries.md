# FlowWeaver — Scope Boundaries

## Regla principal

El proyecto debe proteger el foco del MVP.
El caso de uso núcleo es exclusivamente el puente móvil → desktop.

## In-scope por fase

### Fase 0a

Incluye:

* app desktop Tauri mínima
* lectura local de bookmarks Safari/Chrome
* clasificación por dominio/categoría
* agrupación por similitud básica
* Workspace UI con Panel A + Panel C
* SQLCipher para almacenamiento local
* demostración de valor del contenedor workspace

No incluye:

* móvil
* Share Extension
* sync
* Episode Detector real
* Pattern Detector
* Trust Scorer
* LLM local
* Privacy Dashboard completo
* validación de PMF
* Panel B del workspace (entra en Fase 1)

### Fase 0b

Incluye:

* Share Extension iOS
* captura explícita de URLs
* Session Builder
* Episode Detector dual-mode
* sync iCloud/Google Drive relay cifrado con ACK, retries e idempotencia
* fallback QR manual
* Privacy Dashboard mínimo
* testing E2E del momento mágico

No incluye:

* FS Watcher
* Pattern Detector
* Trust Scorer
* Explainability Log
* Privacy Dashboard completo
* backend propia
* Panel B del workspace (entra en Fase 1)

### Fase 0c

Incluye:

* Pantalla de galería Android: lista de categorías con recursos capturados
* Classifier + Grouper en Android (mismo Rust, compilado para Android vía Tauri 2)
* SQLCipher local en Android (independiente del SQLCipher del desktop)
* Google Drive relay bidireccional: raw_events fluyen en ambas direcciones
* Privacy Dashboard mínimo en móvil: categorías, recuento de recursos, purga local

No incluye:

* workspace completo en móvil (Panel A, Panel B, Panel C)
* Episode Detector en móvil
* Pattern Detector en móvil (Fase 2 desktop primero)
* Trust Scorer ni State Machine en móvil
* sync en tiempo real (el relay sigue siendo async)
* notificaciones push (requiere backend propia — prohibida en MVP)
* vista embebida de contenido (Reels, videos) dentro de la app — solo URLs
* iOS (track paralelo, requiere macOS)

### Fase 1

Incluye:

* FS Watcher `~/Downloads`
* organización de descargas/screenshots
* adaptación del Episode Detector
* Panel B con plantillas

### Fase 2

Incluye:

* Pattern Detector
* Trust Scorer
* máquina de estados
* Privacy Dashboard completo
* lógica longitudinal de confianza

### Fase 3

Incluye:

* beta pública
* métricas
* calibración de umbrales
* LLM local opcional si aporta valor sin romper latencia o hardware

## Prohibiciones fuertes

* no tratar bookmarks como caso núcleo del producto
* no decir que Fase 0a valida PMF
* no introducir observación activa en desktop durante MVP
* no introducir backend propia en MVP
* no introducir P2P como sync MVP
* no adelantar Pattern Detector o Trust antes de Fase 2
* no convertir LLM local en requisito del sistema

## Errores de interpretación que deben evitarse

1. Pensar que 0a ya valida el producto completo
   Incorrecto: 0a valida solo el valor del formato workspace.

2. Pensar que bookmarks retroactivos son el centro del producto
   Incorrecto: son onboarding y cold start.

3. Pensar que si sync falla se puede rediseñar el producto
   Incorrecto: primero deben explorarse fallbacks compatibles.

4. Pensar que broad mode sustituye el valor del precise mode
   Incorrecto: broad mantiene utilidad, pero el wow depende del precise.

5. Pensar que el LLM define el valor central
   Incorrecto: el baseline funcional es con plantillas.

---

## Excepción aprobada: proxy backend para síntesis LLM (D23, D25)

**Fecha de aprobación:** 2026-05-05 — Orchestrator vía CR-005 + HO-029.

### Contexto

El principio fundacional de FlowWeaver es "100% local": los datos del usuario
no salen del dispositivo. Esta sección documenta honestamente la única excepción
aprobada a ese principio, sus límites exactos y las garantías que la hacen aceptable.

### Qué se transmite al proxy (payload autorizado — D25)

```json
{
  "category": "string (en claro — D1 autoriza)",
  "titles": ["string (descifrado con consentimiento explícito — D25)"],
  "domains": ["string (en claro — D1 autoriza)"],
  "synthesis_type": "enum (entretenimiento | cocina | noticias | tecnología)",
  "language": "string"
}
```

### Qué NUNCA se transmite

- URL completa de ningún recurso.
- Contenido de páginas web (el sistema nunca lo lee — D1 núcleo).
- Identidad del usuario (install_token es UUID sin vinculación a email ni cuenta).
- Timestamps personales.
- Datos de BD cifrados.
- Cualquier campo prohibido por D1 en su núcleo.

### Garantías del proxy

- **Zero-retention**: el proxy no persiste, no logea contenido de las peticiones.
- **Zero-log**: Cloudflare Workers AI no retiene datos de inferencia por diseño
  de la plataforma (provider primario).
- **Stateless**: el proxy no mantiene estado entre peticiones.
- **Consentimiento explícito**: el usuario activa la síntesis en un diálogo modal
  informado la primera vez. La desactivación elimina el install_token local.
- **Revocación**: desactivar síntesis desde Privacy Dashboard elimina el
  install_token; sin token, no hay peticiones al proxy.

### Qué NO cambia

- D1 en su núcleo: url y title siguen cifrados en BD local. El sistema sigue sin
  acceder al contenido de páginas web.
- D8: el baseline determinístico (plantillas estáticas) sigue funcionando sin
  proxy y sin red. La síntesis LLM es opt-in, no un requisito del sistema.
- La narrativa de privacidad del producto: "el sistema aprende lo que guardas,
  pero tú controlas qué se envía fuera del dispositivo y puedes revocar en
  cualquier momento."

### Scope de la excepción

Esta excepción aplica exclusivamente a la función de síntesis LLM (T-3-007 a T-3-013).
Ningún otro módulo del sistema transmite datos fuera del dispositivo del usuario.
La telemetría (T-3-002) sigue siendo local por defecto (sin endpoint externo en Fase 3).

