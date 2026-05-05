# Privacy Guardian Review — CR-006: Mobile como Cliente Autónomo

document_id: PGR-CR-006
owner_agent: Privacy Guardian
phase: 3
date: 2026-05-05
status: APROBADO con condiciones obligatorias — condiciones son AC en T-3-022 a T-3-027
documents_reviewed:
  - operations/change-requests/CR-006-mobile-autonomous-client.md
  - operations/architecture-reviews/AR-CR-006-mobile-autonomous.md
  - operations/architecture-reviews/PGR-CR-005-llm-synthesis.md
  - Project-docs/decisions-log.md (D24, D25, D27, D28, D29, D30, D31)

---

## Resultado Global

**APROBADO con condiciones obligatorias.**

Las condiciones son criterios de aceptación que deben verificarse en implementación.
Quedan registradas como AC explícitos en las TS individuales de T-3-022 a T-3-027.

---

## 1. D25 en Mobile: compliance del payload

**Estado: APROBADO con test obligatorio equivalente al de desktop.**

El payload mobile al proxy debe cumplir las mismas restricciones que el desktop
(PGR-CR-005 §1). El cliente Kotlin `SynthesisClient` está bajo las mismas
obligaciones que `synthesis_engine.rs`.

**Campos prohibidos en el payload mobile (idénticos a desktop):**
- `url` completa en ninguna forma.
- Contenido de páginas web.
- `install_token` como campo de body (solo como header Authorization).
- `user_id`, `email`, `device_id` o cualquier identificador vinculable a identidad.
- Timestamps personales (`captured_at`).

**Condición obligatoria (AC en T-3-015):**
Test de integración en Kotlin que verifica la signatura de la función que construye
el payload: únicos parámetros permitidos son `category: String`, `titles: List<String>`,
`domains: List<String>`, `synthesisType: String`, `language: String`. Ningún parámetro
puede ser de tipo `Resource`, `RawEvent`, ni contener `url` o `titleRaw`.

**Referencias:**
- PGR-CR-005 §1 (test estructural equivalente en Rust)
- Anthropic API Data Privacy: https://www.anthropic.com/legal/api-data-privacy
- Cloudflare Workers AI Privacy: https://developers.cloudflare.com/workers-ai/privacy/

---

## 2. D28 Niveles A/B/C: qué pasa exactamente con los datos

**Estado: APROBADO con aviso obligatorio en Nivel A.**

Documentación exacta del comportamiento de cada nivel:

| Nivel | Nombre | Comportamiento del dato | Reversibilidad |
|---|---|---|---|
| Normal | Captura normal (default) | Capturado, procesado, genera síntesis cuando hay material, notifica al usuario. | N/A (estado por defecto) |
| C | Capturar silenciosa | El recurso se captura y procesa normalmente en SQLCipher. NO genera notificaciones proactivas NI síntesis automáticas. Aparece en listados solo cuando el usuario los abre explícitamente. | Reversible: cambiar a "Normal" reactiva síntesis y notificaciones para nuevos recursos. |
| B | Capturar pendiente | El recurso se captura en SQLCipher en estado `pending`. NO se procesa, NO genera síntesis, NO aparece en listados regulares. El usuario puede revisar y cambiar el estado desde Configuración → Captura → Pendientes. | Reversible: aprobar el recurso pendiente lo mueve a estado Normal y entra al pipeline. |
| A | No capturar | **DESTRUCTIVO.** El recurso se descarta a la entrada — no entra en SQLCipher local. El dato se pierde permanentemente para FlowWeaver. El usuario no puede recuperarlo desde la app. | NO reversible. Aviso explícito obligatorio al activar. |

**Condición obligatoria (AC en T-3-024):**
El Nivel A debe ir precedido de un diálogo de confirmación con texto obligatorio:
> "Al activar 'No capturar' para [categoría], cualquier recurso de esta categoría
> que compartas será descartado permanentemente. No podrás recuperarlo desde la app.
> ¿Confirmas?"

Este diálogo no puede ser omitido mediante opciones de configuración.

---

## 3. D30 Modo Estricto vs Flexible: implicaciones GDPR

**Estado: APROBADO con mecanismo de acceso obligatorio.**

**Modo Flexible (free):**
Los eventos de categorías bloqueadas están presentes en SQLCipher local pero con
un campo `visible = 0`. El dato EXISTE en la base de datos del usuario. Si el usuario
cambia el modo o ajusta el filtro, los datos vuelven a aparecer sin pérdida.

**Modo Estricto (paid):**
Los eventos de categorías bloqueadas son DESCARTADOS a la entrada del relay —
no entran en SQLCipher local. El dato NO existe en la base de datos del usuario
en este dispositivo.

**Implicación GDPR (Artículo 15 — Derecho de acceso):**
El usuario tiene derecho a acceder a TODOS sus datos, incluyendo los ocultos en
Modo Flexible. La app debe respetar este derecho.

**Condición obligatoria (AC en T-3-026):**
En Modo Flexible, la sección de configuración D30 debe incluir el acceso:
> "Ver datos ocultos por filtro" → lista de categorías con recuento de recursos
> ocultos, con opción de exportarlos o eliminarlos permanentemente.

En Modo Estricto, los datos descartados no existen en el dispositivo — el usuario
ya fue informado de esto al activar el modo. Un mensaje explicativo lo confirma:
> "Con modo estricto activo, los recursos de categorías bloqueadas nunca se
> almacenan en este dispositivo."

---

## 4. Diálogo de Consentimiento Mobile: redacción exacta y versionado

**Estado: APROBADO con coherencia explícita con PGR-CR-005 §6.**

