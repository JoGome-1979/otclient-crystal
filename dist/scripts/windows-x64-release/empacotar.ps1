[CmdletBinding()]
param([ValidatePattern('^\d+\.\d+\.\d+(\.\d+)?$')][string]$Version = '1.0.0')
$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$preset = 'windows-x64-release'
$source = Join-Path $root "dist\$preset"
if (-not (Test-Path (Join-Path $source 'Clientex64.exe'))) {
    throw "Compile primeiro: cmake --preset $preset; cmake --build build/$preset -j 10"
}
$output = Join-Path $root "dist\instalador\$preset"
New-Item -ItemType Directory -Path $output -Force | Out-Null
$zip = Join-Path $output "CrystalClient-$preset-$Version.zip"
if (Test-Path $zip) {
    $backup = Join-Path $root ("backups\" + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-zip')
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    Copy-Item -LiteralPath $zip -Destination $backup
}
$entries = @(Get-ChildItem -LiteralPath $source | Where-Object { $_.Name -ne '.crystal-distribution' })
Compress-Archive -LiteralPath $entries.FullName -DestinationPath $zip -Force
Write-Host "Pacote criado: $zip"
