# Nota Técnica — T-0c-000: Resultado del Milestone 0

date: 2026-04-24
task_id: T-0c-000
phase: 0c
author: Android Share Intent Specialist
status: COMPLETADO — fallback activado

---

## Resultado

**Build pipeline Rust → Android validado.** APK debug generado para `aarch64-linux-android`.

```
app-arm64-debug.apk
src-tauri/gen/android/app/build/outputs/apk/arm64/debug/
```

---

## SQLCipher: fallback activado (pre-autorizado en AR-0c-001)

### Fallo encontrado

`bundled-sqlcipher-vendored-openssl` no compila en cross-compilación Windows → Android.
El crate `openssl-src` invoca `perl ./Configure linux-aarch64` durante el build script del host.
El script Configure de OpenSSL 3.6.2 falla con exit code 255 en el entorno Windows actual,
independientemente de si se usa Cygwin Perl o Strawberry Perl.

Causa raíz: el Configure de OpenSSL para cross-compilación Android requiere herramientas del
toolchain NDK en PATH en el momento en que corre el build script del host, una combinación que
no funciona de forma fiable desde Windows 10 con el NDK instalado en AppData.

### Fallback aplicado

Cargo.toml actualizado con dependencias condicionales por plataforma:

```toml
[target.'cfg(not(target_os = "android"))'.dependencies]
rusqlite = { version = "0.31", features = ["bundled-sqlcipher-vendored-openssl"] }

[target.'cfg(target_os = "android")'.dependencies]
rusqlite = { version = "0.31", features = ["bundled"] }
```

`storage.rs`: el `PRAGMA key` se omite en Android con `#[cfg(not(target_os = "android"))]`.

### Implicación para D1

La base de datos Android en Fase 0c no tiene cifrado SQLCipher a nivel de fichero.
D1 sigue siendo conforme: url y title se cifran a nivel de campo en `crypto.rs` (XOR)
antes del INSERT, igual que en desktop. La BD está en el directorio privado de la app
(aislamiento de Android) — no es accesible sin root.

Para T-0c-001 se puede añadir AES-256-GCM via Android Keystore para el cifrado de campos,
sustituyendo el XOR actual y elevando la protección a nivel criptográfico fuerte.

---

## Entorno de build verificado

| Herramienta | Versión | Ruta |
| --- | --- | --- |
| NDK | 27.3.13750724 | `%LOCALAPPDATA%\Android\Sdk\ndk\27.3.13750724` |
| JDK | 17.0.18.8 (Microsoft) | `C:\Program Files\Microsoft\jdk-17.0.18.8-hotspot` |
| Rust target | aarch64-linux-android | instalado vía rustup |
| Gradle | 8.14.3 | vía gradlew |
| NDK_HOME | seteado permanentemente | variable de entorno de usuario |
| JAVA_HOME | seteado permanentemente a JDK 17 | variable de entorno de usuario |

---

## Workarounds activos en Windows

### 1. Symlinks deshabilitados sin Developer Mode

Tauri CLI intenta crear symlinks de la `.so` a `jniLibs/`. Esto falla en Windows sin
Developer Mode o sin permisos de administrador.

**Workaround:** `BuildTask.kt` modificado para saltarse el rebuild de Rust si la `.so`
ya existe en `jniLibs/arm64-v8a/`. El flujo correcto es:

```
cargo build --target aarch64-linux-android  (produce la .so)
    ↓
copiar manualmente libflowweaver_lib.so a gen/android/app/src/main/jniLibs/arm64-v8a/
    ↓
./gradlew assembleArm64Debug -PtargetList=aarch64 -PabiList=arm64-v8a -ParchList=arm64
```

### 2. Target único aarch64

Se usa `-PtargetList=aarch64 -PabiList=arm64-v8a -ParchList=arm64` en Gradle para evitar
que el plugin Rust intente compilar armv7/x86/x86_64 (que también fallarían por el mismo
motivo de symlinks o falta de .so).

---

## Procedimiento de rebuild completo (Fase 0c)

Cuando se modifica código Rust y hay que regenerar el APK:

```powershell
# 1. Compilar Rust para Android
$env:NDK_HOME = "$env:LOCALAPPDATA\Android\Sdk\ndk\27.3.13750724"
cd C:\Users\pinnovacion\Desktop\FlowWeaver
cargo build --target aarch64-linux-android --manifest-path src-tauri/Cargo.toml --lib

# 2. Copiar .so a jniLibs
Copy-Item src-tauri\target\aarch64-linux-android\debug\libflowweaver_lib.so `
          src-tauri\gen\android\app\src\main\jniLibs\arm64-v8a\ -Force

# 3. Gradle
cd src-tauri\gen\android
.\gradlew.bat assembleArm64Debug -PtargetList=aarch64 -PabiList=arm64-v8a -ParchList=arm64
```

---

## Gate de salida de T-0c-000

- [x] `libflowweaver_lib.so` compilado para `aarch64-linux-android` sin errores de linking
- [x] APK debug generado sin errores
- [x] Fallback SQLite + field-level XOR documentado (D1 conforme)
- [x] Procedimiento de rebuild documentado
- [ ] SQLCipher a nivel de fichero en Android — diferido a T-0c-001 (AES-256-GCM via Keystore)
