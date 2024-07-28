unit SrvMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs;

type
  TArsenalRamDisk = class(TService)
    procedure ServiceAfterInstall(Sender: TService);
    procedure ServiceExecute(Sender: TService);
    procedure ServiceShutdown(Sender: TService);
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
  private
    { Private declarations }
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  ArsenalRamDisk: TArsenalRamDisk;

implementation

{$R *.DFM}

Uses TntRegistry,Definitions,RamCreate,RamRemove;

Var
  config:TRamDisk;

procedure LoadSettings;
var
  reg: TTntRegistry;
Begin
  reg:=TTntRegistry.Create(KEY_READ);
  Try
    OutputDebugString('Reading settings from registry');
    reg.RootKey:=HKEY_LOCAL_MACHINE;
    if Reg.OpenKey('SYSTEM\CurrentControlSet\Services\ArsenalRamDisk', False) then
    begin
      If Reg.ValueExists('DiskSize') then
      Begin
        config.size:=StrToInt64(reg.ReadString('DiskSize'));
        OutputDebugString(PAnsiChar(Format('Reading DiskSize = %u',[config.size])));
      end;
      if reg.ValueExists('DriveLetter') Then
      Begin
        config.letter:=Char(reg.ReadString('DriveLetter')[1]);
        OutputDebugString(PAnsiChar(Format('Reading DriveLetter = %s',[config.letter])));
      end;
      if reg.ValueExists('LoadContent') Then
      Begin
        config.persistentFolder:=reg.ReadString('LoadContent');
        OutputDebugStringW(PWideChar(WideFormat('Reading LoadContent = %s',[config.persistentFolder])));
      end;
      if reg.ValueExists('ExcludeFolders') Then
      Begin
        config.excludedList:=reg.ReadString('ExcludeFolders');
        OutputDebugStringW(PWideChar(WideFormat('Reading ExcludeFolders = %s',[config.excludedList])));
      end;
      if reg.ValueExists('UseTempFolder') Then
      Begin
        config.useTemp:=reg.ReadBool('UseTempFolder');
        OutputDebugString(PAnsiChar(Format('Reading UseTempFolder = %d',[Ord(config.useTemp)])));
      end;
      if reg.ValueExists('SyncContent') Then
      Begin
        config.synchronize:=reg.ReadBool('SyncContent');
        OutputDebugString(PAnsiChar(Format('Reading SyncContent = %d',[Ord(config.synchronize)])));
      end;
      if reg.ValueExists('DeleteOld') Then
      Begin
        config.deleteOld:=reg.ReadBool('DeleteOld');
        OutputDebugString(PAnsiChar(Format('Reading DeleteOld = %d',[Ord(config.deleteOld)])));
      end;
      Reg.CloseKey;
      OutputDebugString('All settings from registry were loaded');
    end;
  Finally
    reg.Free;
  End;
end;

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  ArsenalRamDisk.Controller(CtrlCode);
end;

function TArsenalRamDisk.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TArsenalRamDisk.ServiceAfterInstall(Sender: TService);
var
  reg:TTntRegistry;
begin
  Reg := TTntRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKey('\SYSTEM\CurrentControlSet\Services\' + Name, false) then
    begin
      Reg.WriteString('Description', DisplayName);
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;

end;

procedure TArsenalRamDisk.ServiceExecute(Sender: TService);
begin
  while not Terminated do ServiceThread.ProcessRequests(True);
end;

procedure TArsenalRamDisk.ServiceShutdown(Sender: TService);
begin
  OutputDebugString('RamDisk service initiated shutdown');
  DetachRamDisk(config);
end;

procedure TArsenalRamDisk.ServiceStart(Sender: TService; var Started: Boolean);
begin
  OutputDebugString('RamDisk service was started');
  LoadSettings;
  if (config.size<>0) then
  try
    if CreateRamDisk(config,False) Then Started:=True;
  except
    On E:ERamDiskError do decodeException(E.ArsenalCode);
    On E:Exception do OutputDebugString(PAnsiChar(E.Message));
  End;
end;

procedure TArsenalRamDisk.ServiceStop(Sender: TService; var Stopped: Boolean);
var
  msg:string;
begin
  OutputDebugString('RamDisk service is being stopped');
  if config.letter <> #0 then
  begin
    OutputDebugString('Trying to unmount RamDisk');
    try
      If DetachRamDisk(config) then Stopped:=True;
    except
      On E:ERamDiskError do
      Begin
        msg:=decodeException(E.ArsenalCode);
        If msg<>'' then OutputDebugString(PAnsiChar(msg));
      end;
      On E:Exception Do OutputDebugString(PAnsiChar(E.Message));
    end;
  End
  Else Stopped:=True;
end;

end.
