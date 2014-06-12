unit SelLangForm;

{
  Inno Setup
  Copyright (C) 1997-2006 Jordan Russell
  Portions by Martijn Laan
  For conditions of distribution and use, see LICENSE.TXT.

  "Select Language" form

  $jrsoftware: issrc/Projects/SelLangForm.pas,v 1.18 2010/01/13 17:48:52 mlaan Exp $
}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  SetupForm, StdCtrls, ExtCtrls, NewStaticText, BitmapImage, BidiCtrls,Logging,ImgList, VCL.ComCtrls;

type
  TSelectLanguageForm = class(TSetupForm)
    SelectLabel: TNewStaticText;
    LangCombo: TNewComboBox;
    OKButton: TNewButton;
    CancelButton: TNewButton;
    IconBitmapImage: TBitmapImage;
  private
    { Private declarations }
  public
    procedure AppMessage(var Msg: TMsg; var Handled: Boolean);
   // procedure ColorComboDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
   // property OnDrawItem: TDrawItemEvent read GetDrawItem write SetDrawItem;
    { Public declarations }
    constructor Create(AOwner: TComponent); override;

  end;

var
  SelectLanguageForm: TSelectLanguageForm;

function AskForLanguage: Boolean;


implementation


uses
  Struct, Msgs, MsgIDs, Main;

{$R *.DFM}

const Colors: array[0..4] of TColor = (clAqua, clBlack, clRed, clWhite, clYellow) ;

var
  DefComboWndProcW, PrevComboWndProc: Pointer;


{
procedure TSelectLanguageForm.ColorComboDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  with Control as TComboBox do
  begin
    //draw filled rectangle
    Canvas.Brush.Color := TColor(Colors[Index mod 5]) ;
    Canvas.FillRect(Rect) ;
    //draw color name
    Canvas.TextOut(Rect.Left+5, Rect.Top, ColorToString(Colors[Index]));
  end;
end;  }

procedure TSelectLanguageForm.AppMessage(var Msg: TMsg; var Handled: Boolean);
var msgStr: String;
begin
  Handled := False;
  if (Msg.message = WM_SYSCOMMAND) and (msg.wParam = SC_CLOSE) then
  begin
    SelectLanguageForm.CancelButton.Click;
    Handled := true;
  end;