**Redacción exacta del título (igual que desktop):**
> "Antes de activar la síntesis inteligente"

**Redacción exacta del cuerpo (adaptado para mobile):**
> "La síntesis envía al proxy FlowWeaver: los títulos de tus páginas guardadas,
> la categoría y los dominios. La URL completa y el contenido de las páginas
> nunca se transmiten.
>
> El proxy no almacena tu contenido. La síntesis generada se guarda solo en
> tu dispositivo.
>
> Puedes desactivar la síntesis en cualquier momento desde el Privacy Dashboard."

**Acciones disponibles (igual que desktop):**
- "Activar síntesis" (botón primario)
- "No activar" (botón secundario — graceful degradation)

**Versionado del consentimiento (AC en T-3-023):**
- `consent_version = "synthesis_v1"` — coherente con desktop (PGR-CR-005 §6).
- Si el texto del aviso cambia materialmente en el futuro, `consent_version` sube
  a `"synthesis_v2"` y el sistema invalida el consentimiento previo, forzando
  nuevo diálogo.
- El registro en SQLCipher mobile es idéntico al desktop:
  ```sql
  CREATE TABLE IF NOT EXISTS consent_log (
      consent_type    TEXT NOT NULL,
      consent_version TEXT NOT NULL,
      accepted_at     INTEGER NOT NULL
  );
  ```

**Condición obligatoria (AC en T-3-023):**
El sistema no puede llamar al proxy de síntesis si no existe un registro en
`consent_log` con `consent_type = 'synthesis'` y `consent_version = 'synthesis_v1'`.
Esta verificación ocurre en `SynthesisClient` antes de construir la petición.

---

## 5. Sync Bidireccional de Syntheses (D27): cifrado en tránsito

**Estado: APROBADO — cifrado heredado del modelo de relay existente.**

Las síntesis viajan cifradas en el relay siguiendo exactamente el modelo de
`resource_captured` documentado en drive_relay.rs:

1. **Dispositivo emisor**: descifra `content_encrypted` con su `local_key` → re-cifra
   con la `shared_key` del par → sube al relay con el campo `content_encrypted` en el
   nuevo cifrado.
2. **Relay (Google Drive)**: almacena solo datos cifrados. Nunca ve el contenido.
3. **Dispositivo receptor**: descarga del relay → descifra con `shared_key` → re-cifra
   con su propia `local_key` → persiste en SQLCipher local.

**D1 transitivo:** el contenido de la síntesis (que puede incluir títulos referenciados)
viaja siempre cifrado. Nunca en claro fuera del dispositivo del usuario.

**Condición obligatoria (AC en T-3-027):**
Test de integración que verifica el ciclo completo de una síntesis: generación en
mobile → re-cifrado para relay → descifrado en desktop (usando el modelo de
`e2e_relay_roundtrip.rs` como referencia). El contenido de la síntesis descifrado
en desktop debe ser idéntico al original generado en mobile.

---

## 6. Configuración Sincronizada (D28/D29): cifrado

**Estado: APROBADO con condición de cifrado.**

D28 (niveles A/B/C) y D29 (perfiles con horarios) se sincronizan entre dispositivos
vía relay como evento `config_updated`. Esta configuración ES dato personal porque
revela las preferencias de categorías del usuario.

**Condición obligatoria (AC en T-3-027):**
El campo `data_encrypted` del evento `config_updated` debe cifrarse con la `shared_key`
del par (igual que `url` y `title` en `resource_captured`). La configuración NO viaja
en claro por el relay.

D30 (filtro por dispositivo) NO se sincroniza — es local por diseño. No hay riesgo
de transmisión.

---

## 7. Captura Silenciosa Nivel C: acceso del usuario

**Estado: APROBADO con visibilidad garantizada.**

El Nivel C es una categoría donde el recurso se captura y procesa normalmente en
SQLCipher, pero sin notificaciones ni síntesis automáticas. El usuario puede ver
todos los recursos capturados en Nivel C si navega explícitamente a la categoría.

**Condición obligatoria (AC en T-3-024):**
La sección "Captura silenciosa" en Configuración → Captura debe incluir un acceso
directo a los recursos de esa categoría:
> "[Categoría]: X recursos capturados en silencio. [Ver todos →]"

El usuario debe poder ver, procesar manualmente (solicitar síntesis bajo demanda
via T-3-020) o eliminar estos recursos en cualquier momento. No existe restricción
de acceso sobre datos en Nivel C — solo restricción de procesamiento automático.

---

## Condiciones Obligatorias Resumidas

| ID | Condición | Tarea |
|---|---|---|
| PG-M-001 | Test en Kotlin: signatura de función de payload — solo 5 inputs permitidos | T-3-015 |
| PG-M-002 | Diálogo de confirmación obligatorio al activar Nivel A con texto exacto | T-3-024 |
| PG-M-003 | Acceso a "datos ocultos por filtro" en D30 modo flexible (GDPR Art. 15) | T-3-026 |
| PG-M-004 | Diálogo de consentimiento mobile con redacción exacta + consent_log en SQLCipher | T-3-023 |
| PG-M-005 | Verificación pre-llamada al proxy: `consent_log` debe tener registro válido | T-3-015 |
| PG-M-006 | Test E2E de síntesis mobile→desktop: contenido descifrado idéntico al original | T-3-027 |
| PG-M-007 | Configuración D28/D29 cifrada con shared_key en evento `config_updated` | T-3-027 |
| PG-M-008 | Acceso visible a recursos de Nivel C desde Configuración → Captura | T-3-024 |

Todas las condiciones son AC verificables. Ninguna bloquea la aprobación de CR-006
pero todas bloquean el gate de salida de las tareas correspondientes.
