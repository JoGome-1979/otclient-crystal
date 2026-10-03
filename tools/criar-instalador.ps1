# Compatibility entry point; packaging now lives under dist/scripts/.
& (Join-Path $PSScriptRoot '..\dist\scripts\windows-x86_64-release\criar-instalador.ps1') @args
