unit Dupline;

(* Duplicate Line Key Binding
  Copyright (c) 2001-2010 Cary Jensen, Jensen Data Systems, Inc.

  You may freely distribute this unit, so long as this comment
  section is retained, and no fee is charged for it.

  This key binding is provided as a demonstration of key bindings.

  To use this key binding, install it into a design-time package.

  Once installed, this key binding adds a Ctrl-Shift-D (duplicate line) function to the code editor.

  No warranty is intended or implied concerning the
  appropriateness of this code example for any other use. If you use
  this examples, or any part of it, you assume all responsibility
  for ensuring that it works as intended.

  For information concerning Delphi training, visit www.jensendatasystems.com.

*)

interface

uses
  SysUtils, Classes, Vcl.Dialogs, Vcl.Controls, Windows { for TShortcut } ,
{$IFDEF LINUX}
  QMenus, { for Shortcut }
{$ENDIF}
{$IFDEF MSWINDOWS}
  Vcl.Menus, { for Shortcut }
{$ENDIF}
  ToolsAPI;
// If ToolsAPI will not compile, add 'designide.dcp' to your Requires clause

procedure Register;

implementation

type
  TDupLineBinding = class(TNotifierObject, IOTAKeyboardBinding)
  private
  public
    procedure Dupline(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
    procedure AppendComment(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
    procedure CommentToggle(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
    { IOTAKeyboardBinding }
    function GetBindingType: TBindingType;
    function GetDisplayName: string;
    function GetName: string;
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
  end;

procedure Register;
begin
  (BorlandIDEServices as IOTAKeyboardServices).AddKeyboardBinding(TDupLineBinding.Create);
end;

{ TKeyBindingImpl }

function TDupLineBinding.GetBindingType: TBindingType;
begin
  Result := btPartial;
end;

function TDupLineBinding.GetDisplayName: string;
begin
  Result := 'Duplicate Line Binding';
end;

function TDupLineBinding.GetName: string;
begin
  Result := 'jdsi.dupline';
end;

procedure TDupLineBinding.BindKeyboard(const BindingServices: IOTAKeyBindingServices);
begin
  BindingServices.AddKeyBinding([Shortcut(Ord('D'), [ssShift, ssCtrl])], Dupline, nil);
  BindingServices.AddKeyBinding([Shortcut(Ord('C'), [ssShift, ssCtrl, ssAlt])], AppendComment, nil);
  BindingServices.AddKeyBinding([Shortcut(VK_F1, [ssCtrl, ssShift])], CommentToggle, nil);
  // Add additional key bindings here
end;

procedure TDupLineBinding.Dupline(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
var
  EditPosition: IOTAEditPosition;
  EditBlock: IOTAEditBlock;
  CurrentRow: Integer;
  CurrentRowEnd: Integer;
  BlockSize: Integer;
  IsAutoIndent: Boolean;
  CodeLine: string;
begin
  EditPosition := Context.EditBuffer.EditPosition;
  EditBlock := Context.EditBuffer.EditBlock;
  // Save the current edit block and edit position
  EditBlock.Save;
  EditPosition.Save;
  try
    // Store original cursor row
    CurrentRow := EditPosition.Row;
    // Length of the selected block (0 means no block)
    BlockSize := EditBlock.Size;
    // Store AutoIndent property
    IsAutoIndent := Context.EditBuffer.BufferOptions.AutoIndent;
    // Turn off AutoIndent, if necessary
    if IsAutoIndent then
      Context.EditBuffer.BufferOptions.AutoIndent := False;
    // If no block is selected, or the selected block is a single line,
    // then duplicate just the current line
    if (BlockSize = 0) or (EditBlock.StartingRow = EditPosition.Row) or ((BlockSize <> 0) and ((EditBlock.StartingRow + 1) = (EditPosition.Row)) and (EditBlock.EndingColumn = 1)) then
    begin
      // Only a single line to duplicate
      // Move to end of current line
      EditPosition.MoveEOL;
      // Get the column position
      CurrentRowEnd := EditPosition.Column;
      // Move to beginning of current line
      EditPosition.MoveBOL;
      // Get the text of the current line, less the EOL marker
      CodeLine := EditPosition.Read(CurrentRowEnd - 1);
      // Add a line
      EditPosition.InsertText(#13);
      // Move to column 1
      EditPosition.Move(CurrentRow, 1);
      // Insert the copied line
      EditPosition.InsertText(CodeLine);
    end
    else
    begin
      // More than one line selected. Get block text
      CodeLine := EditBlock.Text;
      // Move to the end of the block
      EditPosition.Move(EditBlock.EndingRow, EditBlock.EndingColumn);
      // Insert block text
      EditPosition.InsertText(CodeLine);
    end;
    // Restore AutoIndent, if necessary
    if IsAutoIndent then
      Context.EditBuffer.BufferOptions.AutoIndent := True;
    BindingResult := krHandled;
  finally
    // Move cursor to original position
    EditPosition.Restore;
    // Restore the original block (if one existed)
    EditBlock.Restore;
  end;
end;

procedure TDupLineBinding.AppendComment(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
var
  ep: IOTAEditPosition;
  c: Integer;
begin
  ep := Context.EditBuffer.EditPosition; // 9/24/2010 11:03:14 AM
  // Author: Cary Jensen
  ep.MoveEOL;
  c := ep.Column;
  ep.InsertText(' // ' + DateTimeToStr(Now) + #13);
  ep.Move(ep.Row, c + 1);
  ep.InsertText(' // Author: Cary Jensen');
  BindingResult := krHandled;
end;

procedure TDupLineBinding.CommentToggle(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
var
  ep: IOTAEditPosition;
  eb: IOTAEditBlock;
  Comment: Boolean;
  SRow, ERow: Integer;
begin
  // original edit position
  ep := Context.EditBuffer.EditPosition;
  ep.Save;
  // edit block
  eb := Context.EditBuffer.EditBlock;

  // find the starting and ending rows to operate on
  if eb.Size = 0 then
  begin
    SRow := ep.Row;
    ERow := ep.Row;
  end
  else if (eb.EndingColumn = 1) then
  begin
    SRow := eb.StartingRow;
    ERow := eb.EndingRow - 1;
  end
  else
  begin
    SRow := eb.StartingRow;
    ERow := eb.EndingRow;
  end;

  // toggle comments
  repeat
    begin
      ep.Move(SRow, 1);
      while ep.IsWhiteSpace do
        ep.MoveRelative(0, 1);
      if ep.Character = '/' then
      begin
        ep.MoveRelative(0, 1);
        if ep.Character = '/' then
          Comment := True
        else
          Comment := False
      end
      else
        Comment := False;

      if Comment then
      begin
        ep.MoveRelative(0, -1);
        ep.Delete(2);
      end
      else
      begin
        ep.MoveBOL;
        ep.InsertText('//');
      end;
      Inc(SRow);
    end;
  until (SRow > ERow);
  // update caret position
  ep.Restore;
  ep.Move(SRow, ep.Column);
  // All done
  BindingResult := krHandled;
end;

end.

