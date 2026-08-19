; مثبت تكوين المستقل لويندوز.
; يكتشف باء ونظم من تثبيتهما المستقل وPATH ولا يضم نسخهما.

#define MyAppId "{{9D321DC1-69B3-44F0-A52A-86DB6A6E0C97}"
#define MyAppName "تكوين"
#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif
#ifndef TakweenBinaryDir
  #define TakweenBinaryDir "dist\bin"
#endif
#define MyAppPublisher "Omar Aglan"
#define MyAppURL "https://github.com/OmarAglan/Takween"
#define MyAppExeName "تكوين.exe"
#define MyAppAliasName "takween.exe"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\Takween
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
AllowNoIcons=yes
OutputDir=dist\installer
OutputBaseFilename=takween-setup-{#MyAppVersion}-x64
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog commandline
ChangesEnvironment=yes
SetupLogging=yes
UsePreviousAppDir=yes
UsePreviousLanguage=yes
UninstallDisplayIcon={app}\bin\{#MyAppExeName}
UninstallDisplayName={#MyAppName} {#MyAppVersion}

[Languages]
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#TakweenBinaryDir}\{#MyAppExeName}"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "{#TakweenBinaryDir}\{#MyAppAliasName}"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "CHANGELOG.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "ROADMAP.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "مستندات\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "أمثلة\*"; DestDir: "{app}\examples"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\تكوين\دليل تكوين"; Filename: "{app}\README.md"
Name: "{autoprograms}\تكوين\أمثلة تكوين"; Filename: "{app}\examples"
Name: "{autoprograms}\تكوين\إزالة تكوين"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\bin\{#MyAppExeName}"; Parameters: "--إصدار"; Description: "التحقق من إصدار تكوين"; Flags: postinstall skipifsilent unchecked runhidden

[Code]
#include "installer\windows_environment.iss"

const
  TAKWEEN_INSTALLER_KEY = 'Software\BaaEcosystem\Takween';
  TAKWEEN_PATH_OWNED_VALUE = 'PathOwned';
  TAKWEEN_HOME_OWNED_VALUE = 'HomeOwned';
  BAA_UNINSTALL_KEY = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{E4B6D77C-6C22-4E2D-8F9D-61D34A26B0D1}_is1';
  NAZM_UNINSTALL_KEY = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{8D3D57AE-41CF-4B8A-95E9-270E4564E2A1}_is1';

procedure TakweenRegistryRoot(var Root: Integer);
begin
  if IsAdminInstallMode then
    Root := HKLM
  else
    Root := HKCU;
end;

function TakweenOwnedValue(const Name: string): Boolean;
var
  Root: Integer;
  Value: Cardinal;
begin
  TakweenRegistryRoot(Root);
  Result := RegQueryDWordValue(Root, TAKWEEN_INSTALLER_KEY, Name, Value) and
    (Value = 1);
end;

procedure TakweenSetOwnedValue(const Name: string; const Owned: Boolean);
var
  Root: Integer;
begin
  TakweenRegistryRoot(Root);
  if Owned then
    RegWriteDWordValue(Root, TAKWEEN_INSTALLER_KEY, Name, 1)
  else
    RegDeleteValue(Root, TAKWEEN_INSTALLER_KEY, Name);
end;

procedure EnsureTakweenHome;
var
  Root: Integer;
  Subkey, CurrentValue: string;
begin
  EcoEnvironmentRoot(Root, Subkey);
  CurrentValue := '';
  RegQueryStringValue(Root, Subkey, 'TAKWEEN_HOME', CurrentValue);
  if (CurrentValue = '') or TakweenOwnedValue(TAKWEEN_HOME_OWNED_VALUE) then
  begin
    EcoSetOwnedEnvironment('TAKWEEN_HOME', ExpandConstant('{app}'));
    TakweenSetOwnedValue(TAKWEEN_HOME_OWNED_VALUE, True);
  end;
end;

procedure ApplyTakweenEnvironment;
begin
  if EcoEnsurePathContains(ExpandConstant('{app}\bin')) then
    TakweenSetOwnedValue(TAKWEEN_PATH_OWNED_VALUE, True);
  EnsureTakweenHome;
end;

function InstalledFileAt(const Root: Integer; const Key, RelativePath: string): Boolean;
var
  InstallLocation: string;
begin
  Result := RegQueryStringValue(Root, Key, 'InstallLocation', InstallLocation) and
    FileExists(AddBackslash(InstallLocation) + RelativePath);
end;

function BaaAvailable: Boolean;
begin
  Result :=
    (FileSearch('baa.exe', GetEnv('PATH')) <> '') or
    InstalledFileAt(HKCU, BAA_UNINSTALL_KEY, 'baa.exe') or
    InstalledFileAt(HKLM, BAA_UNINSTALL_KEY, 'baa.exe');
end;

function NazmAvailable: Boolean;
begin
  Result :=
    (FileSearch('نظم.exe', GetEnv('PATH')) <> '') or
    InstalledFileAt(HKCU, NAZM_UNINSTALL_KEY, 'bin\نظم.exe') or
    InstalledFileAt(HKLM, NAZM_UNINSTALL_KEY, 'bin\نظم.exe');
end;

function RunTakweenHealthProbe: Boolean;
var
  ExitCode: Integer;
begin
  Result :=
    FileExists(ExpandConstant('{app}\bin\{#MyAppExeName}')) and
    FileExists(ExpandConstant('{app}\bin\{#MyAppAliasName}')) and
    Exec(ExpandConstant('{app}\bin\{#MyAppExeName}'), '--إصدار',
      ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ExitCode) and
    (ExitCode = 0) and
    Exec(ExpandConstant('{app}\bin\{#MyAppAliasName}'), '--version',
      ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ExitCode) and
    (ExitCode = 0);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    ApplyTakweenEnvironment;
    EcoBroadcastEnvironmentChange;
    if not RunTakweenHealthProbe then
      RaiseException('فشل فحص تكوين بعد التثبيت.');
    if not WizardSilent then
    begin
      if BaaAvailable and NazmAvailable then
        MsgBox('اكتمل تثبيت تكوين. افتح طرفية جديدة لاستخدام الأمر تكوين.',
          mbInformation, MB_OK)
      else
        MsgBox('اكتمل تثبيت تكوين، لكن باء أو نظم غير مثبت أو غير ظاهر في PATH. ثبّت الاعتمادين قبل بناء المشاريع.',
          mbInformation, MB_OK);
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Root: Integer;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    if TakweenOwnedValue(TAKWEEN_PATH_OWNED_VALUE) then
      EcoEnsurePathRemoved(ExpandConstant('{app}\bin'));
    if TakweenOwnedValue(TAKWEEN_HOME_OWNED_VALUE) then
      EcoDeleteOwnedEnvironment('TAKWEEN_HOME', ExpandConstant('{app}'));
    TakweenRegistryRoot(Root);
    RegDeleteKeyIncludingSubkeys(Root, TAKWEEN_INSTALLER_KEY);
    EcoBroadcastEnvironmentChange;
  end;
end;
