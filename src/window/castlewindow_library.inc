{
  Copyright 2004-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ CastleWindow backend that depends on external code to initialize
  OpenGL context.
  The external code must notify us about events by calling LibraryXxx methods,
  like TCastleWindowCustom.LibraryKeyDown or TCastleApplication.LibraryUpdate.
  The external code will get notified about our events using LibraryCallbackProc. }

{$ifdef read_interface_uses}
CTypes,
{$endif}

{$ifdef read_implementation_uses}
{$endif}

{$ifdef read_interface_types}
  TLibraryCallbackProc = function (eCode, iParam1, iParam2: cInt32; szParam: pcchar): cInt32; cdecl;
{$endif read_interface_types}

{$ifdef read_window_interface}
public
  { Only the library in src/library/castleengine.lpr uses this,
    to notify our window instance about various events. }
  procedure LibraryMouseWheel(const Scroll: Single; const Vertical: boolean);
{$endif read_window_interface}

{$ifdef read_application_interface}
private
  FScreenWidth, FScreenHeight: Integer;
  procedure WarningToCallback(Sender: TObject; const Category, S: string);
{$endif read_application_interface}

{$ifdef read_global_interface}

procedure CGEApp_Open(InitialWidth, InitialHeight: cUInt32; ApplicationConfigDirectory: PChar); cdecl;
procedure CGEApp_Close; cdecl;
procedure CGEApp_Resize(uiViewWidth, uiViewHeight: cUInt32); cdecl;
procedure CGEApp_Render; cdecl;
procedure CGEApp_SetLibraryCallbackProc(aProc: TLibraryCallbackProc); cdecl;
procedure CGEApp_Update; cdecl;
procedure CGEApp_MouseDown(X, Y: CInt32; bLeftBtn: cBool; FingerIndex: CInt32); cdecl;
procedure CGEApp_Motion(X, Y: CInt32; FingerIndex: CInt32); cdecl;
procedure CGEApp_MouseUp(X, Y: cInt32; bLeftBtn: cBool; FingerIndex: CInt32); cdecl;
procedure CGEApp_KeyDown(eKey: CInt32); cdecl;
procedure CGEApp_KeyUp(eKey: CInt32); cdecl;
procedure CGEApp_SetDpi(nDpi: cInt32); cdecl;

{$endif read_global_interface}

{$ifdef read_implementation}

const
  { Constants used for callbacks.
    Must be synchronized with constants in
    ../library/castlelib_dynloader.pas and
    ../library/castleengine.h }

  // library callback codes
  ecgelibNeedsDisplay          = 0;
  ecgelibSetMouseCursor        = 1;  // sends mouse cursor code in iParam1
  ecgelibNavigationTypeChanged = 2;  // sends ECgeNavigationType in iParam1 (see castleengine.h)
  ecgelibSetMousePosition      = 3;  // sends x in iParam1 and y in iParam2
  ecgelibWarning               = 4;  // sends message in szParam

  // mouse cursor codes
  ecgecursorDefault   = 0;
  ecgecursorWait      = 1;
  ecgecursorHand      = 2;
  ecgecursorText      = 3;
  ecgecursorNone      = 4;

var
  LibraryCallbackProc: TLibraryCallbackProc;

{ TCastleWindowCustom ---------------------------------------------------------- }

procedure TCastleWindowCustom.CreateBackend;
begin
  { Nothing to do. }
end;

procedure TCastleWindowCustom.OpenBackend;
begin
  { We just assume that we already have OpenGL context initialized.
    Nothing to do. }
  Application.OpenWindowsAdd(Self);
end;

procedure TCastleWindowCustom.SwapBuffers;
begin
  { The external code must take care of swapping buffers or doing glFlush. }
end;

procedure TCastleWindowCustom.CloseBackend;
begin
  { Nothing to do. }
end;

procedure TCastleWindowCustom.Invalidate;
begin
  if not Closed then Invalidated := true;
  if Assigned(LibraryCallbackProc) then  // tell the parent window to repaint
    LibraryCallbackProc(ecgelibNeedsDisplay, 0, 0, nil);
end;

procedure TCastleWindowCustom.BackendMakeCurrent;
begin
  { Nothing to do, we assume external code makes sure this is always
    the current OpenGL context. }
