DCRAWL ; dungeon crawler - v2.0.0
 ; entry point and main loop
 ; a love letter to $X and $Y
 ; ANSI MUMPS (tested on YottaDB & GT.M)
 ; the player IS the cursor
 ; $X and $Y are the source of truth
 N ACT,PX,PY,NX,NY,LASTTEST
 D INIT^DCTERM
 D SEED^DCTYPE
 S ^G("maxfloor")=$$MAXFLOOR^DCMAP
 S ^G("floor")=1
 D CLEAR^DCTERM
 D LOAD^DCMAP(1)
 D PAINT^DCMAP
 D DRAWENT^DCENT       ; strip enemies from map into overlay, paint them
 D INIT^DCPLAY         ; find @ in map, write player there, $X $Y now on player
 D LEGEND
 D STATUS
 ; invariant: at the top of MLOOP, $X and $Y point at the player
MLOOP ;
 S PX=$X,PY=$Y
 S ACT=$$READKEY^DCTERM
 I ACT="QUIT" G QUIT
 I ACT="ESC" D CLRFLASH^DCTERM,FLASH^DCTERM("press q to quit, or z for help.") G MLOOP
 I ACT="INSPECT" D INSPECT G MLOOP
 I ACT="SCORES" D SHOWSCORES(PX,PY) G MLOOP
 I ACT="HELP" D SHOWHELP(PX,PY) G MLOOP
 S NX=PX,NY=PY
 I ACT="L" S NX=PX-1
 I ACT="R" S NX=PX+1
 I ACT="U" S NY=PY-1
 I ACT="D" S NY=PY+1
 I NX=PX,NY=PY G MLOOP
 D CLRFLASH^DCTERM       ; clear previous turn's transient message
 I '$$PASS^DCMAP(NX,NY) G BLOCKED
 S LASTTEST=$TEST ; Capture $TEST after the conditional
 ; valid move
 D REPAINT^DCMAP(PX,PY) ; repaint the cell the player is leaving
 D PUTCH^DCTERM(NX,NY,"@",$$COLOR^DCTYPE("@"))
 D MOVECUR^DCTERM(NX,NY) ; reset $X,$Y to land on player
 S PX=NX,PY=NY           ; player now lives at NX,NY
 D STEP^DCMAP(NX,NY)
 I $G(^G("descend")) D  G:$G(^G("won")) QUIT G ENDTURN
 . K ^G("descend")
 . I ^G("floor")<^G("maxfloor") D  Q
 . . S ^G("floor")=^G("floor")+1
 . . S ^G("score")=+$G(^G("score"))+25
 . . D CLEAR^DCTERM
 . . D LOAD^DCMAP(^G("floor"))
 . . D PAINT^DCMAP
 . . D DRAWENT^DCENT
 . . D PLACE^DCPLAY
 . . S PX=$X,PY=$Y
 . . D LEGEND
 . . D FLASH^DCTERM("you descend to floor "_^G("floor")_"/"_^G("maxfloor")_". (+25 gold)")
 . S ^G("won")=1
 . D WIN
 I '$$ALIVE^DCPLAY D DEATH G QUIT
 D TICK^DCENT(NX,NY)
 I '$$ALIVE^DCPLAY D DEATH G QUIT
 G ENDTURN
BLOCKED ;
 I $D(^G("ent",NY,NX)) D  G:'$$ALIVE^DCPLAY DIE G ENDTURN
 . N KILLED
 . S KILLED=$$HIT^DCENT(NX,NY,$$ATK^DCPLAY)
 . D TICK^DCENT(PX,PY)
 D BUMP(NX,NY)
ENDTURN ;
 D MOVECUR^DCTERM(PX,PY) ; restore invariant for next iteration
 D STATUS
 G MLOOP
DIE ;
 D DEATH
 G QUIT
BUMP(X,Y) ; player bumped a non-enemy blocked tile (e.g. locked door)
 N GL
 S GL=$$GLYPHAT^DCMAP(X,Y)
 I GL="+" D FLASH^DCTERM("locked door. you need a key (.")
 QUIT
