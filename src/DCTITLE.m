DCTITLE ; title screen & 3-letter arcade initials prompt - v2.2.0
 ; 30x80 ANSI welcome screen with live ^SCORES #1 champion and optional 3-char initials
 QUIT
SHOW() ; display title screen menu. returns "PLAY", "QUIT", or "TIMEOUT"
 N ACT,RES
TLOOP ;
 D RENDER
 S ACT=$$READTITLE()
 I ACT="TIMEOUT" Q "TIMEOUT"
 I ACT="QUIT" Q "QUIT"
 I ACT="SCORES" D  G:RES="TIMEOUT" TTO G:RES="QUIT" TQ G TLOOP
 . S RES=$$SHOW^DCSCORE(0,"",0,0)
 I ACT="HELP" D  G:RES="TIMEOUT" TTO G:RES="QUIT" TQ G TLOOP
 . S RES=$$SHOWHELP^DCRAWL(-1,-1)
 I ACT="PLAY" D  G:RES="BACK" TLOOP Q RES
 . S RES=$$PROMPTNM()
 G TLOOP
TTO Q "TIMEOUT"
TQ Q "QUIT"
 ;
RENDER ; draw 30x80 ANSI title screen
 N MF,LEAD,LNM,LSC,LFL,LRES,CURNM
 S MF=+$G(^G($J,"maxfloor"),1)
 D CLEAR^DCTERM
 D MOVECUR^DCTERM(16,1) W $C(27)_"[1;36m ____   ____ ____      ___        ___",$C(27)_"[0m"
 D MOVECUR^DCTERM(16,2) W $C(27)_"[1;36m|  _ \ / ___|  _ \    / \ \      / / |",$C(27)_"[0m"
 D MOVECUR^DCTERM(16,3) W $C(27)_"[1;36m| | | | |   | |_) |  / _ \ \ /\ / /| |",$C(27)_"[0m"
 D MOVECUR^DCTERM(16,4) W $C(27)_"[1;33m| |_| | |___|  _ <  / ___ \ V  V / | |___",$C(27)_"[0m"
 D MOVECUR^DCTERM(16,5) W $C(27)_"[1;33m|____/ \____|_| \_\/_/   \_\_/\_/  |_____|",$C(27)_"[0m"
 D MOVECUR^DCTERM(13,7) W $C(27)_"[2mdungeon crawler in ANSI MUMPS where YOU are $X and $Y",$C(27)_"[0m"
 ; mini colored dungeon diorama strip
 D MOVECUR^DCTERM(16,9) D WGLYPH("#",45)
 D MOVECUR^DCTERM(16,10) D LGLYPH^DCRAWL("#") W "  "
 D LGLYPH^DCRAWL("@") W "   "
 D LGLYPH^DCRAWL("(") W "   "
 D LGLYPH^DCRAWL("g") W "   "
 D LGLYPH^DCRAWL("$") W "   "
 D LGLYPH^DCRAWL("!") W "   "
 D LGLYPH^DCRAWL(")") W "   "
 D LGLYPH^DCRAWL("+") W "   "
 D LGLYPH^DCRAWL("r") W "   "
 D LGLYPH^DCRAWL("b") W "   "
 D LGLYPH^DCRAWL(">") W "    "
 D LGLYPH^DCRAWL("#")
 D MOVECUR^DCTERM(16,11) D WGLYPH("#",45)
 ; live #1 champion from shared ^SCORES
 S LEAD=$$LEADER^DCSCORE
 D MOVECUR^DCTERM(14,13)
 I LEAD'="" D
 . S LNM=$P(LEAD,"^",1),LSC=$P(LEAD,"^",2),LFL=$P(LEAD,"^",3),LRES=$P(LEAD,"^",4)
 . W $C(27)_"[1;33m#1 HIGH SCORE:  ",LNM," | ",LSC," gold (flr ",LFL,", ",LRES,")",$C(27)_"[0m"
 E  W $C(27)_"[33m#1 HIGH SCORE:  (unclaimed, descend to claim the throne!)",$C(27)_"[0m"
 ; menu
 D MOVECUR^DCTERM(16,16) W $C(27)_"[1;32m[ENTER / SPACE]",$C(27)_"[0m  descend into the dungeon (",MF," floors)"
 D MOVECUR^DCTERM(16,17) W $C(27)_"[1;36m[T]",$C(27)_"[0m              view live ^SCORES leaderboard"
 D MOVECUR^DCTERM(16,18) W $C(27)_"[1;36m[Z]",$C(27)_"[0m              help & MUMPS intrinsics"
 D MOVECUR^DCTERM(16,19) W $C(27)_"[1;31m[Q]",$C(27)_"[0m              quit"
 S CURNM=$G(^G($J,"name"))
 I CURNM'="",CURNM'="---" D
 . D MOVECUR^DCTERM(16,21)
 . W $C(27)_"[2mcurrent arcade initials: ",CURNM,$C(27)_"[0m"
 ; live MUMPS intrinsics footer
 D MOVECUR^DCTERM(16,24) W $C(27)_"[2m$J ",$J,"   $H ",$H,"   floors 1-",MF,$C(27)_"[0m"
 D MOVECUR^DCTERM(11,26) W $C(27)_"[2mcontrols: arrows / wasd / hjkl = move & attack   i = inspect",$C(27)_"[0m"
 QUIT
 ;
