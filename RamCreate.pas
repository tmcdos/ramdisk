unit RamCreate;

interface

Uses Definitions;

function CreateRamDisk(Var config:TRamDisk;ShowProgress:Boolean): Boolean;

implementation

Uses Types,Windows,Classes,SysUtils,Controls,Forms,ExtCtrls,RamVolume,RamSetup,RamSync;

const
  IMSCSI_DRIVER_VERSION = $101;
  PARTITION_IFS         = $07;
  FMIFS_HARDDISK = $0C;

type
  TCallBackCommand = (
      PROGRESS,
      DONEWITHSTRUCTURE,
    	UNKNOWN2,
	    UNKNOWN3,
    	UNKNOWN4,
	    UNKNOWN5,
    	INSUFFICIENTRIGHTS,
	    FSNOTSUPPORTED,  // added 1.1
    	VOLUMEINUSE,     // added 1.1
    	UNKNOWN9,
	    UNKNOWNA,
    	DONE,
	    UNKNOWNC,
    	UNKNOWND,
    	OUTPUT,
      STRUCTUREPROGRESS,
      CLUSTERSIZETOOSMALL, // 16
      UNKNOWN11,
      UNKNOWN12,
      UNKNOWN13,
      UNKNOWN14,
      UNKNOWN15,
      UNKNOWN16,
      UNKNOWN17,
      UNKNOWN18,
      PROGRESS2,      // added 1.1, Vista percent done seems to duplicate PROGRESS
      UNKNOWN1A) ;

Var
  infoForm: TForm;

function NtClose(_Handle: THandle): NTSTATUS; stdcall; external 'ntdll.dll';
function RtlRandom(Seed : PULONG): ULONG; stdcall; external 'ntdll.dll';
function FindFirstVolume(lpszVolumeName: LPSTR; cchBufferLength: DWORD): THANDLE; stdcall; External kernel32 name 'FindFirstVolumeA';
function FindNextVolume(hFindVolume: THANDLE; lpszVolumeName: LPSTR; cchBufferLength: DWORD): BOOL; stdcall; External kernel32 name 'FindNextVolumeA';
function FindVolumeClose(hFindVolume: THANDLE): BOOL; stdcall; External kernel32;
function GetVolumePathNamesForVolumeName(lpszVolumeName, lpszVolumePathNames: LPCSTR; cchBufferLength: DWORD; var lpcchReturnLength: DWORD): BOOL; stdcall; External kernel32 name 'GetVolumePathNamesForVolumeNameA';
function DeleteVolumeMountPoint(lpszVolumeMountPoint: LPCSTR): BOOL; stdcall;external 'kernel32.dll' name 'DeleteVolumeMountPointA';
function SetVolumeMountPoint(lpszVolumeMountPoint, lpszVolumeName: LPCSTR): BOOL; stdcall;external 'kernel32.dll' name 'SetVolumeMountPointA';
Procedure FormatEx(
  DriveRoot: PWCHAR;
	MediaFlag: DWORD;
	Format: PWCHAR;
	DiskLabel: PWCHAR;
	QuickFormat: BOOL;
	ClusterSize: DWORD;
	Callback: Pointer); stdcall; External 'fmifs.dll';

procedure ShowInfo(const S : string);
begin
  if InfoForm <> nil then InfoForm.Free;
  InfoForm := TForm.Create(nil);
  InfoForm.FormStyle := fsStayOnTop;
  InfoForm.BorderStyle := bsNone;
  InfoForm.BorderIcons := [];
  InfoForm.Caption := '';
  InfoForm.Position := poScreenCenter;
  InfoForm.Width := InfoForm.Canvas.TextWidth(S) + 32;
  InfoForm.Height := 35;
  with TPanel.Create(InfoForm) do
  begin
    Align := alClient;
    Parent := InfoForm;
    Caption := S;
    Color:=255;
    Font.Color:=$FFFFFF;
  end;
  InfoForm.Show;
  InfoForm.Update;
