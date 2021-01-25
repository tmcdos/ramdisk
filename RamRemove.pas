unit RamRemove;

interface

Uses Definitions;

Function DetachRamDisk (Var existing:TRamDisk):Boolean;

implementation

uses SysUtils,Windows,Messages,RamSync;

function OpenVolume(ADrive: char): THandle;
var
  VolumeName: string;
begin
  VolumeName := Format('\\.\%s:', [ADrive]);
  Result := CreateFile(PChar(VolumeName), GENERIC_READ or GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
end;

function PreventRemovalOfVolume(AVolumeHandle: THandle; APreventRemoval: boolean): boolean;
var
  BytesReturned: Cardinal;
  PreventMediaRemoval: BOOL;
begin
  PreventMediaRemoval := APreventRemoval;
  Result := DeviceIoControl(AVolumeHandle, IOCTL_STORAGE_MEDIA_REMOVAL,
    @PreventMediaRemoval, SizeOf(PreventMediaRemoval), nil, 0, BytesReturned, nil);
end;

function AutoEjectVolume(AVolumeHandle: THandle): boolean;
var
  BytesReturned: Cardinal;
begin
  Result := DeviceIoControl(AVolumeHandle, IOCTL_STORAGE_EJECT_MEDIA, nil, 0, nil, 0, BytesReturned, nil);
end;

Procedure ImDiskNotifyRemovePending(DriveLetter:WideChar);
var
  dwp: DWORD;
  devBroadcastVol: TDevBroadcastVolume;
Begin
  devBroadcastVol.dbch_size:=SizeOf(devBroadcastVol);
  devBroadcastVol.dbch_devicetype:=DBT_DEVTYP_VOLUME;
  devBroadcastVol.dbcv_unitmask:=1 shl (Ord(DriveLetter) - Ord('A'));

  SendMessageTimeout(HWND_BROADCAST,
    WM_DEVICECHANGE,
    DBT_DEVICEQUERYREMOVE,
    Integer(@devBroadcastVol),
    SMTO_BLOCK or SMTO_ABORTIFHUNG,
    4000,
    dwp);

  SendMessageTimeout(HWND_BROADCAST,
    WM_DEVICECHANGE,
    DBT_DEVICEREMOVEPENDING,
    Integer(@devBroadcastVol),
    SMTO_BLOCK or SMTO_ABORTIFHUNG,
    4000,
    dwp);
end;

Function ImScsiRemoveDeviceByNumber(hWnd, adapter: THandle; DeviceNumber: TDeviceNumber):Boolean;
Var
  dw: DWORD;
  remove_device: TScsiRemoveDevice;
begin
  ImScsiInitializeSrbIoBlock(remove_device.SrbIoControl, sizeof(TScsiRemoveDevice), SMP_IMSCSI_REMOVE_DEVICE, 0);
  remove_device.DeviceNumber := DeviceNumber;

  if Not ImScsiDeviceIoControl(Adapter, SMP_IMSCSI_REMOVE_DEVICE, remove_device.SrbIoControl, sizeof(remove_device), 0, dw) then
  begin
    //ImScsiMsgBoxLastError(hWnd, L"Error removing virtual disk:");
    Result:=FALSE;
  End
  else Result:=TRUE;
end;

Function DetachRamDisk(var existing:TRamDisk):Boolean;
var
  device,adapter: THandle;
  tmp: Integer;
  dw: DWORD;
  deviceNumber: TDeviceNumber;
  portNumber:  Byte;
  forceDismount: Boolean;
Begin
  Result:=False;
  If existing.letter = #0 Then
  Begin
    adapter := ImScsiOpenScsiAdapter(portNumber);
    if adapter = INVALID_HANDLE_VALUE then
    begin
      dw:=GetLastError;
      if dw = ERROR_FILE_NOT_FOUND then OutputDebugString('Arsenal Driver not installed')
      else OutputDebugString(PAnsiChar(SysErrorMessage(dw)));
      raise ERamDiskError.Create(RamNotInstalled);
    end;
    deviceNumber.LongNumber:=IMSCSI_ALL_DEVICES;
    if not ImScsiRemoveDeviceByNumber(0, adapter, DeviceNumber) then
    begin
      dw:=GetLastError;
      if dw = ERROR_FILE_NOT_FOUND then
      begin
        OutputDebugString('No devices found');
        Exit;
      end
      else
      begin
        OutputDebugString(PAnsiChar(SysErrorMessage(dw)));
        Exit;
      end;
    end;
    Result:=True;
    Exit;
  end;
  if existing.synchronize And (existing.persistentFolder<>'') then SaveRamDisk(existing);
  forceDismount:=False;
  device := OpenVolume(existing.letter);
  if device = INVALID_HANDLE_VALUE then
  begin
    case GetLastError of
      ERROR_INVALID_PARAMETER:
         // "This version of Windows only supports drive letters as mount points.\n"
         // "Windows 2000 or higher is required to support subdirectory mount points.\n",
        Exit;
      ERROR_INVALID_FUNCTION:
        // "Mount points are only supported on NTFS volumes.\n",
        Exit;
      ERROR_NOT_A_REPARSE_POINT,
      ERROR_DIRECTORY,
      ERROR_DIR_NOT_EMPTY:
        // ImScsiOemPrintF(stderr, "Not a mount point: '%1!ws!'", MountPoint);
        Exit;
    else
      tmp:=GetLastError;
      raise Exception.Create(SysErrorMessage(tmp));
    end;
  End;
  // Notify processes that this device is about to be removed.
  ImDiskNotifyRemovePending(WideChar(existing.letter));
  FlushFileBuffers(device);

  // Locking volume
  try
    if Not DeviceIoControl(device, FSCTL_LOCK_VOLUME, NIL, 0, NIL, 0, dw, NIL) then forceDismount := TRUE;
    // Unmounting filesystem
    try
      if DeviceIoControl(device, FSCTL_DISMOUNT_VOLUME, NIL, 0, NIL, 0, dw, NIL) then
      begin
        if forceDismount then DeviceIoControl(device, FSCTL_LOCK_VOLUME, NIL, 0, NIL, 0, dw, NIL);
        // Set prevent removal to false and eject the volume
        if PreventRemovalOfVolume(device, FALSE) then AutoEjectVolume(device);
        Result:=True;
      end;
    finally
      DeviceIoControl(device, FSCTL_UNLOCK_VOLUME, NIL, 0, NIL, 0, dw, NIL);
    End;
  finally
    CloseHandle(device);
  end;
  RestoreTempFolder(WideChar(existing.letter)); // MUST be before UpdateDismounted because it will clear the Letter
end;

end.
 