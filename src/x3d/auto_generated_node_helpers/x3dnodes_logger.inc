{ -*- buffer-read-only: t -*-

  Copyright 2015-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Automatically generated node properties.

  Do not edit this file manually!
  To add new properties:
  - add them to the text files in nodes_specification/components/ ,
  - and regenerate include files by running
    nodes_specification/x3d-nodes-to-pascal/x3d-nodes-to-pascal.lpr .

  The documentation for properties should go to x3dnodes_documentation.txt . }

{$ifdef read_interface}

  strict private
    function GetLevel: Integer;
    procedure SetLevel(const Value: Integer);
    function GetLogFile: string;
    procedure SetLogFile(const Value: string);
    function GetEnabled: boolean;
    procedure SetEnabled(const Value: boolean);
  public
    property Level: Integer read GetLevel write SetLevel;
    property LogFile: string read GetLogFile write SetLogFile;
    property Enabled: boolean read GetEnabled write SetEnabled;

{$endif read_interface}

{$ifdef read_implementation}

{ TLoggerNode ----------------------------------------------- }

function TLoggerNode.GetLevel: Integer;
begin
  Result := FdLevel.Value;
end;

procedure TLoggerNode.SetLevel(const Value: Integer);
begin
  FdLevel.Send(Value);
end;

function TLoggerNode.GetLogFile: string;
begin
  Result := FdLogFile.Value;
end;

procedure TLoggerNode.SetLogFile(const Value: string);
begin
  FdLogFile.Send(Value);
end;

function TLoggerNode.GetEnabled: boolean;
begin
  Result := FdEnabled.Value;
end;

procedure TLoggerNode.SetEnabled(const Value: boolean);
begin
  FdEnabled.Send(Value);
end;

{$endif read_implementation}
