unit Definitions;

interface

uses Types,Windows,SysUtils;

Type
  TRamErrors = (RamOK, RamNotInstalled, RamNotAccessible, RamCantEnumDrives, RamDriverVersion, RamCantCreate, RamCantFormat, RamNoFreeLetter);
  TAssignedDrives = Set of 'A'..'Z';
  ERamDiskError = Class(Exception)
    ArsenalCode: TRamErrors;
    Constructor Create(Code:TRamErrors);
  end;
  TRamDisk = Packed Record
    size: Int64;
    diskNumber: Integer; // \\?\PhysicalDriveXX
    volumeName: string; // \\?\Volume{12345678-1234-1234-1234-123456789abc}
    persistentFolder: WideString;
    excludedList: WideString;
    letter: Char;
    synchronize:Boolean;
    deleteOld:Boolean;
    useTemp:Boolean;
  end;

  DEVICE_TYPE = DWORD;
  PUnicodeString = ^TUnicodeString;
  TUnicodeString = packed record
    Length: Word;
    MaximumLength: Word;
    Buffer: PWideChar;
  end;
  PObjectAttributes = ^TObjectAttributes;
  TObjectAttributes = packed record
    Length: Cardinal;
    RootDirectory: THandle;
    ObjectName: PUnicodeString;
    Attributes: Cardinal;
    SecurityDescriptor: Pointer;
    SecurityQualityOfService: Pointer;
  end;
  NTSTATUS = LongInt;
  IO_STATUS_BLOCK = packed Record
    case Boolean Of
      False: (Status: NTSTATUS);
      True:
        (Pointer: Pointer;
        Information: ULONG); // 'Information' does not belong to the union!
  end;
  TDeviceNumber = Packed Record
    Case Boolean Of
      false: (LongNumber: LongWord);
      true:
        (PathId: Byte;
        TargetId: Byte;
        Lun: Byte);
  End;
  TScsiAddress = Packed Record
    Length: LongInt;
    PortNumber: Byte;
    PathId: Byte;
    TargetId: Byte;
    Lun: Byte;
  End;
  PScsiAddress = ^TScsiAddress;
  ArrayScsiAddress = Array[0..7] of TScsiAddress;
  PArrayScsiAddress = ^ArrayScsiAddress;
  TScsiDeviceConfigFilename = Array [0..4095] of WideChar;
  TScsiDeviceConfig = packed Record
    DeviceNumber: TDeviceNumber; // On create this can be set to IMSCSI_AUTO_DEVICE_NUMBER
    DiskSize: Int64;
    BytesPerSector: LongWord;
    Reserved: LongWord;
    ImageOffset: Int64; // The byte offset in image file where the virtual disk data begins
    Flags: LongWord; // Creation flags. Type of device and type of connection
    FileNameLength: Word; // Length in bytes of the FileName member
    FileName: TScsiDeviceConfigFilename;
  end;
  PScsiDeviceConfig = ^TScsiDeviceConfig;
  TSrbIoControl = packed record
    HeaderLength : ULONG;
    Signature    : Array[0..7] of Char;
    Timeout      : ULONG;
    ControlCode  : ULONG;
    ReturnCode   : LongInt;
    Length       : ULONG;
  end;
  SRB_IO_CONTROL = TSrbIoControl;
  PSrbIoControl = ^TSrbIoControl;
  TScsiCreateData = Packed Record
    SrbIoControl: TSrbIoControl;
    Fields: TScsiDeviceConfig;
  end;
  TScsiRemoveDevice = packed Record
    SrbIoControl: TSrbIoControl;
    DeviceNumber: TDeviceNumber;
  end;
  TScsiVersionCheck = Packed Record
    SrbIoControl: TSrbIoControl;
    // API compatibility version is returned in SrbIoControl.ReturnCode.
    // SubVersion contains, in newer versions, a revision version that
    // applications can check to see if latest version is loaded.
    SubVersion:ULONG;
  end;
  TStorageDeviceNumber = Record
    DeviceType: DEVICE_TYPE;
    DeviceNumber: DWORD;
    PartitionNumber: DWORD;
  end;
  PStorageDeviceNumber = ^TStorageDeviceNumber;

  DEV_BROADCAST_VOLUME = packed record
    dbch_size: DWORD;
    dbch_devicetype: DWORD;
    dbch_reserved: DWORD;
    dbcv_unitmask: DWORD;
    dbcv_flags: WORD;
  end;
  TDevBroadcastVolume = DEV_BROADCAST_VOLUME;
  PDevBroadcastVolume = ^TDevBroadcastVolume;

  DISK_EXTENT = record
    DiskNumber: DWORD;
    StartingOffset: LARGE_INTEGER;
    ExtentLength: LARGE_INTEGER;
  end;
  TDiskExtent = DISK_EXTENT;
  PDiskExtent = ^TDiskExtent;

  VOLUME_DISK_EXTENTS = record
    NumberOfDiskExtents: DWORD;
    Extents: array [0..0] of DISK_EXTENT;
  end;
  TVolumeDiskExtents = VOLUME_DISK_EXTENTS;
  PVolumeDiskExtents = ^TVolumeDiskExtents;

  SET_DISK_ATTRIBUTES = Packed record
    Version: DWORD;
    Persist:Boolean;
    Reserved1: Array[1..3] of Byte;
    Attributes: Int64;
    AttributesMask: Int64;
    Reserved2: Array[1..4] of DWORD;
  end;
  TSetDiskAttributes = SET_DISK_ATTRIBUTES;
  PSetDiskAttributes = ^TSetDiskAttributes;

  PARTITION_INFORMATION = record
    StartingOffset: LARGE_INTEGER;
    PartitionLength: LARGE_INTEGER;
    HiddenSectors: DWORD;
    PartitionNumber: DWORD;
    PartitionType: BYTE;
    BootIndicator: ByteBool;
    RecognizedPartition: ByteBool;
    RewritePartition: ByteBool;
  end;
  TPartitionInformation = PARTITION_INFORMATION;
  PPartitionInformation = ^TPartitionInformation;

  DRIVE_LAYOUT_INFORMATION = record
    PartitionCount: DWORD;
    Signature: DWORD;
    PartitionEntry: array [0..0] of PARTITION_INFORMATION;
  end;
  TDriveLayoutInformation = DRIVE_LAYOUT_INFORMATION;
  PDriveLayoutInformation = ^TDriveLayoutInformation;

