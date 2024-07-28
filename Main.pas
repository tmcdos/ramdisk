unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, TntStdCtrls;

type
  TfrmUI = class(TForm)
    vdSize: TLabeledEdit;
    radioMB: TRadioButton;
    radioGB: TRadioButton;
    txtDrive: TLabel;
    comboLetter: TComboBox;
    chkTemp: TCheckBox;
    btnUnmount: TButton;
    txtContent: TLabel;
    btnLoad: TButton;
    chkSync: TCheckBox;
    grpSync: TGroupBox;
    chkDelete: TCheckBox;
    btnSave: TButton;
    btnApply: TButton;
    btnQuit: TButton;
    grpRAM: TGroupBox;
    lamp: TShape;
    txtSize: TLabel;
    editFolder: TTntEdit;
    memoIgnore: TTntMemo;
    btnInstall: TButton;
    btnUninstall: TButton;
    procedure btnApplyClick(Sender: TObject);
    procedure btnInstallClick(Sender: TObject);
    procedure btnLoadClick(Sender: TObject);
    procedure btnQuitClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnUninstallClick(Sender: TObject);
    procedure btnUnmountClick(Sender: TObject);
    procedure chkSyncClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    Procedure UpdateDismounted;
    Procedure UpdateMounted;
    Procedure UpdateLetters;
    Procedure SaveSettings;
    Procedure LoadSettings;
  public
    { Public declarations }
  end;

var
  frmUI: TfrmUI;

implementation

{$R *.dfm}

Uses Definitions,RamDetect,RamRemove,RamCreate,Types,StrUtils,WinSvc,TntRegistry,TntFileCtrl,TntSysUtils;

const
  serviceName = 'ArsenalRamDisk';

Var
  ramDiskConfig: TRamDisk;

procedure TfrmUI.btnApplyClick(Sender: TObject);
var
  msg:String;
begin
  SaveSettings;
  If not TryStrToInt64(vdSize.Text,ramDiskConfig.size) Then MessageDlg('Invalid disk size',mtError,[mbOK],0)
  else if comboLetter.Items.Count = 0 Then MessageDlg('No free drive letters',mtError,[mbOK],0)
  Else
  begin
    if ramDiskConfig.letter <> #0 Then btnUnmount.Click(); // First unmount
    If comboLetter.ItemIndex <> -1 Then ramDiskConfig.letter:=comboLetter.Items[comboLetter.ItemIndex][1]
    Else ramDiskConfig.letter:='#'; // use first free letter
    ramDiskConfig.size:=ramDiskConfig.size shl 20;
    If radioGB.Checked then ramDiskConfig.size:=ramDiskConfig.size shl 10;
    try
      ramDiskConfig.persistentFolder:=editFolder.Text;
      ramDiskConfig.useTemp:=chkTemp.Checked;
      if CreateRamDisk(ramDiskConfig,True) Then
      Begin
        UpdateLetters;
        UpdateMounted;
      end;
    except
      On E:ERamDiskError do
      Begin
        msg:=decodeException(E.ArsenalCode);
        If msg<>'' then MessageDlg(msg,mtError,[mbOK],0);
      end;
    else raise;
    End;
  end;
end;

procedure TfrmUI.btnLoadClick(Sender: TObject);
var
  dir,root:WideString;
begin
  dir:='';
  root:=editFolder.Text;
  if root = '' then root:='::{20D04FE0-3AEA-1069-A2D8-08002B30309D}';
  if WideSelectDirectory('Select folder to init the RAM-disk',root,dir) then editFolder.Text:=dir;
end;

procedure TfrmUI.btnQuitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmUI.btnSaveClick(Sender: TObject);
begin
  SaveSettings;
end;

procedure TfrmUI.btnUnmountClick(Sender: TObject);
var
  msg:String;
