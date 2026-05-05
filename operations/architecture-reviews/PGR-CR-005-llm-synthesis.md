# Privacy Guardian Review — CR-005: Síntesis LLM vía Proxy Backend

document_id: PGR-CR-005
owner_agent: Privacy Guardian
phase: 3
date: 2026-05-05
status: APROBADO con condiciones obligatorias — condiciones son AC en T-3-009 a T-3-013
documents_reviewed:
  - operations/change-requests/CR-005-llm-synthesis-backend.md
  - operations/architecture-reviews/AR-CR-005-llm-synthesis.md
  - Project-docs/decisions-log.md (D23, D24, D25, D26)
  - Project-docs/scope-boundaries.md (excepción proxy backend)

---

## Resultado Global

**APROBADO con condiciones obligatorias.**

Las condiciones no son objeciones que bloqueen la aprobación — son criterios de
aceptación que deben verificarse en implementación. Quedan registradas como AC
explícitos en las TS individuales de T-3-009 a T-3-013.

---

## 1. D25 Compliance: verificación del payload

**Estado: APROBADO con test obligatorio.**

El payload autorizado por D25 es:
```json
{
  "category": "string",
  "titles": ["string"],
  "domains": ["string"],
  "synthesis_type": "enum",
  "language": "string"
}
```

**Campos prohibidos en el payload (verificación explícita en T-3-009):**
- `url` completa en ninguna forma (cifrada o en claro).
- Contenido de páginas web.
- `install_token` como campo de body (solo como header Authorization).
- `user_id`, `email`, `device_id` o cualquier identificador vinculable a identidad.
- Timestamps personales (`captured_at` u otros campos de BD).
- Datos de BD cifrados.

**Condición obligatoria (AC en T-3-009):**
Test estructural en `synthesis_engine.rs` que verifica que la función que construye
el payload no puede acceder a campos prohibidos. El test inspecciona la signatura
de la función `build_synthesis_payload()` y sus únicos inputs permitidos son
`category: &str`, `titles: &[&str]`, `domains: &[&str]`, `synthesis_type: SynthesisType`,
`language: &str`. Ningún input puede ser `url`, `title_raw` ni ninguna referencia
a `NewResource`.

---

## 2. Cloudflare Workers AI: zero-log confirmado

**Estado: APROBADO.**

Cloudflare Workers AI opera bajo la política de Cloudflare de no-retention de datos
de inferencia. Los datos enviados a Workers AI no se usan para entrenar modelos,
no se almacenan después de la inferencia y no se logean con contenido.

**Referencia documental:**
Cloudflare AI Gateway Documentation y Workers AI Terms of Service declaran que
Cloudflare no retiene ni usa los datos de inferencia para entrenar modelos propios.
El procesamiento ocurre en la infraestructura de Cloudflare bajo el acuerdo DPA
de Cloudflare.

**Condición:** el proxy debe incluir en su documentación el enlace a la política
de privacidad de Cloudflare Workers AI vigente en el momento del despliegue.
El Privacy Dashboard (T-3-011) debe referenciar esta política en la sección
de síntesis.

---

## 3. Anthropic API (Claude Haiku): no-retention confirmado

**Estado: APROBADO.**

Anthropic API (tier de pago) opera bajo política de no-retention de datos: las
peticiones API no se usan para entrenar modelos de Anthropic. Esto está declarado
en los Términos de Servicio de la Anthropic API y en el Data Processing Agreement
disponible para cuentas de API.

**Condición:** la API key de Anthropic debe configurarse en Cloudflare Worker
environment variables (nunca hardcoded). La API key no debe aparecer en logs,
no debe incluirse en el payload al cliente, y debe rotarse si se sospecha compromiso.

---

## 4. GDPR: install_token UUID sin vinculación a identidad

**Estado: APROBADO.**

Un UUIDv4 generado localmente sin vinculación a email, nombre, IP ni ningún otro
dato personal no constituye "dato personal" bajo el RGPD/GDPR (Considerando 26:
datos anónimos que no permiten identificar a una persona).

**Garantías verificadas:**
- El token se genera en el dispositivo del usuario (no asignado por un servidor).
- El token no se asocia con ninguna cuenta, email ni IP en el backend.
- Cloudflare KV solo almacena el token como clave de rate limiting, sin metadatos
  asociados.
- La desactivación de síntesis desde Privacy Dashboard elimina el token del
  SQLCipher local. Sin token, no hay peticiones al proxy.