STATUS ; status bar on rows 22-23 ($X/$Y on row 22, live $H and $J on row 23)
 N SX,SY,I,HP,HPMAX,HASINV
 S SX=$X,SY=$Y
 D MOVECUR^DCTERM(0,22)
 W $C(27)_"[2K"
 S HP=$$HP^DCPLAY,HPMAX=$$HPMAX^DCPLAY
 W "hp "
 I HP<5 W $C(27)_"[1;31m"
 E  W $C(27)_"[1;32m"
 W HP,"/",HPMAX,$C(27)_"[0m   "
 W "atk ",$$ATK^DCPLAY,"   "
 W "flr ",+$G(^G("floor"),1),"/",+$G(^G("maxfloor"),1),"   "
 W "gold ",+$G(^G("score")),"   "
 W "inv "
 S I="",HASINV=0
 F  S I=$O(^G("inv",I)) Q:I=""  W I,"(",^G("inv",I),") " S HASINV=1
 I 'HASINV W "- "
 W "  $X ",SX,"   $Y ",SY
 D MOVECUR^DCTERM(0,23)
 W $C(27)_"[2K"
 W $C(27)_"[2m$H ",$H,"   $J ",$J,$C(27)_"[0m"
 D MOVECUR^DCTERM(SX,SY)
 QUIT
LEGEND ; colorized glyph & controls key spread cleanly across rows 25-27
 N SX,SY
 S SX=$X,SY=$Y
 D MOVECUR^DCTERM(0,25)
 W $C(27)_"[2K"
 D LITEM("@","you"),LITEM("g","goblin"),LITEM("r","rat"),LITEM("b","bat")
 D LITEM("^","spike"),LITEM("~","poison"),LITEM("+","door"),LITEM("/","open"),LITEM(">","stairs")
 D MOVECUR^DCTERM(0,26)
 W $C(27)_"[2K"
 D LITEM("(","key"),LITEM("$","gold"),LITEM("!","potion"),LITEM(")","dagger"),LITEM("}","sword")
 D LGLYPH("M") W "/" D LGLYPH("A") W "/" D LGLYPH("B") W "/" D LGLYPH("T") W "=food"
 D MOVECUR^DCTERM(0,27)
 W $C(27)_"[2K"
 W $C(27)_"[2mkeys: arrows/wasd/hjkl=move  i=inspect  t=scores  z=help  q=quit",$C(27)_"[0m"
 D MOVECUR^DCTERM(SX,SY)
 QUIT
LITEM(GL,DESC) ; write colored glyph=desc
 D LGLYPH(GL)
 W "=",DESC,"  "
 QUIT
LGLYPH(GL) ; write single glyph in its ^TYPE ANSI color
 N COL
 S COL=$$COLOR^DCTYPE(GL)
 I COL'="" W $C(27)_"["_COL_"m",GL,$C(27)_"[0m"
 E  W GL
 QUIT
REDRAWALL(PX,PY) ; full board + HUD redraw preserving player cursor invariant
 D CLEAR^DCTERM
 D PAINT^DCMAP
 D REDRAW^DCENT
 D PUTCH^DCTERM(PX,PY,"@",$$COLOR^DCTYPE("@"))
 D MOVECUR^DCTERM(PX,PY)
 D LEGEND
 D STATUS
 QUIT
SHOWSCORES(PX,PY) ; display ^SCORES leaderboard mid-run and redraw board
 D SHOW^DCSCORE(0,"")
 D REDRAWALL(PX,PY)
 QUIT