end;

procedure TCastleWindowCustom.SetCursor(const Value: TMouseCursor);
var
  CursorCode: cInt32;
begin
  if FCursor <> Value then
  begin
    FCursor := Value;

    if Assigned(LibraryCallbackProc) then
    begin
      // send to client
      case Value of
        mcNone, mcForceNone: CursorCode := ecgecursorNone;
        mcWait: CursorCode := ecgecursorWait;
        mcHand: CursorCode := ecgecursorHand;
        mcText: CursorCode := ecgecursorText;
        else CursorCode := ecgecursorDefault;
      end;
      LibraryCallbackProc(ecgelibSetMouseCursor, CursorCode, 0, nil);
    end;
  end;
end;

procedure TCastleWindowCustom.SetCaption(const Part: TCaptionPart; const Value: string);
begin
  FCaption[Part] := Value;
  if not Closed then
    { TODO: call LibraryCallbackProc to change caption to GetWholeCaption };
end;

procedure TCastleWindowCustom.SetCustomCursor(const Value: TRGBAlphaImage);
begin
  FCustomCursor := Value;
  { TODO: call LibraryCallbackProc with custom cursor shape, if you want this }
end;

procedure TCastleWindowCustom.SetMousePosition(const Value: TVector2);
begin
  if (not Closed) and Assigned(LibraryCallbackProc) then
    LibraryCallbackProc(ecgelibSetMousePosition, Floor(Value[0]), Floor(Value[1]), nil);
end;

procedure TCastleWindowCustom.SetFullScreen(const Value: boolean);
begin
  { TODO: call LibraryCallbackProc to switch fullscreen mode }
  FFullScreen := Value;
end;

{ LibraryXxx methods --------------------------------------------------------- }

procedure TCastleWindowCustom.LibraryMouseWheel(const Scroll: Single; const Vertical: boolean);
begin
  DoMouseWheel(Scroll, Vertical);
end;

{ TCastleWindowCustom menu ----------------------------------------------------
  Does not do anything, this backend cannot manage the menu bar. }

procedure TCastleWindowCustom.BackendMenuInitialize;
begin
end;

procedure TCastleWindowCustom.BackendMenuFinalize;
begin
end;

procedure TCastleWindowCustom.MenuUpdateCaption(Entry: TMenuEntryWithCaption);
begin
end;

procedure TCastleWindowCustom.MenuUpdateEnabled(Entry: TMenuEntryWithCaption);
begin
end;

procedure TCastleWindowCustom.MenuUpdateChecked(Entry: TMenuItemChecked);
begin
end;

function TCastleWindowCustom.MenuUpdateCheckedFast: boolean;
begin
  Result := false;
end;

procedure TCastleWindowCustom.MenuInsert(const Parent: TMenu;
  const ParentPosition: Integer; const Entry: TMenuEntry);
begin
end;

procedure TCastleWindowCustom.MenuDelete(const Parent: TMenu;
  const ParentPosition: Integer; const Entry: TMenuEntry);
begin
end;

function TCastleWindowCustom.RedirectKeyDownToMenuClick: boolean;
begin
  Result := true;
end;

{ TCastleWindowCustom dialogs ---------------------------------------------------------- }

{ Methods below should make native-looking dialog boxes. }

function TCastleWindowCustom.BackendFileDialog(const Title: string; var FileName: string;
  OpenDialog: boolean; FileFilters: TFileFilterList): boolean;
begin
  { TODO } Result := false;
end;

function TCastleWindowCustom.ColorDialog(var Color: TVector3): boolean;
begin
  { TODO } Result := false;
end;

procedure TCastleWindowCustom.MessageOK(const S: string; const MessageType: TWindowMessageType);
begin
  { TODO }
end;

function TCastleWindowCustom.MessageYesNo(const S: string;
  const MessageType: TWindowMessageType): boolean;
begin
  { TODO } Result := true;
end;

{ TCastleApplication ---------------------------------------------------------- }

procedure TCastleApplication.CreateBackend;
begin
end;

procedure TCastleApplication.DestroyBackend;
begin
end;

function TCastleApplication.ProcessMessage(WaitForMessage, WaitToLimitFPS: boolean): boolean;
begin
  Result := true;
