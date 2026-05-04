#define AppName "VolumePro"
#define AppVersion "3.0"
#define AppPublisher "Danh Thanh"
#define AppExeName "VolumePro.exe"
#define AppId "{{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}}"

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppVerName={#AppName} {#AppVersion}
AppId={#AppId}

DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}

OutputDir=Output
OutputBaseFilename=VolumePro_Setup_v{#AppVersion}

Compression=lzma2/ultra64
SolidCompression=yes

WizardStyle=modern
WizardSizePercent=120

SetupIconFile=VolumePro.ico
UninstallDisplayIcon={app}\{#AppExeName}

PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

MinVersion=10.0.10240

DisableProgramGroupPage=yes
AllowNoIcons=yes

; ===== PRO FEATURES =====
CloseApplications=yes
RestartApplications=yes
UsedUserAreasWarning=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

; ================= TASKS =================
[Tasks]
Name: "startup"; Description: "Start with Windows"; GroupDescription: "Options:"; Flags: checkedonce

; ================= FILES =================
[Files]
Source: "VolumePro.exe"; DestDir: "{app}"; Flags: ignoreversion

; ================= ICONS =================
[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"

; ================= REGISTRY (STARTUP) =================
[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; \
ValueType: string; ValueName: "{#AppName}"; \
ValueData: """{app}\{#AppExeName}"""; \
Flags: uninsdeletevalue; Tasks: startup

; ================= RUN =================
[Run]
Filename: "{app}\{#AppExeName}"; \
Description: "Launch {#AppName}"; \
Flags: nowait postinstall skipifsilent

; ================= UNINSTALL =================
[UninstallRun]
Filename: "taskkill.exe"; \
Parameters: "/F /IM {#AppExeName}"; \
Flags: runhidden skipifdoesntexist

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Registry]
Root: HKCU; \
Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; \
ValueName: "{#AppName}"; \
Flags: deletevalue

; ================= CODE (PROTECTION + CLEAN) =================
[Code]
var
  ResultCode: Integer;

function IsAppRunning(): Boolean;
begin
  Result :=
    Exec('tasklist.exe',
      '/FI "IMAGENAME eq {#AppExeName}"',
      '',
      SW_HIDE,
      ewWaitUntilTerminated,
      ResultCode);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    Exec('taskkill.exe',
      '/F /IM {#AppExeName}',
      '',
      SW_HIDE,
      ewWaitUntilTerminated,
      ResultCode);
  end;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;

  if IsAppRunning() then
  begin
    MsgBox('VolumePro is running. It will be closed for update.',
      mbInformation, MB_OK);
  end;
end;