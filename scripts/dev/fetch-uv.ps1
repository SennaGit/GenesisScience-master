# Fetch the pinned uv binary and place it as a Tauri sidecar.
# Output: apps/desktop/src-tauri/binaries/uv-<target-triple>[.exe]
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$TargetTriple = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$UvVersion = if ($env:UV_VERSION) { $env:UV_VERSION } else { "0.11.26" }
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
  "aarch64-apple-darwin" { $Asset = "uv-$TargetTriple.tar.gz"; $Exe = $false; break }
  "x86_64-apple-darwin" { $Asset = "uv-$TargetTriple.tar.gz"; $Exe = $false; break }
  "x86_64-pc-windows-msvc" { $Asset = "uv-$TargetTriple.zip"; $Exe = $true; break }
  "aarch64-pc-windows-msvc" { $Asset = "uv-$TargetTriple.zip"; $Exe = $true; break }
  default { throw "Unsupported triple: $TargetTriple" }
}

$Url = "https://github.com/astral-sh/uv/releases/download/$UvVersion/$Asset"
$Tmp = Join-Path ([IO.Path]::GetTempPath()) ("genesisscience-uv-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
try {
  $Archive = Join-Path $Tmp $Asset
  Write-Host "Downloading $Url"
  Invoke-WebRequest -Uri $Url -OutFile $Archive -UseBasicParsing
  if ($Asset.EndsWith(".zip")) {
    Expand-Archive -Path $Archive -DestinationPath $Tmp -Force
  } else {
    & tar -xzf $Archive -C $Tmp
    if ($LASTEXITCODE -ne 0) { throw "tar failed to extract $Asset" }
  }

  $Name = if ($Exe) { "uv.exe" } else { "uv" }
  $Bin = Get-ChildItem -Path $Tmp -Recurse -File -Filter $Name | Select-Object -First 1
  if (-not $Bin) { throw "Archive did not contain $Name" }

  $DestName = if ($Exe) { "uv-$TargetTriple.exe" } else { "uv-$TargetTriple" }
  $Dest = Join-Path $OutDir $DestName
  Copy-Item -LiteralPath $Bin.FullName -Destination $Dest -Force
  if (-not $Exe -and (Get-Command chmod -ErrorAction SilentlyContinue)) { & chmod +x $Dest }
  Write-Host "Placed uv sidecar for $TargetTriple at $Dest"
} finally {
  Remove-Item -LiteralPath $Tmp -Recurse -Force -ErrorAction SilentlyContinue
}