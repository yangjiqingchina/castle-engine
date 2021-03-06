{
  Copyright 2009-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ KTX loading. }

{ TKTXHandler ----------------------------------------------------------------- }

type
  TKTXHandler = class(TCompositeFormatHandler)
  strict private
    { A couple of optimized routines for image formats that
      closely match corresponding Images unit memory format are below.
      Optimized routines already know the Result memory format (image class)
      and file format (Header.PixelFormat), they don't have to check them.  }
    class procedure ReadOptimized_G8(const Stream: TStream;
      const Image: TCastleImage; const RowBytePadding: Integer); static;
    class procedure ReadOptimized_AG8(const Stream: TStream;
      const Image: TCastleImage; const RowBytePadding: Integer); static;
    class procedure ReadOptimized_RGB8(const Stream: TStream;
      const Image: TCastleImage; const RowBytePadding: Integer); static;
    class procedure ReadOptimized_BGR8(const Stream: TStream;
      const Image: TCastleImage; const RowBytePadding: Integer); static;
    class procedure ReadOptimized_RGBA8(const Stream: TStream;
      const Image: TCastleImage; const RowBytePadding: Integer); static;
    class procedure ReadOptimized_BGRA8(const Stream: TStream;
      const Image: TCastleImage; const RowBytePadding: Integer); static;
    class procedure ReadFloatImage(const Stream: TStream;
      const Image: TRGBFloatImage); static;
  public
    procedure LoadFromStream(const Stream: TStream; const URL: string); override;
  end;

// TODO: detect when rows are inverted in KTX by looking at header

class procedure TKTXHandler.ReadOptimized_G8(const Stream: TStream;
  const Image: TCastleImage; const RowBytePadding: Integer);
var
  Y, Z: Integer;
begin
  for Z := 0 to Image.Depth - 1 do
    for Y := Image.Height - 1 downto 0 do // rows in KTX are usually inverted
    begin
      Stream.ReadBuffer(Image.RowPtr(Y, Z)^, Image.PixelSize * Image.Width);
      if RowBytePadding <> 0 then
        Stream.Seek(RowBytePadding, soFromCurrent);
    end;
end;

class procedure TKTXHandler.ReadOptimized_AG8(const Stream: TStream;
  const Image: TCastleImage; const RowBytePadding: Integer);
var
  Y, Z: Integer;
begin
  for Z := 0 to Image.Depth - 1 do
    for Y := Image.Height - 1 downto 0 do // rows in KTX are usually inverted
    begin
      Stream.ReadBuffer(Image.RowPtr(Y, Z)^, Image.PixelSize * Image.Width);
      if RowBytePadding <> 0 then
        Stream.Seek(RowBytePadding, soFromCurrent);
    end;
end;

class procedure TKTXHandler.ReadOptimized_RGB8(const Stream: TStream;
  const Image: TCastleImage; const RowBytePadding: Integer);
var
  Y, Z: Integer;
  Row: PVector3Byte;
begin
  for Z := 0 to Image.Depth - 1 do
    for Y := Image.Height - 1 downto 0 do // rows in KTX are usually inverted
    begin
      Row := Image.RowPtr(Y, Z);
      Stream.ReadBuffer(Row^, Image.PixelSize * Image.Width);
      if RowBytePadding <> 0 then
        Stream.Seek(RowBytePadding, soFromCurrent);
    end;
end;

class procedure TKTXHandler.ReadOptimized_BGR8(const Stream: TStream;
  const Image: TCastleImage; const RowBytePadding: Integer);
var
  X, Y, Z: Integer;
  Row: PVector3Byte;
begin
  for Z := 0 to Image.Depth - 1 do
    for Y := Image.Height - 1 downto 0 do // rows in KTX are usually inverted
    begin
      Row := Image.RowPtr(Y, Z);
      Stream.ReadBuffer(Row^, Image.PixelSize * Image.Width);
      { Now invert red and blue. }
      for X := 0 to Image.Width - 1 do
      begin
        SwapValues(Row^.Data[2], Row^.Data[0]);
        Inc(Row);
      end;
      if RowBytePadding <> 0 then
        Stream.Seek(RowBytePadding, soFromCurrent);
    end;
end;

class procedure TKTXHandler.ReadOptimized_RGBA8(const Stream: TStream;
  const Image: TCastleImage; const RowBytePadding: Integer);
var
  Y, Z: Integer;
  Row: PVector4Byte;
begin
  for Z := 0 to Image.Depth - 1 do
    for Y := Image.Height - 1 downto 0 do // rows in KTX are usually inverted
    begin
      Row := Image.RowPtr(Y, Z);
      Stream.ReadBuffer(Row^, Image.PixelSize * Image.Width);
      if RowBytePadding <> 0 then
        Stream.Seek(RowBytePadding, soFromCurrent);
    end;
end;

class procedure TKTXHandler.ReadOptimized_BGRA8(const Stream: TStream;
  const Image: TCastleImage; const RowBytePadding: Integer);
var
  X, Y, Z: Integer;
  Row: PVector4Byte;
begin
  for Z := 0 to Image.Depth - 1 do
    for Y := Image.Height - 1 downto 0 do // rows in KTX are usually inverted
    begin
      Row := Image.RowPtr(Y, Z);
      Stream.ReadBuffer(Row^, Image.PixelSize * Image.Width);
      { Now invert red and blue. }
      for X := 0 to Image.Width - 1 do
      begin
        SwapValues(Row^.Data[2], Row^.Data[0]);
        Inc(Row);
      end;
      if RowBytePadding <> 0 then
        Stream.Seek(RowBytePadding, soFromCurrent);
    end;
end;

class procedure TKTXHandler.ReadFloatImage(const Stream: TStream; const Image: TRGBFloatImage);
var
  Floats: TSingleList;
  X, Y, Z: Integer;
  Pixel: PVector3;
  PixelSource: PSingle;
begin
  Floats := TSingleList.Create;
  try
    Floats.Count := Image.Width * Image.Height * Image.Depth;
    Stream.ReadBuffer(Floats.List^, Floats.Count * SizeOf(Single));
    PixelSource := PSingle(Floats.List);

    // move Floats data to Image.Pixels
    for Z := 0 to Image.Depth - 1 do
      for Y := Image.Height - 1 downto 0 do // rows in KTX are usually inverted
      begin
        Pixel := PVector3(Image.RowPtr(Y, Z));
        for X := 0 to Image.Width - 1 do
        begin
          Pixel^[0] := PixelSource^;
          Pixel^[1] := PixelSource^;
          Pixel^[2] := PixelSource^;
          Inc(PixelSource);
          Inc(Pixel);
        end;
      end;
  finally FreeAndNil(Floats) end;
end;

procedure TKTXHandler.LoadFromStream(const Stream: TStream; const URL: string);
const
  // See https://www.khronos.org/opengles/sdk/tools/KTX/file_format_spec/
  CorrectFileId: array [0..11] of Byte =
  ($AB, $4B, $54, $58, $20, $31, $31, $BB, $0D, $0A, $1A, $0A);
type
  TKTXHeader = record
    FileId: array [0..High(CorrectFileId)] of Byte;
    Endianness,
    GlType,
    GlTypeSize,
    GlFormat,
    GlInternalFormat,
    GlBaseInternalFormat,
    Width,
    Height,
    Depth,
    NumberOfArrayElements,
    NumberOfFaces,
    NumberOfMipmapLevels,
    BytesOfKeyValueData: LongWord;
  end;
const
  // See /usr/include/GL/gl.h , /usr/include/GL/glext.h
  GL_BYTE           = $1400;
  GL_UNSIGNED_BYTE  = $1401;
  GL_SHORT          = $1402;
  GL_UNSIGNED_SHORT = $1403;
  GL_INT            = $1404;
  GL_UNSIGNED_INT   = $1405;
  GL_FLOAT          = $1406;
  GL_DOUBLE         = $140A;
  GL_HALF_FLOAT     = $140B;

  GL_RED             = $1903;
  GL_GREEN           = $1904;
  GL_BLUE            = $1905;
  GL_ALPHA           = $1906;
  GL_RGB             = $1907;
  GL_RGBA            = $1908;
  GL_LUMINANCE       = $1909;
  GL_LUMINANCE_ALPHA = $190A;

  GL_BGR            = $80E0;
  GL_BGRA           = $80E1;

  GL_R16F           = $822D;
  GL_R32F           = $822E;

var
  Header: TKTXHeader;
  SwapEndianness: boolean;
  I: Integer;
  ImageSize: LongWord;
begin
  try
    Stream.ReadBuffer(Header, SizeOf(Header));

    for I := 0 to High(CorrectFileId) do
      if Header.FileId[I] <> CorrectFileId[I] then
        raise EInvalidKTX.Create('Invalid KTX file header');

    SwapEndianness := Header.Endianness = $01020304;
    if SwapEndianness then
    begin
      Header.Endianness            := Swap32(Header.Endianness           );
      Header.GlType                := Swap32(Header.GlType               );
      Header.GlTypeSize            := Swap32(Header.GlTypeSize           );
      Header.GlFormat              := Swap32(Header.GlFormat             );
      Header.GlInternalFormat      := Swap32(Header.GlInternalFormat     );
      Header.GlBaseInternalFormat  := Swap32(Header.GlBaseInternalFormat );
      Header.Width                 := Swap32(Header.Width                );
      Header.Height                := Swap32(Header.Height               );
      Header.Depth                 := Swap32(Header.Depth                );
      Header.NumberOfArrayElements := Swap32(Header.NumberOfArrayElements);
      Header.NumberOfFaces         := Swap32(Header.NumberOfFaces        );
      Header.NumberOfMipmapLevels  := Swap32(Header.NumberOfMipmapLevels );
      Header.BytesOfKeyValueData   := Swap32(Header.BytesOfKeyValueData  );
    end;

    if Header.Endianness <> $04030201 then
      raise EInvalidKTX.Create('Invalid KTX endianess');

    Width := Header.Width;
    Height := Header.Height;
    Depth := Max(1, Header.Depth);

    // Skip BytesOfKeyValueData
    Stream.Seek(Header.BytesOfKeyValueData, soFromCurrent);

    Stream.ReadBuffer(ImageSize, SizeOf(ImageSize));
    if SwapEndianness then
      ImageSize := Swap32(ImageSize);

    if (Header.GlType = GL_UNSIGNED_BYTE) and
       (Header.GlTypeSize = 1) and
       (Header.GlFormat = GL_BGRA) and
       (Header.GlInternalFormat = GL_BGRA) and
       (Header.GlBaseInternalFormat = GL_BGRA) then
    begin
      // paranoid check, should not be needed
      if ImageSize <> Width * Height * Depth * 4 then
        raise EInvalidKTX.CreateFmt('Unexpected image size in KTX: %d', [ImageSize]);

      Images.Count := 1;
      Images[0] := TRGBAlphaImage.Create(Width, Height, Depth);
      ReadOptimized_BGRA8(Stream, TRGBAlphaImage(Images[0]), 0); // TODO: row padding, images sliced padding?
    end else
    if (Header.GlType = GL_UNSIGNED_BYTE) and
       (Header.GlTypeSize = 1) and
       (Header.GlFormat = GL_RGBA) and
       (Header.GlInternalFormat = GL_RGBA) and
       (Header.GlBaseInternalFormat = GL_RGBA) then
    begin
      // paranoid check, should not be needed
      if ImageSize <> Width * Height * Depth * 4 then
        raise EInvalidKTX.CreateFmt('Unexpected image size in KTX: %d', [ImageSize]);

      Images.Count := 1;
      Images[0] := TRGBAlphaImage.Create(Width, Height, Depth);
      ReadOptimized_RGBA8(Stream, TRGBAlphaImage(Images[0]), 0); // TODO: row padding, images sliced padding?
    end else
    if (Header.GlType = GL_FLOAT) and
       (Header.GlTypeSize = 4) and
       (Header.GlFormat = GL_RED) and
       (Header.GlInternalFormat = GL_R32F) and
       (Header.GlBaseInternalFormat = GL_RED) then
    begin
      if ImageSize <> Width * Height * Depth * SizeOf(Single) then
        raise EInvalidKTX.CreateFmt('Unexpected image size in KTX: %d', [ImageSize]);

      Images.Count := 1;
      Images[0] := TRGBFloatImage.Create(Width, Height, Depth);
      ReadFloatImage(Stream, TRGBFloatImage(Images[0])); // TODO: row padding, images sliced padding?
    end else
    if Header.GlType = GL_HALF_FLOAT then
    begin
      raise EInvalidKTX.Create('Cannot handle KTX with half-float (16-bit floats) data');
    end else
    begin
      raise EInvalidKTX.CreateFmt('Cannot handle this KTX data type: glType %d, glTypeSize %d, glFormat %d, glInternalFormat %d, glBaseInternalFormat %d',
        [Header.GlType,
         Header.GlTypeSize,
         Header.GlFormat,
         Header.GlInternalFormat,
         Header.GlBaseInternalFormat]);
    end;
  except
    { EReadError is raised by Stream.ReadBuffer when it can't read
      specified number of bytes }
    on E: EReadError do raise EInvalidKTX.Create('Read error: ' + E.Message);
    on E: ECheckFailed do raise EInvalidKTX.Create('Invalid KTX file: ' + E.Message);
  end;
end;
