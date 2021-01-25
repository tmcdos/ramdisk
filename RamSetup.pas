unit RamSetup;

interface

Function ImScsiRescanScsiAdapterAsync(AsyncFlag:Boolean):THandle;

implementation

uses Windows,SysUtils,Classes;

const
  CfgMgrDllName = 'cfgmgr32.dll';
  SetupApiModuleName = 'SETUPAPI.DLL';
  WT_EXECUTEINPERSISTENTTHREAD = $00000080;
  CR_SUCCESS                  = $00000000;
  CM_GETIDLIST_FILTER_SERVICE = $00000002;

type
  DEVINST = DWORD;
  DEVINSTID_A = PAnsiChar;
  RETURN_TYPE = DWORD;
  CONFIGRET = RETURN_TYPE;
  TThreadStartFunc = Function (Event:THandle):DWORD; Stdcall;

function QueueUserWorkItem (func: TThreadStartFunc; Context: Pointer; Flags: DWORD): BOOL; stdcall; external kernel32;
function CM_Locate_DevNode(var dnDevInst: DEVINST; pDeviceID: DEVINSTID_A; ulFlags: ULONG): CONFIGRET; stdcall; external CfgMgrDllName name 'CM_Locate_DevNodeA';
function CM_Reenumerate_DevNode(var dnDevInst: DEVINST; ulFlags: ULONG): CONFIGRET; stdcall; external CfgMgrDllName;
function CM_Get_Device_ID_List(const pszFilter: PAnsiChar; Buffer: PAnsiChar; BufferLen: ULONG; ulFlags: ULONG): CONFIGRET; stdcall; External CfgMgrDllName name 'CM_Get_Device_ID_ListA';
function CM_Get_Device_ID_List_Size(var ulLen: ULONG; const pszFilter: PAnsiChar; ulFlags: ULONG): CONFIGRET; stdcall; External CfgMgrDllName name 'CM_Get_Device_ID_List_SizeA';

Function ImScsiScanForHardwareChanges(rootid:DEVINSTID_A = Nil; flags:DWORD = 0):DWORD;
Var
  dev_inst: DEVINST;
  status: DWORD;
begin
  status := CM_Locate_DevNode(dev_inst, rootid, 0);
  if status <> CR_SUCCESS then
  begin
    OutputDebugString(PAnsiChar('Error scanning for hardware changes: $' + IntToHex(status,8)));
    Result:=status;
  end
  else Result:=CM_Reenumerate_DevNode(dev_inst, flags);
end;

Function ImScsiScanForHardwareChangesThread(Event:THandle):DWORD; Stdcall;
begin
  ImScsiScanForHardwareChanges;
  SetEvent(Event);
  Result:=0;
end;

function ImScsiAllocateDeviceInstanceListForService(service:string;var instances:PAnsiChar):Integer;
var
  length,status:DWORD;
Begin
  length:=0;
  Result:=0;
  status := CM_Get_Device_ID_List_Size(length, PAnsiChar(service), CM_GETIDLIST_FILTER_SERVICE);
  if status = CR_SUCCESS then
  begin
    instances := Pointer(LocalAlloc(LMEM_FIXED, sizeof(Char) * length));
    if Not Assigned(instances) then Exit;
    status := CM_Get_Device_ID_List(PAnsiChar(service), instances, length, CM_GETIDLIST_FILTER_SERVICE);
    if status <> CR_SUCCESS then
    begin
      LocalFree(Cardinal(instances));
      //ImScsiDebugMessage(L"Error enumerating instances for service %1!ws!: %2!#x!", service, status);
    End
    Else Result:=length;
  end;
end;

Function ImScsiRescanScsiAdapter:Boolean;
var
  i,length:Integer;
  hwinstances:PAnsiChar;
  status: DWORD;
Begin
  hwinstances := NIL;
  Result:=False;
  Try
    length:=ImScsiAllocateDeviceInstanceListForService('phdskmnt', hwinstances);
    if length <= 1 Then Exit;
    i:=0;
    while i < length do
    begin
      if hwinstances + i = '' Then Continue;
      status := ImScsiScanForHardwareChanges(hwinstances + i, 0);
      if status = CR_SUCCESS then Result:=True
      else
      begin
        // ImScsiDebugMessage(L"Rescanning of %1 failed: %2!#x!", hwinstances, status);
      end;
      Inc(i,1 + StrLen(hwinstances + i));
    end;
  Finally
    LocalFree(Cardinal(hwinstances));
  end;
end;

Function ImScsiRescanScsiAdapterThread(Event:THandle):DWORD; Stdcall;
begin
  ImScsiRescanScsiAdapter;
  SetEvent(Event);
  Result:=0;
end;

Function ImScsiRescanScsiAdapterAsync(AsyncFlag:Boolean):THandle;
begin
  Result := CreateEvent(NIL, TRUE, FALSE, NIL);
  if Result <> 0 then
  begin
    if AsyncFlag then
    begin
      if Not QueueUserWorkItem(ImScsiRescanScsiAdapterThread, Pointer(Result), WT_EXECUTEINPERSISTENTTHREAD) then
      begin
        CloseHandle(Result);
        Result:=0;
      end;
    end
    else ImScsiRescanScsiAdapterThread(Result);
  end;
end;

end.