begin
  try
    ramDiskConfig.persistentFolder:=editFolder.Text;
    ramDiskConfig.excludedList:=memoIgnore.Text;
    ramDiskConfig.deleteOld:=chkDelete.Checked;
    ramDiskConfig.synchronize:=chkSync.Checked;
    if DetachRamDisk(ramDiskConfig) then
    Begin
      UpdateDismounted;
    end;
  Except
    On E:ERamDiskError do
    Begin
      msg:=decodeException(E.ArsenalCode);
      If msg<>'' then MessageDlg(msg,mtError,[mbOK],0);
    end
  else raise;
  end;
end;

procedure TfrmUI.chkSyncClick(Sender: TObject);
begin
  grpSync.Enabled:=chkSync.Checked;
end;

procedure TfrmUI.FormCreate(Sender: TObject);
begin
  SetWindowLong(vdSize.Handle,GWL_STYLE,GetWindowLong(vdSize.Handle,GWL_STYLE) + ES_NUMBER);
end;

Procedure TfrmUI.LoadSettings;
var
  reg: TTntRegistry;
  diskSize: Int64;
Begin
  reg:=TTntRegistry.Create(KEY_READ);
  Try
    reg.RootKey:=HKEY_LOCAL_MACHINE;
    if Reg.OpenKey('\SYSTEM\CurrentControlSet\Services\'+serviceName, False) then
    begin
      If Reg.ValueExists('DiskSize') then
      Begin
        diskSize:=StrToInt64(reg.ReadString('DiskSize'));
        if (diskSize mod (1 Shl 30))<>0 then
        Begin
          vdSize.Text:=IntToStr(diskSize shr 20);
          radioMB.Checked:=True;
          radioGB.Checked:=False;
        End
        else
        Begin
          vdSize.Text:=IntToStr(diskSize shr 30);
          radioMB.Checked:=False;
          radioGB.Checked:=True;
        end;
      end;
      if reg.ValueExists('DriveLetter') Then
      Begin
        comboLetter.ItemIndex:=comboLetter.Items.IndexOf(reg.ReadString('DriveLetter'));
      end;
      if reg.ValueExists('LoadContent') Then
      Begin
        editFolder.Text:=reg.ReadString('LoadContent');
      end;
      if reg.ValueExists('ExcludeFolders') Then
      Begin
        memoIgnore.Lines.Text:=reg.ReadString('ExcludeFolders');
      end;
      if reg.ValueExists('UseTempFolder') Then
      Begin
        chkTemp.Checked:=reg.ReadBool('UseTempFolder');
      end;
      if reg.ValueExists('SyncContent') Then
      Begin
        chkSync.Checked:=reg.ReadBool('SyncContent');
        grpSync.Enabled:=chkSync.Checked;
      end;
      if reg.ValueExists('DeleteOld') Then
      Begin
        chkDelete.Checked:=reg.ReadBool('DeleteOld');
      end;
      Reg.CloseKey;
    end;
  Finally
    reg.Free;
  End;
end;

Procedure TfrmUI.SaveSettings;
var
  reg: TTntRegistry;
  diskSize: Int64;
  i:Integer;
  s:WideString;
Begin
  reg:=TTntRegistry.Create(KEY_WRITE);
  Try
    reg.RootKey:=HKEY_LOCAL_MACHINE;
    if Reg.OpenKey('\SYSTEM\CurrentControlSet\Services\'+serviceName, True) then
    begin
      diskSize:=StrToInt64(vdSize.Text);
      If radioMB.Checked then diskSize:=diskSize Shl 20 Else diskSize:=diskSize shl 30;
      i:=0;
      while i<memoIgnore.Lines.Count Do
      Begin
        s:=Trim(memoIgnore.Lines[i]);
        If s[2]=':' then s:=Copy(s,4,MaxInt);
        If (s='')or(WidePosEx('\',s)>0)or(WidePosEx('/',s)>0) then memoIgnore.Lines.Delete(i)
        else
        Begin
          memoIgnore.Lines[i]:=s;
          Inc(i);
        end;
      end;
      reg.WriteString('DiskSize',IntToStr(diskSize));
      reg.WriteString('DriveLetter',comboLetter.Text);
      reg.WriteString('LoadContent',editFolder.Text);
      reg.WriteString('ExcludeFolders',memoIgnore.Lines.Text);
      reg.WriteBool('UseTempFolder',chkTemp.Checked);
      reg.WriteBool('SyncContent',chkSync.Checked);
      reg.WriteBool('DeleteOld',chkDelete.Checked);
      Reg.CloseKey;
    end;
  Finally
    reg.Free;
  End;
end;

procedure TfrmUI.UpdateLetters;
var
  freeLetters: TAssignedDrives;
  d: Char;
Begin
  // get assigned drive letters and then compute the list of unassigned letters
  freeLetters:=GetFreeDriveList;
  comboLetter.Clear;
  For d:='C' To 'Z' Do // skip floppy drives
  Begin
    If d in freeLetters Then comboLetter.Items.Add(d);
  end;
end;

procedure TfrmUI.UpdateMounted;
Begin
  if ramDiskConfig.letter <> #0 then comboLetter.Items.Add(ramDiskConfig.letter);
  comboLetter.ItemIndex:=comboLetter.Items.IndexOf(ramDiskConfig.letter);
  if (ramDiskConfig.size mod (1 Shl 30)) <> 0 then txtSize.Caption:=IntToStr(ramDiskConfig.size Shr 20) + ' MB'
  else txtSize.Caption:=IntToStr(ramDiskConfig.size Shr 30) + ' GB';
  btnUnmount.Enabled:=True;
  lamp.Brush.Color:=clLime;
end;

procedure TfrmUI.UpdateDismounted;
Begin
  ramDiskConfig.letter:=#0;
  ramDiskConfig.size:=0;
  ramDiskConfig.diskNumber:=-1;
  txtSize.Caption:='';
  lamp.Brush.Color:=clRed;
  btnUnmount.Enabled:=False;
end;

function ServiceGetStatus(sMachine, sService: string):DWord;
var
  h_manager,h_svc: SC_Handle;
  service_status: TServiceStatus;
  hStat: DWord;
begin
  hStat := 0;
  h_manager := OpenSCManager(PChar(sMachine) ,Nil, SC_MANAGER_CONNECT);

  if h_manager <> 0 then
  begin
    h_svc := OpenService(h_manager,PChar(sService), SERVICE_QUERY_STATUS);
    if h_svc <> 0 then
    begin
      if(QueryServiceStatus(h_svc, service_status)) then hStat := service_status.dwCurrentState;
      CloseServiceHandle(h_svc);
    end;
    CloseServiceHandle(h_manager);
  end;
  Result := hStat;
end;

procedure TfrmUI.btnInstallClick(Sender: TObject);
begin
  if WinExec('RamService /install',SW_HIDE) < 32 then MessageDlg('Error occurred - probably RamService.exe is missing',mtError,[mbOK],0)
  Else
  Begin
    btnInstall.Enabled:=False;
    btnUninstall.Enabled:=True;
  end;
end;

procedure TfrmUI.btnUninstallClick(Sender: TObject);
begin
  if WinExec('RamService /uninstall',SW_HIDE) < 32 then MessageDlg('Error occurred - probably RamService.exe is missing',mtError,[mbOK],0)
  Else
  Begin
    btnInstall.Enabled:=True;
    btnUninstall.Enabled:=False;
  end;
end;

procedure TfrmUI.FormShow(Sender: TObject);
Var
  srvStatus:DWORD;
  msg:String;
begin
  // aim -a -s 50M -t vm -m x:
  UpdateLetters;
  // check service status
  srvStatus:=ServiceGetStatus('',serviceName);
  btnInstall.Enabled:=srvStatus = 0;
  btnUninstall.Enabled:=srvStatus <> 0;
  /// TODO - react on dynamic drive changes (attaching/detaching a device)
  LoadSettings;
  try
    if GetRamDisk(ramDiskConfig) Then UpdateMounted
    Else UpdateDismounted;
  Except
    On E:ERamDiskError do
    Begin
      msg:=decodeException(E.ArsenalCode);
      If msg<>'' then MessageDlg(msg,mtError,[mbOK],0);
    end
  else raise;
  End;
end;

end.
