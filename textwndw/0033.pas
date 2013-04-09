{****************************************************************************}
{*                                                                          *}
{*                     TEST PROGRAM AT THE BOTTOM OF FILE                   *}
{*                                                                          *}
{*                                                                          *}
{*                          VIRTUAL SCREEN UNIT                             *}
{*                                                                          *}
{*                  by Marc Oude Kotte, The Netherlands                     *}
{*                        email: TAL95@hotmail.com                          *}
{*                           i DO reply your mail!!                         *}
{****************************************************************************}

{This unit was designed to work in textmode $ and in VESAmodes $109 and $10A.
 It also should work in either Real and Protected mode. Windows support is
 of course nonsense.

 I don't know if it works in any other mode then the modes called above!

 If you use this unit in your programs, please call my name in the
 credits part of your program. I don't need any money since i never donate
 any money to other programmers myself.                             Bye!}

Unit VirtScr;

Interface

Type TRect = Record
               x1,y1,x2,y2: Integer;
             End;

     TVirtScr = Record
                  xSize, ySize: Integer; {hor and vert size of screen
                                          warning: size is handled as in:
                                            1..xSize
                                            1..ySize, NOT: 0..xSize
                                                           0..ySize!!!!!!}
                  xLoc1, yLoc1,
                  xLoc2, yLoc2: Integer;   {(x,y)-(x,y) location on screen}
                  x,y: Integer;          {current "plus"-position on screen
                                          if both values are zero, the first
                                          character in Data will be on
                                          xLoc,yLoc}
                  Data: Pointer;         {pointer to data}
                  DataSize: LongInt;     {size of data area}
                  Visible: Boolean;      {is screen visible?}
                  MaxX: Integer;         {horizontal width of current video mode}
                  MaxY: Integer;         {vertical length of current video mode}
                  CursorX, CursorY: Integer; {cursor position in window}
                  Attributes: Byte;
                End;

Function DetermineVideoMode: Byte;
{1 = normal textmode $3
 2 = vesa mode $0109
 3 = vesa mode $010A}

Procedure AssignTRect(var R: TRect;
                      x1, y1, x2, y2: Integer);
{place values into a TRect variable}

Procedure AssignTVirtScr(var V: TVirtScr;
                         xSize, ySize: Integer;
                         xLoc1, yLoc1, xLoc2, yLoc2: Integer;
                         x,y: Integer;
                         Data: Pointer;
                         Visible: Boolean);
{place values into a TVirtScr variable, does NOT init it!!!}

Procedure InitVirtualScreen(var V: TVirtScr);
{init the virtual screen: values are placed into certain variables}

Procedure DrawVirtualScreen(var V: TVirtScr);
{draws the virtual screen: you don't have to call this procedure all the
 time, the unit does it when you write(ln) something or when you init
 the screen or when you make it (in)visible}

Procedure VS_ClrScr(var V: TVirtScr);
{same as CRT proc ClrScr --> clears screen with current textbackground}

Procedure VS_ClrWindow(var V: TVirtScr; x1,y1,x2,y2: Integer);
{clears the defined window with current textbackground}

Procedure VS_GotoXY(var V: TVirtScr; ToX,ToY: Integer);
{same as CRT proc GotoXY --> moves CP to ToX,ToY.
Values must be 0 < ToX,ToY < Size+1}

Procedure VS_Write(var V: TVirtScr; s: String);
{same as proc Write --> writes string s, no CRLF}

Procedure VS_WriteLn(var V: TVirtScr; s: String);
{same as proc Write --> writes string s + CRLF}

Procedure VS_TextColor(var V: TVirtScr; Color: Byte);
{same as CRT proc TextColor --> sets text color}

Procedure VS_TextBackGround(var V: TVirtScr; Color: Byte);
{same as CRT proc TextBackGround --> sets textbackground color}

Procedure VS_Move(var V: TVirtScr; Right,Down: Integer);
{moves x,y right/down positions in virt screen
 If you call VS_Move(V,1,2) the virtual screen on your real screen will move
 one to the left and 2 up!!!}

Procedure VS_MoveTo(var V: TVirtScr; ToX,ToY: Integer);
{moves x,y to position ToX, ToY in virt screen}

Procedure VS_SetVisibility(var V: TVirtScr; Visible: Boolean);
{sets the visibility of a virtuals screen}

