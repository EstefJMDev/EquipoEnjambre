# Setup Entorno de Desarrollo — pinnovacion
*Escaneado el 2026-04-24. Pasar este archivo a Claude en el nuevo equipo para que lo configure solo.*

---

## Instrucciones para Claude

Lee este archivo completo antes de instalar nada. El orden importa: algunas herramientas dependen de otras. Sigue las secciones en orden y verifica cada paso antes de pasar al siguiente.

---

## 1. Gestor de paquetes — Winget

Windows Package Manager (winget) viene preinstalado en Windows 11 y Windows 10 actualizado. Verificar con:

```powershell
winget --version
```

Si no está disponible, instalarlo desde la Microsoft Store buscando "App Installer".

---

## 2. Herramientas base (en este orden)

### Git + Git LFS

```powershell
winget install --id Git.Git -e
winget install --id GitHub.GitLFS -e
```

Después de instalar, configurar Git LFS:

```powershell
git lfs install
```

Verificar:

```powershell
git --version        # debe ser >= 2.54.0
git lfs version
```

### 7-Zip

```powershell
winget install --id 7zip.7zip -e
```

### Strawberry Perl (necesario para OpenSSL en Rust/Windows)

```powershell
winget install --id StrawberryPerl.StrawberryPerl -e
```

Verificar que `perl` está en el PATH después de instalar. **Instalar antes que Rust.**

---

## 3. Visual Studio Build Tools 2022

