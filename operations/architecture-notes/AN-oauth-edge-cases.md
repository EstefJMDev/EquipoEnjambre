# AN-oauth-edge-cases — Casos extremos del flujo OAuth Drive

date: 2026-04-30
owner: Sync & Pairing Specialist
related: HO-024, R17

---

## Contexto

El relay Android↔Desktop usa Drive AppData como bus. El access_token de OAuth2 caduca en ~1h. El `refresh_token` se usa para renovarlo. A continuación: inventario de los 9 casos extremos relevantes para la operación del relay.

---

## Inventario de casos

### 1. Refresh token revocado por el usuario

**Cuándo:** el usuario va a su cuenta Google → Seguridad → Aplicaciones con acceso → revoca FlowWeaver.

**Síntoma:** `drive_upload` / `drive_download` devuelven HTTP 401. `ensureValidAccessToken()` intenta refresh → Google devuelve `{"error":"invalid_grant"}`. `TokenResult.Unrecoverable` en Android. En desktop: `run_relay_cycle` falla con error de HTTP.

**Comportamiento actual:** relay se detiene silenciosamente (error logueado en desktop, `BAD_DECRYPT` tipo Android). Usuario no ve notificación.

**Mitigación Fase 3:** detectar `invalid_grant` explícitamente y emitir evento UI "relay desconfigurado — reconectar OAuth".

---

### 2. Cambio de contraseña Google

**Cuándo:** el usuario cambia la contraseña de su cuenta Google.

**Síntoma:** Google revoca todos los refresh_tokens activos. Mismo comportamiento que caso 1.

**Mitigación Fase 3:** ídem caso 1. El flujo de reconfiguración OAuth debe estar en la UI.

---

### 3. Cuota Drive AppData agotada

**Cuándo:** Drive AppData alcanza el límite de almacenamiento de la cuenta Google (compartido con Drive general).

**Síntoma:** `drive_upload` devuelve HTTP 403 `storageQuotaExceeded`. Los eventos pending del Android no se suben. Los desktop events tampoco.

**Comportamiento actual:** error logueado, relay intenta en el siguiente ciclo (30s). Sin limpieza automática de archivos viejos.

**Mitigación Fase 3:** limpieza periódica de ACKs procesados en Drive (ambos lados). Tamaño por evento ≈ 500-1000 bytes; con uso normal < 1MB/mes.

---

### 4. Conectividad intermitente

**Cuándo:** tablet o desktop sin WiFi/datos durante el ciclo relay.

**Síntoma:** `drive_upload` / `drive_download` fallan con error de red. WorkManager en Android reintenta con backoff. Desktop relay espera 30s y vuelve a intentar.

**Comportamiento actual:** correcto por diseño (WorkManager + loop desktop con sleep 30s). Sin pérdida de eventos (pending persiste hasta ACK).

**Mitigación:** ninguna adicional necesaria en Fase 2.

---

### 5. Reloj del dispositivo desfasado

**Cuándo:** el reloj del tablet o del desktop difiere significativamente de la hora real.

**Síntoma:** `drive_token_expires_at` (Unix ms) se compara con `System.currentTimeMillis()` en Android o `now_ms()` en Rust. Si el reloj va adelantado, el token se considera caducado cuando aún es válido. Si va atrasado, se usa un token caducado sin intentar refresh.

**Mitigación:** confiar en el error HTTP 401 de Google como señal autoritativa de token caducado, no solo en el timestamp local. Implementar en Fase 3.

---

### 6. Inactividad de 6 meses (Google política)

**Cuándo:** el usuario no usa la app durante 6+ meses y el refresh_token no se usa en ese período.

**Síntoma:** Google revoca el refresh_token por inactividad. Mismo comportamiento que caso 1.

**Mitigación Fase 3:** ídem caso 1. Añadir "última vez conectado" en UI.

---

### 7. Scopes parciales

**Cuándo:** durante el flujo OAuth, el usuario desmarca el scope `drive.appdata` en la pantalla de consentimiento.

**Síntoma:** el access_token se obtiene pero sin el scope necesario. Las llamadas a Drive AppData devuelven HTTP 403.

**Comportamiento actual:** error no manejado específicamente. Se confunde con error de cuota.

**Mitigación Fase 3:** verificar scopes en el token al configurar el relay. Mostrar error específico si falta `drive.appdata`.

---

### 8. Refresh_token caduca en modo prueba Google Cloud (7 días)

**Cuándo:** la aplicación está en modo "Testing" en Google Cloud Console con el proyecto no verificado.

**Síntoma:** el refresh_token expira a los 7 días independientemente de la actividad. Google devuelve `{"error":"invalid_grant"}`.

**Estado actual:** R17 ABIERTO. Fecha de caducidad estimada: ~2026-05-06.

**Mitigación a corto plazo:** rotar refresh_token manualmente antes de la caducidad (ejecutar flujo OAuth de nuevo). A largo plazo: verificar la app en Google Cloud o usar cuenta de producción.

---

### 9. Client secret comprometido

**Cuándo:** el `client_secret` es expuesto (p.ej. en un log de sesión — ver R19).

**Síntoma:** un tercero podría usar el client_secret para hacer peticiones OAuth en nombre de la app. En modo prueba con usuario de test, el impacto es limitado.

**Estado actual:** R19 ABIERTO. Los secretos de la sesión 2026-04-29 deben rotarse tras los 7 días de prueba.

**Mitigación:** rotar `client_secret` en Google Cloud Console + revocar `refresh_token` actual + re-ejecutar flujo OAuth.
