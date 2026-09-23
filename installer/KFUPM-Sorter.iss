; KFUPM Sorter - Windows installer
; Build with Inno Setup 6 (free): https://jrsoftware.org/isdl.php
; Easiest: double-click build-installer.bat in this folder.

#define AppName      "KFUPM Sorter"
#define AppVersion   "1.2.0"
#define AppPublisher "KFUPM Sorter (student project)"
#define AppURL       "https://github.com/kal429/kfupm-sorter-windows"

[Setup]
AppId={{6C1C4F0E-3B7A-4E53-9A8B-2F4D6E1A9C27}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
AppUpdatesURL={#AppURL}/releases/latest
; per-user install: no administrator rights needed
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=yes
OutputDir=output
; fixed name, so the "latest release" download link never changes
OutputBaseFilename=KFUPM-Sorter-Setup
SetupIconFile=..\src\app.ico
UninstallDisplayIcon={app}\app.ico
UninstallDisplayName={#AppName}
WizardStyle=modern
WizardImageFile=wizard-large.bmp
WizardSmallImageFile=wizard-small.bmp
Compression=lzma2
SolidCompression=yes
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
Source: "..\src\KfupmSorter.ps1";  DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\Picker.ps1";       DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\Catalog.ps1";      DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\Strings.ps1";      DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\run-hidden.vbs";   DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\launch-ui.vbs";    DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\app.ico";          DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\data\*";           DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{userprograms}\{#AppName}"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\launch-ui.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\app.ico"; Comment: "Pick your courses and keep Downloads sorted"; AppUserModelID: "KFUPM.Sorter"
Name: "{userdesktop}\{#AppName}";  Filename: "{sys}\wscript.exe"; Parameters: """{app}\launch-ui.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\app.ico"; AppUserModelID: "KFUPM.Sorter"; Tasks: desktopicon

[Run]
; remove the scheduled task left by the old zip version, if any (harmless when absent)
Filename: "{sys}\schtasks.exe"; Parameters: "/Delete /TN ""Downloads AutoSorter"" /F"; Flags: runhidden; StatusMsg: "Cleaning up older version..."
Filename: "{sys}\wscript.exe"; Parameters: """{app}\launch-ui.vbs"""; Description: "Open {#AppName} now"; Flags: postinstall nowait skipifsilent

[UninstallRun]
; stop and remove the background task before files are deleted
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\KfupmSorter.ps1"" -Uninstall"; Flags: runhidden; RunOnceId: "RemoveTask"

[UninstallDelete]
; settings, log and downloaded catalog. Your sorted files are never touched.
Type: filesandordirs; Name: "{userappdata}\{#AppName}"
