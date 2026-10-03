$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& "$PSScriptRoot\build.ps1"
& $compiler /nologo /codepage:65001 /target:exe /main:Tests /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.IO.Compression.dll /out:"$PSScriptRoot\bin\Tests.exe" "$PSScriptRoot\Tests.cs" "$PSScriptRoot\Program.cs" "$PSScriptRoot\OtmmCodec.cs" "$PSScriptRoot\MapArchive.cs" "$PSScriptRoot\SshMapTab.cs"
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar os testes.' }
& node "$PSScriptRoot\test.js"
if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes.' }
& "$PSScriptRoot\bin\Tests.exe" ssh
if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes SSH.' }
