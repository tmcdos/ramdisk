unit RamDetect;

interface

uses Windows, SysUtils, Definitions;

function GetRamDisk(var existing:TRamDisk): Boolean;

implementation

Uses RamVolume;

procedure RtlInitUnicodeString(DestinationString: PUnicodeString; SourceString: LPWSTR); stdcall; external 'ntdll.dll';
function NtClose(_Handle: THandle): NTSTATUS; stdcall; external 'ntdll.dll';

Function GetRamDisk(var existing:TRamDisk):Boolean;
var
  device: TDeviceNumber;
  address: TScsiAddress;
  adapter: THandle;
  config: TScsiDeviceConfig;
Begin
  Result:=False;
  // check for existing RAMdisk
  adapter := ImScsiOpenScsiAdapter(address.PortNumber);
  if adapter = INVALID_HANDLE_VALUE then Exit;
  CloseHandle(adapter);
  adapter := ImScsiOpenScsiAdapterByScsiPortNumber(address.PortNumber);
  If adapter = INVALID_HANDLE_VALUE then Exit;
  device.LongNumber := 0;
  config.DeviceNumber:=device;
  If not ImScsiQueryDevice(adapter, @config, SizeOf(TScsiDeviceConfig)) Then
  Begin
    // no such device
    CloseHandle(adapter);
    Exit;
  end;
  existing.size:=config.DiskSize;
  // now enumerate disk volumes to find the drive letter
  CloseHandle(adapter);
  existing.letter:=GetRamDiskLetter(device,address.PortNumber,existing);
  Result:=True;
end;
{
Function ImScsiGetScsiAddressForDisk(Device:THandle; ScsiAddress:PScsiAddress):Boolean;
var
  dw:DWORD;
  deviceNumber:TStorageDeviceNumber;
Begin
  Result:=False;
  if DeviceIoControl(Device, IOCTL_STORAGE_GET_DEVICE_NUMBER, NIL, 0, @deviceNumber, sizeof(deviceNumber), dw, NIL) then
    if (deviceNumber.DeviceType = FILE_DEVICE_DISK) and (deviceNumber.PartitionNumber > 0) then
      Result:=DeviceIoControl(Device, IOCTL_SCSI_GET_ADDRESS, NIL, 0, ScsiAddress, sizeof(TScsiAddress), dw, NIL);
end;

Function ImScsiGetScsiAddressesForVolume(Volume:THandle; ScsiAddresses:PArrayScsiAddress; itemCount:Cardinal; Var NeededItemCount:Cardinal):Boolean;
var
  dw:DWORD;
  i:DWORD;
  disk:THandle;
  address:TScsiAddress;
  diskPath:string;
  disk_extents:Array of TDiskExtent;
Begin
  Result:=False;
  SetLength(disk_extents,itemCount);
  if not DeviceIoControl(Volume, IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS, NIL, 0,
    disk_extents, Length(disk_extents) * SizeOf(TDiskExtent), dw, NIL) then Exit;
  NeededItemCount := 0;
  i:=0;
  While (i < itemCount) and (i * SizeOf(TDiskExtent) < dw) do
  begin
    diskPath:=Format('\\?\PhysicalDrive%u',[disk_extents[i].DiskNumber]);
    disk := CreateFile(PAnsiChar(diskPath), GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE, NIL, OPEN_EXISTING, 0, 0);

    if disk = INVALID_HANDLE_VALUE Then Exit;
    if not ImScsiGetScsiAddressForDisk(disk, @address) then
    begin
      CloseHandle(disk);
      Exit;
    end;
    CloseHandle(disk);

    if NeededItemCount < itemCount then ScsiAddresses[NeededItemCount] := address;
    Inc(NeededItemCount);
    Inc(i);
  end;

  if NeededItemCount > itemCount then
  begin
    //  SetLastError(ERROR_MORE_DATA);
    Exit;
  end;
  Result:=True;
end;

Function ImScsiRemoveDeviceByNumber(adapter: THandle; var DeviceNumber:TDeviceNumber):Boolean;
var
  dw: DWORD;
  removeDev: TScsiRemoveDevice;
Begin
  ImScsiInitializeSrbIoBlock(removeDev.SrbIoControl, sizeof(TScsiRemoveDevice), SMP_IMSCSI_REMOVE_DEVICE, 0);
  removeDev.DeviceNumber := DeviceNumber;
  if not ImScsiDeviceIoControl(Adapter, SMP_IMSCSI_REMOVE_DEVICE, removeDev.SrbIoControl, sizeof(removeDev), 0, dw) then
  begin
    // ImScsiMsgBoxLastError(hWnd, L"Error removing virtual disk:");
    Result:=False;
  end
  else Result:=True;
end;
}
end.
