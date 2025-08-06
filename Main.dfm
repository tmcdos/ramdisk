object frmUI: TfrmUI
  Left = 263
  Top = 110
  ActiveControl = vdSize
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'RAMdisk UI'
  ClientHeight = 522
  ClientWidth = 303
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object txtDrive: TLabel
    Left = 40
    Top = 72
    Width = 58
    Height = 13
    Caption = 'Drive letter:'
  end
  object txtContent: TLabel
    Left = 14
    Top = 132
    Width = 119
    Height = 13
    Caption = 'Load content from folder'
  end
  object vdSize: TLabeledEdit
    Left = 36
    Top = 24
    Width = 61
    Height = 21
    Hint = 'Minimum 3MB'
    EditLabel.Width = 23
    EditLabel.Height = 13
    EditLabel.Caption = 'Size:'
    LabelPosition = lpLeft
    MaxLength = 4
    ParentShowHint = False
    ShowHint = True
    TabOrder = 0
  end
  object radioMB: TRadioButton
    Left = 108
    Top = 16
    Width = 57
    Height = 17
    Caption = 'MB'
    Checked = True
    TabOrder = 1
    TabStop = True
  end
  object radioGB: TRadioButton
    Left = 108
    Top = 40
    Width = 57
    Height = 17
    Caption = 'GB'
    TabOrder = 2
  end
  object comboLetter: TComboBox
    Left = 108
    Top = 68
    Width = 41
    Height = 21
    Style = csDropDownList
    ItemHeight = 13
    Sorted = True
    TabOrder = 3
  end
  object chkTemp: TCheckBox
    Left = 12
    Top = 100
    Width = 273
    Height = 17
    Caption = 'Create TEMP folder and set environment variables'
    TabOrder = 4
  end
  object btnLoad: TButton
    Left = 248
    Top = 150
    Width = 32
    Height = 25
    Caption = '...'
    TabOrder = 6
    OnClick = btnLoadClick
  end
  object chkSync: TCheckBox
    Left = 12
    Top = 184
    Width = 225
    Height = 17
    Hint = 
      'Copy RAM-disk contents back to the '#13#10'same folder where it was in' +
      'itialized from.'
    Caption = 'Synchronize at shutdown'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 7
    OnClick = chkSyncClick
  end
  object grpSync: TGroupBox
    Left = 12
    Top = 212
    Width = 274
    Height = 177
    Caption = ' Do not persist these folders '
    Enabled = False
    TabOrder = 8
    object txtExcludeHelp: TLabel
      Left = 6
      Top = 18
      Width = 260
      Height = 13
      Caption = 'No nesting - only root folders and no wildcards'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object chkDelete: TCheckBox
      Left = 8
      Top = 40
      Width = 249
      Height = 17
      Hint = 
        'Delete files and folders from the INIT '#13#10'folder that are not pre' +
        'sent on the RAM-disk.'
      Caption = 'Delete data removed from RAMdisk'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
    end
    object memoIgnore: TTntMemo
      Left = 2
      Top = 68
      Width = 270
      Height = 107
      Hint = 
        'One folder per line,'#13#10'no wildcards, no subfolders,'#13#10'no drive let' +
        'ter - folders are'#13#10'relative to the root of RAM-disk'
      Align = alBottom
      Anchors = [akLeft, akTop, akRight, akBottom]
      HideSelection = False
      ParentShowHint = False
      ScrollBars = ssBoth
      ShowHint = True
      TabOrder = 1
    end
  end
  object btnSave: TButton
    Left = 16
    Top = 398
    Width = 125
    Height = 48
    Caption = 'Save now - apply on reboot'
    TabOrder = 9
    WordWrap = True
    OnClick = btnSaveClick
  end
  object btnApply: TButton
    Left = 160
    Top = 398
    Width = 125
    Height = 48
    Caption = 'Save and apply now'
    TabOrder = 10
    WordWrap = True
    OnClick = btnApplyClick
  end
  object btnQuit: TButton
    Left = 104
    Top = 489
    Width = 101
    Height = 28
    Caption = 'Quit'
    TabOrder = 11
    OnClick = btnQuitClick
  end
  object grpRAM: TGroupBox
    Left = 176
    Top = 12
    Width = 105
    Height = 77
    Caption = ' Active '
    TabOrder = 12
    object lamp: TShape
      Left = 8
      Top = 48
      Width = 16
      Height = 16
      Brush.Color = clLime
      Shape = stCircle
    end
    object txtSize: TLabel
      Left = 12
      Top = 16
      Width = 81
      Height = 16
      Alignment = taCenter
      AutoSize = False
      ShowAccelChar = False
      Layout = tlCenter
    end
    object btnUnmount: TButton
      Left = 32
      Top = 44
      Width = 67
      Height = 25
      Caption = 'Unmount'
      Enabled = False
      TabOrder = 0
      OnClick = btnUnmountClick
    end
  end
  object editFolder: TTntEdit
    Left = 12
    Top = 152
    Width = 229
    Height = 21
    Hint = 
      'If you select a folder - its entire content will be'#13#10'copied to t' +
      'he RAM-disk. Symlinks are recognized.'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 5
  end
  object btnInstall: TButton
    Left = 16
    Top = 454
    Width = 125
    Height = 28
    Caption = 'Install service'
    TabOrder = 13
    OnClick = btnInstallClick
  end
  object btnUninstall: TButton
    Left = 160
    Top = 454
    Width = 125
    Height = 28
    Caption = 'Uninstall service'
    TabOrder = 14
    OnClick = btnUninstallClick
  end
end
