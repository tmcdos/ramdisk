unit RamVolume;

interface

uses Windows,Definitions;

function GetRamDiskLetter(device:TDeviceNumber;portNumber:Cardinal;Var existing:TRamDisk): Char;
Function ImScsiOpenDiskByDeviceNumber(DeviceNumber: TDeviceNumber; PortNumber: DWORD; var DiskNumber: Integer):THandle;

implementation

uses Classes,StrUtils,SysUtils;

function FindFirstVolume(lpszVolumeName: LPSTR; cchBufferLength: DWORD): THANDLE; stdcall; External kernel32 name 'FindFirstVolumeA';
function FindNextVolume(hFindVolume: THANDLE; lpszVolumeName: LPSTR; cchBufferLength: DWORD): BOOL; stdcall; External kernel32 name 'FindNextVolumeA';
function FindVolumeClose(hFindVolume: THANDLE): BOOL; stdcall; External kernel32;
function GetVolumePathNamesForVolumeName(lpszVolumeName, lpszVolumePathNames: LPCSTR; cchBufferLength: DWORD; var lpcchReturnLength: DWORD): BOOL; stdcall; External kernel32 name 'GetVolumePathNamesForVolumeNameA';

Function ImScsiOpenDiskByDeviceNumber(DeviceNumber: TDeviceNumber; PortNumber: DWORD; var DiskNumber: Integer):THandle;
Const
  disk_prefix: WideString = 'PhysicalDrive';
var
  dosdevs: string;
  disk, adapter: THandle;
  disk_number: Integer;
  dw: DWORD;
  dev_path: WideString;
  config:TScsiDeviceConfig;
  i, len, multiple: Integer;
  devices: TStringList;
  address: TScsiAddress;
  device_number: TStorageDeviceNumber;
  disk_size: Int64;
Begin
  disk_number:= -1;
  Result:=INVALID_HANDLE_VALUE;
  multiple:=1;
  Repeat
    SetLength(dosDevs, MAX_DOS_NAMES * multiple);
    len:=QueryDosDevice(NIL, PAnsiChar(dosdevs), Length(dosdevs));
    // ImScsiDebugMessage(L"Error opening SCSI port %1!i!: %2!ws!", PortNumber & 0xFF, (LPCWSTR)errmsg);
    if len=0 then Inc(multiple);
    if multiple > 10 then
    begin
      DebugLog(Format('QueryDosDevice can not fit DOS device names inside %d bytes',[Length(dosdevs)]),EVENTLOG_ERROR_TYPE);
      Exit;
    end;
  Until len <> 0;
  adapter := ImScsiOpenScsiAdapterByScsiPortNumber(PortNumber);
  if adapter = INVALID_HANDLE_VALUE then
  Begin
    DebugLog('Could not open SCSI adapter inside ImScsiOpenDiskByDeviceNumber',EVENTLOG_ERROR_TYPE);
    Exit;
  end;

  config.DeviceNumber := DeviceNumber;
  If not ImScsiQueryDevice(adapter, @config, SizeOf(TScsiDeviceConfig)) Then
  begin
    CloseHandle(adapter);
    DebugLog('Could not get SCSI device config inside ImScsiOpenDiskByDeviceNumber',EVENTLOG_ERROR_TYPE);
    Exit;
  end;
  CloseHandle(adapter);

  for i:=1 to len Do
    if dosDevs[i] = #0 then dosDevs[i]:= #13;
  devices:=Nil;
  Try
    devices:=TStringList.Create;
    devices.Text:=dosDevs;
    for i:=0 to devices.Count-1 do
    Begin
      if LeftStr(devices[i],Length(disk_prefix)) <> disk_prefix Then Continue;
      if not TryStrToInt(Copy(devices[i],Length(disk_prefix)+1,10), disk_number) then continue;
      dev_path := '\\?\' + devices[i];
      disk := CreateFileW(PWideChar(dev_path), GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, NIL, OPEN_EXISTING, 0, 0);
      if disk = INVALID_HANDLE_VALUE then Continue;
      if DeviceIoControl(disk, IOCTL_SCSI_GET_ADDRESS, NIL, 0, @address, sizeof(address), dw, NIL) then
      Begin
        if ((address.PortNumber = PortNumber) and
          (address.PathId = DeviceNumber.PathId) and
          (address.TargetId = DeviceNumber.TargetId) and
          (address.Lun = DeviceNumber.Lun)) then
        Begin
          if DeviceIoControl(disk, IOCTL_STORAGE_GET_DEVICE_NUMBER, NIL, 0, @device_number, sizeof(device_number), dw, NIL) then
          Begin
            if ((device_number.DeviceNumber = DWORD(disk_number)) and
              (device_number.DeviceType = FILE_DEVICE_DISK) and
              (device_number.PartitionNumber = 0)) then
            Begin
              DeviceIoControl(disk, FSCTL_ALLOW_EXTENDED_DASD_IO, NIL, 0, NIL, 0, dw, NIL);
              disk_size := 0;
              if DeviceIoControl(disk, IOCTL_DISK_GET_LENGTH_INFO, NIL, 0, @disk_size, sizeof(disk_size), dw, NIL) then
              begin
                if disk_size = config.DiskSize then
                Begin
                  DiskNumber := disk_number;
                  Result:=disk;
                  Exit;
                end;
              end
            end;
          end;
        end;
      end
      else Case GetLastError of
        ERROR_INVALID_PARAMETER,
        ERROR_INVALID_FUNCTION,
        ERROR_NOT_SUPPORTED,
        ERROR_IO_DEVICE:
        Begin
          DebugLog(Format('Could not get the SCSI address of device %s',[devices[i]]),EVENTLOG_ERROR_TYPE);
          break;
        end;
      end;
      CloseHandle(disk);
    end;
  Finally
    devices.Free;
  end;
