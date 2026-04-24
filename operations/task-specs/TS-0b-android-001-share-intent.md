# Especificación Operativa — T-0b-android-001

owner_agent: Android Share Intent Specialist
document_id: TS-0b-android-001
task_id: T-0b-android-001
phase: 0b
date: 2026-04-24
status: DRAFT — pendiente de revisión por Technical Architect y Privacy Guardian
referenced_decisions: D1, D8, D9, D12, D19
referenced_arch_note: operations/architecture-notes/arch-note-phase-0c-android-review.md
required_review: Technical Architect (viabilidad Tauri 2 Android), Privacy Guardian (D1, D9)
depends_on: ninguna
blocks: TS-0b-android-002 (el sync necesita el payload que define esta TS)

---

## Propósito En Fase 0b

El Android Share Intent es el observer primario del producto (D9, D19). Es el
mecanismo por el que el usuario captura una URL desde cualquier app de Android
— Instagram, YouTube, el navegador, Twitter — y la entrega a FlowWeaver para
que el desktop prepare el workspace.

Este módulo es el punto de entrada del caso núcleo del producto: sin él, el
puente móvil→desktop no existe. Todos los módulos de procesamiento (Session
Builder, Episode Detector, Anticipated Workspace) ya están implementados en
desktop y esperan este input.

En Fase 0b, el Share Intent tiene un único rol: **capturar, clasificar y
encolar para sync**. No hay galería, no hay SQLCipher local permanente, no
hay historial en el móvil. El valor del producto en esta fase se entrega en
el desktop — el móvil es el punto de entrada del flujo.

---

## Plataforma Y Stack

- **Plataforma:** Android (API level 26+ / Android 8.0+)
- **Framework:** Tauri 2 con soporte Android nativo
- **Backend:** Rust compilado para `aarch64-linux-android` (target principal)
  y `armv7-linux-androideabi` (dispositivos más antiguos)
- **Build:** desde Windows 10 con Android Studio + NDK + Android SDK (D19)
- **Sin macOS requerido**

---

## Qué Hace

### Trigger

El usuario toca "Compartir" en cualquier app de Android y selecciona FlowWeaver
en el share sheet. El sistema invoca FlowWeaver con:

```
Intent action: android.intent.action.SEND
MIME type:     text/plain
Extras:        EXTRA_TEXT (URL), EXTRA_SUBJECT (título — opcional)
```

### Pipeline de captura (síncrono, completa en < 300ms)

```
Share Intent recibido
    │
    ├── extraer URL de EXTRA_TEXT
    ├── extraer título de EXTRA_SUBJECT (o cadena vacía si no existe)
    ├── derivar dominio de la URL (local, sin red)
    │
    ├── invocar Classifier (Rust, mismo que desktop)
    │       └── asigna categoría por dominio (determinístico, D8)
    │
    ├── generar event_id (UUID v4)
    ├── registrar captured_at (timestamp Unix ms)
    │
    ├── cifrar URL + título con clave de sync (D1)
    ├── construir raw_event (ver estructura abajo)
    │
    ├── encolar raw_event en cola local (SharedPreferences o archivo)
    │
    └── mostrar confirmación al usuario (ver UX abajo)
```

### Estructura del raw_event

```json
{
  "event_id":     "uuid-v4",
  "device_id":    "android-<uuid-fijo-del-dispositivo>",
  "captured_at":  1714000000000,
  "domain":       "instagram.com",
  "category":     "entertainment",
  "url_encrypted":   "<bytes base64>",
  "title_encrypted": "<bytes base64>",
  "schema_version": 1
}
```

Campos en claro (D1 conforme): `event_id`, `device_id`, `captured_at`,
`domain`, `category`. Campos cifrados: `url_encrypted`, `title_encrypted`.

El `device_id` es un UUID generado una vez al instalar la app y almacenado
en `SharedPreferences`. No cambia entre capturas ni entre reinicios.

### UX de confirmación

Al completar la captura, mostrar una tarjeta sobre el share sheet durante 4
segundos antes de cerrar la actividad:

```
┌─────────────────────────────────────────────────┐
│  ✓  Guardado en FlowWeaver                      │
│                                                 │
│  entertainment  ·  instagram.com                │
│                                                 │
│  Tu workspace del escritorio estará listo.      │
│                                     [Deshacer]  │
└─────────────────────────────────────────────────┘
```

- La categoría es el feedback inmediato de que el sistema procesó el recurso.
- "Deshacer" elimina el raw_event de la cola local antes de que el sync lo
  envíe. Disponible solo durante los 4 segundos de la tarjeta.
- Si el sync ya envió el evento (improbable en 4 segundos), "Deshacer" genera
  un evento de borrado con el mismo event_id (ver TS-0b-android-002).
- No hay botón "Ver en galería" en Fase 0b (la galería es Fase 0c).

---

## Qué NO Hace

