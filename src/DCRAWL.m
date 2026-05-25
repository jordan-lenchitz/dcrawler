DCRAWL ; dungeon crawler - v1.1.0
 ; entry point and main loop
 ; a love letter to $X and $Y
 ; ANSI MUMPS
 ; tested on GT.M and YottaDB
 ; the player IS the cursor
 ; $X and $Y are the source of truth
 N CH,PX,PY,NX,NY,LASTTEST
 D INIT^DCTERM
 D CLEAR^DCTERM
 D SEED^DCTYPE
 D LOAD^DCMAP
 D PAINT^DCMAP
 D DRAWENT^DCENT       ; strip enemies from map into overlay, paint them
 D INIT^DCPLAY         ; find @ in map, write player there, $X $Y now on player
 D STATUS
 ; invariant: at the top of MLOOP, $X and $Y point at the player
MLOOP ;
 S PX=$X,PY=$Y
 R *CH
 I CH=113 G QUIT
 S NX=PX,NY=PY
 I CH=104!(CH=97) S NX=PX-1
 I CH=108!(CH=100) S NX=PX+1
 I CH=107!(CH=119) S NY=PY-1
 I CH=106!(CH=115) S NY=PY+1
 I CH=105 D INSPECT G MLOOP ; 'i' for inspect
 I NX=PX,NY=PY G MLOOP
 I '$$PASS^DCMAP(NX,NY) D BUMP(NX,NY) G ENDTURN
 S LASTTEST=$TEST ; Capture $TEST after the conditional
 ; valid move
 D REPAINT^DCMAP(PX,PY) ; repaint the cell the player is leaving
 D MOVECUR^DCTERM(NX,NY)
 W "@"
 D MOVECUR^DCTERM(NX,NY) ; reset $X,$Y to land on player
 S PX=NX,PY=NY           ; player now lives at NX,NY
 D STEP^DCMAP(NX,NY)
 I $G(^G("won")) D WIN G QUIT
 I '$$ALIVE^DCPLAY D DEATH G QUIT
 D TICK^DCENT(NX,NY)
 I '$$ALIVE^DCPLAY D DEATH G QUIT
ENDTURN ;
 D MOVECUR^DCTERM(PX,PY) ; restore invariant for next iteration
 D STATUS
 G MLOOP
BUMP(X,Y) ; player tried to step into X,Y but it's blocked. enemy? take damage.
 N GL,K,V
 I '$D(^G("ent",Y,X)) Q
 S GL=^G("ent",Y,X)
 S K=$$KIND^DCTYPE(GL)
 I K'="enemy" Q
 S V=$$FIELD^DCTYPE(K,GL,2)
 D DAMAGE^DCPLAY(V)
 D FLASH^DCTERM($$FIELD^DCTYPE(K,GL,1)_" hits you for "_V_".")
 QUIT
STATUS ; status bar on row 22
 N SX,SY,I
 S SX=$X,SY=$Y
 D MOVECUR^DCTERM(0,22)
 W $C(27)_"[2K"
 W "hp ",$$HP^DCPLAY,"/",$$HPMAX^DCPLAY,"  "
 W "inv "
 S I=""
 F  S I=$O(^G("inv",I)) Q:I=""  W I,"(",^G("inv",I),") "
 W "  gold ",+$G(^G("score"))
 W "  pos ",SX,",",SY,"  $J ",$J,"  $IO ",$IO,"  $H ",$HOROLOG,"  $TEST ",LASTTEST
 D MOVECUR^DCTERM(SX,SY)
 QUIT
WIN ;
 D MOVECUR^DCTERM(0,23)
 W $C(27)_"[2K"
 W "you reached the stairs. press any key. $ZUT=",$ZUT
 R *CH:30
 QUIT
DEATH ;
 D MOVECUR^DCTERM(0,23)
 W $C(27)_"[2K"
 W "you died. press any key. $ZUT=",$ZUT
 R *CH:30
 QUIT
QUIT ;
 D END^DCTERM
 QUIT
INSPECT ; allow player to inspect map cells
 N SX,SY,IX,IY,CH,GL,KIND,MSG
 S SX=$X,SY=$Y ; save player cursor
 S IX=SX,IY=SY ; inspection cursor starts at player
INSLOOP ;
 D MOVECUR^DCTERM(IX,IY)
 R *CH
 I CH=27 G INSQ ; Escape to quit
 S NX=IX,NY=IY
 I CH=104!(CH=97) S NX=IX-1 ; h or a
 I CH=108!(CH=100) S NX=IX+1 ; l or d
 I CH=107!(CH=119) S NY=IY-1 ; k or w
 I CH=106!(CH=115) S NY=IY+1 ; j or s
 ; Boundary checks
 I NX<0 S NX=0
 I NY<0 S NY=0
 I NX>79 S NX=79 ; Assuming 80 width
 I NY>21 S NY=21 ; Max row for map display
 S IX=NX,IY=NY
 S GL=$$GLYPHAT^DCMAP(IX,IY)
 S KIND=$$KIND^DCTYPE(GL)
 S MSG="X:"_IX_",Y:"_IY_", GL:"_GL_", KIND:"_KIND
 D FLASH^DCTERM(MSG)
 G INSLOOP
INSQ ;
 D MOVECUR^DCTERM(SX,SY)
 D FLASH^DCTERM("") ; Clear flash message
 QUIT

