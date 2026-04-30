# INC-001 — Bug de escape `^&` en script OAuth

date: 2026-04-29
detected_by: Product Owner durante sesión de setup OAuth
time_lost: ~2 horas
severity: medio (coste de tiempo, sin pérdida de datos ni secretos)
status: CERRADO

---

## Síntoma

Al ejecutar `tmp_oauth_flow.js` (script de setup OAuth para Drive), el navegador no se abría automáticamente. Al abrirlo manualmente, Google Cloud mostraba un error de configuración que hacía pensar que el problema estaba en la configuración de la aplicación OAuth (client_id, scopes, redirect_uri).

Se invirtieron ~2 horas revisando la configuración de Google Cloud Console (scopes, authorized URIs, tipo de aplicación) asumiendo que el error era de configuración, cuando el problema era el script.

---

## Hipótesis incorrectas perseguidas (~2h)

1. Scopes incorrectos en OAuth consent screen → revisados y correctos.
2. Redirect URI no autorizada → verificada y correcta.
3. Tipo de aplicación equivocado (Web vs Desktop) → correcto.
4. Client ID incorrecto → correcto.

La URL que llegaba al navegador estaba malformada porque los `&` del query string habían sido convertidos a `^&` antes de pasarse al shell de Windows. El navegador recibía una URL rota y Google mostraba un error de parámetros, no de configuración.

---

## Causa raíz

En `tmp_oauth_flow.js`, la función que construía el comando `start` para abrir el navegador en Windows aplicaba `replace(/&/g, '^&')` sobre la URL OAuth:

```javascript
const escaped = url.replace(/&/g, '^&');  // bug
exec(`start "" "${escaped}"`);
```

El escape `^&` es correcto para argumentos pasados directamente al shell CMD de Windows sin comillas. Pero con comillas dobles alrededor de la URL, el `^` se pasa literalmente al navegador como parte de la URL, corrompiendo los parámetros `scope`, `redirect_uri`, etc.

El navegador recibía: `https://accounts.google.com/o/oauth2/v2/auth?...scope=...^&redirect_uri=...^&...`

Google interpretaba esos parámetros malformados como error de configuración de la app, no como error en la URL.

---

## Método de diagnóstico

Leer literalmente el mensaje de error de Google en el navegador en lugar de asumir que era un error de configuración. El mensaje indicaba "parámetros inválidos", no "aplicación no configurada". Al copiar la URL del navegador y verla en texto plano, los `^` eran visibles.

---

## Fix aplicado

No autoabrir el navegador. Imprimir la URL en consola para que el usuario la pegue manualmente:

```javascript
console.log('Abre este URL en el navegador:\n' + url);
// exec(`start "" "${url}"`);  // desactivado
```

---

## Lección aprendida

Los mensajes de error de Google OAuth son descriptivos si se leen con atención. "Invalid parameter" ≠ "Bad configuration". Leer el mensaje exacto antes de investigar la configuración habría ahorrado ~2h.

Antes de escalar a "la configuración está mal", verificar que el input (URL) llegó íntegro al destino.