| Elemento excluido | Primera fase permitida | Regla |
| --- | --- | --- |
| SQLCipher local permanente | Fase 0c | D20 — galería local es 0c |
| Galería de recursos en móvil | Fase 0c | scope-boundaries 0b |
| Background observer | nunca en MVP | D9 — solo captura explícita |
| Observación del clipboard | nunca | D9 |
| Acceso a historial del navegador | nunca | D9 |
| Scraping de contenido de la URL | nunca | D1 |
| Llamadas a red en el pipeline de captura | nunca | el pipeline es local |
| LLM para mejorar la clasificación | 0b (no como requisito) | D8 |
| Metadata adicional de Instagram API | nunca | D1, D9 |
| Sync bidireccional (recibir del desktop) | Fase 0c | D21 — 0b es unidireccional |

---

## Contrato Con Otros Módulos

### Con el Classifier (Rust, compartido con desktop)

El mismo crate Rust que clasifica en desktop compila para Android. El Share
Intent invoca `classify_domain(domain: &str) -> Category` de forma síncrona.
Sin red, sin LLM, sin async. El resultado debe estar disponible en < 10ms.

### Con la cola de sync (TS-0b-android-002)

El Share Intent no envía directamente a Google Drive. Escribe el raw_event en
una cola local (archivo JSON en el directorio privado de la app o
`SharedPreferences`) y el módulo de sync (TS-0b-android-002) lo consume de
forma independiente. Esta separación garantiza que el Share Intent completa
en < 300ms aunque Google Drive no esté disponible en ese momento.

### Con el desktop (indirecto — vía sync)

El raw_event llega al desktop a través del relay de Google Drive. El comando
`add_capture` ya implementado en el desktop recibe exactamente este payload.
No se requieren cambios en el backend desktop.

---

## Criterios De Aceptación

- [ ] el Share Intent se declara como target en `AndroidManifest.xml` con
      action `android.intent.action.SEND` y MIME type `text/plain`
- [ ] al compartir una URL desde Instagram, YouTube, el navegador o Twitter,
      FlowWeaver aparece en el share sheet de Android
- [ ] el pipeline de captura completa en < 300ms desde que el Intent se recibe
      hasta que la tarjeta de confirmación es visible
- [ ] la tarjeta de confirmación muestra la categoría asignada y el dominio
- [ ] "Deshacer" elimina el raw_event de la cola local si el sync no lo ha
      enviado aún
- [ ] el campo `url_encrypted` en el raw_event está cifrado — no es legible en
      claro en el archivo de la cola ni en Google Drive (D1)
- [ ] el campo `domain` y `category` en el raw_event están en claro (D1)
- [ ] el `device_id` es consistente entre capturas del mismo dispositivo
- [ ] no hay proceso activo, polling, watcher ni background observer fuera del
      Share Intent explícito (D9)
- [ ] si se comparte una URL sin título (sin `EXTRA_SUBJECT`), el campo
      `title_encrypted` cifra una cadena vacía — no falla el pipeline
- [ ] compartir desde el navegador (Chrome o Firefox de Android) funciona igual
      que desde Instagram o YouTube
- [ ] `cargo test` en el módulo Rust de Android pasa sin regresiones en los 14
      tests existentes del backend desktop

---

## Riesgos

| Riesgo | Descripción | Mitigación |
| --- | --- | --- |
| Share sheet no aparece | La app no se registra correctamente en el sistema | Verificar `AndroidManifest.xml` con prueba real en dispositivo físico |
| Timeout del Intent | Android mata la actividad si tarda > 5s | Pipeline síncrono en < 300ms garantiza margen |
| `EXTRA_TEXT` no contiene URL | Algunas apps comparten texto plano, no URLs | Validar formato URL; si inválido, mostrar "Solo se admiten URLs" y no encolar |
| Cifrado falla sin clave de sync | Si el usuario no ha emparejado el dispositivo | Ver TS-0b-android-002 — el emparejamiento genera la clave antes del primer uso |
| Classifier no compila para Android | Problema de NDK / cross-compilation | Milestone 0 de Fase 0b: verificar build antes de implementar UX |

---

## Milestone 0 — Validación Del Build Pipeline (Bloqueante)

Antes de implementar la UX de captura, verificar que el build Tauri 2 Android
compila el backend Rust completo (incluyendo Classifier) para el target Android:

```
tauri android build --debug --target aarch64-linux-android
```

Criterio de éxito: el APK se genera sin errores de linking. Si falla, escalar
al Technical Architect para decisión de fallback antes de continuar.

---

## Handoff Esperado

1. Android Share Intent Specialist produce este documento.
2. Technical Architect verifica viabilidad del build y contrato del raw_event.
3. Privacy Guardian verifica D1 (cifrado de URL/title) y D9 (captura explícita únicamente).
4. Tras aprobación: implementación del Share Intent + Milestone 0.
5. Completado: Android Share Intent Specialist produce TS-0b-android-002 (sync).
