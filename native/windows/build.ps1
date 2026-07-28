param(
    [ValidateSet('template_debug', 'template_release')]
    [string]$Target = 'template_debug',
    [string]$GodotConsole = 'D:\godot\引擎版本\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe',
    [string]$VsDevShell = 'D:\Dev\Tools\Microsoft Visual Studio\18\BuildTools\Common7\Tools\Launch-VsDevShell.ps1'
)

$ErrorActionPreference = 'Stop'
$nativeRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $nativeRoot)
$apiPath = Join-Path $nativeRoot 'extension_api.json'

if (-not (Test-Path -LiteralPath $GodotConsole)) {
    throw "Godot 4.7.1 console executable not found: $GodotConsole"
}
if (-not (Test-Path -LiteralPath $VsDevShell)) {
    throw "Visual Studio developer shell not found: $VsDevShell"
}
if (-not (Test-Path -LiteralPath (Join-Path $nativeRoot 'godot-cpp\SConstruct'))) {
    throw 'godot-cpp submodule is missing. Run: git submodule update --init --recursive'
}

if (-not (Test-Path -LiteralPath $apiPath)) {
    Push-Location -LiteralPath $nativeRoot
    try {
        & $GodotConsole --headless --dump-extension-api
        if ($LASTEXITCODE -ne 0) {
            throw "Godot extension API export failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

. $VsDevShell -Arch amd64 -HostArch amd64
$env:UV_CACHE_DIR = Join-Path $repoRoot '.cache\uv'
Push-Location -LiteralPath $nativeRoot
try {
    uvx --from scons scons platform=windows target=$Target arch=x86_64 custom_api_file=$apiPath
    if ($LASTEXITCODE -ne 0) {
        throw "SCons failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