**Condición:** la pantalla de onboarding (T-3-008) y la sección de síntesis del
Privacy Dashboard (T-3-011) deben explicar claramente que el token no está
vinculado a ninguna identidad y puede eliminarse en cualquier momento.

---

## 5. Privacy Dashboard sección síntesis: requisitos mínimos de contenido

**Requisitos obligatorios (AC en T-3-011):**

La sección "Síntesis inteligente" del Privacy Dashboard debe incluir:

1. **Qué se envía al proxy** (texto exacto obligatorio):
   > "Cuando solicitas una síntesis, FlowWeaver envía al proxy únicamente: la
   > categoría del episodio, los títulos de las páginas que guardaste, y los
   > dominios. Nunca se envía la URL completa ni el contenido de las páginas."

2. **A dónde se envía**: "Proxy FlowWeaver en Cloudflare (zero-retention)"
   con enlace a la política de privacidad de Cloudflare Workers AI.

3. **Política de retención**: "El proxy no almacena tu contenido. La síntesis
   generada se guarda solo en tu dispositivo, cifrada."

4. **Toggle de activación/desactivación**: visible y funcional. Al desactivar,
   el install_token se elimina del SQLCipher local.

5. **Contador de uso**: "X de 5 síntesis usadas hoy" (tier free).

---

## 6. Diálogo de consentimiento primer uso

**Requisitos obligatorios (AC en T-3-012):**

El diálogo modal del primer uso debe cumplir:

**Redacción exacta del título:**
> "Antes de activar la síntesis inteligente"

**Redacción exacta del cuerpo:**
> "La síntesis envía al proxy FlowWeaver: los títulos de tus páginas guardadas,
> la categoría y los dominios. La URL completa y el contenido de las páginas
> nunca se transmiten.
>
> El proxy no almacena tu contenido. La síntesis generada se guarda solo en
> tu dispositivo.
>
> Puedes desactivar la síntesis en cualquier momento desde el Privacy Dashboard."

**Acciones disponibles:**
- "Activar síntesis" (botón primario)
- "No activar" (botón secundario — graceful degradation)

**Registro del consentimiento (AC obligatorio en T-3-012):**
```sql
-- Tabla en SQLCipher
CREATE TABLE IF NOT EXISTS consent_log (
    consent_type    TEXT NOT NULL,
    consent_version TEXT NOT NULL,  -- "synthesis_v1"
    accepted_at     INTEGER NOT NULL -- unix seconds
);
```
El campo `consent_version` permite invalidar consentimientos anteriores si el
aviso se actualiza materialmente. El sistema debe verificar que la versión del
consentimiento registrado coincide con la versión del aviso actual antes de
permitir síntesis.

---

## 7. Política de revocación del install_token

**Estado: APROBADO sin cambios necesarios en el backend.**

Cuando el usuario desactiva la síntesis desde Privacy Dashboard:
1. El install_token se elimina del SQLCipher local.
2. Sin token, el synthesis_engine.rs no puede construir el header Authorization.
3. Sin header, el proxy rechaza cualquier petición con 401.

**No es necesario notificar al backend de la revocación.** El token en Cloudflare KV
queda huérfano pero no causa daño: no está vinculado a identidad, no permite acceder
a datos del usuario, y expirará naturalmente o será eliminado manualmente por el PO
al final de la beta.

**Ventaja de no-notificar:** el sistema de revocación es puramente local, sin
dependencia de conectividad. La revocación es efectiva inmediatamente incluso sin red.

---

## Condiciones Obligatorias Resumidas

| ID | Condición | Tarea |
|---|---|---|
| PG-001 | Test estructural: `build_synthesis_payload()` no puede recibir url ni title raw | T-3-009 |
| PG-002 | Privacy Dashboard sección síntesis con los 5 elementos declarados en §5 | T-3-011 |
| PG-003 | Diálogo consentimiento con redacción exacta y tabla consent_log en SQLCipher | T-3-012 |
| PG-004 | API key Anthropic en Cloudflare env vars, nunca hardcoded ni en logs | T-3-007 |
| PG-005 | Referencia a política Cloudflare Workers AI en Privacy Dashboard | T-3-011 |
| PG-006 | Desactivación síntesis elimina install_token de SQLCipher local | T-3-011 |

Todas las condiciones son AC verificables. Ninguna bloquea la aprobación de CR-005
pero todas bloquean el gate de salida de las tareas correspondientes.
