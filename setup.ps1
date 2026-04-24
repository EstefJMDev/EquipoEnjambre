# setup.ps1 — Configura el entorno de desarrollo completo desde cero
# Ejecutar desde la raiz de EquipoEnjambre:  .\setup.ps1
# Seguro de relanzar: winget ignora paquetes ya instalados.

$ErrorActionPreference = "Continue"

function Write-Step  { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "    OK  $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "    WARN $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "    FAIL $msg" -ForegroundColor Red }

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$FlowWeaverDir = Join-Path (Split-Path -Parent $ScriptDir) "FlowWeaver"

Write-Host ""
Write-Host "FlowWeaver — Setup de entorno completo" -ForegroundColor White
Write-Host "=======================================" -ForegroundColor White

# ─────────────────────────────────────────────────────────────────────────────
Write-Step "1. Git — nombre y email de usuario"
# ─────────────────────────────────────────────────────────────────────────────

$gitName  = git config --global user.name  2>$null
$gitEmail = git config --global user.email 2>$null

if (-not $gitName) {
    $gitName = Read-Host "   Introduce tu nombre para Git (ej: EstefJMDev)"
    git config --global user.name $gitName
}
if (-not $gitEmail) {
    $gitEmail = Read-Host "   Introduce tu email para Git"
    git config --global user.email $gitEmail
}
Write-Ok "git user: $gitName <$gitEmail>"

# ─────────────────────────────────────────────────────────────────────────────
Write-Step "2. Herramientas base via winget (orden critico)"
# ─────────────────────────────────────────────────────────────────────────────

$packages = @(
    @{ id = "7zip.7zip";                          name = "7-Zip" },
    @{ id = "StrawberryPerl.StrawberryPerl";      name = "Strawberry Perl (OpenSSL para Rust)" },
    @{ id = "Microsoft.VisualStudio.2022.BuildTools"; name = "VS Build Tools 2022" },
    @{ id = "Microsoft.WindowsSDK.10.0.26100";    name = "Windows SDK" },
    @{ id = "Git.Git";                            name = "Git" },
    @{ id = "GitHub.GitLFS";                      name = "Git LFS" },
    @{ id = "Rustlang.Rustup";                    name = "Rustup" },
    @{ id = "OpenJS.NodeJS";                      name = "Node.js" },
    @{ id = "Python.Launcher";                    name = "Python" },
    @{ id = "Microsoft.VisualStudioCode";         name = "VS Code" },
    @{ id = "Google.AndroidStudio";               name = "Android Studio" },
    @{ id = "Ollama.Ollama";                      name = "Ollama" },
    @{ id = "Docker.DockerDesktop";               name = "Docker Desktop" },
    @{ id = "Google.GoogleDrive";                 name = "Google Drive" },
    @{ id = "Google.Chrome.EXE";                  name = "Google Chrome" }
)

foreach ($pkg in $packages) {
    Write-Host "    Instalando $($pkg.name)..." -NoNewline
    winget install --id $pkg.id --accept-package-agreements --accept-source-agreements --silent 2>$null | Out-Null
    Write-Ok $pkg.name
}

# Refrescar PATH para que los nuevos programas sean accesibles
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","User")

# Git LFS init
git lfs install 2>$null | Out-Null
Write-Ok "Git LFS inicializado"

# ─────────────────────────────────────────────────────────────────────────────
Write-Step "3. Rust — targets para compilacion Android (Tauri)"
# ─────────────────────────────────────────────────────────────────────────────

$targets = @(
    "aarch64-linux-android",
    "armv7-linux-androideabi",
    "i686-linux-android",
    "x86_64-linux-android"
)

