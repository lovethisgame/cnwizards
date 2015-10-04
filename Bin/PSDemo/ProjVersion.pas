{*******************************************************}
{                                                       }
{       Pascal Script Source File                       }
{       Run by RemObjects Pascal Script in CnWizards    }
{                                                       }
{       Generated by CnPack IDE Wizards                 }
{                                                       }
{       Script created by :                             }
{       - Erik De Laet - E.De.L.Com bvba                }
{         'Programmer by choice and profession!'        }
{         www.edelcom.be - Belgium                      }
{                                                       }
{       Thanks to Passion (LiuXiao) of the CnPack team  }
{       for the necessary and appreciated help and      }
{       insight in the CnPack routines.                 }
{                                                       }
{*******************************************************}

program ProjVersion;

{
  Note: Please Add this Script to Script Library, and Run it from the
    Corresponding item of the Dropdown Menu under "Run" ToolButton in
    Script Window. Or Assign a Shortcut to Run it.
}

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ToolsAPI, CnCommon, CnWizUtils;

var
  EditView: IOTAEditView;
  Options: IOTAProjectOptions;
  Project: IOTAProject;
  Position: IOTAEditPosition;
  MajorVer, MinorVer, ReleaseNo, BuildNo: Integer;
  sVersion: string;
  iColInSource, iCol, iLine: Integer;
  sFiller: string;
begin
  Writeln(CnOtaGetProjectVersion(nil));

  Options := CnOtaGetActiveProjectOptions(nil);
  if Options = nil then Exit;
  Project := CnOtaGetCurrentProject;
  if Project = nil then Exit;
  EditView := CnOtaGetTopMostEditView(nil);                                  
  if EditView = nil then Exit;                                       

  // Get the Versions
  MajorVer := Options.GetOptionValue('MajorVersion');
  MinorVer := Options.GetOptionValue('MinorVersion');
  ReleaseNo  := Options.GetOptionValue('Release');
  BuildNo := Options.GetOptionValue('Build');

  // build string to insert
  sVersion := '//!' + IntToStr(MajorVer) + '.' + IntToStr(MinorVer) + '.' + IntToStr(ReleaseNo) + '.' + IntToStr(BuildNo);

  // get and keep de current cursor position
  IdeEditorGetEditPos(iColInSource, iLine);

  // move to end of line
  Position := EditView.GetPosition;
  if Position = nil then Exit;
  Position.MoveEOL;

  // get current position
  IdeEditorGetEditPos(iCol, iLine);
  sFiller := '';

  if iCol = 1 then
  begin
    // if we are at the beginning of the line, the line was empty, so insert
    // the text at the saved position (by inserting spaces - see note below)
    sFiller := Spc(iColInSource - 1);

    // we cannot use "IdeEditorGotoEditPos" because this takes a third parameter
    // and this will move the current line to the top or the middle of the
    // editor window (don't know why this third parameter is needed ???)
    // IdeEditorGotoEditPos(iColInSource,iLine,True);
  end
  else if iCol + Length(sVersion) < 80 then
    sFiller := Spc(80 - Length(sVersion) - iCol + 1);

  IdeInsertTextIntoEditor(sFiller + sVersion);
end.