end;

function TCastleApplication.ProcessAllMessages: boolean;
begin
  Result := ProcessMessage(false, false);
end;

procedure TCastleApplication.Run;
begin
  { for this CastleWindow backend, Run makes no sense, the external code
    must perform event loop }
end;

procedure TCastleApplication.QuitWhenNoOpenWindows;
begin
end;

function TCastleApplication.ScreenWidth: integer;
begin
  if FScreenWidth = 0 then
    WritelnWarning('Window', 'Application.ScreenWidth is queried before window is open, returns zero');
  Result := FScreenWidth;
end;

function TCastleApplication.ScreenHeight: integer;
begin
  if FScreenHeight = 0 then
    WritelnWarning('Window', 'Application.ScreenHeight is queried before window is open, returns zero');
  Result := FScreenHeight;
end;

function TCastleApplication.BackendName: string;
begin
  Result := 'Library (Using Existing OpenGL Context)';
end;

procedure TCastleApplication.WarningToCallback(Sender: TObject; const Category, S: string);
var
  sMsg: string;
  szBuffer: PChar;
  nBufSize: cardinal;
begin
  if Assigned(LibraryCallbackProc) then
  begin
    sMsg := Category + ': ' + S;
    nBufSize := Length(sMsg);
    szBuffer := StrAlloc(nBufSize+1);
    StrPLCopy(szBuffer, sMsg, nBufSize);
    LibraryCallbackProc(4 {ecgelibWarning}, 0, 0, pcchar(szBuffer));
    StrDispose(szBuffer);
  end;
end;

{ TCastleClipboard ----------------------------------------------------------- }

function TCastleClipboard.GetAsText: string;
begin
  { TODO }
  Result := '';
end;

procedure TCastleClipboard.SetAsText(const Value: string);
begin
  { TODO }
end;

{ TCastleWindow -------------------------------------------------------------- }

procedure TCastleWindow.NavigationInfoChanged;
var
  NavValue: integer;
begin
  // send info to parent app (to update navigation buttons state)
  if Assigned(LibraryCallbackProc) then
  begin
    case NavigationType of
      ntWalk     : NavValue := 0;
      ntFly      : NavValue := 1;
      ntExamine  : NavValue := 2;
      ntTurntable: NavValue := 3;
      ntNone     : NavValue := 4;
    end;
    LibraryCallbackProc(ecgelibNavigationTypeChanged, NavValue, 0, nil);
  end;
end;

{$define read_implementation}

procedure CheckMainWindow;
begin
  if Application.MainWindow = nil then
    raise Exception.Create('Application.MainWindow not set. One of the game units *must* set Application.MainWindow value in the "initialization" section');
end;

procedure CGEApp_Open(InitialWidth, InitialHeight: cUInt32; ApplicationConfigDirectory: PChar); cdecl;
begin
  try
    CheckMainWindow;

    // use given ApplicationConfigDirectory
    ApplicationConfigOverride := FilenameToURISafe(InclPathDelim(ApplicationConfigDirectory));

    { We have to set window sizes, and Application.Screen* sizes,
      before calling MainWindow.Open. That's because EventOpen may already
      look at these values.
      Yes, other CastleWindow backends also make sure that these are set early. }

    WritelnLog('Library received CGEApp_Open (window size: %d %d)', [InitialWidth, InitialHeight]);
    WritelnLog('Library set application config directory to URL: %s', [ApplicationConfigOverride]);
    Application.FScreenWidth := InitialWidth;
    Application.FScreenHeight := InitialHeight;
    //Window.FullScreen := true; // TODO: setting fullscreen should work like that 4 lines below. Also, should be default?
    Application.MainWindow.FLeft := 0;
    Application.MainWindow.FTop := 0;
    Application.MainWindow.FWidth := InitialWidth;
    Application.MainWindow.FHeight := InitialHeight;

    ApplicationProperties.OnWarning.Add(@Application.WarningToCallback);
    Application.MainWindow.Open;
  except
    on E: TObject do WritelnWarning('CGEApp_Open', ExceptMessage(E));
  end;
end;

