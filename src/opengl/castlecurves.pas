{
  Copyright 2004-2012 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ 3D curves (TCurve and basic descendants). }

unit CastleCurves;

interface

uses CastleVectors, CastleBoxes, CastleUtils, CastleScript,
  CastleClassUtils, Classes, Castle3D, CastleFrustum, FGL;

type
  { 3D curve, a set of points defined by a continous function @link(Point)
    for arguments within [TBegin, TEnd].

    Note that some descendants return only an approximate BoundingBox result,
    it may be too small or too large sometimes.
    (Maybe at some time I'll make this more rigorous, as some code may require
    that it's a proper bounding box, maybe too large but never too small.) }
  TCurve = class(T3D)
  private
    FTBegin, FTEnd: Float;
    FDefaultSegments: Cardinal;
  public
    { The valid range of curve function argument. Must be TBegin <= TEnd.
      @groupBegin }
    property TBegin: Float read FTBegin;
    property TEnd: Float read FTEnd;
    { @groupEnd }

    { Curve function, for each parameter value determine the 3D point.
      This determines the actual shape of the curve. }
    function Point(const t: Float): TVector3Single; virtual; abstract;

    { Curve function to work with rendered line segments begin/end points.
      This is simply a more specialized version of @link(Point),
      it scales the argument such that you get Point(TBegin) for I = 0
      and you get Point(TEnd) for I = Segments. }
    function PointOfSegment(i, Segments: Cardinal): TVector3Single;

    { Render curve by dividing it into a given number of line segments.
      So actually @italic(every) curve will be rendered as a set of straight lines.
      You should just give some large number for Segments to have something
      that will be really smooth.

      OpenGL commands:
      @orderedList(
        @item(This method calls glBegin(GL_LINE_STRIP);)
        @item(Then it calls glVertexv(PointOfSegment(i, Segments))
          for i in [0; Segments]
          (yes, this means that it calls glVertex Segments+1 times).)
        @item(Then this method calls glEnd.)
      ) }
    procedure Render(Segments: Cardinal);

    { Default number of segments, used when rendering by T3D interface
      (that is, @code(Render(Frustum, TransparentGroup...)) method.) }
    property DefaultSegments: Cardinal
      read FDefaultSegments write FDefaultSegments default 10;

    procedure Render(const Frustum: TFrustum;
      const Params: TRenderParams); override;

    constructor Create(const ATBegin, ATEnd: Float); reintroduce;
  end;

  TCurveList = specialize TFPGObjectList<TCurve>;

  { Curve defined by explicitly giving functions for
    Point(t) = x(t), y(t), z(t) as CastleScript expressions. }
  TCasScriptCurve = class(TCurve)
  protected
    FTVariable: TCasScriptFloat;
    FXFunction, FYFunction, FZFunction: TCasScriptExpression;
    FBoundingBox: TBox3D;
  public
    function Point(const t: Float): TVector3Single; override;

    { XFunction, YFunction, ZFunction are functions based on variable 't'.
      @groupBegin }
    property XFunction: TCasScriptExpression read FXFunction;
    property YFunction: TCasScriptExpression read FYFunction;
    property ZFunction: TCasScriptExpression read FZFunction;
    { @groupEnd }

    { This is the variable controlling 't' value, embedded also in
      XFunction, YFunction, ZFunction. }
    property TVariable: TCasScriptFloat read FTVariable;

    { Simple bounding box. It is simply
      a BoundingBox of Point(i, SegmentsForBoundingBox)
      for i in [0 .. SegmentsForBoundingBox].
      Subclasses may override this to calculate something more accurate. }
    function BoundingBox: TBox3D; override;

    { XFunction, YFunction, ZFunction references are copied here,
      and will be freed in destructor (so don't Free them yourself). }
    constructor Create(const ATBegin, ATEnd: Float;
      AXFunction, AYFunction, AZFunction: TCasScriptExpression;
      ATVariable: TCasScriptFloat;
      ASegmentsForBoundingBox: Cardinal = 100);

    destructor Destroy; override;
  end;

  { A basic abstract class for curves determined my some set of ControlPoints.
    Note: it is @italic(not) defined in this class any correspondence between
    values of T (argument for Point function) and ControlPoints. }
  TControlPointsCurve = class(TCurve)
  private
    FBoundingBox: TBox3D;
  protected
    { Using these function you can control how Convex Hull (for RenderConvexHull)
      is calculated: CreateConvexHullPoints should return points that must be
      in convex hull (we will run ConvexHull function on those points),
      DestroyConvexHullPoints should finalize them.

      This way you can create new object in CreateConvexHullPoints and free it in
      DestroyConvexHullPoints, but you can also give in CreateConvexHullPoints
      reference to some already existing object and do nothing in
      DestroyConvexHullPoints. (we will not modify object given as
      CreateConvexHullPoints in any way)

      Default implementation in this class returns ControlPoints as
      CreateConvexHullPoints. (and does nothing in DestroyConvexHullPoints) }
    function CreateConvexHullPoints: TVector3SingleList; virtual;
    procedure DestroyConvexHullPoints(Points: TVector3SingleList); virtual;
  public
    ControlPoints: TVector3SingleList;

    { glBegin(GL_POINTS) + glVertex fo each ControlPoints[i] + glEnd. }
    procedure RenderControlPoints;

    { This class provides implementation for BoundingBox: it is simply
      a BoundingBox of ControlPoints. Subclasses may (but don't have to)
      override this to calculate better (more accurate) BoundingBox. }
    function BoundingBox: TBox3D; override;

    { Always after changing ControlPoints and before calling Point,
      BoundingBox (and anything that calls them, e.g. Render calls Point)
      call this method. It recalculates necessary things.
      ControlPoints.Count must be >= 2.

      When overriding: always call inherited first. }
    procedure UpdateControlPoints; virtual;

    { Nice class name, with spaces, starts with a capital letter.
      Much better than ClassName. Especially under FPC 1.0.x where
      ClassName is always uppercased. }
    class function NiceClassName: string; virtual; abstract;

    { do glBegin(GL_POLYGON), glVertex(v)..., glEnd,
      where glVertex are points of Convex Hull of ControlPoints
      (ignoring Z-coord of ControlPoints). }
    procedure RenderConvexHull;

    { Constructor.
      This is virtual because it's called by CreateDivideCasScriptCurve.
      It's also useful in many places in curves.lpr. }
    constructor Create(const ATBegin, ATEnd: Float); virtual;

    { Calculates ControlPoints taking Point(i, ControlPointsCount-1)
      for i in [0 .. ControlPointsCount-1] from CasScriptCurve.
      TBegin and TEnd are copied from CasScriptCurve. }
    constructor CreateDivideCasScriptCurve(CasScriptCurve: TCasScriptCurve;
      ControlPointsCount: Cardinal);

    destructor Destroy; override;
  end;

  TControlPointsCurveClass = class of TControlPointsCurve;

  TControlPointsCurveList = specialize TFPGObjectList<TControlPointsCurve>;

  { Curve that passes exactly through it's ControlPoints.x
    I.e. for each ControlPoint[i] there exists some value Ti
    that Point(Ti) = ControlPoint[i] and
    TBegin = T0 <= .. Ti-1 <= Ti <= Ti+1 ... <= Tn = TEnd
    (i.e. Point(TBegin) = ControlPoints[0],
          Point(TEnd) = ControlPoints[n]
     and all Ti are ordered,
     n = ControlPoints.High) }
  TInterpolatedCurve = class(TControlPointsCurve)
    { This can be overriden in subclasses.
      In this class this provides the most common implementation:
      equally (uniformly) spaced Ti values. }
    function ControlPointT(i: Integer): Float; virtual;
  end;

  { Curve defined as [Lx(t), Ly(t), Lz(t)] where
    L?(t) are Lagrange's interpolation polynomials.
    Lx(t) crosses points (ti, xi) (i = 0..ControlPoints.Count-1)
    where ti = TBegin + i/(ControlPoints.Count-1) * (TEnd-TBegin)
    and xi = ControlPoints[i, 0].
    Similarly for Ly and Lz.

    Later note: in fact, you can override ControlPointT to define
    function "ti" as you like. }
  TLagrangeInterpolatedCurve = class(TInterpolatedCurve)
  private
    { Values for Newton's polynomial form of Lx, Ly and Lz.
      Will be calculated in UpdateControlPoints. }
    Newton: array[0..2]of TFloatList;
  public
    procedure UpdateControlPoints; override;
    function Point(const t: Float): TVector3Single; override;

    class function NiceClassName: string; override;

    constructor Create(const ATBegin, ATEnd: Float); override;
    destructor Destroy; override;
  end;

  { Natural cubic spline (1D).
    May be periodic or not. }
  TNaturalCubicSpline = class
  private
    FMinX, FMaxX: Float;
    FOwnsX, FOwnsY: boolean;
    FPeriodic: boolean;
    FX, FY: TFloatList;
    M: TFloatList;
  public
    property MinX: Float read FMinX;
    property MaxX: Float read FMaxX;
    property Periodic: boolean read FPeriodic;

    { Constructs natural cubic spline such that for every i in [0; X.Count-1]
      s(X[i]) = Y[i]. Must be X.Count = Y.Count.
      X must be already sorted.
      MinX = X[0], MaxX = X[X.Count-1].

      Warning: we will copy references to X and Y ! So make sure that these
      objects are available for the life of this object.
      We will free in destructor X if OwnsX and free Y if OwnsY. }
    constructor Create(X, Y: TFloatList; AOwnsX, AOwnsY, APeriodic: boolean);
    destructor Destroy; override;

    { Evaluate value of natural cubic spline at x.
      Must be MinX <= x <= MaxX. }
    function Evaluate(x: Float): Float;
  end;

  { 3D curve defined by three 1D natural cubic splines.
    Works just like TLagrangeInterpolatedCurve, only the interpolation
    is different now. }
  TNaturalCubicSplineCurve_Abstract = class(TInterpolatedCurve)
  protected
    { Is the curve closed. May depend on ControlPoints,
      it will be recalculated in UpdateControlPoints. }
    function Closed: boolean; virtual; abstract;
  private
    { Created/Freed in UpdateControlPoints, Freed in Destroy }
    Spline: array[0..2]of TNaturalCubicSpline;
  public
    procedure UpdateControlPoints; override;
    function Point(const t: Float): TVector3Single; override;

    constructor Create(const ATBegin, ATEnd: Float); override;
    destructor Destroy; override;
  end;

  { 3D curve defined by three 1D natural cubic splines, automatically
    closed if first and last points match. This is the most often suitable
    non-abstract implementation of TNaturalCubicSplineCurve_Abstract. }
  TNaturalCubicSplineCurve = class(TNaturalCubicSplineCurve_Abstract)
  protected
    function Closed: boolean; override;
  public
    class function NiceClassName: string; override;
  end;

  { 3D curve defined by three 1D natural cubic splines, always treated as closed. }
  TNaturalCubicSplineCurveAlwaysClosed = class(TNaturalCubicSplineCurve_Abstract)
  protected
    function Closed: boolean; override;
  public
    class function NiceClassName: string; override;
  end;

  { 3D curve defined by three 1D natural cubic splines, never treated as closed. }
  TNaturalCubicSplineCurveNeverClosed = class(TNaturalCubicSplineCurve_Abstract)
  protected
    function Closed: boolean; override;
  public
    class function NiceClassName: string; override;
  end;

  { Rational Bezier curve (Bezier curve with weights).
    Note: for Bezier Curve ControlPoints.Count MAY be 1.
    (For TControlPointsCurve it must be >= 2) }
  TRationalBezierCurve = class(TControlPointsCurve)
  public
    { Splits this curve using Casteljau algorithm.

      Under B1 and B2 returns two new, freshly created, bezier curves,
      such that if you concatenate them - they will create this curve.
      Proportion is something from (0; 1).
      B1 will be equal to Self for T in TBegin .. TMiddle,
      B2 will be equal to Self for T in TMiddle .. TEnd,
      where TMiddle = TBegin + Proportion * (TEnd - TBegin).

      B1.ControlPoints.Count = B2.ControlPoints.Count =
        Self.ControlPoints.Count. }
    procedure Split(const Proportion: Float; var B1, B2: TRationalBezierCurve);

    function Point(const t: Float): TVector3Single; override;
    class function NiceClassName: string; override;
  public
    { Curve weights.
      Must always be Weights.Count = ControlPoints.Count.
      After changing Weights you also have to call UpdateControlPoints.}
    Weights: TFloatList;

    procedure UpdateControlPoints; override;

    constructor Create(const ATBegin, ATEnd: Float); override;
    destructor Destroy; override;
  end;

  TRationalBezierCurveList = specialize TFPGObjectList<TRationalBezierCurve>;

  { Smooth interpolated curve, each segment (ControlPoints[i]..ControlPoints[i+1])
    is converted to a rational Bezier curve (with 4 control points)
    when rendering.

    You can also explicitly convert it to a list of bezier curves using
    ToRationalBezierCurves.

    Here too ControlPoints.Count MAY be 1.
    (For TControlPointsCurve it must be >= 2) }
  TSmoothInterpolatedCurve = class(TInterpolatedCurve)
  private
    BezierCurves: TRationalBezierCurveList;
    ConvexHullPoints: TVector3SingleList;
  protected
    function CreateConvexHullPoints: TVector3SingleList; override;
    procedure DestroyConvexHullPoints(Points: TVector3SingleList); override;
  public
    function Point(const t: Float): TVector3Single; override;

    { convert this to a list of TRationalBezierCurve.

      From each line segment ControlPoint[i] ... ControlPoint[i+1]
      you get one TRationalBezierCurve with 4 control points,
      where ControlPoint[0] and ControlPoint[3] are taken from
      ours ControlPoint[i] ... ControlPoint[i+1] and the middle
      ControlPoint[1], ControlPoint[2] are calculated so that all those
      bezier curves join smoothly.

      All Weights are set to 1.0 (so actually these are all normal
      Bezier curves; but I'm treating normal Bezier curves as Rational
      Bezier curves everywhere here) }
    function ToRationalBezierCurves(ResultOwnsCurves: boolean): TRationalBezierCurveList;

    procedure UpdateControlPoints; override;

    class function NiceClassName: string; override;

    constructor Create(const ATBegin, ATEnd: Float); override;
    destructor Destroy; override;
  end;

implementation

uses SysUtils, GL, GLU, CastleConvexHull, CastleGLUtils;

{ TCurve ------------------------------------------------------------ }

function TCurve.PointOfSegment(i, Segments: Cardinal): TVector3Single;
begin
 Result := Point(TBegin + (i/Segments) * (TEnd-TBegin));
end;

procedure TCurve.Render(Segments: Cardinal);
var i: Integer;
begin
  glBegin(GL_LINE_STRIP);
  for i := 0 to Segments do glVertexv(PointOfSegment(i, Segments));
  glEnd;
end;

procedure TCurve.Render(const Frustum: TFrustum;
  const Params: TRenderParams);
begin
  if GetExists and (not Params.Transparent) and Params.ShadowVolumesReceivers then
  begin
    if not Params.RenderTransformIdentity then
    begin
      glPushMatrix;
      glMultMatrix(Params.RenderTransform);
    end;

    Render(DefaultSegments);

    if not Params.RenderTransformIdentity then
      glPopMatrix;
  end;
end;

constructor TCurve.Create(const ATBegin, ATEnd: Float);
begin
 inherited Create(nil);
 FTBegin := ATBegin;
 FTEnd := ATEnd;
 FDefaultSegments := 10;
end;

{ TCasScriptCurve ------------------------------------------------------------ }

function TCasScriptCurve.Point(const t: Float): TVector3Single;
begin
  TVariable.Value := t;
  Result[0] := (XFunction.Execute as TCasScriptFloat).Value;
  Result[1] := (YFunction.Execute as TCasScriptFloat).Value;
  Result[2] := (ZFunction.Execute as TCasScriptFloat).Value;

 {test: Writeln('Point at t = ',FloatToNiceStr(Single(t)), ' is (',
   VectorToNiceStr(Result), ')');}
end;

function TCasScriptCurve.BoundingBox: TBox3D;
begin
 Result := FBoundingBox;
end;

constructor TCasScriptCurve.Create(const ATBegin, ATEnd: Float;
  AXFunction, AYFunction, AZFunction: TCasScriptExpression;
  ATVariable: TCasScriptFloat;
  ASegmentsForBoundingBox: Cardinal);
var i, k: Integer;
    P: TVector3Single;
begin
 inherited Create(ATBegin, ATEnd);
 FXFunction := AXFunction;
 FYFunction := AYFunction;
 FZFunction := AZFunction;
 FTVariable := ATVariable;

 { calculate FBoundingBox }
 P := PointOfSegment(0, ASegmentsForBoundingBox); { = Point(TBegin) }
 FBoundingBox.Data[0] := P;
 FBoundingBox.Data[1] := P;
 for i := 1 to ASegmentsForBoundingBox do
 begin
  P := PointOfSegment(i, ASegmentsForBoundingBox);
  for k := 0 to 2 do
  begin
   FBoundingBox.Data[0, k] := Min(FBoundingBox.Data[0, k], P[k]);
   FBoundingBox.Data[1, k] := Max(FBoundingBox.Data[1, k], P[k]);
  end;
 end;
end;

destructor TCasScriptCurve.Destroy;
begin
 FXFunction.FreeByParentExpression;
 FYFunction.FreeByParentExpression;
 FZFunction.FreeByParentExpression;
 inherited;
end;

{ TControlPointsCurve ------------------------------------------------ }

procedure TControlPointsCurve.RenderControlPoints;
var i: Integer;
begin
 glBegin(GL_POINTS);
 for i := 0 to ControlPoints.Count-1 do glVertexv(ControlPoints.L[i]);
 glEnd;
end;

function TControlPointsCurve.BoundingBox: TBox3D;
begin
 Result := FBoundingBox;
end;

procedure TControlPointsCurve.UpdateControlPoints;
begin
 FBoundingBox := CalculateBoundingBox(PVector3Single(ControlPoints.List),
   ControlPoints.Count, 0);
end;

function TControlPointsCurve.CreateConvexHullPoints: TVector3SingleList;
begin
 Result := ControlPoints;
end;

procedure TControlPointsCurve.DestroyConvexHullPoints(Points: TVector3SingleList);
begin
end;

procedure TControlPointsCurve.RenderConvexHull;
var CHPoints: TVector3SingleList;
    CH: TIntegerList;
    i: Integer;
begin
 CHPoints := CreateConvexHullPoints;
 try
  CH := ConvexHull(CHPoints);
  try
   glBegin(GL_POLYGON);
   try
    for i := 0 to CH.Count-1 do
     glVertexv(CHPoints.L[CH[i]]);
   finally glEnd end;
  finally CH.Free end;
 finally DestroyConvexHullPoints(CHPoints) end;
end;

constructor TControlPointsCurve.Create(const ATBegin, ATEnd: Float);
begin
 inherited Create(ATBegin, ATEnd);
 ControlPoints := TVector3SingleList.Create;
 { DON'T call UpdateControlPoints from here - UpdateControlPoints is virtual !
   So we set FBoundingBox by hand. }
 FBoundingBox := EmptyBox3D;
end;

constructor TControlPointsCurve.CreateDivideCasScriptCurve(
  CasScriptCurve: TCasScriptCurve; ControlPointsCount: Cardinal);
var i: Integer;
begin
 Create(CasScriptCurve.TBegin, CasScriptCurve.TEnd);
 ControlPoints.Count := ControlPointsCount;
 for i := 0 to ControlPointsCount-1 do
  ControlPoints.L[i] := CasScriptCurve.PointOfSegment(i, ControlPointsCount-1);
 UpdateControlPoints;
end;

destructor TControlPointsCurve.Destroy;
begin
 FreeAndNil(ControlPoints);
 inherited;
end;

{ TInterpolatedCurve ----------------------------------------------- }

function TInterpolatedCurve.ControlPointT(i: Integer): Float;
begin
 Result := TBegin + (i/(ControlPoints.Count-1)) * (TEnd-TBegin);
end;

{ TLagrangeInterpolatedCurve ----------------------------------------------- }

procedure TLagrangeInterpolatedCurve.UpdateControlPoints;
var i, j, k, l: Integer;
begin
 inherited;

 for i := 0 to 2 do
 begin
  Newton[i].Count := ControlPoints.Count;
  for j := 0 to ControlPoints.Count-1 do
   Newton[i].L[j] := ControlPoints.L[j, i];

  { licz kolumny tablicy ilorazow roznicowych in place, overriding Newton[i] }
  for k := 1 to ControlPoints.Count-1 do
   { licz k-ta kolumne }
   for l := ControlPoints.Count-1 downto k do
    { licz l-ty iloraz roznicowy w k-tej kolumnie }
    Newton[i].L[l]:=
      (Newton[i].L[l] - Newton[i].L[l-1]) /
      (ControlPointT(l) - ControlPointT(l-k));
 end;
end;

function TLagrangeInterpolatedCurve.Point(const t: Float): TVector3Single;
var i, k: Integer;
    f: Float;
begin
 for i := 0 to 2 do
 begin
  { Oblicz F przy pomocy uogolnionego schematu Hornera z Li(t).
    Wspolczynniki b_k sa w tablicy Newton[i].L[k],
    wartosci t_k sa w ControlPointT(k). }
  F := Newton[i].L[ControlPoints.Count-1];
  for k := ControlPoints.Count-2 downto 0 do
   F := F*(t-ControlPointT(k)) + Newton[i].L[k];
  { Dopiero teraz przepisz F do Result[i]. Dzieki temu obliczenia wykonujemy
    na Floatach. Tak, to naprawde pomaga -- widac ze kiedy uzywamy tego to
    musimy miec wiecej ControlPoints zeby dostac Floating Point Overflow. }
  Result[i] := F;
 end;
end;

class function TLagrangeInterpolatedCurve.NiceClassName: string;
begin
 Result := 'Lagrange interpolated curve';
end;

constructor TLagrangeInterpolatedCurve.Create(const ATBegin, ATEnd: Float);
var i: Integer;
begin
 inherited Create(ATBegin, ATEnd);
 for i := 0 to 2 do Newton[i] := TFloatList.Create;
end;

destructor TLagrangeInterpolatedCurve.Destroy;
var i: Integer;
begin
 for i := 0 to 2 do FreeAndNil(Newton[i]);
 inherited;
end;

{ TNaturalCubicSpline -------------------------------------------------------- }

constructor TNaturalCubicSpline.Create(X, Y: TFloatList;
  AOwnsX, AOwnsY, APeriodic: boolean);

{ Based on SLE (== Stanislaw Lewanowicz) notes on ii.uni.wroc.pl lecture. }

var
  { n = X.High. Integer, not Cardinal, to avoid some overflows in n-2. }
  n: Integer;

  { [Not]PeriodicDK licza wspolczynnik d_k. k jest na pewno w [1; n-1] }
  function PeriodicDK(k: Integer): Float;
  var h_k: Float;
      h_k1: Float;
  begin
   h_k  := X[k] - X[k-1];
   h_k1 := X[k+1] - X[k];
   Result := ( 6 / (h_k + h_k1) ) *
             ( (Y[k+1] - Y[k]) / h_k1 -
               (Y[k] - Y[k-1]) / h_k
             );
  end;

  { special version, works like PeriodicDK(n) should work
    (but does not, PeriodicDK works only for k < n.) }
  function PeriodicDN: Float;
  var h_n: Float;
      h_n1: Float;
  begin
   h_n  := X[n] - X[n-1];
   h_n1 := X[1] - X[0];
   Result := ( 6 / (h_n + h_n1) ) *
             ( (Y[1] - Y[n]) / h_n1 -
               (Y[n] - Y[n-1]) / h_n
             );
  end;

  function IlorazRoznicowy(const Start, Koniec: Cardinal): Float;
  { liczenie pojedynczego ilorazu roznicowego wzorem rekurencyjnym.
    Poniewaz do algorytmu bedziemy potrzebowali tylko ilorazow stopnia 3
    (lub mniej) i to tylko na chwile - wiec taka implementacja
    (zamiast zabawa w tablice) bedzie prostsza i wystarczajaca. }
  begin
   if Start = Koniec then
    Result := Y[Start] else
    Result := (IlorazRoznicowy(Start + 1, Koniec) -
               IlorazRoznicowy(Start, Koniec - 1))
               / (X[Koniec] - X[Start]);
  end;

  function NotPeriodicDK(k: Integer): Float;
  begin
   Result := 6 * IlorazRoznicowy(k-1, k+1);
  end;

var u, q, s, t, v: TFloatList;
    hk, dk, pk, delta_k, delta_n, h_n, h_n1: Float;
    k: Integer;
begin
 inherited Create;
 Assert(X.Count = Y.Count);
 FMinX := X.First;
 FMaxX := X.Last;
 FOwnsX := AOwnsX;
 FOwnsY := AOwnsY;
 FX := X;
 FY := Y;
 FPeriodic := APeriodic;

 { prepare to calculate M }
 n := X.Count - 1;
 M := TFloatList.Create;
 M.Count := n+1;

 { Algorytm obliczania wartosci M[0..n] z notatek SLE, te same oznaczenia.
   Sa tutaj polaczone algorytmy na Periodic i not Perdiodic, zeby mozliwie
   nie duplikowac kodu (i uniknac pomylek z copy&paste).
   Tracimy przez to troche czasu (wielokrotne testy "if Periodic ..."),
   ale kod jest prostszy i bardziej elegancki.

   Notka: W notatkach SLE dla Periodic = true w jednym miejscu uzyto
   M[n+1] ale tak naprawde nie musimy go liczyc ani uzywac. }

 u := nil;
 q := nil;
 s := nil;
 try
  u := TFloatList.Create; U.Count := N;
  q := TFloatList.Create; Q.Count := N;
  if Periodic then begin s := TFloatList.Create; S.Count := N; end;

  { calculate u[0], q[0], s[0] }
  u[0] := 0;
  q[0] := 0;
  if Periodic then s[0] := 1;

  for k := 1 to n - 1 do
  begin
   { calculate u[k], q[k], s[k] }

   hk := X[k] - X[k-1];
   { delta[k] = h[k] / (h[k] + h[k+1])
              = h[k] / (X[k] - X[k-1] + X[k+1] - X[k])
              = h[k] / (X[k+1] - X[k-1])
   }
   delta_k := hk / (X[k+1] - X[k-1]);
   pk := delta_k * q[k-1] + 2;
   q[k]:=(delta_k - 1) / pk;
   if Periodic then s[k] := - delta_k * s[k-1] / pk;
   if Periodic then
    dk := PeriodicDK(k) else
    dk := NotPeriodicDK(k);
   u[k]:=(dk - delta_k * u[k-1]) / pk;
  end;

  { teraz wyliczamy wartosci M[0..n] }
  if Periodic then
  begin
   t := nil;
   v := nil;
   try
    t := TFloatList.Create; T.Count := N + 1;
    v := TFloatList.Create; V.Count := N + 1;

    t[n] := 1;
    v[n] := 0;

    { z notatek SLE wynika ze t[0], v[0] nie sa potrzebne (i k moze robic
      "downto 1" zamiast "downto 0") ale t[0], v[0] MOGA byc potrzebne:
      przy obliczaniu M[n] dla n = 1. }
    for k := n-1 downto 0 do
    begin
     t[k] := q[k] * t[k+1] + s[k];
     v[k] := q[k] * v[k+1] + u[k];
    end;

    h_n  := X[n] - X[n-1];
    h_n1 := X[1] - X[0];
    delta_n := h_n / (h_n + h_n1);
    M[n] := (PeriodicDN - (1-delta_n) * v[1] - delta_n * v[n-1]) /
            (2          + (1-delta_n) * t[1] + delta_n * t[n-1]);
    M[0] := M[n];
    for k := n-1 downto 1 do  M[k] := v[k] + t[k] * M[n];
   finally
    t.Free;
    v.Free;
   end;
  end else
  begin
   { zawsze M[0] = M[n] = 0, zeby latwo bylo zapisac obliczenia w Evaluate }
   M[0] := 0;
   M[n] := 0;
   M[n-1] := u[n-1];
   for k := n-2 downto 1 do M[k] := u[k] + q[k] * M[k+1];
  end;
 finally
  u.Free;
  q.Free;
  s.Free;
 end;
end;

destructor TNaturalCubicSpline.Destroy;
begin
 if FOwnsX then FX.Free;
 if FOwnsY then FY.Free;
 M.Free;
 inherited;
end;

function TNaturalCubicSpline.Evaluate(x: Float): Float;

  function Power3rd(const a: Float): Float;
  begin
   Result := a * a * a;
  end;

var k, KMin, KMax, KMiddle: Cardinal;
    hk: Float;
begin
 Clamp(x, MinX, MaxX);

 { calculate k: W ktorym przedziale x[k-1]..x[k] jest argument ?
   TODO: nalezoloby pomyslec o wykorzystaniu faktu
   ze czesto wiadomo iz wezly x[i] sa rownoodlegle. }
 KMin := 1;
 KMax := FX.Count - 1;
 repeat
  KMiddle:=(KMin + KMax) div 2;
  { jak jest ulozony x w stosunku do przedzialu FX[KMiddle-1]..FX[KMiddle] ? }
  if x < FX[KMiddle-1] then KMax := KMiddle-1 else
   if x > FX[KMiddle] then KMin := KMiddle+1 else
    begin
     KMin := KMiddle; { set only KMin, KMax is meaningless from now }
     break;
    end;
 until KMin = KMax;

 k := KMin;

 Assert(Between(x, FX[k-1], FX[k]));

 { obliczenia uzywaja tych samych symboli co w notatkach SLE }
 { teraz obliczam wartosc s(x) gdzie s to postac funkcji sklejanej
   na przedziale FX[k-1]..FX[k] }
 hk := FX[k] - FX[k-1];
 Result := ( ( M[k-1] * Power3rd(FX[k] - x) + M[k] * Power3rd(x - FX[k-1]) )/6 +
             ( FY[k-1] - M[k-1]*Sqr(hk)/6 )*(FX[k] - x)                        +
             ( FY[k]   - M[k  ]*Sqr(hk)/6 )*(x - FX[k-1])
           ) / hk;
end;

{ TNaturalCubicSplineCurve_Abstract ------------------------------------------- }

procedure TNaturalCubicSplineCurve_Abstract.UpdateControlPoints;
var i, j: Integer;
    SplineX, SplineY: TFloatList;
begin
 inherited;

 { calculate SplineX.
   Spline[0] and Spline[1] and Spline[2] will share the same reference to X.
   Only Spline[2] will own SplineX. (Spline[2] will be always Freed as the
   last one, so it's safest to set OwnsX in Spline[2]) }
 SplineX := TFloatList.Create;
 SplineX.Count := ControlPoints.Count;
 for i := 0 to ControlPoints.Count-1 do SplineX[i] := ControlPointT(i);

 for i := 0 to 2 do
 begin
  FreeAndNil(Spline[i]);

  { calculate SplineY }
  SplineY := TFloatList.Create;
  SplineY.Count := ControlPoints.Count;
  for j := 0 to ControlPoints.Count-1 do SplineY[j] := ControlPoints.L[j, i];

  Spline[i] := TNaturalCubicSpline.Create(SplineX, SplineY, i = 2, true,
    Closed);
 end;
end;

function TNaturalCubicSplineCurve_Abstract.Point(const t: Float): TVector3Single;
var i: Integer;
begin
 for i := 0 to 2 do Result[i] := Spline[i].Evaluate(t);
end;

constructor TNaturalCubicSplineCurve_Abstract.Create(const ATBegin, ATEnd: Float);
begin
 inherited Create(ATBegin, ATEnd);
end;

destructor TNaturalCubicSplineCurve_Abstract.Destroy;
var i: Integer;
begin
 for i := 0 to 2 do FreeAndNil(Spline[i]);
 inherited;
end;

{ TNaturalCubicSplineCurve -------------------------------------------------- }

class function TNaturalCubicSplineCurve.NiceClassName: string;
begin
 Result := 'Natural cubic spline curve';
end;

function TNaturalCubicSplineCurve.Closed: boolean;
begin
 Result := VectorsEqual(ControlPoints.First,
                        ControlPoints.Last);
end;

{ TNaturalCubicSplineCurveAlwaysClosed -------------------------------------- }

class function TNaturalCubicSplineCurveAlwaysClosed.NiceClassName: string;
begin
 Result := 'Natural cubic spline curve (closed)';
end;

function TNaturalCubicSplineCurveAlwaysClosed.Closed: boolean;
begin
 Result := true;
end;

{ TNaturalCubicSplineCurveNeverClosed ---------------------------------------- }

class function TNaturalCubicSplineCurveNeverClosed.NiceClassName: string;
begin
 Result := 'Natural cubic spline curve (not closed)';
end;

function TNaturalCubicSplineCurveNeverClosed.Closed: boolean;
begin
 Result := false;
end;

{ TRationalBezierCurve ----------------------------------------------- }

{$define DE_CASTELJAU_DECLARE:=
var
  W: TVector3SingleList;
  Wgh: TFloatList;
  i, k, n, j: Integer;}

{ This initializes W and Wgh (0-th step of de Casteljau algorithm).
  It uses ControlPoints, Weights. }
{$define DE_CASTELJAU_BEGIN:=
  n := ControlPoints.Count - 1;

  W := nil;
  Wgh := nil;
  try
    // using nice FPC memory manager should make this memory allocating
    // (in each call to Point) painless. So I don't care about optimizing
    // this by moving W to private class-scope.
    W := TVector3SingleList.Create;
    W.Assign(ControlPoints);
    Wgh := TFloatList.Create;
    Wgh.Assign(Weights);
}

{ This caculates in W and Wgh k-th step of de Casteljau algorithm.
  This assumes that W and Wgh already contain (k-1)-th step.
  Uses u as the target point position (in [0; 1]) }
{$define DE_CASTELJAU_STEP:=
begin
  for i := 0 to n - k do
  begin
    for j := 0 to 2 do
      W.L[i][j]:=(1-u) * Wgh[i  ] * W.L[i  ][j] +
                         u * Wgh[i+1] * W.L[i+1][j];
    Wgh.L[i]:=(1-u) * Wgh[i] + u * Wgh[i+1];
    for j := 0 to 2 do
      W.L[i][j] /= Wgh.L[i];
  end;
end;}

{ This frees W and Wgh. }
{$define DE_CASTELJAU_END:=
  finally
    Wgh.Free;
    W.Free;
  end;}

procedure TRationalBezierCurve.Split(const Proportion: Float; var B1, B2: TRationalBezierCurve);
var TMiddle, u: Float;
DE_CASTELJAU_DECLARE
begin
  TMiddle := TBegin + Proportion * (TEnd - TBegin);
  B1 := TRationalBezierCurve.Create(TBegin, TMiddle);
  B2 := TRationalBezierCurve.Create(TMiddle, TEnd);
  B1.ControlPoints.Count := ControlPoints.Count;
  B2.ControlPoints.Count := ControlPoints.Count;
  B1.Weights.Count := Weights.Count;
  B2.Weights.Count := Weights.Count;

  { now we do Casteljau algorithm, similiar to what we do in Point.
    But this time our purpose is to update B1.ControlPoints/Weights and
    B2.ControlPoints/Weights. }

  u := Proportion;

  DE_CASTELJAU_BEGIN
    B1.ControlPoints.L[0] := ControlPoints.L[0];
    B1.Weights      .L[0] := Wgh          .L[0];
    B2.ControlPoints.L[n] := ControlPoints.L[n];
    B2.Weights      .L[n] := Wgh          .L[n];

    for k := 1 to n do
    begin
      DE_CASTELJAU_STEP

      B1.ControlPoints.L[k]   := W  .L[0];
      B1.Weights      .L[k]   := Wgh.L[0];
      B2.ControlPoints.L[n-k] := W  .L[n-k];
      B2.Weights      .L[n-k] := Wgh.L[n-k];
    end;
  DE_CASTELJAU_END
end;

function TRationalBezierCurve.Point(const t: Float): TVector3Single;
var
  u: Float;
DE_CASTELJAU_DECLARE
begin
  { u := t normalized to [0; 1] }
  u := (t - TBegin) / (TEnd - TBegin);

  DE_CASTELJAU_BEGIN
    for k := 1 to n do DE_CASTELJAU_STEP
    Result := W.L[0];
  DE_CASTELJAU_END
end;

class function TRationalBezierCurve.NiceClassName: string;
begin
  Result := 'Rational Bezier curve';
end;

procedure TRationalBezierCurve.UpdateControlPoints;
begin
  inherited;
  Assert(Weights.Count = ControlPoints.Count);
end;

constructor TRationalBezierCurve.Create(const ATBegin, ATEnd: Float);
begin
  inherited;
  Weights := TFloatList.Create;
  Weights.Count := ControlPoints.Count;
end;

destructor TRationalBezierCurve.Destroy;
begin
  Weights.Free;
  inherited;
end;

{ TSmoothInterpolatedCurve ------------------------------------------------------------ }

function TSmoothInterpolatedCurve.CreateConvexHullPoints: TVector3SingleList;
begin
  Result := ConvexHullPoints;
end;

procedure TSmoothInterpolatedCurve.DestroyConvexHullPoints(Points: TVector3SingleList);
begin
end;

function TSmoothInterpolatedCurve.Point(const t: Float): TVector3Single;
var
  i: Integer;
begin
  if ControlPoints.Count = 1 then
    Exit(ControlPoints.L[0]);

  for i := 0 to BezierCurves.Count-1 do
    if t <= BezierCurves[i].TEnd then Break;

  Result := BezierCurves[i].Point(t);
end;

function TSmoothInterpolatedCurve.ToRationalBezierCurves(ResultOwnsCurves: boolean): TRationalBezierCurveList;
var
  S: TVector3SingleList;

  function MiddlePoint(i, Sign: Integer): TVector3Single;
  begin
    Result := ControlPoints.L[i];
    VectorAddTo1st(Result,
      VectorScale(S.L[i], Sign * (ControlPointT(i) - ControlPointT(i-1)) / 3));
  end;

var
  C: TVector3SingleList;
  i: Integer;
  NewCurve: TRationalBezierCurve;
begin
  Result := TRationalBezierCurveList.Create(ResultOwnsCurves);
  try
    if ControlPoints.Count <= 1 then Exit;

    if ControlPoints.Count = 2 then
    begin
      { Normal calcualtions (based on SLE mmgk notes) cannot be done when
        ControlPoints.Count = 2:
        C.Count would be 1, S.Count would be 2,
        S[0] would be calculated based on C[0] and S[1],
        S[1] would be calculated based on C[0] and S[0].
        So I can't calculate S[0] and S[1] using given equations when
        ControlPoints.Count = 2. So I must implement a special case for
        ControlPoints.Count = 2. }
      NewCurve := TRationalBezierCurve.Create(ControlPointT(0), ControlPointT(1));
      NewCurve.ControlPoints.Add(ControlPoints.L[0]);
      NewCurve.ControlPoints.Add(Lerp(1/3, ControlPoints.L[0], ControlPoints.L[1]));
      NewCurve.ControlPoints.Add(Lerp(2/3, ControlPoints.L[0], ControlPoints.L[1]));
      NewCurve.ControlPoints.Add(ControlPoints.L[1]);
      NewCurve.Weights.AddArray([1.0, 1.0, 1.0, 1.0]);
      NewCurve.UpdateControlPoints;
      Result.Add(NewCurve);

      Exit;
    end;

    { based on SLE mmgk notes, "Krzywe Beziera" page 4 }
    C := nil;
    S := nil;
    try
      C := TVector3SingleList.Create;
      C.Count := ControlPoints.Count-1;
      { calculate C values }
      for i := 0 to C.Count-1 do
      begin
        C.L[i] := VectorSubtract(ControlPoints.L[i+1], ControlPoints.L[i]);
        VectorScaleTo1st(C.L[i],
          1/(ControlPointT(i+1) - ControlPointT(i)));
      end;

      S := TVector3SingleList.Create;
      S.Count := ControlPoints.Count;
      { calculate S values }
      for i := 1 to S.Count-2 do
        S.L[i] := Lerp( (ControlPointT(i+1) - ControlPointT(i))/
                            (ControlPointT(i+1) - ControlPointT(i-1)),
                            C.L[i-1], C.L[i]);
      S.L[0        ] := VectorSubtract(VectorScale(C.L[0        ], 2), S.L[1        ]);
      S.L[S.Count-1] := VectorSubtract(VectorScale(C.L[S.Count-2], 2), S.L[S.Count-2]);

      for i := 1 to ControlPoints.Count-1 do
      begin
        NewCurve := TRationalBezierCurve.Create(ControlPointT(i-1), ControlPointT(i));
        NewCurve.ControlPoints.Add(ControlPoints.L[i-1]);
        NewCurve.ControlPoints.Add(MiddlePoint(i-1, +1));
        NewCurve.ControlPoints.Add(MiddlePoint(i  , -1));
        NewCurve.ControlPoints.Add(ControlPoints.L[i]);
        NewCurve.Weights.AddArray([1.0, 1.0, 1.0, 1.0]);
        NewCurve.UpdateControlPoints;
        Result.Add(NewCurve);
      end;
    finally
      C.Free;
      S.Free;
    end;
  except Result.Free; raise end;
end;

class function TSmoothInterpolatedCurve.NiceClassName: string;
begin
  Result := 'Smooth Interpolated curve';
end;

procedure TSmoothInterpolatedCurve.UpdateControlPoints;
var
  i: Integer;
begin
  inherited;
  FreeAndNil(BezierCurves);

  BezierCurves := ToRationalBezierCurves(true);

  ConvexHullPoints.Clear;
  ConvexHullPoints.AddList(ControlPoints);
  for i := 0 to BezierCurves.Count-1 do
  begin
    ConvexHullPoints.Add(BezierCurves[i].ControlPoints.L[1]);
    ConvexHullPoints.Add(BezierCurves[i].ControlPoints.L[2]);
  end;
end;

constructor TSmoothInterpolatedCurve.Create(const ATBegin, ATEnd: Float);
begin
  inherited;
  ConvexHullPoints := TVector3SingleList.Create;
end;

destructor TSmoothInterpolatedCurve.Destroy;
begin
  FreeAndNil(BezierCurves);
  FreeAndNil(ConvexHullPoints);
  inherited;
end;

end.