end;

Function GetRamDiskLetter(device:TDeviceNumber;portNumber:Cardinal;Var existing:TRamDisk):Char;
var
  adapter, volHandle, volume: THandle;
  tmp: DWORD;
  address: TScsiAddress;
  device_number: TStorageDeviceNumber;
  volumeName: Array[0..49] of AnsiChar;
  mountName: Array[0..250] Of AnsiChar;
Begin
  Result:=#0;
  adapter:= ImScsiOpenDiskByDeviceNumber(device, PortNumber, existing.diskNumber);
  if adapter <> INVALID_HANDLE_VALUE then
  begin
    volume := FindFirstVolume(volumeName, Length(volumeName));
    if volume <> INVALID_HANDLE_VALUE then
    begin
      repeat
        volumeName[48] := #0;
        volHandle:= CreateFileA(volumeName, 0, FILE_SHARE_READ or FILE_SHARE_WRITE, NIL, OPEN_EXISTING, 0, 0);
        volumeName[48] := '\';

        if volHandle = INVALID_HANDLE_VALUE then break;
        if DeviceIoControl(volHandle, IOCTL_SCSI_GET_ADDRESS, NIL, 0, @address, sizeof(address), tmp, NIL) then
        Begin
          if ((address.PortNumber = portNumber) and
            (address.PathId = device.PathId) and
            (address.TargetId = device.TargetId) and
            (address.Lun = device.Lun)) then
          Begin
            if DeviceIoControl(volHandle, IOCTL_STORAGE_GET_DEVICE_NUMBER, NIL, 0, @device_number, sizeof(device_number), tmp, NIL) then
            Begin
              if (device_number.DeviceNumber = DWORD(existing.diskNumber)) and
                (device_number.DeviceType = FILE_DEVICE_DISK) and
                (device_number.PartitionNumber > 0) then
              Begin
                if GetVolumePathNamesForVolumeName(volumeName, mountName, Length(mountName), tmp) then
                begin
                  CloseHandle(volHandle);
                  existing.volumeName:=volumeName;
                  Result:=Char(mountName[0]); // mountName is array of ASCIIZ, ending with empty ASCIIZ
                  Break;
                end;
              end;
            end;
          end;
        end;
        CloseHandle(volHandle);
      until not FindNextVolume(volume, volumeName, Length(volumeName));
      FindVolumeClose(volume);
    end;
  end;
end;

end.
 