end;
function NewComboWndProc(Wnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
stdcall;
begin
  case Msg of
    { CB_ADDSTRING must pass to the default Unicode combo box window procedure
      since PrevWndProc is an ANSI window procedure and calling it would result
      in Unicode->ANSI conversion. Do the same for CB_GETLBTEXT(LEN) so that
      MSAA sees Unicode strings. }
    CB_ADDSTRING, CB_GETLBTEXT, CB_GETLBTEXTLEN:
      Result := CallWindowProcW(DefComboWndProcW, Wnd, Msg, wParam, lParam)
  else
    Result := CallWindowProcW(PrevComboWndProc, Wnd, Msg, wParam, lParam);
  end;
end;

function AskForLanguage: Boolean;
{ Creates and shows the "Select Language" dialog. Returns True and activates
  the selected language if the user clicks OK, or False otherwise. }
var
  I, J: Integer;
  LangEntry: PSetupLanguageEntry;
{$IFNDEF UNICODE}
  ClassInfo: TWndClassW;
  N: String;
{$ENDIF}
  PrevLang: String;
begin
  SelectLanguageForm := TSelectLanguageForm.Create(Application);
  try
{$IFNDEF UNICODE}
    { On NT, make it possible to add Unicode strings to our ANSI combo box by
      installing a window procedure with special CB_ADDSTRING handling.
      Yeah, this is a hack; it's too hard to create a native Unicode control
      in Delphi. }
    if Win32Platform = VER_PLATFORM_WIN32_NT then begin
      if GetClassInfoW(0, 'COMBOBOX', ClassInfo) then begin
        DefComboWndProcW := ClassInfo.lpfnWndProc;
        Longint(PrevComboWndProc) := SetWindowLongW(LangForm.LangCombo.Handle,
          GWL_WNDPROC, Longint(@NewComboWndProc));
      end;
    end;
{$ENDIF}

    for I := 0 to Entries[seLanguage].Count-1 do begin
      LangEntry := Entries[seLanguage][I];
{$IFDEF UNICODE}
      J := SelectLanguageForm.LangCombo.Items.Add(LangEntry.LanguageName);
      SelectLanguageForm.LangCombo.Items.Objects[J] := TObject(I);
{$ELSE}
      if (I = ActiveLanguage) or (LangEntry.LanguageCodePage = 0) or
         (LangEntry.LanguageCodePage = GetACP) or
         (shShowUndisplayableLanguages in SetupHeader.Options) then begin
        { Note: LanguageName is Unicode }
        N := LangEntry.LanguageName + #0#0;  { need wide null! }
        if Win32Platform = VER_PLATFORM_WIN32_NT then
          J := SendMessageW(LangForm.LangCombo.Handle, CB_ADDSTRING, 0,
            Longint(PWideChar(Pointer(N))))
        else
          J := LangForm.LangCombo.Items.Add(WideCharToString(PWideChar(Pointer(N))));
        if J >= 0 then
          LangForm.LangCombo.Items.Objects[J] := TObject(I);
      end;
{$ENDIF}
    end;

   { If there's multiple languages, select the previous language, if available }
    if (shUsePreviousLanguage in SetupHeader.Options) and
       (SelectLanguageForm.LangCombo.Items.Count > 1) then begin
      { do not localize or change the following string }
      PrevLang := GetPreviousData(ExpandConst(SetupHeader.AppId), 'Inno Setup: Language', '');

      if PrevLang <> '' then begin
        for I := 0 to Entries[seLanguage].Count-1 do begin
          if CompareText(PrevLang, PSetupLanguageEntry(Entries[seLanguage][I]).Name) = 0 then begin
            SelectLanguageForm.LangCombo.ItemIndex := SelectLanguageForm.LangCombo.Items.IndexOfObject(TObject(I));
            Break;
          end;
        end;
      end;
    end;

    { Select the active language if no previous language was selected }
    if SelectLanguageForm.LangCombo.ItemIndex = -1 then
      SelectLanguageForm.LangCombo.ItemIndex := SelectLanguageForm.LangCombo.Items.IndexOfObject(TObject(ActiveLanguage));

   // for i := 0 to TWinControl(SelectLanguageForm).ControlCount-1 do
  //  if( TWinControl(SelectLanguageForm).Controls[i].ClassName = 'TNewComboBox' )     then
  //  TNewComboBox(TWinControl(SelectLanguageForm).Controls[i]).OnDrawItem := SelectLanguageForm.ColorComboDrawItem;


    if SelectLanguageForm.LangCombo.Items.Count > 1 then
    begin
      if (CodeRunner <> nil) and CodeRunner.FunctionExists('InitializeLanguageDialog') then begin
        try
          CodeRunner.RunBooleanFunction('InitializeLanguageDialog', [''], False, True);
        except
          Log('InitializeLanguageDialog raised an exception.');
          Application.HandleException(nil);
        end;
      end;
      Result := (SelectLanguageForm.ShowModal = mrOK);
      if Result then
      begin
        I := SelectLanguageForm.LangCombo.ItemIndex;
        if I >= 0 then
          SetActiveLanguage(Integer(SelectLanguageForm.LangCombo.Items.Objects[I]));
      end;
    end
    else begin
      { Don't show language dialog if there aren't multiple languages to choose
        from, which can happen if only one language matches the user's code
        page. }
      Result := True;
    end;
  finally
    SelectLanguageForm.Free;
  end;
end;

constructor TSelectLanguageForm.Create(AOwner: TComponent);
var i:integer;
begin
  inherited;

  InitializeFont;
  Center;
  Caption := SetupMessages[msgSelectLanguageTitle];
  SelectLabel.Caption := SetupMessages[msgSelectLanguageLabel];
  OKButton.Caption := SetupMessages[msgButtonOK];
  CancelButton.Caption := SetupMessages[msgButtonCancel];
  LangCombo.Style := csDropDownList;
  //LangCombo.OnDrawItem := @TSelectLanguageForm.ColorComboDrawItem;
  //LangCombo.OnMeasureItem := @TSelectLanguageForm.LangComboMeasureItem;
  IconBitmapImage.Bitmap.Canvas.Brush.Color := Color;
  IconBitmapImage.Bitmap.Width := Application.Icon.Width;
  IconBitmapImage.Bitmap.Height := Application.Icon.Height;
  IconBitmapImage.Bitmap.Canvas.Draw(0, 0, Application.Icon);
  IconBitmapImage.Width := IconBitmapImage.Bitmap.Width;
  IconBitmapImage.Height := IconBitmapImage.Bitmap.Height;
end;

end.
