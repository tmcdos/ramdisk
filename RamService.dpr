program RamService;

{$R 'manifest.res' 'manifest.rc'}

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
