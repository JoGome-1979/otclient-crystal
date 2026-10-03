[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+\.\d+(\.\d+)?$')]
    [string]$Version = '1.0.0'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Find-InnoCompiler {
    <# Localiza o compilador do Inno Setup no PATH ou nos diretórios padrão. #>
    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $installed = @(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -match '^Inno Setup' -and $_.PSObject.Properties['InstallLocation'] -and $_.InstallLocation })
    foreach ($app in $installed) {
        $path = Join-Path $app.InstallLocation 'ISCC.exe'
        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }

    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        'D:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'D:\Program Files\Inno Setup 6\ISCC.exe'
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }

    throw 'Inno Setup 6 não encontrado. Instale com: winget install --id JRSoftware.InnoSetup -e'
}

function Backup-ExistingInstaller {
    <# Preserva instaladores de mesmo nome antes que o Inno Setup os substitua. #>
    param(
        [Parameter(Mandatory)][string]$InstallerPath,
        [Parameter(Mandatory)][string]$RepositoryRoot
    )

    if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
        return
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupDirectory = Join-Path $RepositoryRoot "backups\$timestamp-installer"
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    Copy-Item -LiteralPath $InstallerPath -Destination $backupDirectory
    Write-Host "Instalador anterior preservado em: $backupDirectory" -ForegroundColor Yellow
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$definitionFile = Join-Path $PSScriptRoot 'CrystalClient.iss'
$outputFile = Join-Path $repositoryRoot "dist\instalador\windows-x86_64-release\CrystalClient-Setup-$Version.exe"
$packages = @(
    [pscustomobject]@{
        Architecture = 'x64'
        Preset = 'windows-x64-release'
        Executable = Join-Path $repositoryRoot 'dist\windows-x64-release\Clientex64.exe'
        Stage = Join-Path $repositoryRoot 'dist\windows-x64-release'
        Machine = 0x8664
    },
    [pscustomobject]@{
        Architecture = 'x86'
        Preset = 'windows-x86-release'
        Executable = Join-Path $repositoryRoot 'dist\windows-x86-release\Clientex86.exe'
        Stage = Join-Path $repositoryRoot 'dist\windows-x86-release'
        Machine = 0x014C
    }
)

foreach ($package in $packages) {
    if (-not (Test-Path -LiteralPath $package.Executable -PathType Leaf)) {
        throw "O instalador precisa dos dois executaveis. Falta: $($package.Executable). Compile primeiro com: cmake --preset $($package.Preset); cmake --build build/$($package.Preset) -j 10"
    }
    # Check the PE target before labeling and packaging each executable.
    $stream = [System.IO.File]::OpenRead($package.Executable)
    $reader = [System.IO.BinaryReader]::new($stream)
    try {
        if ($reader.ReadUInt16() -ne 0x5A4D) { throw 'Executavel Windows invalido.' }
        $stream.Position = 0x3C
        $peOffset = $reader.ReadUInt32()
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) { throw 'Cabecalho PE invalido.' }
        if ($reader.ReadUInt16() -ne $package.Machine) {
            throw "O executavel $($package.Executable) nao corresponde a arquitetura $($package.Architecture)."
        }
    } finally {
        $reader.Dispose()
    }
}
if (-not (Test-Path -LiteralPath $definitionFile -PathType Leaf)) {
    throw "Arquivo de empacotamento nao encontrado: $definitionFile"
}
foreach ($package in $packages) {
    foreach ($required in @('init.lua', 'cacert.pem', 'config.ini', 'modules\updater\updater.otmod')) {
        if (-not (Test-Path -LiteralPath (Join-Path $package.Stage $required) -PathType Leaf)) {
            throw "Distribuicao incompleta: $($package.Stage) ($required)"
        }
    }
    if (@(Get-ChildItem -LiteralPath $package.Stage -Filter '*.dll').Count -gt 0) {
        throw "Release deve usar ligacao estatica: $($package.Stage) contem DLLs."
    }
}
$compiler = Find-InnoCompiler

$commonPackage = $packages[0].Stage
$x86Package = $packages[1].Stage
Backup-ExistingInstaller -InstallerPath $outputFile -RepositoryRoot $repositoryRoot

Write-Host "Criando instalador Crystal Client $Version com x86 e x64..." -ForegroundColor Cyan
& $compiler "/DRepositoryRoot=$repositoryRoot" "/DAppVersion=$Version" "/DPackageDirectory=$commonPackage" "/DX86PackageDirectory=$x86Package" $definitionFile
if ($LASTEXITCODE -ne 0) {
    throw "A criacao do instalador falhou com o codigo $LASTEXITCODE"
}
if (-not (Test-Path -LiteralPath $outputFile -PathType Leaf)) {
    throw "O Inno Setup terminou sem gerar o arquivo esperado: $outputFile"
}

$hash = (Get-FileHash -LiteralPath $outputFile -Algorithm SHA256).Hash
Write-Host 'Instalador com as duas arquiteturas criado com sucesso.' -ForegroundColor Green
Write-Host "Arquivo: $outputFile"
Write-Host "SHA256: $hash"