procedure CGEApp_Close; cdecl;
begin
  try
    CheckMainWindow;
    Application.MainWindow.Close;
    ApplicationProperties.OnWarning.Remove(@Application.WarningToCallback);
  except
    on E: TObject do WritelnWarning('CGEApp_Close', ExceptMessage(E));
  end;
end;

procedure CGEApp_Resize(uiViewWidth, uiViewHeight: cUInt32); cdecl;
begin
  try
    CheckMainWindow;
    Application.FScreenWidth  := uiViewWidth;
    Application.FScreenHeight := uiViewHeight;
    Application.MainWindow.DoResize(uiViewWidth, uiViewHeight, false);
  except
    on E: TObject do WritelnWarning('CGEApp_Resize', ExceptMessage(E));
  end;
end;

procedure CGEApp_Render; cdecl;
begin
  try
    CheckMainWindow;
    Application.MainWindow.DoRender;
  except
    on E: TObject do WritelnWarning('CGEApp_Render', ExceptMessage(E));
  end;
end;

procedure CGEApp_SetLibraryCallbackProc(aProc: TLibraryCallbackProc); cdecl;
begin
  try
    LibraryCallbackProc := aProc;
  except
    on E: TObject do WritelnWarning('CGEApp_SetLibraryCallbackProc', ExceptMessage(E));
  end;
end;

procedure CGEApp_Update; cdecl;
begin
  try
    Application.DoApplicationUpdate;
    Application.FOpenWindows.DoUpdate;
    Application.MaybeDoTimer;
  except
    on E: TObject do WritelnWarning('CGEApp_Update', ExceptMessage(E));
  end;
end;

procedure CGEApp_MouseDown(X, Y: CInt32; bLeftBtn: cBool; FingerIndex: CInt32); cdecl;
var
  MyButton: TMouseButton;
begin
  try
    CheckMainWindow;
    if (bLeftBtn) then MyButton := mbLeft else MyButton := mbRight;
    Application.MainWindow.DoMouseDown(Vector2(X, Y), MyButton, FingerIndex);
  except
    on E: TObject do WritelnWarning('CGEApp_MouseDown', ExceptMessage(E));
  end;
end;

procedure CGEApp_Motion(X, Y: CInt32; FingerIndex: CInt32); cdecl;
var
  W: TCastleWindowCustom;
begin
  try
    CheckMainWindow;
    { TODO: using MousePressed as Pressed is only OK without multi-touch. }
    W := Application.MainWindow;
    W.DoMotion(InputMotion(W.FTouches.FingerIndexPosition[FingerIndex],
      Vector2(X, Y), W.MousePressed, FingerIndex));
  except
    on E: TObject do WritelnWarning('CGEApp_Motion', ExceptMessage(E));
  end;
end;

procedure CGEApp_MouseUp(X, Y: cInt32; bLeftBtn: cBool; FingerIndex: CInt32); cdecl;
var
  MyButton: TMouseButton;
begin
  try
    CheckMainWindow;
    if (bLeftBtn) then MyButton := mbLeft else MyButton := mbRight;
    Application.MainWindow.DoMouseUp(Vector2(X, Y), MyButton, FingerIndex);
  except
    on E: TObject do WritelnWarning('CGEApp_TouchUp', ExceptMessage(E));
  end;
end;

procedure CGEApp_KeyDown(eKey: CInt32); cdecl;
begin
  try
    CheckMainWindow;
    if TKey(eKey)<>K_None then
      // TODO: calculate sensible char
      Application.MainWindow.DoKeyDown(TKey(eKey), #0);
  except
    on E: TObject do WritelnWarning('CGEApp_KeyDown', ExceptMessage(E));
  end;
end;

procedure CGEApp_KeyUp(eKey: CInt32); cdecl;
begin
  try
    CheckMainWindow;
    if TKey(eKey)<>K_None then
      Application.MainWindow.DoKeyUp(TKey(eKey));
  except
    on E: TObject do WritelnWarning('CGEApp_KeyUp', ExceptMessage(E));
  end;
end;

procedure CGEApp_SetDpi(nDpi: cInt32); cdecl;
begin
  try
    CheckMainWindow;
    Application.MainWindow.Dpi := nDpi;
  except
    on E: TObject do WritelnWarning('CGEApp_Dpi', ExceptMessage(E));
  end;
end;

{$endif read_implementation}