const
  MAX_DOS_NAMES = 125000; // enough room to handle all possible block and serial devices on an average PC, sometimes it might not be enough !!!
  OBJ_CASE_INSENSITIVE = $00000040;
  FILE_NON_DIRECTORY_FILE = $00000040;
  FILE_SYNCHRONOUS_IO_NONALERT = $00000020;
  FILE_DEVICE_MASS_STORAGE = $0000002d;
  FILE_DEVICE_DISK = $00000007;
  FILE_DEVICE_FILE_SYSTEM = $00000009;
  FILE_ANY_ACCESS    = 0;
  FILE_READ_ACCESS   = 1;
  FILE_WRITE_ACCESS   = $0002;
  FILE_READ_ATTRIBUTES = $0080;
  METHOD_BUFFERED    = 0;
  METHOD_NEITHER     = 3;
  DBT_DEVICEQUERYREMOVE = $8001;
  DBT_DEVICEREMOVEPENDING = $8003;
  DBT_DEVTYP_VOLUME = 2;
  ERROR_NOT_A_REPARSE_POINT = 4390;
  DISK_ATTRIBUTE_OFFLINE = 1;
  DISK_ATTRIBUTE_READ_ONLY = 2;
  IOCTL_SCSI_MINIPORT = $4D008;
  IOCTL_SCSI_GET_ADDRESS = $41018;
  IOCTL_DISK_BASE = FILE_DEVICE_DISK;
  IOCTL_STORAGE_BASE = FILE_DEVICE_MASS_STORAGE;
  IOCTL_VOLUME_BASE = DWORD('V');
  IOCTL_VOLUME_OFFLINE = $56c00c;
  IOCTL_VOLUME_ONLINE = $56c008;
  IOCTL_STORAGE_EJECT_MEDIA = ($2d shl 16) or (1 shl 14) or ($202 shl 2);
  IOCTL_STORAGE_MEDIA_REMOVAL = ($2d shl 16) or (1 shl 14) or ($201 shl 2);
  IOCTL_STORAGE_GET_DEVICE_NUMBER = (
    (IOCTL_STORAGE_BASE shl 16) or (FILE_ANY_ACCESS shl 14) or
    ($0420 shl 2) or METHOD_BUFFERED);
  IOCTL_DISK_GET_LENGTH_INFO = (
    (IOCTL_DISK_BASE shl 16) or (FILE_READ_ACCESS shl 14) or
    ($0017 shl 2) or METHOD_BUFFERED);
  IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS = (
    (IOCTL_VOLUME_BASE shl 16) or (FILE_ANY_ACCESS shl 14) or
    (0 shl 2) or METHOD_BUFFERED);
  IOCTL_DISK_SET_DISK_ATTRIBUTES = $7c0f4;
  IOCTL_DISK_UPDATE_PROPERTIES = (
    (IOCTL_DISK_BASE shl 16) or (FILE_ANY_ACCESS shl 14) or
	  ($0050 shl 2) or METHOD_BUFFERED);
  IOCTL_DISK_SET_DRIVE_LAYOUT = (
    (IOCTL_DISK_BASE shl 16) or ((FILE_READ_ACCESS or FILE_WRITE_ACCESS) shl 14) or
    ($0004 shl 2) or METHOD_BUFFERED);
  FSCTL_ALLOW_EXTENDED_DASD_IO = (
    (FILE_DEVICE_FILE_SYSTEM shl 16) or (FILE_ANY_ACCESS shl 14) or
    (32 shl 2) or METHOD_NEITHER);
  FSCTL_LOCK_VOLUME = (FILE_DEVICE_FILE_SYSTEM shl 16) or (FILE_ANY_ACCESS shl 14) or (6 shl 2) or METHOD_BUFFERED;
  FSCTL_UNLOCK_VOLUME = (
    (FILE_DEVICE_FILE_SYSTEM shl 16) or (FILE_ANY_ACCESS shl 14) or
    (7 shl 2) or METHOD_BUFFERED);
  FSCTL_DISMOUNT_VOLUME = (
    (FILE_DEVICE_FILE_SYSTEM shl 16) or (FILE_ANY_ACCESS shl 14) or
    (8 shl 2) or METHOD_BUFFERED);

  // Control codes for IOCTL_SCSI_MINIPORT requests.
  SMP_IMSCSI                      = $83730000;
  SMP_IMSCSI_QUERY_VERSION        = SMP_IMSCSI + $800;
  SMP_IMSCSI_CREATE_DEVICE        = SMP_IMSCSI + $801;
  SMP_IMSCSI_QUERY_DEVICE         = SMP_IMSCSI + $802;
  SMP_IMSCSI_QUERY_ADAPTER        = SMP_IMSCSI + $803;
  SMP_IMSCSI_CHECK                = SMP_IMSCSI + $804;
  SMP_IMSCSI_SET_DEVICE_FLAGS     = SMP_IMSCSI + $805;
  SMP_IMSCSI_REMOVE_DEVICE        = SMP_IMSCSI + $806;
  SMP_IMSCSI_EXTEND_DEVICE        = SMP_IMSCSI + $807;

  IMSCSI_FUNCTION_SIGNATURE = 'PhDskMnt';
  IMSCSI_AUTO_DEVICE_NUMBER = $00FFFFFF;
  IMSCSI_ALL_DEVICES = $00FFFFFF;

  function GetFreeDriveList: TAssignedDrives;
  Procedure ImScsiInitializeSrbIoBlock(var SrbIoControl:TSrbIoControl; Size, ControlCode, Timeout: Cardinal);
  procedure InitializeObjectAttributes(var InitializedAttributes: TObjectAttributes;
                                     ObjectName: PUnicodeString;
                                     Attributes: ULONG;
                                     RootDirectory: THandle;
                                     SecurityDescriptor: Pointer;
                                     SecurityQualityOfService: Pointer = NIL);
  Function ImScsiOpenScsiAdapterByScsiPortNumber(PortNumber:Byte):THandle;
  Function ImScsiQueryDevice(adapter:THandle; config:PScsiDeviceConfig; configSize:LongWord):Boolean;
  Function ImDiskOpenDeviceByName(FileName:PUnicodeString; AccessMode:DWORD):THandle;
  Function ImScsiOpenScsiAdapter(var PortNumber:Byte):THandle;
  Function ImScsiDeviceIoControl(device:THandle; ControlCode: DWORD; var SrbIoControl: TSrbIoControl; Size, Timeout: DWORD; var ReturnLength: DWORD):Boolean;
  Function WidePosEx(const SubStr, S: widestring; Offset: Integer = 1): Integer;
  Function decodeException(code:TRamErrors):String;
  Procedure DebugLog(msg:string;eventType:DWord = EVENTLOG_INFORMATION_TYPE);

