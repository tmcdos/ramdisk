unit Junctions;

// http://progmatix.blogspot.com/2010/10/get-target-of-symlink-in-delphi.html
// https://delphisources.ru/pages/faq/base/hardlink_symbolic_link.html
// http://www.flexhex.com/docs/articles/hard-links.phtml#junctions
// https://fossil.2of4.net/zaap/artifact/ad9fc313554aea05

interface

const
    FILE_ATTRIBUTE_REPARSE_POINT = 1024;

function GetSymLinkTarget(const AFilename: Widestring): Widestring;
function CreateJunction(const ALink,ADest:WideString): Boolean;

implementation

uses Windows;

const
  MAX_REPARSE_SIZE = 17000;
  MAX_NAME_LENGTH = 1024;
  REPARSE_MOUNTPOINT_HEADER_SIZE = 8;
  IO_REPARSE_TAG_MOUNT_POINT    = $0A0000003;
  FILE_FLAG_OPEN_REPARSE_POINT = $00200000;
  FILE_DEVICE_FILE_SYSTEM = $0009;
  FILE_ANY_ACCESS = 0;
  METHOD_BUFFERED   = 0;
  FSCTL_SET_REPARSE_POINT    = (FILE_DEVICE_FILE_SYSTEM shl 16) or (FILE_ANY_ACCESS shl 14) or (41 shl 2) or (METHOD_BUFFERED);
  FSCTL_GET_REPARSE_POINT    = (FILE_DEVICE_FILE_SYSTEM shl 16) or (FILE_ANY_ACCESS shl 14) or (42 shl 2) or (METHOD_BUFFERED);

type
  REPARSE_DATA_BUFFER = packed record
    ReparseTag: DWORD;
    ReparseDataLength: Word;
    Reserved: Word;
    SubstituteNameOffset: Word;
    SubstituteNameLength: Word;
    PrintNameOffset: Word;
    PrintNameLength: Word;
    PathBuffer: array[0..0] of WideChar;
  end;
  TReparseDataBuffer = REPARSE_DATA_BUFFER;
  PReparseDataBuffer = ^TReparseDataBuffer;

  REPARSE_MOUNTPOINT_DATA_BUFFER = packed record
    ReparseTag: DWORD;
    ReparseDataLength: DWORD;
    Reserved: Word;
    ReparseTargetLength: Word;
    ReparseTargetMaximumLength: Word;
    Reserved1: Word;
    ReparseTarget: array[0..0] of WideChar;
  end;
  TReparseMountPointDataBuffer = REPARSE_MOUNTPOINT_DATA_BUFFER;
  PReparseMountPointDataBuffer = ^TReparseMountPointDataBuffer;

  Function CreateSymbolicLinkW(Src,Target:PWideChar;Flags:Cardinal):BOOL; Stdcall; External 'kernel32.dll';

function OpenDirectory(const ADir:WideString;bReadWrite:Boolean):THandle;
var
  token:THandle;
  tp:TTokenPrivileges;
  bp:WideString;
  dw,access:DWORD;
begin
  // Obtain backup/restore privilege in case we don't have it
  OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, token);
  If bReadWrite Then bp:='SeRestorePrivilege' else bp:='SeBackupPrivilege';
  LookupPrivilegeValueW(NIL, PWideChar(bp), tp.Privileges[0].Luid);
  tp.PrivilegeCount := 1;
  tp.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
  AdjustTokenPrivileges(token, FALSE, tp, sizeof(TOKEN_PRIVILEGES), NIL, dw);
  CloseHandle(token);

  // Open the directory
  access:=GENERIC_READ;
  if bReadWrite then access:=access or GENERIC_WRITE;
  Result := CreateFileW(PWideChar(ADir), access, 0, NIL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT or FILE_FLAG_BACKUP_SEMANTICS, 0);
end;

function GetSymLinkTarget(const AFilename: WideString): Widestring;
var
  hDir:THandle;
  nRes:DWORD;
  reparseInfo: PReparseDataBuffer;
  name2: array[0..MAX_NAME_LENGTH-1] of WideChar;
begin
  Result := '';
  hDir:= OpenDirectory(AFilename,False);
  if hDir = INVALID_HANDLE_VALUE then Exit;
  GetMem(reparseInfo,MAX_REPARSE_SIZE);
  if DeviceIoControl(hDir, FSCTL_GET_REPARSE_POINT, nil, 0, reparseInfo, MAX_REPARSE_SIZE, nRes, nil) Then
    If reparseInfo.ReparseTag = IO_REPARSE_TAG_MOUNT_POINT then
    Begin
      FillChar(name2, SizeOf(name2), 0);
      lstrcpynW(name2, reparseInfo.PathBuffer + reparseInfo.SubstituteNameOffset, reparseInfo.SubstituteNameLength);
      Result:= Copy(name2,5,Length(name2)); // remove the '\??\' prefix
    end;
  FreeMem(reparseInfo,MAX_REPARSE_SIZE);
  CloseHandle(hDir);
end;

// target must NOT begin with "\??\" - it will be added automatically
Function CreateJunction(const ALink,ADest:WideString):Boolean;
Const
  LinkPrefix: WideString = '\??\';
var
  Buffer: PReparseMountPointDataBuffer;
  BufSize: integer;
  TargetName: WideString;
  hDir:THandle;
  dw:DWORD;
Begin
  Result:=False;
  hDir:=OpenDirectory(ALink,True);
  If hDir = INVALID_HANDLE_VALUE then Exit;
  If Pos(LinkPrefix,ADest)=1 then TargetName:=ADest else TargetName:=LinkPrefix+ADest;
  BufSize:=(Length(TargetName)+1)*SizeOf(WideChar) + REPARSE_MOUNTPOINT_HEADER_SIZE + 12;
  GetMem(Buffer,BufSize);
  FillChar(Buffer^,BufSize,#0);
  With Buffer^ Do
  Begin
    Move(TargetName[1], ReparseTarget, (Length(TargetName)+1)*SizeOf(WideChar));
    ReparseTag:= IO_REPARSE_TAG_MOUNT_POINT;
    ReparseTargetLength:= Length(TargetName)*SizeOf(WideChar);
    ReparseTargetMaximumLength:= ReparseTargetLength+2;
    ReparseDataLength:= ReparseTargetLength+12;
  end;
  Result:=DeviceIoControl(hDir,FSCTL_SET_REPARSE_POINT,Buffer,Buffer.ReparseDataLength + REPARSE_MOUNTPOINT_HEADER_SIZE,Nil,0,dw,Nil);
  FreeMem(Buffer,BufSize);
  CloseHandle(hDir);
end;

end.
