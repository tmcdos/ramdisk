unit RamSync;

interface

Uses Definitions;

procedure LoadRamDisk(Var config:TRamDisk);
procedure SaveRamDisk(Var existing:TRamDisk);
procedure RestoreTempFolder(letter:WideChar);

implementation

uses SysUtils,Windows,TntRegistry,TntSysUtils,TntClasses,Junctions;

const
  DIR_ATTR = FILE_ATTRIBUTE_DIRECTORY or FILE_ATTRIBUTE_REPARSE_POINT;

type
  TStrArray = Array of WideString;
  TPathList = Array Of TStrArray;

procedure CopyTime(const src,dest:WideString);
var
  hDir:THandle;
  creationTime,accessTime,writeTime:TFileTime;
Begin
  hDir := CreateFileW(PWideChar(src), 0, FILE_SHARE_READ, NIL, OPEN_EXISTING, 0, 0);
  if hDir <> INVALID_HANDLE_VALUE Then
  begin
    GetFileTime(hDir,@creationTime,@accessTime,@writeTime);
    CloseHandle(hDir);
    hDir := CreateFileW(PWideChar(dest), GENERIC_WRITE, FILE_SHARE_WRITE, NIL, OPEN_EXISTING, 0, 0);
    if hDir <> INVALID_HANDLE_VALUE Then
    begin
      SetFileTime(hDir,@creationTime,@accessTime,@writeTime);
      CloseHandle(hDir);
    end;
  end;
end;

procedure TreeCopy(const src,dest:WideString);
var
  SR: TSearchRecW;
  junction,current,source: WideString;
