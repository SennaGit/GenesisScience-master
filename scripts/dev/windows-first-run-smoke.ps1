# Minimal repeatable Windows first-run smoke test for Genesis Science.
# Fast default: validates generated assets, Windows paths, sidecar names, and config.
# Optional: -BuildInstaller builds NSIS/MSI; -Launch starts the packaged app for manual first-run checks.
[CmdletBinding()]
param(
  [string]$TargetTriple = "",
  [switch]$Bootstrap,
  [switch]$BuildInstaller,
  [switch]$Launch,
  [switch]$SkipNodeChecks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Desktop = Join-Path $Root "apps\desktop"
$Tauri = Join-Path $Desktop "src-tauri"
$Binaries = Join-Path $Tauri "binaries"
$Failures = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$Message) {
  $Failures.Add($Message) | Out-Null
  Write-Host "FAIL $Message" -ForegroundColor Red
}

function Pass([string]$Message) { Write-Host "OK   $Message" -ForegroundColor Green }
function Info([string]$Message) { Write-Host "INFO $Message" -ForegroundColor Cyan }

function Require-Path([string]$Path, [string]$Label) {
  if (Test-Path -LiteralPath $Path) { Pass "$Label exists: $Path" } else { Add-Failure "$Label missing: $Path" }
}

function Get-HostTriple {
  if ($TargetTriple) { return $TargetTriple }
  if (-not (Get-Command rustc -ErrorAction SilentlyContinue)) {
    return "x86_64-pc-windows-msvc"
  }
  $rustc = & rustc -Vv 2>$null
  if ($LASTEXITCODE -ne 0) { return "x86_64-pc-windows-msvc" }
  $hostLine = $rustc | Where-Object { $_ -like "host: *" } | Select-Object -First 1
  if ($hostLine) { return ($hostLine -replace "^host:\s*", "").Trim() }
  return "x86_64-pc-windows-msvc"
}

$TargetTriple = Get-HostTriple
Info "Root: $Root"
Info "Target: $TargetTriple"

if ($env:OS -ne "Windows_NT") {
  Add-Failure "This is a Windows smoke test; run it on a real Windows host."
}

if ($Bootstrap) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "fetch-opencode.ps1") $TargetTriple
  if ($LASTEXITCODE -ne 0) { throw "fetch-opencode.ps1 failed" }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "fetch-uv.ps1") $TargetTriple
  if ($LASTEXITCODE -ne 0) { throw "fetch-uv.ps1 failed" }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "fetch-skills.ps1")
  if ($LASTEXITCODE -ne 0) { throw "fetch-skills.ps1 failed" }
}

$OpenCode = Join-Path $Binaries "opencode-$TargetTriple.exe"
$Uv = Join-Path $Binaries "uv-$TargetTriple.exe"
Require-Path $OpenCode "OpenCode Windows sidecar"
Require-Path $Uv "uv Windows sidecar"
Require-Path (Join-Path $Root "runtime\skills\external\aether-synth-skills") "external bundled skills"
Require-Path (Join-Path $Root "runtime\skills\core") "first-party skills"
Require-Path (Join-Path $Root "examples\climate-trends") "bundled climate example"