WGLYPH(GL,N) ; write N copies of glyph in its ^TYPE color
 N I,COL
 S COL=$$COLOR^DCTYPE(GL)
 I COL'="" W $C(27)_"["_COL_"m"
 F I=1:1:N W GL
 I COL'="" W $C(27)_"[0m"
 QUIT
 ;
READTITLE() ; read a menu key on the title screen
 N CH,C2,C3
 S CH=$$READCH^DCTERM(0)
 I CH=-2 Q "TIMEOUT"
 I CH=-1 Q "QUIT"
 I CH=27 D  Q ""
 . R *C2:0.05 I '$T Q
 . I C2=91!(C2=79) R *C3:0.05
 I CH=13!(CH=10)!(CH=32)!(CH=112)!(CH=80) Q "PLAY"
 I CH=116!(CH=84)!(CH=72) Q "SCORES"
 I CH=122!(CH=90)!(CH=63) Q "HELP"
 I CH=113!(CH=81) Q "QUIT"
 Q ""
 ;
PROMPTNM() ; optional 3-letter arcade initials prompt. returns "PLAY", "BACK", "QUIT", or "TIMEOUT"
 N BUF,CH,C2,C3,UP,PREV
 S PREV=$G(^G($J,"name"))
 S BUF=$S(PREV="---":"",1:$E(PREV,1,3))
 D MOVECUR^DCTERM(10,21) W $C(27)_"[2K"
 D MOVECUR^DCTERM(10,22) W $C(27)_"[2K"
 D MOVECUR^DCTERM(11,21)
 W $C(27)_"[1;37mARCADE INITIALS ",$C(27)_"[0m",$C(27)_"[2m(3 chars, Enter to start, Esc back): ",$C(27)_"[0m"
 W $C(27)_"[?25h"
NLOOP ;
 D DRAWSLOT(BUF)
 S CH=$$READCH^DCTERM(0)
 I CH=-2 W $C(27)_"[?25l" Q "TIMEOUT"
 I CH=-1 W $C(27)_"[?25l" Q "QUIT"
 I CH=13!(CH=10) D  Q "PLAY"
 . W $C(27)_"[?25l"
 . D SETNAME^DCPLAY(BUF)
 I CH=27 D  Q "BACK"
 . R *C2:0.05
 . I $T,(C2=91!(C2=79)) R *C3:0.05
 . W $C(27)_"[?25l"
 I CH=127!(CH=8) D  G NLOOP
 . I $L(BUF)>0 S BUF=$E(BUF,1,$L(BUF)-1)
 ; accept ASCII A-Z, a-z, 0-9 -> auto-uppercase, max 3 chars
 I $L(BUF)<3 D
 . S UP=""
 . I CH'<97,CH'>122 S UP=$C(CH-32)
 . E  I CH'<65,CH'>90 S UP=$C(CH)
 . E  I CH'<48,CH'>57 S UP=$C(CH)
 . I UP'="" S BUF=BUF_UP
 G NLOOP
 ;
DRAWSLOT(BUF) ; render [ A B _ ] slot at col 64, row 21 and place cursor on active cell
 N I,C,POS
 D MOVECUR^DCTERM(64,21)
 W $C(27)_"[1;36m[ "
 F I=1:1:3 D
 . S C=$E(BUF,I)
 . I C="" W "_"
 . E  W C
 . W " "
 W "]",$C(27)_"[0m"
 S POS=$S($L(BUF)<3:$L(BUF),1:2)
 D MOVECUR^DCTERM(66+(POS*2),21)
 QUIT