Begin
  if WideFindFirst(src+'*.*',faAnyFile,SR)<>0 then Exit;
  repeat
    if (SR.Name <> '.') and (SR.Name <> '..') then
    begin
      //Application.ProcessMessages;
      current:=dest + SR.Name;
      source:=src + SR.Name;
      if (SR.Attr and faDirectory) <> 0 then
      begin
        WideCreateDir(current);
        // check for junction point
        if (GetFileAttributesW(PWideChar(source)) and DIR_ATTR) = DIR_ATTR Then
        Begin
          junction:=GetSymLinkTarget(source);
          If junction<>'' Then
          Begin
            CreateJunction(current, junction);
            CopyTime(source,current);
            Continue;
          end;
        end;
        TreeCopy(src + SR.Name + '\', dest + SR.Name + '\');
        CopyTime(source,current);
      end
      else
      Begin
        CopyFileW(PWideChar(source), PWideChar(current),False); // we don't care if it is a symlink
        CopyTime(source,current);
      End;
    end;
  Until WideFindNext(SR) <> 0;
  WideFindClose(SR);
end;

procedure DelTree(const path:String);
var
  SR: TSearchRec;
Begin
  if FindFirst(path+'*.*',faAnyFile,SR)<>0 then Exit;
  Repeat
    if (SR.Name <> '.') and (SR.Name <> '..') then
    begin
      if (SR.Attr and faDirectory) <> 0 then
      Begin
        DelTree(path + SR.Name + '\');
        RemoveDir(path + SR.Name);
      end
      else SysUtils.DeleteFile(path + SR.Name);
    end;
  Until FindNext(SR) <> 0;
  SysUtils.FindClose(SR);
  RemoveDir(path);
end;

Procedure LoadRamDisk(Var config:TRamDisk);
Var
  reg: TTntRegistry;
  tempDir:String;
Begin
  OutputDebugString('Configuring RAM-disk');
  If (config.persistentFolder<>'') And DirectoryExists(config.persistentFolder) Then
  Begin
    TreeCopy(WideIncludeTrailingPathDelimiter(config.persistentFolder),config.letter+':\');
    OutputDebugStringW(PWideChar('RAM-disk was populated with content from ' + config.persistentFolder));
  end;
  If config.useTemp Then
  Begin
    tempDir:=config.letter+':\TEMP';
    OutputDebugString(PAnsiChar('Configuring TEMP folder as ' + tempDir));
    if CreateDir(tempDir) Then
    Begin
      reg:=Nil;
      Try
        reg:=TTntRegistry.Create(KEY_WRITE);
        reg.RootKey:=HKEY_LOCAL_MACHINE;
        if Reg.OpenKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', True) then
        Begin
          reg.WriteExpandString('TMP',tempDir);
          reg.WriteExpandString('TEMP',tempDir);
          OutputDebugString('TMP and TEMP folders for all users were set');
        end;
        reg.CloseKey;

        reg.RootKey:=HKEY_CURRENT_USER;
        if Reg.OpenKey('Environment', True) then
        Begin
          reg.WriteExpandString('TMP',tempDir);
          reg.WriteExpandString('TEMP',tempDir);
          OutputDebugString('TMP and TEMP folders for the current user were set');
        end;
        reg.CloseKey;
      finally
        reg.Free;
      end;
    end;
  end;
  // remove $RECYCLE.BIN
  DelTree(config.letter+':\$RECYCLE.BIN\');
end;

procedure RestoreTempFolder(letter:WideChar);
Var
  reg: TTntRegistry;
  tmpFolder, tempFolder: String;
  tmp:WideString;
Begin
  reg:=Nil;
  try
    OutputDebugString('Switching to the default TEMP folder');
    reg:=TTntRegistry.Create(KEY_ALL_ACCESS);
    // read defaults
    reg.RootKey:=HKEY_USERS;
    if Reg.OpenKey('.DEFAULT\Environment', False) then
    Begin
      tmpFolder:=reg.ReadString('TMP');
      OutputDebugString(PAnsiChar(Format('Default TMP folder = %s',[tmpFolder])));
      tempFolder:=reg.ReadString('TEMP');
      OutputDebugString(PAnsiChar(Format('Default TEMP folder = %s',[tempFolder])));
    end;
    reg.CloseKey;
    // set active values
    reg.RootKey:=HKEY_LOCAL_MACHINE;
    if Reg.OpenKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', True) then
    Begin
      // restore default only if current setting was using the just unmounted Ramdisk
      tmp:=WideUpperCase(reg.ReadString('TMP'));
      If (tmp<>'')And(tmp[1] = letter) then
      Begin
        reg.WriteExpandString('TMP',tmpFolder);
        OutputDebugString('Restoring TMP folder for all users');
      End;
      tmp:=WideUpperCase(reg.ReadString('TEMP'));
      If (tmp<>'')and(tmp[1] = letter) then
      Begin
        reg.WriteExpandString('TEMP',tempFolder);
        OutputDebugString('Restoring TEMP folder for all users');
      End;
    end;
    reg.CloseKey;

    reg.RootKey:=HKEY_CURRENT_USER;
    if Reg.OpenKey('Environment', True) then
    Begin
      tmp:=WideUpperCase(reg.ReadString('TMP'));
      If (tmp<>'')and(tmp[1] = letter) then
      Begin
        reg.WriteExpandString('TMP',tmpFolder);
        OutputDebugString('Restoring TMP folder for the current user');
      end;
      tmp:=WideUpperCase(reg.ReadString('TEMP'));
      If (tmp<>'')and(tmp[1] = letter) then
      Begin
        reg.WriteExpandString('TEMP',tempFolder);
        OutputDebugString('Restoring TMP folder for the current user');
      end;
    end;
    reg.CloseKey;
  finally
    reg.Free;
  end;
end;

Function NewerSource(const src,dest:WideString):Boolean;
var
  hDir:THandle;
  srcCreation,srcAccess,srcModify,destCreation,destAccess,destModify:TFileTime;
Begin
  Result:=False;
  hDir := CreateFileW(PWideChar(src), 0, FILE_SHARE_READ, NIL, OPEN_EXISTING, 0, 0);
  if hDir <> INVALID_HANDLE_VALUE Then
  begin
    GetFileTime(hDir,@srcCreation,@srcAccess,@srcModify);
    CloseHandle(hDir);
    hDir := CreateFileW(PWideChar(dest), 0, FILE_SHARE_READ, NIL, OPEN_EXISTING, 0, 0);
    if hDir <> INVALID_HANDLE_VALUE Then
    begin
      GetFileTime(hDir,@destCreation,@destAccess,@destModify);
      CloseHandle(hDir);
      //-1, Source is older than Destination
      //0, Source is the same age as Destination
      //+1 Source is younger than Destination
      Result:=(CompareFileTime(srcModify,destModify)>0) or (CompareFileTime(srcCreation,destCreation)>0);
    end
    Else Result:=True; // destination probably does not exist
  end;
end;

// copy from RAM-disk to the persistent folder, excluding disabled paths
procedure TreeSave(const src,dest:WideString;excluded:TTntStringList);
var
  SR: TSearchRecW;
  junction,current,source: WideString;
Begin
  OutputDebugStringW(PWideChar(WideFormat('Now persisting folder %s',[src])));
  if WideFindFirst(src+'*.*',faAnyFile,SR)<>0 then Exit;
  repeat
    if (SR.Name <> '.') and (SR.Name <> '..') then
    begin
      //Application.ProcessMessages;
      current:=dest + SR.Name;
      source:=src + SR.Name;
      if (SR.Attr and faDirectory) <> 0 then
      begin
        if Assigned(excluded) And (excluded.IndexOf(WideUpperCase(SR.Name)) <> -1) then Continue;
        WideCreateDir(current);
        // check for junction point
        if (GetFileAttributesW(PWideChar(source)) and DIR_ATTR) = DIR_ATTR Then
        Begin
          junction:=GetSymLinkTarget(source);
          If junction<>'' Then
          Begin
            CreateJunction(current, junction);
            Continue;
          end;
        end;
        TreeSave(source + '\', current + '\',Nil);
      end
      else
      Begin
        if NewerSource(source,current) then CopyFileW(PWideChar(source), PWideChar(current),False); // overwrite existing
      End;
    end;
  Until WideFindNext(SR) <> 0;
  WideFindClose(SR);
end;

// delete from persistent folder items which are no longer present on the RAM-disk
procedure TreeDelete(const src,dest:WideString;excluded:TTntStringList);
var
  SR: TSearchRecW;
Begin
  OutputDebugStringW(PWideChar(WideFormat('Now removing folder %s',[src])));
  if WideFindFirst(src+'*.*',faAnyFile,SR)<>0 then Exit;
  repeat
    if (SR.Name <> '.') and (SR.Name <> '..') then
    begin
      //Application.ProcessMessages;
      if (SR.Attr and faDirectory) <> 0 then
      begin
        if Assigned(excluded) And (excluded.IndexOf(WideUpperCase(SR.Name)) <> -1) then Continue;
        TreeDelete(src + SR.Name + '\', dest + SR.Name + '\',Nil);
        if not DirectoryExists(dest + SR.Name) then WideRemoveDir(src + SR.Name);
      end
      else
      Begin
        if Not FileExists(dest + SR.Name) Then WideDeleteFile(src + SR.Name);
      End;
    end;
  Until WideFindNext(SR) <> 0;
  WideFindClose(SR);
end;

Procedure SplitPath(const path:WideString;var list:TStrArray);
var
  oldPos,newPos,k:Integer;
Begin
  SetLength(List,Length(path));
  k:=0;
  oldPos:=1;
  Repeat
    newPos:=WidePosEx('\',path,oldPos);
    if newPos=0 then list[k]:=Copy(path,oldPos,MaxInt)
    Else
    Begin
      list[k]:=Copy(path,oldPos,newPos);
      oldPos:=newPos;
    end;
    Inc(k);
  Until newPos=0;
  SetLength(list,k);
end;

Procedure SaveRamDisk(Var existing:TRamDisk);
var
  list:TTntStringList;
Begin
  OutputDebugString('Trying to persist RamDisk before unmount');
  if WideDirectoryExists(existing.persistentFolder) then
  Begin
    list:=Nil;
    try
      list:=TTntStringList.Create;
      list.Text:=WideUpperCase(existing.excludedList);
      list.Add('TEMP'); // always exclude TEMP folder and system folders
      list.Add('$RECYCLE.BIN');
      list.Add('System Volume Information');
      // first we persist RAM-disk, excluding disabled paths
      TreeSave(existing.letter+':\',WideIncludeTrailingPathDelimiter(existing.persistentFolder),list);
      OutputDebugString('RamDisk content was persisted');
      // then we delete the data that is not present on the RAM-disk
      if existing.deleteOld then
      Begin
        TreeDelete(WideIncludeTrailingPathDelimiter(existing.persistentFolder),existing.letter+':\',list);
        OutputDebugString('Obsolete data inside the synchronization folder was removed');
      End;
    Finally
      list.Free;
    end;
  End
  else OutputDebugStringW(PWideChar(WideFormat('Folder "%s" does not exist',[existing.persistentFolder])));
end;

end.