Procedure VS_ScreenDump(var V: TVirtScr; fn: String);
{makes a complete virtual screen dump into a file}

Procedure DrawWindow(x1,y1,x2,y2,Lines: Byte);
{extra proc: draws windows. Lines=1 --> �
                            Lines=2 --> �}

Procedure CursorOff;
  Inline($B4/$01/$B7/$00/$B9/$1E/$1F/$CD/$10);

Procedure CursorOn;
  Inline($B4/$01/$B7/$00/$B9/$07/$06/$CD/$10);

Implementation

Uses Crt;

Var VidMem: Pointer; {pointer to video memory}

Procedure FastMove(Var source; Var dest; NumToMove : Word);
{This procedure ain't mine, but i don't know who made it... sorry
 The reasen i use it is that it's �1.6 times faster then Pascal's Move}
Begin
  InLine ($8C/$DA/$C5/$B6/> Source/$C4/$BE/> Dest/$8B/$8E/> NumToMove/
          $39/$FE/$72/$08/$FC/$D1/$E9/$73/$11/$A4/$EB/$0E/$FD/$01/$CE/
          $4E/$01/$CF/$4F/$D1/$E9/$73/$01/$A4/$4E/$4F/$F2/$A5/$8E/$DA);
End;

Function DetermineVideoMode: Byte;
Var Mode: Byte;
Begin
  Mode:=1;
  Asm
    mov ax, $4F03    {function $4F, subfunction 03: get SVGA mode}
    int $10          {call interrupt 16}
    cmp bx, $0109    {bx=$0109?}
    jnz @Try010A     {no? goto Try010A}
    mov Mode, 2      {mode = 2}
    jmp @End         {goto end}

   @Try010A:
    cmp bx, $010A    {bx=$010A?}
    jnz @End         {no? goto End --> no vesa text mode --> mode = 1}
    mov Mode, 3      {mode = 3}

   @End:
  End;
  DetermineVideoMode:=Mode;
End;

Procedure AssignTRect(var R: TRect; x1, y1, x2, y2: Integer);
Begin
  R.x1:=x1; R.y1:=y1; R.x2:=x2; R.y2:=y2;
End;

Procedure AssignTVirtScr(var V: TVirtScr; xSize, ySize, xLoc1, yLoc1, xLoc2, yLoc2, x ,y: Integer;
                         Data: Pointer; Visible: Boolean);
Begin
  V.xSize:=xSize; V.ySize:=ySize;
  V.xLoc1:=xLoc1; V.yLoc1:=yLoc1;
  V.xLoc2:=xLoc2; V.yLoc2:=yLoc2;
  V.x:=x;         V.y:=y;
  V.Data:=Data;   V.Visible:=Visible;
End;

Procedure InitVirtualScreen(var V: TVirtScr);
Begin
  With V Do
    Begin
      CursorX:=1;
      CursorY:=1;
      DataSize:=xSize; DataSize:=DataSize*ySize; DataSize:=DataSize*2;
      GetMem(Data, DataSize);
      FillChar(Data^, DataSize, 0);
      Attributes:=7;
      Case DetermineVideoMode Of
        1: Begin MaxX:=80;  MaxY:=25; End;
        2: Begin MaxX:=132; MaxY:=25; End;
        3: Begin MaxX:=132; MaxY:=43; End;
      End;
    End;
  DrawVirtualScreen(V);
End;

Procedure DrawVirtualScreen(var V: TVirtScr);
Var xBytesToDraw :Integer;
    yLinesToDraw :Integer;
    yTemp        :Integer;
Begin
 If V.Visible Then
  With V Do
    Begin
      xBytesToDraw:=(xLoc2-xLoc1)+1;
      If xBytesToDraw>xSize Then xBytesToDraw:=xSize;
      xBytesToDraw:=xBytesToDraw*2; {1 byte for char, 1 byte for attribs}
      yLinesToDraw:=(yLoc2-yLoc1)+1;
      If yLinesToDraw>ySize Then yLinesToDraw:=ySize;

      For yTemp:=0 To yLinesToDraw-1 Do
       Begin
        FastMove( Mem[Seg(Data^):Ofs(Data^) + (2*x + y*2*xSize) + (yTemp*2*xSize)],
                  Mem[Seg(VidMem^):Ofs(VidMem^) + 2*(xLoc1-1) + (yTemp+yLoc1-1)*2*MaxX],
                  xBytesToDraw);
       End;
    End;
