[CmdletBinding()]
param(
  [ValidateSet('windows-x86-release','windows-x64-release','windows-x86-debug','windows-x64-debug')]
  [string]$Preset = 'windows-x64-release',
  [ValidateRange(1,256)][int]$Jobs = 10
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
  & cmake --build "build/$Preset" -j $Jobs
  if ($LASTEXITCODE -ne 0) { throw "Build failed: $LASTEXITCODE" }
} finally { Pop-Location }
