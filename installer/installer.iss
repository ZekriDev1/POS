; Inno Setup Script for CashManager POS
; Build the Flutter app first: flutter build windows
; Then compile this script with Inno Setup Compiler

#define MyAppName "CashManager"
#define MyAppVersion "0.2.0"
#define MyAppPublisher "Akram Zekri"
#define MyAppExeName "restropos.exe"
#define MyBuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{B8F4A3D2-1C5E-4A7B-9D6F-8E2C1A3B5D7F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppCopyright=Akram Zekri | +212 691157363
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=.\output
OutputBaseFilename=CashManagerPOS_Setup_{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
SetupIconFile=..\windows\runner\resources\app_icon.ico
DisableProgramGroupPage=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: checkedonce
Name: "startup"; Description: "Launch at Windows &startup"; GroupDescription: "Startup options:"; Flags: checkedonce
Name: "pin2taskbar"; Description: "&Pin to taskbar"; GroupDescription: "Taskbar:"; Flags: unchecked

[Files]
Source: "{#MyBuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "pin_to_taskbar.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "unpin_from_taskbar.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{#MyAppName} (Uninstall)"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue; Tasks: startup

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
Filename: "{app}\pin_to_taskbar.bat"; Parameters: """{app}\{#MyAppExeName}"""; StatusMsg: "Pinning to taskbar..."; Flags: runhidden; Tasks: pin2taskbar

[UninstallRun]
Filename: "{app}\unpin_from_taskbar.bat"; Parameters: """{app}\{#MyAppExeName}"""; Flags: runhidden
