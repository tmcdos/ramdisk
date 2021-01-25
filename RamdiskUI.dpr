program RamdiskUI;

{$R 'manifest.res' 'manifest.rc'}

uses
  Forms,
  Main in 'Main.pas' {frmUI};
{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'RAMdisk';
  Application.CreateForm(TfrmUI, frmUI);
  Application.Run;
end.
