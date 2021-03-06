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
    function GetRadius: Single;
    procedure SetRadius(const Value: Single);
    function GetSlices: Integer;
    procedure SetSlices(const Value: Integer);
    function GetStacks: Integer;
    procedure SetStacks(const Value: Integer);
  public
    property Radius: Single read GetRadius write SetRadius;
    property Slices: Integer read GetSlices write SetSlices;
    property Stacks: Integer read GetStacks write SetStacks;

{$endif read_interface}

{$ifdef read_implementation}

{ TSphereNode ----------------------------------------------- }

function TSphereNode.GetRadius: Single;
begin
  Result := FdRadius.Value;
end;

procedure TSphereNode.SetRadius(const Value: Single);
begin
  FdRadius.Send(Value);
end;

function TSphereNode.GetSlices: Integer;
begin
  Result := FdSlices.Value;
end;

procedure TSphereNode.SetSlices(const Value: Integer);
begin
  FdSlices.Send(Value);
end;

function TSphereNode.GetStacks: Integer;
begin
  Result := FdStacks.Value;
end;

procedure TSphereNode.SetStacks(const Value: Integer);
begin
  FdStacks.Send(Value);
end;

{$endif read_implementation}
