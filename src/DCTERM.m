DCTERM ; terminal handling - v2.2.0
 ; encapsulates the ansi escapes so everything else can just ask for {,$}{X,Y}
 QUIT
INIT ; raw mode on $PRINCIPAL (NOWRAP after WIDTH; HUPENABLE+EXCEPTION route disconnect to TRAP^DCRAWL)
 U $P:(NOECHO:NOESCAPE:WIDTH=512:NOWRAP:LENGTH=40:TERMINATOR="":HUPENABLE:EXCEPTION="D TRAP^DCRAWL")
 W $C(27)_"[?25l"      ; hide the cursor, we draw @ ourselves
 QUIT
END ; restore terminal for the human's return to sanity
 W $C(27)_"[0m"
 W $C(27)_"[?25h"
 W $C(27)_"[2J"
 W $C(27)_"[H"
 U $P:(ECHO:WIDTH=80:WRAP:TYPE:TERMINATOR=$C(13,10))
 QUIT
CLEAR ; wipe screen, home cursor, reset $X $Y
 W $C(27)_"[0m",$C(27)_"[2J",$C(27)_"[H"
 S $X=0,$Y=0
 QUIT
MOVECUR(X,Y) ; move to 0-indexed X,Y and update $X,$Y so our invariant holds
 W $C(27)_"["_(Y+1)_";"_(X+1)_"H"
 S $X=X,$Y=Y
 QUIT
PUTCH(X,Y,GL,COL) ; draw single glyph at X,Y with optional ANSI color, keeping $X/$Y exact
 D MOVECUR(X,Y)
 I $G(COL)'="" W $C(27)_"["_COL_"m"_GL_$C(27)_"[0m"
 E  W GL
 S $X=X+1,$Y=Y
 QUIT
CLRFLASH ; clear transient message buffer and row 20
 K ^G($J,"msg")
 N SX,SY
 S SX=$X,SY=$Y
 D MOVECUR(0,20)
 W $C(27)_"[2K"
 D MOVECUR(SX,SY)
 QUIT
FLASH(MSG) ; one-line transient message on row 20 (appends within a turn if non-empty)
 N SX,SY,CUR,OUT
 S SX=$X,SY=$Y
 I MSG="" K ^G($J,"msg") S OUT=""
 E  D
 . S CUR=$G(^G($J,"msg"))
 . S OUT=$S(CUR="":MSG,1:$E(CUR_" | "_MSG,1,79))
 . S ^G($J,"msg")=OUT
 D MOVECUR(0,20)
 W $C(27)_"[2K"
 W OUT
 D MOVECUR(SX,SY)
 QUIT
IDLESEC() ; session idle timeout in seconds from DCRAWL_IDLE_SEC (0 = disabled)
 N V
 S V=+$ZTRNLNM("DCRAWL_IDLE_SEC")
 Q $S(V>0:V,1:0)
READCH(WAITSEC) ; read single raw byte; uses WAITSEC or DCRAWL_IDLE_SEC. -1=EOF, -2=timeout
 N CH,TO
 S TO=+$G(WAITSEC)
 I TO'>0 S TO=$$IDLESEC()
 I TO>0 R *CH:TO E  Q -2
 E  R *CH
 I $ZEOF!(CH<0) Q -1
 Q CH
READKEY() ; read a single key or ANSI arrow escape sequence, return canonical action token
 N CH,C2,C3,ACT,TO
 S TO=$$IDLESEC()
 I TO>0 R *CH:TO E  Q "TIMEOUT"
 E  R *CH
 I $ZEOF!(CH<0) Q "QUIT"
 I CH=27 D  Q ACT
 . S ACT="ESC"
 . R *C2:0.08
 . I '$T Q
 . I C2=27 Q
 . I C2'=91,C2'=79 S ACT="" Q
 . R *C3:0.08
 . I '$T S ACT="" Q
 . I C3=65 S ACT="U" Q
 . I C3=66 S ACT="D" Q
 . I C3=67 S ACT="R" Q
 . I C3=68 S ACT="L" Q
 . S ACT=""
 I CH=13!(CH=10) Q "ENTER"
 I CH=32 Q "SPACE"
 I CH=104!(CH=97) Q "L"
 I CH=108!(CH=100) Q "R"
 I CH=107!(CH=119) Q "U"
 I CH=106!(CH=115) Q "D"
 I CH=105 Q "INSPECT"
 I CH=116!(CH=72) Q "SCORES"
 I CH=122!(CH=63) Q "HELP"
 I CH=113!(CH=81) Q "QUIT"
 Q ""
