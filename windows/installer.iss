#define MyAppName "Lan Secure Messenger"
#define MyAppVersion "1.2.0"
#define MyAppPublisher "Lan Secure Messenger"
#define MyAppExeName "lan_secure_messenger.exe"

[Setup]
AppId={{D4F8A2B8-8A68-4A0D-9B45-1B1B5C0F7C21}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\LanSecureMessenger
DefaultGroupName={#MyAppName}
OutputDir=.
OutputBaseFilename=lan-secure-messenger-windows-setup
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#MyAppExeName}

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Khởi động {#MyAppName}"; Flags: nowait postinstall skipifsilent