implementation

Uses Math,Classes, TntWideStrUtils;

Var
  EventLogHandle:Integer;

procedure RtlInitUnicodeString(DestinationString: PUnicodeString; SourceString: LPWSTR); stdcall; external 'ntdll.dll';
function RtlNtStatusToDosError(Status: NTSTATUS): ULONG; stdcall; external 'ntdll.dll';
function NtClose(_Handle: THandle): NTSTATUS; stdcall; external 'ntdll.dll';
function NtOpenFile(out FileHandle: THandle;
  DesiredAccess: ACCESS_MASK;
  const ObjectAttributes: TObjectAttributes;
  out IoStatusBlock: IO_STATUS_BLOCK;
  ShareAccess, OpenOptions: ULONG): NTSTATUS; stdcall; external 'ntdll.dll';

Constructor ERamDiskError.Create (Code:TRamErrors);
Begin
  ArsenalCode:=Code;
end;

procedure InitializeObjectAttributes(var InitializedAttributes: TObjectAttributes;
                                     ObjectName: PUnicodeString;
                                     Attributes: ULONG;
                                     RootDirectory: THandle;
                                     SecurityDescriptor: Pointer;
                                     SecurityQualityOfService: Pointer = NIL);
begin
  InitializedAttributes.Length := SizeOf(TObjectAttributes);
  InitializedAttributes.RootDirectory := RootDirectory;
  InitializedAttributes.Attributes := Attributes;
  InitializedAttributes.ObjectName := ObjectName;
  InitializedAttributes.SecurityDescriptor := SecurityDescriptor;
  InitializedAttributes.SecurityQualityOfService := SecurityQualityOfService;