End;

Procedure VS_ClrScr(var V: TVirtScr);
Var t: LongInt;
    w: LongInt;
    x: LongInt;
Begin
  With V Do
    Begin
      w:=(xSize*ySize) - 1;
      For t:=0 To w Do
        Begin
          Mem[Seg(Data^):Ofs(Data^)+2*t]:=32;
          Mem[Seg(Data^):Ofs(Data^)+2*t + 1]:=Attributes;
        End;
    End;
  DrawVirtualScreen(V);
End;

Procedure VS_ClrWindow(var V: TVirtScr; x1,y1,x2,y2: Integer);
Var t: LongInt;
    w: LongInt;
Begin
  With V Do
    For t:=y1-1 To y2-1 Do
      For w:=x1-1 To x2-1 Do
        Begin
          Mem[Seg(Data^):Ofs(Data^) + 2 * (t*xSize + w)]:=32;
          Mem[Seg(Data^):Ofs(Data^) + 2 * (t*xSize + w) + 1]:=Attributes;
        End;

  DrawVirtualScreen(V);
End;

Procedure VS_GotoXY(var V: TVirtScr; ToX,ToY: Integer);
Begin
  With V Do
    Begin
      If (ToX>=1) and (ToX<=xSize) Then CursorX:=ToX;
      If (ToY>=1) and (ToY<=ySize) Then CursorY:=ToY;
    End;
End;

Procedure VS_Write(var V: TVirtScr; s: String);
Var t: Byte;
    w: Word;
Begin
  With V Do
    Begin
      For t:=1 To Length(s) Do
        Begin
          w:=Ofs(Data^) + 2*(CursorX - 1 + (CursorY-1)*xSize );
          Mem[Seg(Data^):w]:=Ord(s[t]);
          Mem[Seg(Data^):w+1]:=Attributes;
          Inc(CursorX);
        End;

      While CursorX>xSize Do Begin Dec(CursorX, xSize); Inc(CursorY); End;
      If CursorY>ySize Then CursorY:=ySize;
    End;
  DrawVirtualScreen(V);
End;

Procedure VS_WriteLn(var V: TVirtScr; s: String);
Var t: Byte;
    w: Word;
Begin
  With V Do
    Begin
      For t:=1 To Length(s) Do
        Begin
          w:=Ofs(Data^) + 2*(CursorX - 1 + (CursorY-1)*xSize );
          Mem[Seg(Data^):w]:=Ord(s[t]);
          Mem[Seg(Data^):w + 1]:=Attributes;
          Inc(CursorX);
        End;

      While CursorX>xSize Do Begin Dec(CursorX, xSize); Inc(CursorY); End;
      Inc(CursorY); {LF}
      CursorX:=1;   {CR}
      If CursorY>ySize Then CursorY:=ySize;
    End;
  DrawVirtualScreen(V);
End;

Procedure VS_TextColor(var V: TVirtScr; Color: Byte);
Begin
  V.Attributes:=V.Attributes shr 4;
  V.Attributes:=V.Attributes shl 4;
  V.Attributes:=V.Attributes or Color;
End;

Procedure VS_TextBackGround(var V: TVirtScr; Color: Byte);
Begin
  V.Attributes:=V.Attributes shl 4;
  V.Attributes:=V.Attributes shr 4;
  V.Attributes:=V.Attributes or (Color shl 4);
End;

Procedure VS_Move(var V: TVirtScr; Right,Down: Integer);
Var Oldx, Oldy: Integer;
Begin
  With V Do
    Begin
      Oldx:=x;
      Oldy:=y;
      Inc(x, Right);
      Inc(y, Down);
      If x>xSize-(xLoc2-xLoc1+1) Then x:=xSize-(xLoc2-xLoc1+1);
      If y>ySize-(yLoc2-yLoc1+1) Then y:=ySize-(yLoc2-yLoc1+1);
      If x<0 Then x:=0;
      If y<0 Then y:=0;
    End;
  If (v.x<>Oldx) or (v.y<>Oldy) Then DrawVirtualScreen(V);
End;

Procedure VS_MoveTo(var V: TVirtScr; ToX, ToY: Integer);
Begin
  With V Do
    Begin
      x:=ToX;
      y:=ToY;
      If x>xSize-(xLoc2-xLoc1+1) Then x:=xSize-(xLoc2-xLoc1+1);
      If y>ySize-(yLoc2-yLoc1+1) Then y:=ySize-(yLoc2-yLoc1+1);
      If x<0 Then x:=0;
      If y<0 Then y:=0;
    End;
  DrawVirtualScreen(V);