function Invoke-WithSmokeRuntime([scriptblock]$Block) {
  $base = Join-Path $Root ".tmp"
  $smokeRoot = Join-Path $base "windows-smoke-runtime"
  New-Item -ItemType Directory -Force -Path $smokeRoot | Out-Null
  $old = @{
    XDG_CONFIG_HOME = $env:XDG_CONFIG_HOME
    XDG_DATA_HOME = $env:XDG_DATA_HOME
    XDG_CACHE_HOME = $env:XDG_CACHE_HOME
    XDG_STATE_HOME = $env:XDG_STATE_HOME
  }
  try {
    $env:XDG_CONFIG_HOME = Join-Path $smokeRoot "xdg-config"
    $env:XDG_DATA_HOME = Join-Path $smokeRoot "xdg-data"
    $env:XDG_CACHE_HOME = Join-Path $smokeRoot "xdg-cache"
    $env:XDG_STATE_HOME = Join-Path $smokeRoot "xdg-state"
    foreach ($dir in @($env:XDG_CONFIG_HOME, $env:XDG_DATA_HOME, $env:XDG_CACHE_HOME, $env:XDG_STATE_HOME)) {
      New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    & $Block
  } finally {
    $env:XDG_CONFIG_HOME = $old.XDG_CONFIG_HOME
    $env:XDG_DATA_HOME = $old.XDG_DATA_HOME
    $env:XDG_CACHE_HOME = $old.XDG_CACHE_HOME
    $env:XDG_STATE_HOME = $old.XDG_STATE_HOME
    Remove-Item -LiteralPath $smokeRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
if (Test-Path -LiteralPath $OpenCode) {
  Invoke-WithSmokeRuntime {
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & $OpenCode --version 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $oldEap
    if ($code -eq 0) { Pass "OpenCode sidecar executes: $($out | Select-Object -First 1)" } else { Add-Failure "OpenCode sidecar did not execute --version: $($out | Select-Object -First 1)" }
  }
}
if (Test-Path -LiteralPath $Uv) {
  $oldEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $out = & $Uv --version 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = $oldEap
  if ($code -eq 0) { Pass "uv sidecar executes: $($out | Select-Object -First 1)" } else { Add-Failure "uv sidecar did not execute --version" }
}

$TauriConfig = Join-Path $Tauri "tauri.conf.json"
$config = Get-Content -Raw -Encoding UTF8 $TauriConfig | ConvertFrom-Json
$external = @($config.bundle.externalBin)
if ($external -contains "binaries/opencode" -and $external -contains "binaries/uv") {
  Pass "Tauri externalBin uses sidecar base names"
} else {
  Add-Failure "Tauri externalBin must include binaries/opencode and binaries/uv"
}

$resources = $config.bundle.resources.PSObject.Properties.Name
foreach ($resource in @("../../../runtime/skills/external/aether-synth-skills", "../../../runtime/skills/core", "../../../examples/climate-trends")) {
  if ($resources -contains $resource) { Pass "Tauri resource mapped: $resource" } else { Add-Failure "Tauri resource missing: $resource" }
}

$WorkspaceBase = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "GenesisScience"
$AppDataRoot = Join-Path $env:APPDATA "com.aethersynth.genesisscience"
$RuntimeRoot = Join-Path $AppDataRoot "runtime"
$AuthPath = Join-Path $RuntimeRoot "xdg-data\opencode\auth.json"
Info "Expected first-run workspace base: $WorkspaceBase"
Info "Expected app-private runtime root: $RuntimeRoot"
Info "Provider auth/config are app-private files, not Windows Credential Manager: $AuthPath"
$JupyterEnv = Join-Path $RuntimeRoot "jupyter-env"
$JupyterScripts = Join-Path $JupyterEnv "Scripts"
Info "Expected Jupyter env path after setup: $JupyterEnv"
Info "Expected Jupyter executables: $(Join-Path $JupyterScripts "jupyter-lab.exe"), $(Join-Path $JupyterScripts "jupyter-mcp-server.exe")"

if (-not $SkipNodeChecks) {
  & pnpm typecheck
  if ($LASTEXITCODE -eq 0) { Pass "pnpm typecheck" } else { Add-Failure "pnpm typecheck failed" }
}

if ($BuildInstaller) {
  & pnpm --filter "@aether-synth/desktop" tauri build --target $TargetTriple
  if ($LASTEXITCODE -eq 0) { Pass "Tauri Windows installer build" } else { Add-Failure "Tauri Windows installer build failed" }
}

if ($Launch) {
  $Exe = Get-ChildItem -Path (Join-Path $Tauri "target\$TargetTriple\release") -Filter "*.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($Exe) {
    Start-Process -FilePath $Exe.FullName
    Pass "Launched packaged app: $($Exe.FullName)"
    Info "Manual first-run checks: runtime badge ready, workspace shown under Documents\GenesisScience, new session creates a dated subfolder, Files can preview pdf/html/docx/xlsx/pptx, Jupyter setup creates runtime\jupyter-env\Scripts, provider login does not write into the workspace."
  } else {
    Add-Failure "No packaged app exe found; run with -BuildInstaller first."
  }
}

if ($Failures.Count -gt 0) {
  Write-Host "`nWindows smoke failed:" -ForegroundColor Red
  $Failures | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
  exit 1
}

Write-Host "`nWindows smoke passed." -ForegroundColor Green