end;

// Prepares for sending a device request to an Arsenal Image Mounter adapter
Procedure ImScsiInitializeSrbIoBlock(var SrbIoControl:TSrbIoControl; Size, ControlCode, Timeout: Cardinal);
begin
  SrbIoControl.HeaderLength := sizeof(SRB_IO_CONTROL);
  SrbIoControl.Signature := IMSCSI_FUNCTION_SIGNATURE;
  SrbIoControl.ControlCode := ControlCode;
  SrbIoControl.Length := Size - sizeof(TSrbIoControl);
  SrbIoControl.Timeout := Timeout;
  SrbIoControl.ReturnCode := 0;
end;

Function ImDiskOpenDeviceByName(FileName:PUnicodeString; AccessMode:DWORD):THandle;
var
  status: NTSTATUS;
  object_attrib: TObjectAttributes;
  io_status: IO_STATUS_BLOCK;
begin
  InitializeObjectAttributes(object_attrib, FileName, OBJ_CASE_INSENSITIVE, 0, NIL);
  status := NtOpenFile(Result, SYNCHRONIZE or AccessMode, object_attrib, io_status, FILE_SHARE_READ Or FILE_SHARE_WRITE, FILE_NON_DIRECTORY_FILE or FILE_SYNCHRONOUS_IO_NONALERT);

  if status<0 then
  begin
    SetLastError(RtlNtStatusToDosError(status));
    Result:=INVALID_HANDLE_VALUE;
  end;
end;

Function ImScsiOpenScsiAdapterByScsiPortNumber(PortNumber:Byte):THandle;
var
  devName: TUnicodeString;
  check: TSrbIoControl;
  tmp: DWORD;