Requerido por Rust en Windows para compilar código nativo.

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
```

Durante la instalación seleccionar el workload:
- **"Desarrollo para el escritorio con C++"**

También instalar Windows SDK:

```powershell
winget install --id Microsoft.WindowsSDK.10.0.26100 -e
```

---

## 4. Rust + Cargo (via rustup)

```powershell
winget install --id Rustlang.Rustup -e
```

Cerrar y reabrir la terminal. Verificar:

```powershell
rustc --version    # debe ser >= 1.95.0
cargo --version    # debe ser >= 1.95.0
```

### Targets de Rust para compilación Android (Tauri Android)

Este equipo compila para Android. Instalar los cuatro targets:

```powershell
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add i686-linux-android
rustup target add x86_64-linux-android
```

Verificar targets instalados:

```powershell
rustup target list --installed
```

Debe mostrar los cuatro targets Android más `x86_64-pc-windows-msvc`.

---

## 5. Node.js

```powershell
winget install --id OpenJS.NodeJS -e
```

Verificar:

```powershell
node --version    # debe ser >= 24.13.0
npm --version     # debe ser >= 11.6.0
```

---

## 6. Python

```powershell
winget install --id Python.Launcher -e
```

Verificar:

```powershell
python --version    # debe ser >= 3.14.2
```

---

## 7. Android SDK + NDK (para Tauri Android)

### Opción A — Via Android Studio (recomendado)

Descargar e instalar Android Studio desde [developer.android.com/studio](https://developer.android.com/studio).

Durante la configuración inicial, instalar:
- Android SDK (API level 34 o superior)
- Android SDK Platform-Tools
- Android SDK Build-Tools
- NDK (Side by side) versión **27.3.13750724**
- CMake

### Opción B — SDK standalone (sin Android Studio)

Usar sdkmanager desde command line tools:
- Descargar "Command line tools only" desde la misma página
- Instalar en `C:\Users\<usuario>\AppData\Local\Android\Sdk`

### NDK específico (versión exacta usada en este equipo)

Una vez instalado el SDK, instalar el NDK exacto:

```powershell
# Desde Android Studio SDK Manager o via sdkmanager:
sdkmanager "ndk;27.3.13750724"
```

---

## 8. Variables de entorno (configurar en Sistema > Variables de entorno > Usuario)

| Variable | Valor |
|---|---|
| `ANDROID_HOME` | `C:\Users\<usuario>\AppData\Local\Android\Sdk` |
| `ANDROID_SDK_ROOT` | `C:\Users\<usuario>\AppData\Local\Android\Sdk` |
| `NDK_HOME` | `C:\Users\<usuario>\AppData\Local\Android\Sdk\ndk\27.3.13750724` |
| `JAVA_HOME` | Ruta al JDK de Android Studio (normalmente `C:\Program Files\Android\Android Studio\jbr`) |

### Añadir al PATH de usuario (en orden):

```
C:\Users\<usuario>\.cargo\bin
C:\Users\<usuario>\AppData\Local\Android\Sdk\platform-tools
C:\Users\<usuario>\AppData\Local\Android\Sdk\emulator
C:\Users\<usuario>\AppData\Roaming\npm
```

Verificar variables después de configurar (nueva terminal):

```powershell
echo $env:ANDROID_HOME
echo $env:NDK_HOME
adb --version
```

---

## 9. VS Code

```powershell
winget install --id Microsoft.VisualStudioCode -e
```

### Extensiones de VS Code a instalar

Instalar estas extensiones después de abrir VS Code:

```powershell
# Extensiones recomendadas para este stack (instalar una a una o via marketplace)
code --install-extension rust-lang.rust-analyzer
code --install-extension tauri-apps.tauri-vscode
code --install-extension dbaeumer.vscode-eslint
code --install-extension esbenp.prettier-vscode
code --install-extension bradlc.vscode-tailwindcss
code --install-extension ms-vscode.vscode-typescript-next
code --install-extension usernamehw.errorlens
```

---

## 10. Herramientas globales de npm

```powershell
npm install -g @anthropic-ai/claude-code
```

Verificar:

```powershell
claude --version    # debe ser >= 2.1.119
```

### Qwen Code (opcional, también instalado en este equipo)

```powershell
npm install -g @qwen-code/qwen-code
```

---

## 11. Ollama (modelos de IA local)

```powershell
winget install --id Ollama.Ollama -e
```

Verificar:

```powershell
ollama --version    # debe ser >= 0.21.1
```

Los modelos descargados no se migran automáticamente — habrá que volver a descargar los que se usen.

---

## 12. Otras aplicaciones instaladas

```powershell
winget install --id Docker.DockerDesktop -e
winget install --id Google.GoogleDrive -e
winget install --id Google.Chrome.EXE -e
winget install --id AnyDesk.AnyDesk -e
winget install --id Adobe.Acrobat.Reader.64-bit -e
```

---

## 13. Verificación final del entorno

Ejecutar estos comandos en una terminal nueva para confirmar que todo está correcto:

```powershell
git --version
rustc --version
cargo --version
rustup target list --installed
node --version
npm --version
python --version
adb --version
claude --version
ollama --version
```

### Verificación específica para Tauri Android

```powershell
# Debe mostrar los 4 targets Android
rustup target list --installed | Select-String "android"

# Debe encontrar el NDK
Test-Path $env:NDK_HOME
```

---

## 14. Clonar y levantar el proyecto FlowWeaver

```powershell
# Clonar el repo
git clone <url-del-repo> FlowWeaver
cd FlowWeaver

# Instalar dependencias frontend
npm install

# Verificar que TypeScript compila
npx tsc --noEmit

# Compilar y lanzar en desktop
npx tauri dev

# Para Android (con dispositivo conectado o emulador activo)
npx tauri android dev
```

---

## Notas importantes

- **Strawberry Perl debe instalarse antes de Rust** o la compilación de dependencias con OpenSSL fallará.
- **Visual Studio Build Tools debe instalarse antes de compilar cualquier crate Rust** con dependencias nativas.
- **JAVA_HOME debe apuntar a un JDK completo**, no al JRE de Autofirma. Android Studio instala su propio JDK (JBR) — usar ese.
- El NDK versión `27.3.13750724` es la versión exacta usada en este equipo. Usar otra puede introducir diferencias de compilación.
- Claude Code guarda su configuración en `C:\Users\<usuario>\.claude\` — copiar esa carpeta al nuevo equipo si se quiere migrar la memoria y ajustes.