SHOWHELP(PX,PY) ; display help & MUMPS intrinsics overlay (mapped to 'z')
 N CH
 D CLEAR^DCTERM
 D MOVECUR^DCTERM(0,1) W $C(27)_"[1;36m=== DCRAWL HELP (press z anytime) ===",$C(27)_"[0m"
 D MOVECUR^DCTERM(0,3) W $C(27)_"[1mCONTROLS",$C(27)_"[0m"
 D MOVECUR^DCTERM(2,4) W "arrows / wasd / hjkl  move or bump-attack adjacent enemy"
 D MOVECUR^DCTERM(2,5) W "i                     inspect map cells (exit: i / q / enter / space / esc)"
 D MOVECUR^DCTERM(2,6) W "t  (or H)             view persistent YottaDB ^SCORES leaderboard"
 D MOVECUR^DCTERM(2,7) W "z  (or ?)             this help screen"
 D MOVECUR^DCTERM(2,8) W "q                     quit game"
 D MOVECUR^DCTERM(0,10) W $C(27)_"[1mCOMBAT & PROGRESSION",$C(27)_"[0m"
 D MOVECUR^DCTERM(2,11) W "bump into g/r/b to attack using your ATK (upgrade via ) dagger, } sword)."
 D MOVECUR^DCTERM(2,12) W "grab a key ( to unlock + doors, then step on > stairs to descend floors 1-",+$G(^G("maxfloor"),1),"."
 D MOVECUR^DCTERM(2,13) W "goblins pursue, rats flee when hurt, bats flutter erratically."
 D MOVECUR^DCTERM(0,15) W $C(27)_"[1mMUMPS INTRINSICS IN ACTION",$C(27)_"[0m"
 D MOVECUR^DCTERM(2,16) W "$X, $Y   player coordinates (ground truth, never mirrored in a global)"
 D MOVECUR^DCTERM(2,17) W "$H       live MUMPS $HOROLOG clock (days since Dec 31, 1840, seconds)"
 D MOVECUR^DCTERM(2,18) W "$J       current MUMPS job / process ID"
 D MOVECUR^DCTERM(2,19) W "$ZUT     microseconds since Unix epoch (stored in ^SCORES)"
 D MOVECUR^DCTERM(0,21) W "press any key to return to the dungeon..."
 R *CH
 D REDRAWALL(PX,PY)
 QUIT
WIN ;
 N ID,MSG
 S ID=$$RECORD^DCSCORE("WIN")
 S MSG="YOU ESCAPED ALL "_^G("maxfloor")_" FLOORS! score="_+$G(^G("score"))_"  $ZUT="_$ZUT
 D SHOW^DCSCORE(ID,MSG,30)
 QUIT
DEATH ;
 N ID,MSG
 S ID=$$RECORD^DCSCORE("DEAD")
 S MSG="YOU DIED ("_$$CAUSE^DCPLAY_"). score="_+$G(^G("score"))_"  $ZUT="_$ZUT
 D SHOW^DCSCORE(ID,MSG,30)
 QUIT
QUIT ;
 D END^DCTERM
 QUIT
INSPECT ; allow player to inspect map cells (supports arrow keys, wasd, hjkl)
 N SX,SY,IX,IY,NX,NY,ACT,GL,KIND,NM,MSG,EHP
 S SX=$X,SY=$Y ; save player cursor
 S IX=SX,IY=SY ; inspection cursor starts at player
 W $C(27)_"[?25h" ; show cursor during inspect
INSLOOP ;
 I IX=SX,IY=SY S GL="@",KIND="player",NM="you"
 E  I $D(^G("ent",IY,IX)) D
 . S GL=$$ENTGL^DCENT(IY,IX),KIND=$$KIND^DCTYPE(GL)
 . S EHP=$$ENTHP^DCENT(IY,IX)
 . S NM=$$FIELD^DCTYPE(KIND,GL,1)_" hp:"_EHP
 E  S GL=$$GLYPHAT^DCMAP(IX,IY),KIND=$$KIND^DCTYPE(GL),NM=$$FIELD^DCTYPE(KIND,GL,1)
 S MSG="inspect ("_IX_","_IY_") '"_GL_"' "_KIND_$S(NM'="":" ("_NM_")",1:"")_" [i/q/enter/esc]"
 D CLRFLASH^DCTERM
 D FLASH^DCTERM(MSG)
 D MOVECUR^DCTERM(IX,IY)
 S ACT=$$READKEY^DCTERM
 I ACT="ESC"!(ACT="QUIT")!(ACT="INSPECT")!(ACT="ENTER")!(ACT="SPACE") G INSQ
 S NX=IX,NY=IY
 I ACT="L" S NX=IX-1
 I ACT="R" S NX=IX+1
 I ACT="U" S NY=IY-1
 I ACT="D" S NY=IY+1
 ; Boundary checks
 I NX<0 S NX=0
 I NY<0 S NY=0
 I NX>79 S NX=79
 I NY>19 S NY=19
 S IX=NX,IY=NY
 G INSLOOP
INSQ ;
 W $C(27)_"[?25l" ; hide cursor again
 D MOVECUR^DCTERM(SX,SY)
 D FLASH^DCTERM("") ; Clear flash message
 QUIT
