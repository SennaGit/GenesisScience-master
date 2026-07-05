# Fetch the pinned aether-synth-skills pack into runtime/skills/external/aether-synth-skills/.
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$Commit = if ($env:AETHER_SYNTH_SKILLS_COMMIT) { $env:AETHER_SYNTH_SKILLS_COMMIT } else { "8fa2ab0523082c135598909b227ed8feb48263ad" }
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$OutDir = Join-Path $Root "runtime\skills\external\aether-synth-skills"
$Url = "https://github.com/aether-synth/aether-synth-skills/archive/$Commit.tar.gz"
$Tmp = Join-Path ([IO.Path]::GetTempPath()) ("genesisscience-skills-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
try {
  $ArchivePath = Join-Path $Tmp "skills.tar.gz"
  Write-Host "Downloading $Url"
  Invoke-WebRequest -Uri $Url -OutFile $ArchivePath -UseBasicParsing
  & tar -xzf $ArchivePath -C $Tmp
  if ($LASTEXITCODE -ne 0) { throw "tar failed to extract skills archive" }

  $Src = Get-ChildItem -Path $Tmp -Directory -Filter "aether-synth-skills-*" | Select-Object -First 1
  if (-not $Src -or -not (Test-Path (Join-Path $Src.FullName "skills"))) {
    throw "No skills/ directory in archive"
  }

  Remove-Item -LiteralPath $OutDir -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
  Copy-Item -Path (Join-Path $Src.FullName "skills\*") -Destination $OutDir -Recurse -Force
  Set-Content -Path (Join-Path $OutDir ".commit") -Value $Commit -Encoding UTF8 -NoNewline

  Write-Host "Placed aether-synth-skills@$($Commit.Substring(0, 7)) in $OutDir"
  Get-ChildItem -Path $OutDir | Select-Object -ExpandProperty Name
} finally {
  Remove-Item -LiteralPath $Tmp -Recurse -Force -ErrorAction SilentlyContinue
}
