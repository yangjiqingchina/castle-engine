{
  Copyright 2014-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Android project services and their configurations. }
unit ToolAndroidServices;

interface

uses SysUtils, Generics.Collections, DOM,
  CastleUtils, CastleStringUtils,
  ToolUtils;

type
  ECannotMergeManifest = class(Exception);
  ECannotMergeBuildGradle = class(Exception);

  TAndroidService = class
  private
    FParameters: TStringStringMap;
    FName: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ReadCastleEngineManifest(const Element: TDOMElement);
    property Name: string read FName;
    property Parameters: TStringStringMap read FParameters;
  end;

  TAndroidServiceList = class(specialize TObjectList<TAndroidService>)
  public
    procedure ReadCastleEngineManifest(const Element: TDOMElement);
    function HasService(const Name: string): boolean;
  end;

procedure MergeAndroidManifest(const Source, Destination: string;
  const ReplaceMacros: TReplaceMacros);
procedure MergeAppend(const Source, Destination: string;
  const ReplaceMacros: TReplaceMacros);
procedure MergeAndroidMainActivity(const Source, Destination: string;
  const ReplaceMacros: TReplaceMacros);
procedure MergeBuildGradle(const Source, Destination: string;
  const ReplaceMacros: TReplaceMacros);

implementation

uses Classes, XMLRead, XMLWrite,
  CastleXMLUtils, CastleURIUtils, CastleFilesUtils;

{ TAndroidService ---------------------------------------------------------- }

constructor TAndroidService.Create;
begin
  inherited;
  FParameters := TStringStringMap.Create;
end;

destructor TAndroidService.Destroy;
begin
  FreeAndNil(FParameters);
  inherited;
end;

procedure TAndroidService.ReadCastleEngineManifest(const Element: TDOMElement);
var
  ChildElements: TXMLElementIterator;
  ChildElement: TDOMElement;
  Key, Value: string;
begin
  FName := Element.AttributeString('name');

  ChildElements := Element.ChildrenIterator('parameter');
  try
    while ChildElements.GetNext do
    begin
      ChildElement := ChildElements.Current;
      Key := ChildElement.AttributeString('key');
      if ChildElement.HasAttribute('value') then
        Value := ChildElement.AttributeString('value')
      else
      begin
        Value := ChildElement.TextData;
        { value cannot be empty in this case }
        if Value = '' then
          raise Exception.CreateFmt('No value for key "%s" specified in CastleEngineManifest.xml', [Key]);
      end;
      FParameters.Add(Key, Value);
    end;
  finally FreeAndNil(ChildElements) end;
end;

{ TAndroidServiceList ------------------------------------------------------ }

procedure TAndroidServiceList.ReadCastleEngineManifest(const Element: TDOMElement);
var
  ChildElements: TXMLElementIterator;
  ChildElement: TDOMElement;
  Service: TAndroidService;
begin
  ChildElements := Element.ChildrenIterator('component');
  try
    while ChildElements.GetNext do
    begin
      ChildElement := ChildElements.Current;
      Service := TAndroidService.Create;
      Add(Service);
      Service.ReadCastleEngineManifest(ChildElement);
    end;
  finally FreeAndNil(ChildElements) end;

  ChildElements := Element.ChildrenIterator('service');
  try
    while ChildElements.GetNext do
    begin
      ChildElement := ChildElements.Current;
      Service := TAndroidService.Create;
      Add(Service);
      Service.ReadCastleEngineManifest(ChildElement);
    end;
  finally FreeAndNil(ChildElements) end;
end;

function TAndroidServiceList.HasService(const Name: string): boolean;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Items[I].Name = Name then
      Exit(true);
  Result := false;
end;

{ globals -------------------------------------------------------------------- }

procedure MergeAndroidManifest(const Source, Destination: string;
  const ReplaceMacros: TReplaceMacros);
