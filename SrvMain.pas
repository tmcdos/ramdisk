unit SrvMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs;

type
  TStartThread = class(TThread)
  protected
    procedure Execute; override;
  end;
  TStopThread = class(TThread)
  protected
    procedure Execute; override;
  end;

  TArsenalRamDisk = class(TService)
    procedure ServiceAfterInstall(Sender: TService);
    procedure ServiceExecute(Sender: TService);
    procedure ServiceShutdown(Sender: TService);
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
  private
    { Private declarations }
    FStartThread: TStartThread;
    FStopThread: TStopThread;
  public
    { Public declarations }
    function GetServiceController: TServiceController; override;
  end;

var
  ArsenalRamDisk: TArsenalRamDisk;

implementation

{$R *.DFM}

Uses TntRegistry,Definitions,RamCreate,RamRemove;

Var
  config:TRamDisk;

procedure TStartThread.Execute;
Begin
  Inherited;
  try
    if CreateRamDisk(config,False) Then
    begin
      ReturnValue:=1;
      DebugLog('RamDisk service was started');
    end;
  except
    On E:ERamDiskError do
    Begin
      ReturnValue:=-2;
      DebugLog('Service could not create RAM-disk, error = ' + decodeException(E.ArsenalCode));
    End;
    On E:Exception do
    Begin
      ReturnValue:=-2;
      DebugLog('Exception in service start = ' + E.Message);
    end;
  End;
end;

procedure TStopThread.Execute;
begin
  inherited;
  DetachRamDisk(config);
  ReturnValue:=1;
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
  while not Terminated do ServiceThread.ProcessRequests(True);
end;

procedure TArsenalRamDisk.ServiceShutdown(Sender: TService);
begin
  DebugLog('RamDisk service initiated shutdown');
  if FStopThread = nil then FStopThread := TStopThread.Create(False);
  While not FStopThread.Terminated Do
  Begin
    ReportStatus;
    Sleep(1000);
  end;
  FStopThread.Free;
  FStartThread.Free;
end;

procedure TArsenalRamDisk.ServiceStart(Sender: TService; var Started: Boolean);
begin
  DebugLog('RamDisk service is starting');
  LoadSettings;
  Started:=True;
  if (config.size<>0) then
  Begin
    If FStartThread = Nil then FStartThread := TStartThread.Create(False) Else FStartThread.Execute;
    DebugLog('RamDisk service was started');
  end;
end;

procedure TArsenalRamDisk.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  DebugLog('RamDisk service is being stopped');
  if config.letter <> #0 then
  Begin
    If FStopThread = Nil then FStopThread := TStopThread.Create(False)
    Else FStopThread.Execute;
    While not FStopThread.Terminated do
    Begin
      ReportStatus;
      Sleep(1000);
    end;
    if FStartThread.ReturnValue > 0 Then DebugLog('RamDisk service was stopped');
    Stopped:=True;
  end
  Else Stopped:=True;
end;

end.