foreach ($target in $targets) {
    rustup target add $target 2>$null | Out-Null
    Write-Ok "target: $target"
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Step "4. Variables de entorno (ANDROID_HOME, NDK_HOME, JAVA_HOME)"
# ─────────────────────────────────────────────────────────────────────────────

$sdkPath = "$env:LOCALAPPDATA\Android\Sdk"
$ndkVersion = "27.3.13750724"
$ndkPath = "$sdkPath\ndk\$ndkVersion"

# Android Studio instala el SDK aqui por defecto. Si no existe, avisar.
if (-not (Test-Path $sdkPath)) {
    Write-Warn "Android SDK no encontrado en $sdkPath"
    Write-Warn "Abre Android Studio, completa el wizard inicial y vuelve a ejecutar este script."
    Write-Warn "El SDK se instalara en: $sdkPath"
} else {
    [System.Environment]::SetEnvironmentVariable("ANDROID_HOME",     $sdkPath, "User")
    [System.Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkPath, "User")
    Write-Ok "ANDROID_HOME = $sdkPath"

    # NDK
    if (Test-Path $ndkPath) {
        [System.Environment]::SetEnvironmentVariable("NDK_HOME", $ndkPath, "User")
        Write-Ok "NDK_HOME = $ndkPath"
    } else {
        Write-Warn "NDK $ndkVersion no encontrado. Instalalo desde Android Studio > SDK Manager > SDK Tools > NDK (Side by side) version $ndkVersion"
    }

    # JAVA_HOME — usar el JBR de Android Studio
    $jbrPath = "C:\Program Files\Android\Android Studio\jbr"
    if (Test-Path $jbrPath) {
        [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $jbrPath, "User")
        Write-Ok "JAVA_HOME = $jbrPath"
    } else {
        Write-Warn "JBR de Android Studio no encontrado en $jbrPath. Ajusta JAVA_HOME manualmente tras instalar Android Studio."
    }
}

# PATH additions
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$additions = @(
    "$env:USERPROFILE\.cargo\bin",
    "$sdkPath\platform-tools",
    "$sdkPath\emulator",
    "$env:APPDATA\npm"
)
foreach ($add in $additions) {
    if ($userPath -notlike "*$add*") {
        $userPath = "$add;$userPath"
        Write-Ok "PATH += $add"
    }
}
[System.Environment]::SetEnvironmentVariable("PATH", $userPath, "User")
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + $userPath

# ─────────────────────────────────────────────────────────────────────────────
Write-Step "5. npm — paquetes globales"
# ─────────────────────────────────────────────────────────────────────────────

npm install -g @anthropic-ai/claude-code 2>$null | Out-Null
Write-Ok "claude-code instalado"

npm install -g @qwen-code/qwen-code 2>$null | Out-Null
Write-Ok "qwen-code instalado"

# ─────────────────────────────────────────────────────────────────────────────
Write-Step "6. GitHub CLI — autenticacion"
# ─────────────────────────────────────────────────────────────────────────────

$ghInstalled = Get-Command gh -ErrorAction SilentlyContinue
if (-not $ghInstalled) {
    winget install --id GitHub.cli --accept-package-agreements --accept-source-agreements --silent 2>$null | Out-Null
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
}

$ghAuth = gh auth status 2>&1
if ($ghAuth -like "*Logged in*") {
    Write-Ok "GitHub CLI ya autenticado"
} else {
    Write-Host "    Iniciando autenticacion con GitHub..." -ForegroundColor Yellow
    gh auth login
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Step "7. Repositorio FlowWeaver"
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Test-Path $FlowWeaverDir)) {
    Write-Host "    Clonando FlowWeaver en $FlowWeaverDir..."
    git clone https://github.com/EstefJMDev/FlowWeaver.git $FlowWeaverDir
    Write-Ok "FlowWeaver clonado"
} else {
    Write-Ok "FlowWeaver ya existe en $FlowWeaverDir"
    Set-Location $FlowWeaverDir
    git pull origin main 2>$null | Out-Null
    Write-Ok "FlowWeaver actualizado"
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Step "8. FlowWeaver — dependencias y setup"
# ─────────────────────────────────────────────────────────────────────────────

Set-Location $FlowWeaverDir

Write-Host "    npm install..."
npm install 2>$null | Out-Null
Write-Ok "Dependencias npm instaladas"

# Regenerar carpeta gen/ (ignorada por git, necesaria para Android)
if (Test-Path "$sdkPath") {
    Write-Host "    Generando proyecto Android (tauri android init)..."
    $env:ANDROID_HOME = $sdkPath
    $env:ANDROID_SDK_ROOT = $sdkPath
    npx tauri android init 2>$null | Out-Null
    Write-Ok "Proyecto Android generado"
} else {
    Write-Warn "Android SDK no disponible — ejecuta 'npx tauri android init' tras instalar Android Studio"
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Step "9. VS Code — extensiones recomendadas"
# ─────────────────────────────────────────────────────────────────────────────

Write-Ok "Las extensiones recomendadas se instalan automaticamente al abrir el workspace en VS Code."
Write-Ok "Archivo: EquipoEnjambre.code-workspace"

# ─────────────────────────────────────────────────────────────────────────────
Write-Step "10. Verificacion final"
# ─────────────────────────────────────────────────────────────────────────────

Set-Location $ScriptDir

$checks = @(
    @{ cmd = "git --version";      label = "Git" },
    @{ cmd = "rustc --version";    label = "Rust" },
    @{ cmd = "cargo --version";    label = "Cargo" },
    @{ cmd = "node --version";     label = "Node.js" },
    @{ cmd = "npm --version";      label = "npm" },
    @{ cmd = "python --version";   label = "Python" },
    @{ cmd = "perl --version";     label = "Perl" },
    @{ cmd = "adb --version";      label = "ADB" },
    @{ cmd = "ollama --version";   label = "Ollama" },
    @{ cmd = "gh --version";       label = "GitHub CLI" },
    @{ cmd = "claude --version";   label = "Claude Code" }
)

foreach ($check in $checks) {
    $result = Invoke-Expression $check.cmd 2>$null
    if ($result) {
        Write-Ok "$($check.label): $result"
    } else {
        Write-Fail "$($check.label): no encontrado — revisa la instalacion"
    }
}

$rustTargets = rustup target list --installed 2>$null | Select-String "android"
if ($rustTargets) {
    Write-Ok "Rust targets Android: $($rustTargets.Count) instalados"
} else {
    Write-Fail "Rust targets Android: no encontrados"
}

Write-Host ""
Write-Host "Setup completado." -ForegroundColor Green
Write-Host "Abre el workspace: EquipoEnjambre.code-workspace" -ForegroundColor White
Write-Host ""

# Si Android Studio fue recien instalado, recordar completar el wizard
if (-not (Test-Path "$sdkPath\platform-tools")) {
    Write-Host "PENDIENTE: Abre Android Studio, completa el wizard inicial (instala SDK + NDK $ndkVersion)" -ForegroundColor Yellow
    Write-Host "           Despues ejecuta de nuevo: .\setup.ps1" -ForegroundColor Yellow
    Write-Host ""
}