End;

Procedure VS_SetVisibility(var V: TVirtScr; Visible: Boolean);
Begin
  V.Visible:=Visible;
  DrawVirtualScreen(V);
End;

Procedure VS_ScreenDump(var V: TVirtScr; fn: String);
Var f: File;
    w: Word;
Begin
  Assign(f, fn);
  {$I-} ReWrite(f, 1); {$I+}
  If IOResult=0 Then
    Begin
      BlockWrite(f, V.Data^, V.DataSize, w);
      Close(f);
    End;
End;

Procedure DrawWindow(x1,y1,x2,y2,Lines: Byte);
Var x,y: Byte;
    lb,rb,lo,ro,vert,hor: Char;
Begin
  Case Lines Of
    1: Begin lb:='�'; rb:='�'; lo:='�'; ro:='�'; vert:='�'; hor:='�'; End;
    2: Begin lb:='�'; rb:='�'; lo:='�'; ro:='�'; vert:='�'; hor:='�'; End;
    Else Begin lb:=' '; rb:=' '; lo:=' '; ro:=' '; vert:=' '; hor:=' ';End;
  End;
  GotoXY(x1,y1); Write(lb); For x:=x1+1 To x2-1 Do Write(hor); Write(rb);
  For y:=y1+1 To y2-1 Do Begin GotoXY(x1,y); Write(vert); GotoXY(x2,y); Write(vert); End;
  GotoXY(x1,y2); Write(lo); For x:=x1+1 To x2-1 Do Write(hor); Write(ro);
End;


Var w: String;
Begin
  w:='--== VIRTUAL SCREEN UNIT by Marc Oude Kotte ==--';
  VidMem:=Ptr(SegB800,0);
End.

{***********************************TEST PROGRAM****************************}

