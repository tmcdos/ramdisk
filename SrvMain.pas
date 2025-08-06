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
    FShutdownThread: TThread;
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  ArsenalRamDisk: TArsenalRamDisk;

implementation

{$R *.DFM}

Uses TntRegistry,Definitions,RamCreate,RamRemove;

Type
  TShutdownThread = class(TThread)
  protected
    procedure Execute; override;
  end;

Var
  config:TRamDisk;

procedure TShutdownThread.Execute;
begin
  inherited;
  DetachRamDisk(config);
end;

procedure LoadSettings;
var
  reg: TTntRegistry;
Begin
  reg:=TTntRegistry.Create(KEY_READ);
  Try
    DebugLog('Reading settings from registry');
    reg.RootKey:=HKEY_LOCAL_MACHINE;
    if Reg.OpenKey('SYSTEM\CurrentControlSet\Services\ArsenalRamDisk', False) then
    begin
      If Reg.ValueExists('DiskSize') then
      Begin
        config.size:=StrToInt64(reg.ReadString('DiskSize'));
        DebugLog(Format('Reading DiskSize = %u',[config.size]));
      end;
      if reg.ValueExists('DriveLetter') Then
      Begin
        config.letter:=Char(reg.ReadString('DriveLetter')[1]);
        DebugLog(Format('Reading DriveLetter = %s',[config.letter]));
      end;
      if reg.ValueExists('LoadContent') Then
      Begin
        config.persistentFolder:=reg.ReadString('LoadContent');
        DebugLog(WideFormat('Reading LoadContent = %s',[config.persistentFolder]));
      end;
      if reg.ValueExists('ExcludeFolders') Then
      Begin
        config.excludedList:=reg.ReadString('ExcludeFolders');
        DebugLog(WideFormat('Reading ExcludeFolders = %s',[config.excludedList]));
      end;
      if reg.ValueExists('UseTempFolder') Then
      Begin
        config.useTemp:=reg.ReadBool('UseTempFolder');
        DebugLog(Format('Reading UseTempFolder = %d',[Ord(config.useTemp)]));
      end;
      if reg.ValueExists('SyncContent') Then
      Begin
        config.synchronize:=reg.ReadBool('SyncContent');
        DebugLog(Format('Reading SyncContent = %d',[Ord(config.synchronize)]));
      end;
      if reg.ValueExists('DeleteOld') Then
      Begin
        config.deleteOld:=reg.ReadBool('DeleteOld');
        DebugLog(Format('Reading DeleteOld = %d',[Ord(config.deleteOld)]));
      end;
      Reg.CloseKey;
      DebugLog('All settings from registry were loaded');
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
  while not Terminated do
  begin
    ServiceThread.ProcessRequests(True);
  end;
  if FShutdownThread <> nil then
  begin
    FShutdownThread.WaitFor;
  end;
end;

procedure TArsenalRamDisk.ServiceShutdown(Sender: TService);
begin
  DebugLog('RamDisk service initiated shutdown');
  if FShutdownThread = nil then
  begin
    FShutdownThread := TShutdownThread.Create(False);
    FShutdownThread.FreeOnTerminate := True;
  end;
  inherited;
end;

procedure TArsenalRamDisk.ServiceStart(Sender: TService; var Started: Boolean);
begin
  FShutdownThread := nil;
  DebugLog('RamDisk service was started');

  // Report that we are starting, with a 60 second timeout
  WaitHint := 60000;
  CheckPoint := 1;
  ReportStatus;

  LoadSettings;

  // Report progress
  CheckPoint := 2;
  ReportStatus;

  if (config.size<>0) then
  try
    if CreateRamDisk(config,False) Then Started:=True;
  except
    On E:ERamDiskError do DebugLog(decodeException(E.ArsenalCode));
    On E:Exception do DebugLog(E.Message);
  End;

  // Reset WaitHint
  WaitHint := 0;
end;

procedure TArsenalRamDisk.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  DebugLog('RamDisk service is being stopped');
  // Report that we are stopping, with a 60 second timeout
  WaitHint := 60000;
  CheckPoint := 1;
  ReportStatus;
  try
    if config.letter <> #0 then
    begin
      DebugLog('Trying to unmount RamDisk');
      if FShutdownThread = nil then
      begin
        FShutdownThread := TShutdownThread.Create(False);
        FShutdownThread.FreeOnTerminate := True;
      end;
    end
    Else Stopped:=True;
  finally
    inherited;
  end;
  // Reset WaitHint
  WaitHint := 0;
end;

end.