var
  SourceXml, DestinationXml: TXMLDocument;

  procedure ReadXmlExpandingMacros(out Document: TXMLDocument; const FileName: string);
  var
    StringStream: TStringStream;
  begin
    StringStream := TStringStream.Create(
      ReplaceMacros(FileToString(FilenameToURISafe(FileName))));
    try
      ReadXMLFile(Document, StringStream);
    finally FreeAndNil(StringStream) end;
  end;

  procedure MergeApplication(const SourceApplication: TDOMElement);
  var
    DestinationApplication: TDOMElement;
    SourceNodes: TDOMNodeList;
    SourceAttribs: TDOMNamedNodeMap;
    I: Integer;
  begin
    DestinationApplication := DestinationXml.DocumentElement.ChildElement('application');

    // GetChildNodes includes child comments, elements, everything... except attributes
    SourceNodes := SourceApplication.GetChildNodes;
    for I := 0 to SourceNodes.Count - 1 do
    begin
      // if Verbose then
      //   Writeln('Appending node ', SourceNodes[I].NodeName, ' of type ', SourceNodes[I].NodeType);
      DestinationApplication.AppendChild(
        SourceNodes[I].CloneNode(true, DestinationXml));
    end;

    SourceAttribs := SourceApplication.Attributes;
    for I := 0 to SourceAttribs.Length - 1 do
    begin
      if SourceAttribs[I].NodeType <> ATTRIBUTE_NODE then
        raise ECannotMergeManifest.Create('Attribute node does not have NodeType = ATTRIBUTE_NODE: ' +
          SourceAttribs[I].NodeName8);
      // if Verbose then
      //   Writeln('Appending attribute ', SourceAttribs[I].NodeName);
      DestinationApplication.SetAttribute(
        SourceAttribs[I].NodeName, SourceAttribs[I].NodeValue);
    end;
  end;

  procedure MergeUsesPermission(const SourceUsesPermission: TDOMElement);
  var
    SourceName: string;
    I: TXMLElementIterator;
  begin
    SourceName := SourceUsesPermission.AttributeString('android:name');

    I := DestinationXml.DocumentElement.ChildrenIterator;
    try
      while I.GetNext do
      begin
        if (I.Current.TagName = 'uses-permission') and
           I.Current.HasAttribute('android:name') and
           (I.Current.AttributeString('android:name') = SourceName) then
        begin
          // if Verbose then
          //   Writeln('Main AndroidManifest.xml already uses-permission with ' + SourceName);
          Exit;
        end;
      end;
    finally FreeAndNil(I) end;

    DestinationXml.DocumentElement.AppendChild(
      SourceUsesPermission.CloneNode(true, DestinationXml));
  end;

  procedure MergeSupportsScreens(const SourceElement: TDOMElement);
  begin
    if DestinationXml.DocumentElement.ChildElement(SourceElement.TagName8, false) <> nil then
      raise ECannotMergeManifest.Create(
        'Cannot merge AndroidManifest.xml, only one <' + SourceElement.TagName8 + '> is allowed');
    DestinationXml.DocumentElement.AppendChild(SourceElement.CloneNode(true, DestinationXml));
  end;

var
  I: TXMLElementIterator;
begin
  // if Verbose then
  //   Writeln('Merging "', Source, '" into "', Destination, '"');

  try
    { Do not simply read Source by
        ReadXMLFile(SourceXml, Source);
      because we want to call ReplaceMacros() on source contents. }
    ReadXMLExpandingMacros(SourceXml, Source); // this nils SourceXml in case of error
    try
      ReadXMLFile(DestinationXml, Destination); // this nils DestinationXml in case of error

      I := SourceXml.DocumentElement.ChildrenIterator;
      try
        while I.GetNext do
        begin
          if I.Current.TagName = 'application' then
            MergeApplication(I.Current) else
          if (I.Current.TagName = 'uses-permission') and
             I.Current.HasAttribute('android:name') then
            MergeUsesPermission(I.Current) else
          if I.Current.TagName = 'supports-screens' then
            MergeSupportsScreens(I.Current) else
            raise ECannotMergeManifest.Create('Cannot merge AndroidManifest.xml element <' + I.Current.TagName8 + '>');
        end;
      finally FreeAndNil(I) end;

      WriteXMLFile(DestinationXml, Destination);
    finally FreeAndNil(DestinationXml) end;
  finally FreeAndNil(SourceXml) end;
