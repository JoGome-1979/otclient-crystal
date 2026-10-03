$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$output = Join-Path $PSScriptRoot 'bin'
New-Item -ItemType Directory -Force -Path $output | Out-Null
& $compiler /nologo /codepage:65001 /target:winexe /optimize+ /platform:anycpu /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.IO.Compression.dll /out:"$output\OTMapas.exe" "$PSScriptRoot\Program.cs" "$PSScriptRoot\OtmmCodec.cs" "$PSScriptRoot\MapArchive.cs" "$PSScriptRoot\SshMapTab.cs"
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar o aplicativo.' }
Write-Output "Aplicativo: $output\OTMapas.exe"
