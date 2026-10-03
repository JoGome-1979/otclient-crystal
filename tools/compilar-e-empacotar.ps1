[CmdletBinding()]
param(
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-RequiredPath {
    <# Garante que um arquivo ou diretorio obrigatorio existe antes do empacotamento. #>
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Description)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Description nao encontrado: $Path"
    }
}

function Copy-DirectoryContent {
    <# Copia inclusive arquivos ocultos, sem carregar sobras de uma distribuicao anterior. #>
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Destination)

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | Copy-Item -Destination $Destination -Recurse -Force
}

function Copy-RuntimeFiles {
    <# Monta os arquivos Lua, certificados e recursos necessarios para executar o cliente. #>
    param([Parameter(Mandatory)][string]$RepositoryRoot, [Parameter(Mandatory)][string]$Destination)

    foreach ($directoryName in @('data', 'modules', 'mods')) {
        Copy-DirectoryContent -Source (Join-Path $RepositoryRoot $directoryName) -Destination (Join-Path $Destination $directoryName)
    }

    foreach ($fileName in @('init.lua', 'meta.lua', 'config.ini', 'cacert.pem', 'otclientrc.lua', 'crystalrc.lua', 'Crystalrc.lua')) {
        $sourceFile = Join-Path $RepositoryRoot $fileName
        if (Test-Path -LiteralPath $sourceFile -PathType Leaf) {
            Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $Destination $fileName) -Force
        }
    }
}

function Get-DirectoryFileCount {
    <# Retorna a quantidade real de arquivos para o relatorio de verificacao. #>
    param([Parameter(Mandatory)][string]$Path)

    return @(Get-ChildItem -LiteralPath $Path -File -Recurse -Force).Count
}

function Remove-DevelopmentOnlyFiles {
    <# Remove exemplos de integracao do servidor que nao sao carregados pelo cliente em runtime. #>
    param([Parameter(Mandatory)][string]$Destination)

    $paperdollsServerExample = Join-Path $Destination 'modules\game_paperdolls\server'
    if (Test-Path -LiteralPath $paperdollsServerExample -PathType Container) {
        Remove-Item -LiteralPath $paperdollsServerExample -Recurse -Force
    }
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildDirectory = Join-Path $repositoryRoot 'build'
$releaseExecutable = Join-Path $repositoryRoot 'Release\otclient.exe'
$distributionDirectory = Join-Path $repositoryRoot 'dist'
$backupRoot = Join-Path $repositoryRoot 'backups'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

foreach ($requiredDirectory in @('data', 'modules', 'mods')) {
    Assert-RequiredPath -Path (Join-Path $repositoryRoot $requiredDirectory) -Description "Diretorio $requiredDirectory"
}
Assert-RequiredPath -Path (Join-Path $repositoryRoot 'init.lua') -Description 'Arquivo init.lua'
Assert-RequiredPath -Path (Join-Path $repositoryRoot 'tools\api\updater.php') -Description 'API updater.php'

if ($Build) {
    Assert-RequiredPath -Path (Join-Path $buildDirectory 'CMakeCache.txt') -Description 'Configuracao CMake'
    Write-Host 'Compilando o cliente em Release...' -ForegroundColor Cyan
    & cmake --build $buildDirectory --config Release
    if ($LASTEXITCODE -ne 0) {
        throw "A compilacao falhou com o codigo $LASTEXITCODE. A distribuicao nao foi alterada."
    }
}

Assert-RequiredPath -Path $releaseExecutable -Description 'Executavel Release'

if (Test-Path -LiteralPath $distributionDirectory) {
    $expectedDistributionPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot 'dist'))
    if ([System.IO.Path]::GetFullPath($distributionDirectory) -ne $expectedDistributionPath) {
        throw "Destino de distribuicao inesperado: $distributionDirectory"
    }

    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $distributionBackup = Join-Path $backupRoot "$timestamp-dist"
    Move-Item -LiteralPath $distributionDirectory -Destination $distributionBackup
    Write-Host "Distribuicao anterior preservada em: $distributionBackup" -ForegroundColor Yellow
}

$clientDirectory = Join-Path $distributionDirectory 'CrystalClient'
$serverDirectory = Join-Path $distributionDirectory 'servidor'
$serverApiDirectory = Join-Path $serverDirectory 'api'
$serverFilesDirectory = Join-Path $serverDirectory 'files'
New-Item -ItemType Directory -Path $clientDirectory, $serverApiDirectory, $serverFilesDirectory -Force | Out-Null

Copy-RuntimeFiles -RepositoryRoot $repositoryRoot -Destination $clientDirectory
Remove-DevelopmentOnlyFiles -Destination $clientDirectory
Copy-Item -LiteralPath $releaseExecutable -Destination (Join-Path $clientDirectory 'Crystal.exe') -Force
Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'Release') -Filter '*.dll' -File |
    Copy-Item -Destination $clientDirectory -Force

Copy-RuntimeFiles -RepositoryRoot $repositoryRoot -Destination $serverFilesDirectory
Remove-DevelopmentOnlyFiles -Destination $serverFilesDirectory
Copy-Item -LiteralPath $releaseExecutable -Destination (Join-Path $serverFilesDirectory 'otclient_x64.exe') -Force
Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'Release') -Filter '*.dll' -File |
    Copy-Item -Destination $serverFilesDirectory -Force
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'tools\api\updater.php') -Destination (Join-Path $serverApiDirectory 'updater.php') -Force

$clientExecutable = Join-Path $clientDirectory 'Crystal.exe'
$serverExecutable = Join-Path $serverFilesDirectory 'otclient_x64.exe'
$clientHash = (Get-FileHash -LiteralPath $clientExecutable -Algorithm SHA256).Hash
$serverHash = (Get-FileHash -LiteralPath $serverExecutable -Algorithm SHA256).Hash
$reportPath = Join-Path $distributionDirectory 'RELATORIO-COMPILACAO.txt'
$reportLines = @(
    'Crystal Client - Relatorio de compilacao e empacotamento'
    "Gerado em: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')"
    "Origem: $repositoryRoot"
    "Cliente: $clientExecutable"
    "SHA256 Crystal.exe: $clientHash"
    "Servidor: $serverExecutable"
    "SHA256 otclient_x64.exe: $serverHash"
    "Arquivos data: $(Get-DirectoryFileCount -Path (Join-Path $clientDirectory 'data'))"
    "Arquivos modules: $(Get-DirectoryFileCount -Path (Join-Path $clientDirectory 'modules'))"
    "Arquivos mods: $(Get-DirectoryFileCount -Path (Join-Path $clientDirectory 'mods'))"
    "Bibliotecas DLL: $(@(Get-ChildItem -LiteralPath $clientDirectory -Filter '*.dll' -File).Count)"
)
Set-Content -LiteralPath $reportPath -Value $reportLines -Encoding utf8

$thingVersions = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'data\things') -Directory -ErrorAction SilentlyContinue)
$soundVersions = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'data\sounds') -Directory -ErrorAction SilentlyContinue)
if ($thingVersions.Count -eq 0 -or $soundVersions.Count -eq 0) {
    Write-Warning 'data\things ou data\sounds nao possui uma versao instalada. O auto-instalador precisara baixar esses recursos no primeiro uso.'
}

Write-Host ''
Write-Host 'Empacotamento concluido.' -ForegroundColor Green
Write-Host "Cliente para abrir: $clientExecutable"
Write-Host "Conteudo para a VPS: $serverDirectory"
Write-Host "Relatorio: $reportPath"
