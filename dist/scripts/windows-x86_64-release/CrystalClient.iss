; Crystal Client installer with x86/x64 selection, for Inno Setup 6.3+ or 7.
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef RepositoryRoot
  #define RepositoryRoot AddBackslash(SourcePath) + "..\..\.."
#endif
#ifndef PackageDirectory
  #define PackageDirectory RepositoryRoot + "\dist\windows-x64-release"
#endif
#ifndef X86PackageDirectory
  #define X86PackageDirectory RepositoryRoot + "\dist\windows-x86-release"
#endif

#define AppName "Crystal"
#define AppPublisher "Crystal Setup"

[Setup]
AppId={{D8746183-4DDA-46A6-9BE3-0DA762E180B0}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={localappdata}\Programs\Crystal Client
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
; The installer itself must run on 32-bit Windows as well.
#if VER >= EncodeVer(7, 0, 0)
SetupArchitecture=x86
#endif
ArchitecturesAllowed=x86os x64os
ArchitecturesInstallIn64BitMode=x64os
OutputDir={#RepositoryRoot}\dist\instalador\windows-x86_64-release
OutputBaseFilename=CrystalClient-Setup-{#AppVersion}
SetupIconFile={#RepositoryRoot}\cmake\icon\otcicon.ico
UninstallDisplayIcon={app}\Crystal.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription=Instalador do {#AppName}
VersionInfoProductName={#AppName}

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Files]
Source: "{#PackageDirectory}\*"; DestDir: "{app}"; Excludes: ".crystal-distribution,.crystal-installer-stage,*.log,*.pdb,*.ilk,*.exp,*.lib,*.debug"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: InstallX64
Source: "{#X86PackageDirectory}\*"; DestDir: "{app}"; Excludes: ".crystal-distribution,.crystal-installer-stage,*.log,*.pdb,*.ilk,*.exp,*.lib,*.debug"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: InstallX86
Source: "{#RepositoryRoot}\cmake\icon\otcicon.ico"; DestDir: "{app}"; DestName: "Crystal.ico"; Flags: ignoreversion

[InstallDelete]
Type: files; Name: "{app}\Clientex86.exe"; Check: InstallX64
Type: files; Name: "{app}\Clientex64.exe"; Check: InstallX86

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{code:GetClientExecutable}"; WorkingDir: "{app}"; IconFilename: "{app}\Crystal.ico"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{code:GetClientExecutable}"; WorkingDir: "{app}"; IconFilename: "{app}\Crystal.ico"

[Run]
Filename: "{app}\{code:GetClientExecutable}"; Description: "Abrir {#AppName}"; Flags: nowait postinstall skipifsilent

[Code]
function InstallX64: Boolean;
begin
  Result := IsWin64;
end;

function InstallX86: Boolean;
begin
  Result := not IsWin64;
end;

function GetClientExecutable(Param: String): String;
begin
  if InstallX64 then
    Result := 'Clientex64.exe'
  else
    Result := 'Clientex86.exe';
end;