end;

procedure MergeAppend(const Source, Destination: string;
  const ReplaceMacros: TReplaceMacros);
var
  SourceContents, DestinationContents: string;
begin
  // if Verbose then
  //   Writeln('Merging "', Source, '" into "', Destination, '"');

  SourceContents := ReplaceMacros(FileToString(FilenameToURISafe(Source)));
  DestinationContents := FileToString(FilenameToURISafe(Destination));
  DestinationContents := DestinationContents + NL + SourceContents;
  StringToFile(Destination, DestinationContents);
end;

procedure MergeAndroidMainActivity(const Source, Destination: string;
  const ReplaceMacros: TReplaceMacros);
const
  InsertMarker = '/* ANDROID-SERVICES-INITIALIZATION */';
var
  SourceContents, DestinationContents: string;
  MarkerPos: Integer;
begin
  // if Verbose then
  //   Writeln('Merging "', Source, '" into "', Destination, '"');

  SourceContents := ReplaceMacros(FileToString(FilenameToURISafe(Source)));
  DestinationContents := FileToString(FilenameToURISafe(Destination));
  MarkerPos := Pos(InsertMarker, DestinationContents);
  if MarkerPos = 0 then
    raise ECannotMergeManifest.CreateFmt('Cannot find marker "%s" in MainActivity.java', [InsertMarker]);
  Insert(SourceContents, DestinationContents, MarkerPos);
  StringToFile(Destination, DestinationContents);
end;

procedure MergeBuildGradle(const Source, Destination: string;
  const ReplaceMacros: TReplaceMacros);
var
  DestinationContents: string;
  Doc: TXMLDocument;

  { Modify DestinationContents to add information specified in source XML file. }
  procedure MergeItems(const ListElement, ChildElement, Marker: string);
  var
    I: TXMLElementIterator;
    E: TDOMElement;
    MarkerPos: Integer;
  begin
    E := Doc.DocumentElement.ChildElement(ListElement, false);
    if E <> nil then
    begin
      MarkerPos := Pos(Marker, DestinationContents);
      if MarkerPos = 0 then
        raise ECannotMergeBuildGradle.CreateFmt('The destination build.gradle does not contain "%s" marker.',
          [Marker]);
      MarkerPos += Length(Marker);

      I := E.ChildrenIterator(ChildElement);
      try
        while I.GetNext do
        begin
          Insert(NL + '    ' + I.Current.TextData, DestinationContents, MarkerPos);
        end;
      finally FreeAndNil(I) end;
    end;
  end;

var
  SourceContents: string;
  SStream: TStringStream;
begin
  SourceContents      := ReplaceMacros(FileToString(FilenameToURISafe(Source)));
  DestinationContents := ReplaceMacros(FileToString(FilenameToURISafe(Destination)));

  SStream := TStringStream.Create(SourceContents);
  try
    try
      ReadXMLFile(Doc, SStream); // ReadXMLFile within "try" clause, as it initializes Doc always
      if Doc.DocumentElement.TagName <> 'build_gradle_merge' then
        raise ECannotMergeBuildGradle.Create('The source file from which to merge build.gradle must be XML with root <build_gradle_merge>');
      MergeItems('dependencies', 'dependency', '// MERGE-DEPENDENCIES');
      MergeItems('plugins', 'plugin', '// MERGE-PLUGINS');
      MergeItems('repositories', 'repository', '// MERGE-REPOSITORIES');
    finally FreeAndNil(Doc) end;
  finally FreeAndNil(SStream) end;

  StringToFile(Destination, DestinationContents);
end;

end.
