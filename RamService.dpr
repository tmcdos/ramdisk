program RamService;

{$R 'manifest.res' 'manifest.rc'}
{$DEFINE RAMDISK_SVC}

uses
  SvcMgr,
  SrvMain in 'SrvMain.pas' {ArsenalRamDisk: TServiceArsenal};

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'RamDisk service';
  Application.CreateForm(TArsenalRamDisk, ArsenalRamDisk);
  Application.Run;
end.
