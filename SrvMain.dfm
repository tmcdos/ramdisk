object ArsenalRamDisk: TArsenalRamDisk
  OldCreateOrder = False
  AllowPause = False
  DisplayName = 'Arsenal RAM-disk'
  WaitHint = 8000
  AfterInstall = ServiceAfterInstall
  OnExecute = ServiceExecute
  OnShutdown = ServiceShutdown
  OnStart = ServiceStart
  OnStop = ServiceStop
  Left = 263
  Top = 110
  Height = 150
  Width = 215
end
