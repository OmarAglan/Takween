#define MyAppName "Takween"
#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif
#define MyAppPublisher "Takween Project"
#define MyAppURL "https://github.com/OmarAglan/Takween"
#define MyAppExeName "takween.exe"

[Setup]
AppId={{9D321DC1-69B3-44F0-A52A-86DB6A6E0C97}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\Programs\Takween
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=dist\installer
OutputBaseFilename=takween-setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ChangesEnvironment=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\bin\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "addpath"; Description: "Add Takween to PATH"; GroupDescription: "Environment:"; Flags: checkedonce

[Files]
Source: "dist\bin\takween.exe"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "ROADMAP.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "مستندات\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "أمثلة\*"; DestDir: "{app}\examples"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "stdlib\baalib.baahd"; DestDir: "{app}\stdlib"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Takween CLI"; Filename: "{cmd}"; Parameters: "/K cd /d ""{app}\\bin"" && ""{app}\\bin\\takween.exe"" --help"; WorkingDir: "{app}\bin"

[Run]
Filename: "{app}\bin\takween.exe"; Parameters: "--help"; Description: "Run Takween help"; Flags: postinstall skipifsilent unchecked

[Code]
function IsOnPath(const Path, Paths: string): Boolean;
var
  PaddedPaths: string;
begin
  PaddedPaths := ';' + Uppercase(Paths) + ';';
  Result := Pos(';' + Uppercase(Path) + ';', PaddedPaths) > 0;
end;

function AddPathCurrentUser(const PathToAdd: string): Boolean;
var
  Paths: string;
begin
  if not RegQueryStringValue(HKCU, 'Environment', 'Path', Paths) then
    Paths := '';

  if not IsOnPath(PathToAdd, Paths) then
  begin
    if (Paths <> '') and (Copy(Paths, Length(Paths), 1) <> ';') then
      Paths := Paths + ';';
    Paths := Paths + PathToAdd;
  end;

  Result := RegWriteStringValue(HKCU, 'Environment', 'Path', Paths);
end;

function RemovePathCurrentUser(const PathToRemove: string): Boolean;
var
  Paths, Target, Prefix, Suffix: string;
  PosStart, PosEnd: Integer;
begin
  Result := True;
  if not RegQueryStringValue(HKCU, 'Environment', 'Path', Paths) then
    Exit;

  Target := ';' + Paths + ';';
  PosStart := Pos(';' + Uppercase(PathToRemove) + ';', Uppercase(Target));
  if PosStart = 0 then
    Exit;

  PosEnd := PosStart + Length(PathToRemove) + 1;
  Prefix := Copy(Target, 1, PosStart - 1);
  Suffix := Copy(Target, PosEnd + 1, Length(Target));
  Target := Prefix + Suffix;

  while (Length(Target) > 0) and (Copy(Target, 1, 1) = ';') do
    Delete(Target, 1, 1);
  while (Length(Target) > 0) and (Copy(Target, Length(Target), 1) = ';') do
    Delete(Target, Length(Target), 1);

  Result := RegWriteStringValue(HKCU, 'Environment', 'Path', Target);
end;

function IsBaaAvailable(): Boolean;
var
  ExitCode: Integer;
begin
  Result := Exec(ExpandConstant('{cmd}'), '/C where baa >nul 2>&1', '', SW_HIDE, ewWaitUntilTerminated, ExitCode) and (ExitCode = 0);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssPostInstall) then
  begin
    if WizardIsTaskSelected('addpath') then
      AddPathCurrentUser(ExpandConstant('{app}\\bin'));

    RegWriteStringValue(HKCU, 'Environment', 'TAKWEEN_HOME', ExpandConstant('{app}'));

    if not IsBaaAvailable() then
      MsgBox('Baa compiler was not found in PATH. Takween requires baa.exe to build projects.' + #13#10 +
             'Install Baa compiler or add it to PATH first.', mbInformation, MB_OK);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    RemovePathCurrentUser(ExpandConstant('{app}\\bin'));
    RegDeleteValue(HKCU, 'Environment', 'TAKWEEN_HOME');
  end;
end;
