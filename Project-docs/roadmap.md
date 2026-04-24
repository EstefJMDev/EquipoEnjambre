# FlowWeaver — Roadmap

## Fase 0a

**Objetivo:** validar que el formato workspace genera valor.

**Entregables principales:**

* app Tauri mínima
* lectura bookmarks Safari/Chrome
* clasificación de dominios
* agrupación básica
* Panel A + Panel C
* almacenamiento local cifrado

**Hipótesis a validar:**
La agrupación visual y el formato de workspace generan interés y comprensión del concepto.

**No valida:**

* PMF
* wow moment real del puente móvil→desktop

---

## Fase 0b

**Objetivo:** validar la hipótesis núcleo del puente móvil→desktop.

**Entregables principales (track Android — primario):**

* Android Share Intent (Tauri 2 Android)
* Session Builder ✅ implementado
* Episode Detector dual-mode ✅ implementado
* sync con Google Drive + ACK/idempotencia/retries
* Privacy Dashboard mínimo ✅ implementado
* testing E2E del momento mágico

**Entregables pendientes (track iOS — secundario, requiere macOS):**

* Share Extension iOS
* Sync Layer vía iCloud

**Hipótesis a validar:**
Que el usuario abra el desktop y experimente espontáneamente el “ya me lo había preparado”.

**Riesgo clave:**
fiabilidad de Google Drive sync y preservación del wow moment.

**Plataforma primaria:** Android + Windows (D19). iOS continúa como track paralelo.

---

## Fase 0c

**Objetivo:** convertir la app Android en un cliente completo con galería propia y sync bidireccional.

**Entregables principales:**

* Pantalla de galería Android: categorías → recursos (Tauri 2 + React mobile UI)
* Classifier + Grouper corriendo localmente en Android (mismo Rust compilado para Android)
* SQLCipher local en Android (independiente del desktop)
* Google Drive relay extendido a bidireccional (raw_events en ambas direcciones)
* Privacy Dashboard mínimo móvil: qué categorías, cuántos recursos, botón de purga local

**Hipótesis a validar:**
Que el usuario abra la app en el móvil y encuentre sus capturas organizadas sin
necesitar el desktop. Que el valor del producto sea accesible en el dispositivo
donde ocurre la captura.

**No valida:**
* workspace rico en móvil (Panel B, Episode Detector en móvil)
* sync en tiempo real (el relay sigue siendo async)
* Pattern Detector ni Trust Scorer en móvil (Fase 2 desktop primero)
* iOS (track paralelo, requiere macOS)

**Riesgo clave:**
idempotencia del relay con dos emisores simultáneos (móvil + desktop).

**Plataforma primaria:** Android + Windows (D19, D20, D21).

**Autorizado por:** OD-005 / CR-001 (2026-04-24).

---

## Fase 1

**Objetivo:** añadir un segundo caso de uso local: organización de descargas/screenshots.

**Entregables principales:**

* FS Watcher
* adaptación del Episode Detector
* Panel B con plantillas

---

## Fase 2

**Objetivo:** añadir aprendizaje longitudinal y escalera de confianza.

**Entregables principales:**

* Pattern Detector
* Trust Scorer
* State Machine
* Privacy Dashboard completo

---

## Fase 3

**Objetivo:** beta pública y calibración.

**Entregables principales:**

* beta 20-50 usuarios
* métricas de uso, precisión y confianza
* calibración de umbrales
* LLM local opcional donde proceda

---

## V1 / V2+

Líneas futuras:

* MCP
* timeline privada
* deep work guardian
* LAN/BLE
* rituales compartidos
* marketplace
* SDK
