DCMAP ; map state - v2.2.0
 ; ^G($J,"map",row) holds row strings per MUMPS job
 ; single source of truth for terrain
 QUIT
MAXFLOOR() ; count sequential txt/dungeon_N.txt files (1..99), default 1
 N N,Z,F
 S Z=$ZSEARCH("")
 S N=0
 F  S F="txt/dungeon_"_(N+1)_".txt" Q:$ZSEARCH(F)=""  S N=N+1 Q:N'<99
 Q $S(N>0:N,1:1)
LOAD(FLOOR) ; read txt/dungeon_<FLOOR>.txt (fallback txt/dungeon.txt) into ^G($J,"map")
 N F,R,L,Z
 S Z=$ZSEARCH("")
 S F=""
 I +$G(FLOOR)>0 D
 . N CAND
 . S CAND="txt/dungeon_"_FLOOR_".txt"
 . I $ZSEARCH(CAND)'="" S F=CAND
 I F="" S F="txt/dungeon.txt"
 K ^G($J,"map")
 O F:(READONLY):5 E  W "cannot open "_F Q
 U F
 S R=0
 F  D  Q:$ZEOF
 . R L:5
 . I $ZEOF Q
 . S ^G($J,"map",R)=L
 . S R=R+1
 C F
 U $P
 QUIT
PAINT ; draw the entire map with ANSI colors from ^TYPE
 N R,C,MAX,ROW,GL,COL,CURCOL
 S MAX=$O(^G($J,"map",""),-1)
 F R=0:1:MAX D
 . S ROW=$G(^G($J,"map",R))
 . D MOVECUR^DCTERM(0,R)
 . S CURCOL=""
 . F C=1:1:$L(ROW) D
 . . S GL=$E(ROW,C)
 . . S COL=$$COLOR^DCTYPE(GL)
 . . I COL'=CURCOL D
 . . . I COL="" W $C(27)_"[0m"
 . . . E  W $C(27)_"[0;"_COL_"m"
 . . . S CURCOL=COL
 . . W GL
 . I CURCOL'="" W $C(27)_"[0m"
 . S $X=$L(ROW),$Y=R
 QUIT
GLYPHAT(X,Y) ; glyph at X,Y from ^G($J,"map"). empty string if out of range.
 Q $E($G(^G($J,"map",Y)),X+1)
SETCELL(X,Y,G) ; patch a single cell in the map string
 N ROW
 S ROW=$G(^G($J,"map",Y))
 I $L(ROW)<(X+1) Q
 S $E(ROW,X+1)=G
 S ^G($J,"map",Y)=ROW
 QUIT
PASS(X,Y) ; 1 if player can enter X,Y, 0 otherwise
 N G,K
 ; enemies block movement; bumping attacks them
 I $D(^G($J,"ent",Y,X)) Q 0
 S G=$$GLYPHAT(X,Y)
 I G="" Q 0
 S K=$$KIND^DCTYPE(G)
 I K="wall"!(K="void")!(K="") Q 0
 I K="door",G="+" Q $$HAS^DCINV("(")
 Q 1
EPASS(X,Y) ; 1 if enemy can enter X,Y, 0 otherwise
 N G,K
 I $D(^G($J,"ent",Y,X)) Q 0
 S G=$$GLYPHAT(X,Y)
 I G="" Q 0
 S K=$$KIND^DCTYPE(G)
 I K="wall"!(K="void")!(K="") Q 0
 I K="door",G="+" Q 0
 Q 1
REPAINT(X,Y) ; redraw colored terrain cell at X,Y
 N GL
 S GL=$$GLYPHAT(X,Y)
 D PUTCH^DCTERM(X,Y,GL,$$COLOR^DCTYPE(GL))
 QUIT
STEP(X,Y) ; player stepped on X,Y. apply effects.
 N K,G,BEH,V,NM
 S G=$$GLYPHAT(X,Y)
 S K=$$KIND^DCTYPE(G)
 I K="trap" D  Q
 . S V=$$FIELD^DCTYPE(K,G,2)
 . S BEH=$$FIELD^DCTYPE(K,G,3)
 . S NM=$$FIELD^DCTYPE(K,G,1)
 . D DAMAGE^DCPLAY(V,NM)
 . D FLASH^DCTERM(NM_" hits you for "_V_".")
 . I BEH'="" D @(BEH_"(X,Y)")
 I K="item" D  Q
 . S BEH=$$FIELD^DCTYPE(K,G,3)
 . I BEH'="" D @(BEH_"(X,Y)")
 . D SETCELL(X,Y," ")
 I K="door",G="+" D  Q
 . D CONSUME^DCINV("(")
 . D SETCELL(X,Y,"/")
 . D FLASH^DCTERM("the door unlocks.")
 I K="exit" D  Q
 . S BEH=$$FIELD^DCTYPE(K,G,3)
 . I BEH'="" D @(BEH_"(X,Y)")
 QUIT
TRAPSP(X,Y) ; spike trap triggers once then disarms
 D SETCELL(X,Y," ")
 QUIT
TRAPPO(X,Y) ; poison tile persists, damage every step
 QUIT
ITEMPO(X,Y) ; potion, heal 5
 D HEAL^DCPLAY(5)
 D FLASH^DCTERM("you drink a potion. +5 hp.")
 QUIT
ITEMME(X,Y) ; vegan meat, heal 10
 D HEAL^DCPLAY(10)
 D FLASH^DCTERM("you eat some vegan meat. +10 hp.")
 QUIT
ITEMAP(X,Y) ; apple, heal 3
 D HEAL^DCPLAY(3)
 D FLASH^DCTERM("you eat an apple. +3 hp.")
 QUIT
ITEMBR(X,Y) ; bread, heal 7
 D HEAL^DCPLAY(7)
 D FLASH^DCTERM("you eat some bread. +7 hp.")
 QUIT
ITEMTO(X,Y) ; tofu, heal 15
 D HEAL^DCPLAY(15)
 D FLASH^DCTERM("you eat some tofu. +15 hp.")
 QUIT
ITEMKE(X,Y) ; key
 D ADD^DCINV("(",1)
 D FLASH^DCTERM("you pick up a key.")
 QUIT
ITEMGO(X,Y) ; gold
 S ^G($J,"score")=+$G(^G($J,"score"))+10
 D FLASH^DCTERM("you pick up gold. +10.")
 QUIT
ITEMDG(X,Y) ; dagger (+1 atk)
 D UPATK^DCPLAY(1)
 D FLASH^DCTERM("you equip a dagger! (+1 atk, now "_$$ATK^DCPLAY_")")
 QUIT
ITEMSW(X,Y) ; sword (+2 atk)
 D UPATK^DCPLAY(2)
 D FLASH^DCTERM("you equip a sword! (+2 atk, now "_$$ATK^DCPLAY_")")
 QUIT
EXITST(X,Y) ; stairs trigger floor descent or win in DCRAWL
 S ^G($J,"descend")=1
 QUIT
