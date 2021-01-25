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
    reg.RootKey:=HKEY_LOCAL_MACHINE;
    if Reg.OpenKey('SYSTEM\CurrentControlSet\Services\ArsenalRamDisk', False) then
    begin
      If Reg.ValueExists('DiskSize') then
      Begin
        config.size:=StrToInt64(reg.ReadString('DiskSize'));
      end;
      if reg.ValueExists('DriveLetter') Then
      Begin
        config.letter:=Char(reg.ReadString('DriveLetter')[1]);
      end;
      if reg.ValueExists('LoadContent') Then
      Begin
        config.persistentFolder:=reg.ReadString('LoadContent');
      end;
      if reg.ValueExists('ExcludeFolders') Then
      Begin
        config.excludedList:=reg.ReadString('ExcludeFolders');
      end;
      if reg.ValueExists('UseTempFolder') Then
      Begin
        config.useTemp:=reg.ReadBool('UseTempFolder');
      end;
      if reg.ValueExists('SyncContent') Then
      Begin
        config.synchronize:=reg.ReadBool('SyncContent');
      end;
      if reg.ValueExists('DeleteOld') Then
      Begin
        config.deleteOld:=reg.ReadBool('DeleteOld');
      end;
      Reg.CloseKey;
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
  DetachRamDisk(config);
end;

procedure TArsenalRamDisk.ServiceStart(Sender: TService; var Started: Boolean);
begin
  LoadSettings;
  if (config.size<>0) then
    if CreateRamDisk(config,False) Then Started:=True;
end;

procedure TArsenalRamDisk.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  if config.letter <> #0 then
    If DetachRamDisk(config) then Stopped:=True;
end;

end.