Begin
  RtlInitUnicodeString(@devName, PWideChar(WideString(Format('\??\Scsi%u:',[PortNumber]))));
  Result:=ImDiskOpenDeviceByName(@devName, GENERIC_READ + GENERIC_WRITE);
  if Result <> INVALID_HANDLE_VALUE then
  Begin
    ImScsiInitializeSrbIoBlock(check, sizeof(check), SMP_IMSCSI_CHECK, 0);
    if not DeviceIoControl(Result, IOCTL_SCSI_MINIPORT, @check, sizeof(check), @check, sizeof(check), tmp, NIL) then
    Begin
      NtClose(Result);
      Result:=INVALID_HANDLE_VALUE;
    end;
  end;
end;

Function ImScsiDeviceIoControl(device:THandle; ControlCode: DWORD; var SrbIoControl: TSrbIoControl; Size, Timeout: DWORD; var ReturnLength: DWORD):Boolean;
Begin
  ImScsiInitializeSrbIoBlock(SrbIoControl, Size, ControlCode, Timeout);
  if Not DeviceIoControl(Device, IOCTL_SCSI_MINIPORT, @SrbIoControl, Size, @SrbIoControl, Size, ReturnLength, NIL) then
  begin
    DebugLog(SysErrorMessage(RtlNtStatusToDosError(SrbIoControl.ReturnCode)),EVENTLOG_ERROR_TYPE);
    Result:=FALSE;
    Exit;
  end;
  DebugLog(SysErrorMessage(RtlNtStatusToDosError(SrbIoControl.ReturnCode)));
  Result:=SrbIoControl.ReturnCode >= 0;
end;

Function ImScsiQueryDevice(adapter:THandle; config:PScsiDeviceConfig; configSize:LongWord):Boolean;
var
  createData: TScsiCreateData;
  tmp: DWORD;
Begin
  Result:=False;
  createData.Fields.DeviceNumber:= config.DeviceNumber;
  if Not ImScsiDeviceIoControl(Adapter, SMP_IMSCSI_QUERY_DEVICE, createData.SrbIoControl, SizeOf(TScsiCreateData), 0, tmp) then Exit;
  if tmp < SizeOf(TScsiCreateData) - SizeOf(TScsiDeviceConfigFilename) then
  begin
     SetLastError(ERROR_INVALID_PARAMETER);
     Exit;
  end;

  Move(createData.Fields, Config^, min(tmp - SizeOf(TSrbIoControl), ConfigSize));
  Result:=TRUE;
end;

Function ImScsiOpenScsiAdapter(var PortNumber:Byte):THandle;
Var
  dosDevs, target: String;
  devName: TUnicodeString;
  i, len, multiple: Integer;
  portNum: LongWord;
  devices: TStringList;
  handle: THandle;
  check: TSrbIoControl;
  tmp: DWORD;
const
  scsiport_prefix = '\Device\Scsi\phdskmnt';
  storport_prefix = '\Device\RaidPort';