end;

procedure HideInfo;
begin
  if InfoForm <> nil then
  begin
    InfoForm.Hide;
    InfoForm.Free;
    InfoForm := nil;
  end;
end;

Function ImScsiCheckDriverVersion(device:THandle):Boolean;
Var
  check: TScsiVersionCheck;
  dw: DWORD;
Begin
  Result:=False;
  DebugLog('Trying to query the version of Arsenal driver');
  ImScsiInitializeSrbIoBlock(check.SrbIoControl, sizeof(check), SMP_IMSCSI_QUERY_VERSION, 0);
  if Not DeviceIoControl(Device, IOCTL_SCSI_MINIPORT, @check, sizeof(check), @check, sizeof(check), dw, NIL) then
  Begin
    DebugLog('Arsenal driver does not support version checking',EVENTLOG_ERROR_TYPE);
    Exit;
  end;
  if dw < sizeof(check) then
  Begin
    DebugLog(Format('Arsenal driver reports the size of data structure for version check as %u which is less than expected %u',[dw,SizeOf(check)]),EVENTLOG_ERROR_TYPE);
    Exit;
  end;
  if check.SrbIoControl.ReturnCode < IMSCSI_DRIVER_VERSION Then
  Begin
    DebugLog(Format('Arsenal driver reports version %u which is less than required %u',[check.SrbIoControl.ReturnCode,IMSCSI_DRIVER_VERSION]),EVENTLOG_ERROR_TYPE);
    Exit;
  end;
  Result:=True;
end;

Function ImScsiVolumeUsesDisk(Volume:THandle; DiskNumber:DWORD):Boolean;
Var
  dw:DWORD;
  disk_extents: TVolumeDiskExtents;
begin
  Result:=False;
  if Not DeviceIoControl(Volume, IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS, NIL, 0,
    @disk_extents, SizeOf(TVolumeDiskExtents) + Length(disk_extents.Extents) * SizeOf(TDiskExtent), dw, NIL) Then Exit;
  Result:= disk_extents.Extents[0].DiskNumber = DiskNumber;
end;

Function ImDiskFindFreeDriveLetter:Char;
var
  freeLetters:TAssignedDrives;
  d:Char;
begin
  freeLetters := GetFreeDriveList();
  Result:=#0;
  For d:='C' to 'Z' Do
    if d in freeLetters Then
    Begin
      Result:=d;
      Exit;
    end;
end;

function FormatCallback (Command: TCallBackCommand; SubAction: DWORD; ActionInfo: Pointer): Boolean; stdcall;
Begin
  // we do not need visual progress
  Result:=True;
end;

// if Letter is "#" - the first unused letter is used
Function CreateRamDisk(Var config:TRamDisk;ShowProgress:Boolean):Boolean;
Var
  driver,disk,event,volume,volHandle: THandle;
  dw: DWORD;
  portNumber: Byte;
  create_data: TScsiCreateData;
  deviceNumber: TDeviceNumber;
  i,diskNumber, numVolumes: Integer;
  devPath,mountPoint: string;
  disk_attributes: TSetDiskAttributes;
  disk_size: Int64;
  rand_seed,start_time: Cardinal;
  drive_layout:TDriveLayoutInformation;
  volumeName: Array[0..49] of AnsiChar;
  mountName: Array[0..250] Of AnsiChar;
  formatDriveName: WideString;
  mountList:TStringList;
  mustFormat, formatDone, mount_point_found:Boolean;
