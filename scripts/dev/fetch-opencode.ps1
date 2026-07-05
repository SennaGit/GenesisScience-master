# Fetch the pinned OpenCode binary and place it as a Tauri sidecar.
# Output: apps/desktop/src-tauri/binaries/opencode-<target-triple>[.exe]
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$TargetTriple = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$OpenCodeVersion = if ($env:OPENCODE_VERSION) { $env:OPENCODE_VERSION } else { "1.17.13" }
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$OutDir = Join-Path $Root "apps\desktop\src-tauri\binaries"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Get-HostTriple {
  $rustc = & rustc -Vv
  if ($LASTEXITCODE -ne 0) { throw "rustc is required to infer the host target triple" }
  $hostLine = $rustc | Where-Object { $_ -like "host: *" } | Select-Object -First 1
  if (-not $hostLine) { throw "could not read host target triple from rustc -Vv" }
  return ($hostLine -replace "^host:\s*", "").Trim()
}

if (-not $TargetTriple) { $TargetTriple = Get-HostTriple }

switch ($TargetTriple) {
  "aarch64-apple-darwin" { $Asset = "opencode-darwin-arm64.zip"; $Exe = $false; break }
  "x86_64-apple-darwin" { $Asset = "opencode-darwin-x64.zip"; $Exe = $false; break }
  "x86_64-pc-windows-msvc" { $Asset = "opencode-windows-x64.zip"; $Exe = $true; break }
  "aarch64-pc-windows-msvc" { $Asset = "opencode-windows-arm64.zip"; $Exe = $true; break }
  default { throw "Unsupported triple: $TargetTriple" }
}

$Url = "https://github.com/anomalyco/opencode/releases/download/v$OpenCodeVersion/$Asset"
$Tmp = Join-Path ([IO.Path]::GetTempPath()) ("genesisscience-opencode-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
try {
  $ZipPath = Join-Path $Tmp "opencode.zip"
  Write-Host "Downloading $Url"
  Invoke-WebRequest -Uri $Url -OutFile $ZipPath -UseBasicParsing
  Expand-Archive -Path $ZipPath -DestinationPath $Tmp -Force

  $Name = if ($Exe) { "opencode.exe" } else { "opencode" }
  $Bin = Get-ChildItem -Path $Tmp -Recurse -File -Filter $Name | Select-Object -First 1
  if (-not $Bin) { throw "Archive did not contain $Name" }

  $DestName = if ($Exe) { "opencode-$TargetTriple.exe" } else { "opencode-$TargetTriple" }
  $Dest = Join-Path $OutDir $DestName
  Copy-Item -LiteralPath $Bin.FullName -Destination $Dest -Force
  if (-not $Exe -and (Get-Command chmod -ErrorAction SilentlyContinue)) { & chmod +x $Dest }
  Write-Host "Placed sidecar for $TargetTriple at $Dest"
} finally {
  Remove-Item -LiteralPath $Tmp -Recurse -Force -ErrorAction SilentlyContinue
}