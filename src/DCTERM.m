DCTERM ; terminal handling - v1.1.0
 ; encapsulates the ansi escapes so everything else can just ask for {,$}{X,Y}
 QUIT
INIT ; raw mode on $PRINCIPAL
 U $P:(NOECHO:TERMINATOR="":WIDTH=80:LENGTH=24)
 W $C(27)_"[?25l"      ; hide the cursor, we draw @ ourselves
 QUIT
END ; restore terminal for the human's return to sanity
 W $C(27)_"[?25h"
 W $C(27)_"[2J"
 W $C(27)_"[H"
 U $P:(ECHO:TYPE:TERMINATOR=$C(13,10))
 QUIT
CLEAR ; wipe screen, home cursor, reset $X $Y
 W $C(27)_"[2J"
 W $C(27)_"[H"
 S $X=0,$Y=0
 QUIT
MOVECUR(X,Y) ; move to 0-indexed X,Y and update $X,$Y so our invariant holds
 W $C(27)_"["_(Y+1)_";"_(X+1)_"H"
 S $X=X,$Y=Y
 QUIT
FLASH(MSG) ; one-line transient message on row 23
 N SX,SY
 S SX=$X,SY=$Y
 D MOVECUR(0,23)
 W $C(27)_"[2K"
 W MSG
 D MOVECUR(SX,SY)
 QUIT