Begin
  Result:=False;
  DebugLog('Trying to create a new RAM-disk');
  driver := ImScsiOpenScsiAdapter(portNumber);
  if driver = INVALID_HANDLE_VALUE then
  Begin
    DebugLog('Arsenal driver is not running',EVENTLOG_ERROR_TYPE);
    Exit;
  end;
  if not ImScsiCheckDriverVersion(driver) then
  begin
    DebugLog('Arsenal driver version is not suitable',EVENTLOG_ERROR_TYPE);
    CloseHandle(driver);
    Raise ERamDiskError.Create(RamDriverVersion);
  end;
  create_data.Fields.DeviceNumber.LongNumber := IMSCSI_AUTO_DEVICE_NUMBER;
  create_data.Fields.DiskSize := config.size;
  if not ImScsiDeviceIoControl(driver, SMP_IMSCSI_CREATE_DEVICE, create_data.SrbIoControl, SizeOf(create_data), 0, dw) then
  begin
    NtClose(driver);
    DebugLog(Format('Could not create the RAM-disk, error is "%s"',[SysErrorMessage(GetLastError)]),EVENTLOG_ERROR_TYPE);
    raise ERamDiskError.Create(RamCantCreate);
  end;
  NtClose(driver);
  DeviceNumber := create_data.Fields.DeviceNumber;
  disk := INVALID_HANDLE_VALUE;
  diskNumber := -1;

  Sleep(200);

  while true do
  begin
    DebugLog('Disk not attached yet, waiting 200 msec');
    disk := ImScsiOpenDiskByDeviceNumber(create_data.Fields.DeviceNumber, portNumber, diskNumber);
    if disk <> INVALID_HANDLE_VALUE then Break;
    //printf("Disk not attached yet, waiting... %c\r", NextWaitChar(&wait_char));

    event := ImScsiRescanScsiAdapterAsync(TRUE);
    Sleep(200);

    if event = 0 then Sleep(200)
    else
    begin
      while WaitForSingleObject(event, 200) = WAIT_TIMEOUT do
      begin
        DebugLog('Rescanning SCSI adapters, disk not attached yet. Waiting 200 msec');
        // printf("Disk not attached yet, waiting... %c\r", NextWaitChar(&wait_char));
      end;
      CloseHandle(event);
    end;
  end;
  CloseHandle(disk);

  devPath:='\\?\PhysicalDrive' + IntToStr(diskNumber);
  config.diskNumber:=diskNumber;
  disk := CreateFile(PAnsiChar(devPath), GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE, NIL, OPEN_EXISTING, 0, 0);
  if disk = INVALID_HANDLE_VALUE then
  begin
    dw:=GetLastError;
    DebugLog('Error reopening for writing ' + devPath + ': ' + SysErrorMessage(dw),EVENTLOG_ERROR_TYPE);
    raise ERamDiskError.Create(RamNotAccessible);
  end;

  disk_attributes.Version:=SizeOf(disk_attributes);
  disk_attributes.AttributesMask := DISK_ATTRIBUTE_OFFLINE;
  if not DeviceIoControl(disk, IOCTL_DISK_SET_DISK_ATTRIBUTES, @disk_attributes, sizeof(disk_attributes), NIL, 0, dw, NIL)
    And (GetLastError <> ERROR_INVALID_FUNCTION) then
  begin
    DebugLog('Cannot set disk in writable online mode',EVENTLOG_ERROR_TYPE);
  end;
  DeviceIoControl(disk, FSCTL_ALLOW_EXTENDED_DASD_IO, NIL, 0, NIL, 0, dw, NIL);

  disk_size := 0;
  mustFormat:=True;
  if DeviceIoControl(disk, IOCTL_DISK_GET_LENGTH_INFO, NIL, 0, @disk_size, sizeof(disk_size), dw, NIL) then
  begin
    if disk_size <> config.size then
    begin
      DebugLog('Disk ' + devPath + ' has unexpected size: ' + IntToStr(disk_size),EVENTLOG_ERROR_TYPE);
      mustFormat := False;
    end;
  end
  else if GetLastError <> ERROR_INVALID_FUNCTION then
  begin
    dw:=GetLastError;
    DebugLog('Can not query size of disk ' + devPath + ': ' + SysErrorMessage(dw),EVENTLOG_ERROR_TYPE);
    mustFormat := False;
  end;
  if mustFormat then
  begin
    DebugLog('Will now create a partition on the RAM device');
    rand_seed := GetTickCount();
    while true do
    begin
      ZeroMemory(@drive_layout,SizeOf(drive_layout));
      drive_layout.Signature := RtlRandom(@rand_seed);
      drive_layout.PartitionCount := 1;
      drive_layout.PartitionEntry[0].StartingOffset.QuadPart := 1048576;
      drive_layout.PartitionEntry[0].PartitionLength.QuadPart :=
          create_data.Fields.DiskSize -
          drive_layout.PartitionEntry[0].StartingOffset.QuadPart;
      drive_layout.PartitionEntry[0].PartitionNumber := 1;
      drive_layout.PartitionEntry[0].PartitionType := PARTITION_IFS;
      drive_layout.PartitionEntry[0].BootIndicator := TRUE;
      drive_layout.PartitionEntry[0].RecognizedPartition := TRUE;
      drive_layout.PartitionEntry[0].RewritePartition := TRUE;

      if DeviceIoControl(disk, IOCTL_DISK_SET_DRIVE_LAYOUT, @drive_layout, sizeof(drive_layout), NIL, 0, dw, NIL) then
      Begin
        DebugLog('Successfully created the partition');
        Break;
      end;
      if GetLastError <> ERROR_WRITE_PROTECT then
      begin
        CloseHandle(disk);
        Raise ERamDiskError.Create(RamCantFormat);
      end;

      //printf("Disk not yet ready, waiting... %c\r", NextWaitChar(&wait_char));
      DebugLog('Disk is not yet ready for partitioning, waiting ...');

      ZeroMemory(@disk_attributes, sizeof(disk_attributes));
      disk_attributes.AttributesMask := DISK_ATTRIBUTE_OFFLINE or DISK_ATTRIBUTE_READ_ONLY;

      if Not DeviceIoControl(disk, IOCTL_DISK_SET_DISK_ATTRIBUTES, @disk_attributes, sizeof(disk_attributes), NIL, 0, dw, NIL) then Sleep(400)
      else Sleep(0);
    end;
  end;

  if not DeviceIoControl(disk, IOCTL_DISK_UPDATE_PROPERTIES, NIL, 0, NIL, 0, dw, NIL)
    And (GetLastError <> ERROR_INVALID_FUNCTION) then DebugLog('Error updating disk properties',EVENTLOG_ERROR_TYPE);
  CloseHandle(disk);
  start_time := GetTickCount();
  formatDone := false;
  numVolumes:=0;
  while true do
  begin
    DebugLog('Trying to find the volume (partition) by name');
    volume := FindFirstVolume(volumeName, Length(volumeName));
    if volume = INVALID_HANDLE_VALUE then
    begin
      DebugLog('Error enumerating disk volumes',EVENTLOG_ERROR_TYPE);
      raise ERamDiskError.Create(RamCantEnumDrives);
    End;

    MountPoint:=config.letter+':\';
    mountList:=TStringList.Create;
    try
      repeat
        volumeName[48] := #0;
        DebugLog(Format('Quering volume %s',[volumeName]));
        volHandle := CreateFile(volumeName, 0, FILE_SHARE_READ or FILE_SHARE_WRITE, NIL, OPEN_EXISTING, 0, 0);
        if volHandle = INVALID_HANDLE_VALUE then Continue;
        if not ImScsiVolumeUsesDisk(volHandle, diskNumber) then
        begin
          CloseHandle(volHandle);
          DebugLog('This volume is not used (created) by Arsenal');
          continue;
        end;

        CloseHandle(volHandle);
        Inc(numVolumes);

        volHandle := CreateFile(volumeName, GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE, NIL, OPEN_EXISTING, 0, 0);
        if volHandle = INVALID_HANDLE_VALUE then DebugLog('Error opening volume in read/write mode',EVENTLOG_ERROR_TYPE)
        else
        begin
          if Not DeviceIoControl(volHandle, IOCTL_VOLUME_ONLINE, NIL, 0, NIL, 0, dw, NIL) then
          begin
            DebugLog('Error setting volume in online mode',EVENTLOG_ERROR_TYPE);
          end;
          CloseHandle(volHandle);
        end;

        if mustFormat then
        begin
          formatDone := true;
          if ShowProgress then ShowInfo('Formatting ...');
          // https://wreckorwalker.wordpress.com/2014/06/30/how-to-format-a-raw-disk-in-windows-by-c/
          // https://webcache.googleusercontent.com/search?q=cache:SY0k8D6vIxIJ:https://msmania.wordpress.com/tag/ivdsdisk/+&cd=21&hl=bg&ct=clnk&gl=bg
          // we use the undocumented FMIFS.DLL instead of Format.COM or VDS or WMI or ShFormatDrive - it always takes at least 5 seconds
          formatDriveName:=volumeName;
          FormatEx(PWideChar(formatDriveName),FMIFS_HARDDISK,'NTFS','RAMDISK',True,4096,@FormatCallBack);
          DebugLog('Successfully created NTFS filesystem on the RAM-disk');
          if ShowProgress then HideInfo;
        end;

        volumeName[48] := '\';
        if Not GetVolumePathNamesForVolumeName(volumeName, mountName, Length(mountName), dw) then
        begin
          DebugLog(Format('Error enumerating mount points for volume %s',[volumeName]),EVENTLOG_ERROR_TYPE);
          continue;
        end;

        mount_point_found := false;
        for i:=Low(mountName) to High(mountName) do
          If mountName[i] = #0 then mountName[i] := #13;
        mountList.Text:=mountName;
        for i:=0 to mountList.Count-1 do
        begin
          DebugLog(Format('Now trying to get a drive letter for "%s"',[mountList[i]]));
          if mountList[i] = '' then Break;
          if CompareText(mountPoint,mountList[i])<>0 then
          begin
            DebugLog('Removing the old mount point');
            if Not DeleteVolumeMountPoint(PAnsiChar(mountList[i])) then
            begin
              dw:=GetLastError;
              DebugLog('Error removing old mount point "'+mountList[i]+'": ' + SysErrorMessage(dw),EVENTLOG_ERROR_TYPE);
            end;
          end
          else
          begin
            mount_point_found := true;
            DebugLog(Format('Mounted at %s',[mountPoint]));
            // ImScsiOemPrintF(stdout, "  Mounted at %1!ws!", mnt);
          end;
        end;
        if (MountPoint <> '') and ((MountPoint <> '#:\') or not mount_point_found) then
        begin
          if MountPoint = '#:\' then
          begin
            MountPoint[1] := ImDiskFindFreeDriveLetter();
            if MountPoint[1] = #0 then raise ERamDiskError.Create(RamNoFreeLetter)
            Else config.letter:=MountPoint[1];
            DebugLog('Will use drive letter ' + MountPoint[1]);
          end;
          if not SetVolumeMountPoint(PAnsiChar(MountPoint), volumeName) then
          begin
            dw:=GetLastError;
            DebugLog('Error setting volume ' + volumeName + ' mount point to ' + MountPoint + ' : ' + SysErrorMessage(dw),EVENTLOG_ERROR_TYPE);
          end
          else Break;
          //MountPoint := '';
        end;
      Until not FindNextVolume(volume, volumeName, Length(volumeName));
    finally
      mountList.Free;
    end;
    FindVolumeClose(volume);

    if formatDone or (numVolumes > 0) then break;
    if not mustFormat and ((GetTickCount() - start_time) > 3000) then
    begin
      DebugLog('No volumes attached. Disk could be offline or not partitioned.',EVENTLOG_ERROR_TYPE);
      break;
    end;

    //printf("Volume not yet attached, waiting... %c\r", NextWaitChar(&wait_char));
    DebugLog('Volume not yet attached, waiting 200 msec');
    Sleep(200);
  end;
  LoadRamDisk(config);
  Result:=True;
end;

end.