Program TestProgram; {for VirtScr Unit}
Uses Mouse, Crt, VirtScr;
Var V: TVirtScr;
Const NC : Array[1..4000] Of Char = (
#32,#7,#32,#112,#70,#116,#105,#112,#108,#112,#101,#112,#32,#112,
#32,#112,#69,#116,#100,#112,#105,#112,#116,#112,#32,#112,#32,#112,#83,
#116,#101,#112,#97,#112,#114,#112,#99,#112,#104,#112,#32,#112,#32,#112,
#82,#116,#117,#112,#110,#112,#32,#112,#32,#112,#67,#116,#111,#112,#109,
#112,#112,#112,#105,#112,#108,#112,#101,#112,#32,#112,#32,#112,#68,#116,
#101,#112,#98,#112,#117,#112,#103,#112,#32,#112,#32,#112,#84,#116,#111,
#112,#111,#112,#108,#112,#115,#112,#32,#112,#32,#112,#79,#116,#112,#112,
#116,#112,#105,#112,#111,#112,#110,#112,#115,#112,#32,#112,#32,#112,#87,
#116,#105,#112,#110,#112,#100,#112,#111,#112,#119,#112,#32,#112,#32,#112,
#72,#116,#101,#112,#108,#112,#112,#112,#32,#112,#32,#112,#32,#112,#32,
#112,#32,#112,#32,#112,#32,#112,#32,#112,#32,#112,#201,#31,#205,#31,
#91,#31,#254,#26,#93,#31,#205,#31,#205,#31,#205,#31,#205,#31,#205,
#31,#205,#31,#205,#31,#205,#31,#205,#31,#205,#31,#205,#31,#205,#31,
#205,#31,#205,#31,#205,#31,#205,#31,#205,#31,#205,#31,#32,#31,#92,
#31,#66,#31,#80,#31,#92,#31,#80,#31,#65,#31,#83,#31,#70,#31,
#73,#31,#76,#31,#69,#31,#83,#31,#92,#31,#86,#31,#73,#31,#82,
#31,#84,#31,#83,#31,#67,#31,#82,#31,#92,#31,#86,#31,#73,#31,
#82,#31,#84,#31,#83,#31,#67,#31,#82,#31,#46,#31,#80,#31,#65,
#31,#83,#31,#32,#31,#205,#31,#205,#31,#205,#31,#205,#31,#205,#31,
#205,#31,#205,#31,#205,#31,#205,#31,#205,#31,#205,#31,#205,#31,#205,
#31,#205,#31,#205,#31,#205,#31,#49,#31,#205,#31,#91,#31,#18,#26,
#93,#31,#205,#31,#187,#31,#186,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#49,#31,#58,#31,#32,#31,#66,#28,#101,#28,#103,#28,#105,#28,
#110,#28,#32,#31,#108,#31,#98,#31,#58,#31,#61,#31,#39,#27,#218,
#27,#39,#27,#59,#31,#32,#31,#114,#31,#98,#31,#58,#31,#61,#31,
#39,#27,#191,#27,#39,#27,#59,#31,#32,#31,#108,#31,#111,#31,#58,
#31,#61,#31,#39,#27,#192,#27,#39,#27,#59,#31,#32,#31,#114,#31,
#111,#31,#58,#31,#61,#31,#39,#27,#217,#27,#39,#27,#59,#31,#32,
#31,#118,#31,#101,#31,#114,#31,#116,#31,#58,#31,#61,#31,#39,#27,
#179,#27,#39,#27,#59,#31,#32,#31,#104,#31,#111,#31,#114,#31,#58,
#31,#61,#31,#39,#27,#196,#27,#39,#27,#59,#31,#32,#31,#69,#28,
#110,#28,#100,#28,#59,#31,#32,#31,#32,#31,#32,#31,#32,#31,#30,
#49,#186,#31,#32,#31,#32,#31,#32,#31,#32,#31,#50,#31,#58,#31,
#32,#31,#66,#28,#101,#28,#103,#28,#105,#28,#110,#28,#32,#31,#108,
#31,#98,#31,#58,#31,#61,#31,#39,#27,#201,#27,#39,#27,#59,#31,
#32,#31,#114,#31,#98,#31,#58,#31,#61,#31,#39,#27,#187,#27,#39,
#27,#59,#31,#32,#31,#108,#31,#111,#31,#58,#31,#61,#31,#39,#27,
#200,#27,#39,#27,#59,#31,#32,#31,#114,#31,#111,#31,#58,#31,#61,
#31,#39,#27,#188,#27,#39,#27,#59,#31,#32,#31,#118,#31,#101,#31,
#114,#31,#116,#31,#58,#31,#61,#31,#39,#27,#186,#27,#39,#27,#59,
#31,#32,#31,#104,#31,#111,#31,#114,#31,#58,#31,#61,#31,#39,#27,
#205,#27,#39,#27,#59,#31,#32,#31,#69,#28,#110,#28,#100,#28,#59,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#177,#49,#186,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#69,#28,#108,#28,#115,#28,#101,#28,#32,
#31,#66,#28,#101,#28,#103,#28,#105,#28,#110,#28,#32,#31,#108,#31,
#98,#31,#58,#31,#61,#31,#39,#27,#32,#27,#39,#27,#59,#31,#32,
#31,#114,#31,#98,#31,#58,#31,#61,#31,#39,#27,#32,#27,#39,#27,
#59,#31,#32,#31,#108,#31,#111,#31,#58,#31,#61,#31,#39,#27,#32,
#27,#39,#27,#59,#31,#32,#31,#114,#31,#111,#31,#58,#31,#61,#31,
#39,#27,#32,#27,#39,#27,#59,#31,#32,#31,#118,#31,#101,#31,#114,
#31,#116,#31,#58,#31,#61,#31,#39,#27,#32,#27,#39,#27,#59,#31,
#32,#31,#104,#31,#111,#31,#114,#31,#58,#31,#61,#31,#39,#27,#32,
#27,#39,#27,#59,#31,#69,#28,#110,#28,#100,#28,#59,#31,#32,#31,
#32,#31,#32,#31,#177,#49,#186,#31,#32,#31,#32,#31,#69,#28,#110,
#28,#100,#28,#59,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#177,
#49,#186,#31,#32,#31,#32,#31,#71,#31,#111,#31,#116,#31,#111,#31,
#88,#31,#89,#31,#40,#31,#120,#31,#49,#31,#44,#31,#121,#31,#49,
#31,#41,#31,#59,#31,#32,#31,#87,#31,#114,#31,#105,#31,#116,#31,
#101,#31,#40,#31,#108,#31,#98,#31,#41,#31,#59,#31,#32,#31,#70,
#28,#111,#28,#114,#28,#32,#31,#120,#31,#58,#31,#61,#31,#120,#31,
#49,#31,#43,#31,#49,#31,#32,#31,#84,#28,#111,#28,#32,#31,#120,
#31,#50,#31,#45,#31,#49,#31,#32,#31,#68,#28,#111,#28,#32,#31,
#87,#31,#114,#31,#105,#31,#116,#31,#101,#31,#40,#31,#104,#31,#111,
#31,#114,#31,#41,#31,#59,#31,#32,#31,#87,#31,#114,#31,#105,#31,
#116,#31,#101,#31,#40,#31,#114,#31,#98,#31,#41,#31,#59,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#177,#49,#186,#31,#32,#31,
#32,#31,#70,#28,#111,#28,#114,#28,#32,#31,#121,#31,#58,#31,#61,
#31,#121,#31,#49,#31,#43,#31,#49,#31,#32,#31,#84,#28,#111,#28,
#32,#31,#121,#31,#50,#31,#45,#31,#49,#31,#32,#31,#68,#28,#111,
#28,#32,#31,#66,#28,#101,#28,#103,#28,#105,#28,#110,#28,#32,#31,
#71,#31,#111,#31,#116,#31,#111,#31,#88,#31,#89,#31,#40,#31,#120,
#31,#49,#31,#44,#31,#121,#31,#41,#31,#59,#31,#32,#31,#87,#31,
#114,#31,#105,#31,#116,#31,#101,#31,#40,#31,#118,#31,#101,#31,#114,
#31,#116,#31,#41,#31,#59,#31,#32,#31,#71,#31,#111,#31,#116,#31,
#111,#31,#88,#31,#89,#31,#40,#31,#120,#31,#50,#31,#44,#31,#121,
#31,#41,#31,#59,#31,#32,#31,#87,#31,#114,#31,#105,#31,#116,#31,
#101,#31,#40,#31,#177,#49,#186,#31,#32,#31,#32,#31,#71,#31,#111,
#31,#116,#31,#111,#31,#88,#31,#89,#31,#40,#31,#120,#31,#49,#31,
#44,#31,#121,#31,#50,#31,#41,#31,#59,#31,#32,#31,#87,#31,#114,
#31,#105,#31,#116,#31,#101,#31,#40,#31,#108,#31,#111,#31,#41,#31,
#59,#31,#32,#31,#70,#28,#111,#28,#114,#28,#32,#31,#120,#31,#58,
#31,#61,#31,#120,#31,#49,#31,#43,#31,#49,#31,#32,#31,#84,#28,
#111,#28,#32,#31,#120,#31,#50,#31,#45,#31,#49,#31,#32,#31,#68,
#28,#111,#28,#32,#31,#87,#31,#114,#31,#105,#31,#116,#31,#101,#31,
#40,#31,#104,#31,#111,#31,#114,#31,#41,#31,#59,#31,#32,#31,#87,
#31,#114,#31,#105,#31,#116,#31,#101,#31,#40,#31,#114,#31,#111,#31,
#41,#31,#59,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#177,
#49,#186,#31,#69,#28,#110,#28,#100,#28,#59,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#177,#49,#186,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#177,#49,#186,#31,#86,#28,#97,#28,#114,#28,#32,
#31,#119,#31,#58,#31,#32,#31,#83,#28,#116,#28,#114,#28,#105,#28,
#110,#28,#103,#28,#59,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#177,
#49,#186,#31,#66,#28,#101,#28,#103,#28,#105,#28,#110,#28,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#177,#49,#186,#31,#32,#31,
#32,#31,#119,#31,#58,#31,#61,#31,#39,#27,#45,#27,#45,#27,#61,
#27,#61,#27,#32,#27,#86,#27,#73,#27,#82,#27,#84,#27,#85,#27,
#65,#27,#76,#27,#32,#27,#83,#27,#67,#27,#82,#27,#69,#27,#69,
#27,#78,#27,#32,#27,#85,#27,#78,#27,#73,#27,#84,#27,#32,#27,
#98,#27,#121,#27,#32,#27,#77,#27,#97,#27,#114,#27,#99,#27,#32,
#27,#79,#27,#117,#27,#100,#27,#101,#27,#32,#27,#75,#27,#111,#27,
#116,#27,#116,#27,#101,#27,#32,#27,#61,#27,#61,#27,#45,#27,#45,
#27,#39,#27,#59,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#177,#49,#186,#31,#32,#31,#32,#31,#86,#31,#105,
#31,#100,#31,#77,#31,#101,#31,#109,#31,#58,#31,#61,#31,#80,#31,
#116,#31,#114,#31,#40,#31,#83,#31,#101,#31,#103,#31,#66,#31,#56,
#31,#48,#31,#48,#31,#44,#31,#48,#31,#41,#31,#59,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#177,
#49,#186,#31,#69,#28,#110,#28,#100,#28,#46,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#177,#49,#186,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#177,#49,#186,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#177,
#49,#186,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#177,#49,#186,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#177,#49,#186,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#254,
#49,#186,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#177,#49,#186,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,
#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,#32,#31,
#32,#31,#32,#31,#31,#49,#200,#31,#205,#31,#205,#31,#205,#31,#205,
#31,#205,#31,#32,#31,#51,#31,#53,#31,#49,#31,#58,#31,#49,#31,
#32,#31,#205,#31,#205,#31,#205,#31,#205,#31,#205,#31,#17,#49,#254,
#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,
#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,
#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,
#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,
#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,
#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,
#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,
#177,#49,#177,#49,#177,#49,#177,#49,#177,#49,#16,#49,#196,#26,#217,
#26,#32,#112,#70,#116,#49,#116,#32,#112,#72,#112,#101,#112,#108,#112,
#112,#112,#32,#112,#32,#112,#70,#116,#50,#116,#32,#112,#83,#112,#97,
#112,#118,#112,#101,#112,#32,#112,#32,#112,#70,#116,#51,#116,#32,#112,
#79,#112,#112,#112,#101,#112,#110,#112,#32,#112,#32,#112,#65,#116,#108,
#116,#116,#116,#43,#116,#70,#116,#57,#116,#32,#112,#67,#112,#111,#112,
#109,#112,#112,#112,#105,#112,#108,#112,#101,#112,#32,#112,#32,#112,#70,
#116,#57,#116,#32,#112,#77,#112,#97,#112,#107,#112,#101,#112,#32,#112,
#32,#112,#65,#116,#108,#116,#116,#116,#43,#116,#70,#116,#49,#116,#48,
#116,#32,#112,#76,#112,#111,#112,#99,#112,#97,#112,#108,#112,#32,#112,
#109,#112,#101,#112,#110,#112,#117,#112,#32,#112,#32,#112,#32,#112,#32,
#112,#32,#112,#32,#112,#32,#112,#32,#112,#32,#112);

Function InBox(x1,y1,x2,y2,x,y:Word):Boolean;
Begin
   If (x>=x1) and (x<=x2) and (y>=y1) and (y<=y2) Then InBox:=True Else InBox:=False;
End;

Var OldMx, OldMy: Word;
    Knop, Mx, My: Word;
Begin
  CursorOff; {VirtScr unit}
  TextBackGround(Black);
  TextColor(LightGray);
  ClrScr;

  DrawWindow(15,6,65,18,1);
  AssignTVirtScr(V, 80, 25, 16, 7, 64, 17, 0, 0, V.Data, True);
  InitVirtualScreen(V);

  Move(NC, V.Data^, 4000);
  DrawVirtualScreen(V);

  GotoXY(3,3); WriteLn('Test program for Virtual Screens:');
  GotoXY(12,20); WriteLn('Press right mouse button to move Pascal!');
  GotoXY(1,24); Write('--== VIRTUAL SCREEN UNIT by Marc Oude Kotte ==--':80);

  ShowMouse;

  Repeat
    GetMouse(Knop, Mx, My);
    Mx:=Mx div 8 + 1;
    My:=My div 8 + 1;
    If Knop=2 Then If InBox(16,7,64,17,Mx,My) Then
      Begin
        OldMx:=Mx;
        OldMy:=My;
        HideMouse;
        Repeat
          GetMouse(Knop, Mx, My);
          Mx:=Mx div 8 + 1;
          My:=My div 8 + 1;
          If (Mx<>OldMx) or (My<>OldMy) Then
            Begin
              VS_Move(V, -(OldMx-Mx), -(OldMy-My));
              OldMx:=Mx;
              OldMy:=My;
            End;
        Until Knop<>2;
        ShowMouse;
      End;
  Until KeyPressed;
  ReadKey;

  CursorOn;
End.