Begin
  multiple:=1;
  Repeat
    SetLength(dosDevs, MAX_DOS_NAMES * multiple);
    len:=QueryDosDevice(NIL, PAnsiChar(dosDevs), Length(dosDevs));
    if len=0 then Inc(multiple);
    if multiple > 10 then
    begin
      DebugLog(Format('ImScsiOpenScsiAdapter::QueryDosDevice can not fit DOS device names inside %d bytes',[Length(dosdevs)]),EVENTLOG_ERROR_TYPE);
      tmp:=GetLastError;
      raise Exception.Create('ImScsiOpenScsiAdapter::QueryDosDevice = ' + SysErrorMessage(tmp));
    end;
  Until len <> 0;
  for i:=1 to len Do
    if dosDevs[i] = #0 then dosDevs[i]:= #13;
  devices:=Nil;
  Result:=INVALID_HANDLE_VALUE;
  Try
    SetLength(target, 2000);
    devices:=TStringList.Create;
    devices.Text:=dosDevs;
    for i:=0 to devices.Count-1 do
    Begin
      if (Copy(devices[i],1,4) = 'Scsi') And (AnsiLastChar(devices[i]) = ':') Then
      Begin
        portNum:=StrToInt(Copy(devices[i],5,Length(devices[i])-5));
        if portNum < 256 Then
        Begin
          if QueryDosDevice(PAnsiChar(devices[i]), PAnsiChar(target), Length(target)) = 0 then
          try
            DebugLog(Format('ImScsiOpenScsiAdapter::QueryDosDevice can not fit DOS device name for "%s" inside %d bytes',[devices[i],Length(target)]),EVENTLOG_ERROR_TYPE);
            RaiseLastOSError;
          except
            on E:Exception do
            Begin
              E.Message:= 'ImScsiOpenScsiAdapter::QueryDosDevice[' + IntToStr(i) + '] = ' + E.Message;
              raise E;
            end;
          end;
          if (Pos(scsiport_prefix, target) = 1) Or (Pos(storport_prefix, target) = 1) then
          Begin
            RtlInitUnicodeString(@devName, PWideChar(WideString(target)));
            handle:=ImDiskOpenDeviceByName(@devName, GENERIC_READ + GENERIC_WRITE);
            if handle <> INVALID_HANDLE_VALUE then
            Begin
              ImScsiInitializeSrbIoBlock(check, sizeof(check), SMP_IMSCSI_CHECK, 0);
              if not DeviceIoControl(handle, IOCTL_SCSI_MINIPORT, @check, sizeof(check), @check, sizeof(check), tmp, NIL) then NtClose(handle)
              else
              Begin
                PortNumber:=portNum;
                Result:=handle;
                Exit;
              end;
            end;
          end;
        end;
      end;
    end;
  Finally
    devices.Free;
  end;
end;

function GetFreeDriveList: TAssignedDrives;
var
  Buff: array[0..128] of Char;
  ptr: PChar;
  used:TAssignedDrives;
begin
  if (GetLogicalDriveStrings(Length(Buff), Buff) = 0) then RaiseLastOSError;
  // There can't be more than 26 lettered drives (A..Z).
  used:=[];

  ptr := @Buff[0];
  while StrLen(ptr) > 0 do
  begin
    Include(used,ptr^);
    ptr := StrEnd(ptr);
    Inc(ptr);
  end;
  Result:=['C'..'Z'] - used; // exclude floppy drives
end;

procedure WStrDelete(var S: WideString; Index, Count: Integer);
var
  L, N: Integer;
  NewStr: PWideChar;
begin
  L := Length(S);
  if (L > 0) and (Index >= 1) and (Index <= L) and (Count > 0) then
  begin
    Dec(Index);
    N := L - Index - Count;
    if N < 0 then N := 0;
    if (Index = 0) and (N = 0) then NewStr := nil else
    begin
      NewStr := WStrAlloc(Index + N);
      if Index > 0 then
        Move(Pointer(S)^, NewStr^, Index * 2);
      if N > 0 then
        Move(PWideChar(Pointer(S))[L - N], NewStr[Index], N * 2);
    end;
    S := WStrPas(NewStr);
    WStrDispose(NewStr);
  end;
end;

function WidePosEx(const SubStr, S: widestring; Offset: Integer = 1): Integer;
var
  i: integer;
  tmp: widestring;
begin
  Result := 0;
  tmp := S;
  WStrDelete(tmp,1,Offset);
  i := Pos(SubStr, tmp);
  if (i > 0) then
    Result := Offset + i;
end;

Function decodeException(code:TRamErrors):String;
Begin
  Result:='';
  Case code Of
    RamNotInstalled: Result:='Arsenal Driver is not installed';
    RamNotAccessible: Result:='Arsenal Driver is not accessible';
    RamCantEnumDrives: Result:='Can not enumerate disk volumes';
    RamDriverVersion: Result:='Arsenal Driver is old version';
    RamCantCreate: Result:='Could not create RAM-disk';
    RamCantFormat: Result:='Could not create a partition on the RAM-disk';
    RamNoFreeLetter: Result:='No free drive letters available';
  end;
End;

Procedure DebugLog(msg:string;eventType:DWord = EVENTLOG_INFORMATION_TYPE);
Begin
  ReportEvent(EventLogHandle,eventType,0,0,Nil,1,0,PChar(msg),Nil);
end;

Initialization
  EventLogHandle:=RegisterEventSource(Nil,'Arsenal RamDisk');

Finalization
  DeregisterEventSource(EventLogHandle);
end.
