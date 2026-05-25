DCMAP ; map state
 ; ^G("map",row) holds row strings
 ; single source of truth for terrain
 QUIT
LOAD ; read data/dungeon.txt row by row into ^G("map")
 N F,R,L
 S F="data/dungeon.txt"
 K ^G("map")
 O F:(READONLY):5 E  W "cannot open "_F Q
 U F
 S R=0
 F  D  Q:$ZEOF
 . R L:5
 . I $ZEOF Q
 . S ^G("map",R)=L
 . S R=R+1
 C F
 U $P
 QUIT
PAINT ; draw the entire map once
 N R,MAX
 S MAX=$O(^G("map",""),-1)
 F R=0:1:MAX D MOVECUR^DCTERM(0,R) W $G(^G("map",R))
 QUIT
GLYPHAT(X,Y) ; glyph at X,Y from ^G("map"). empty string if out of range.
 Q $E($G(^G("map",Y)),X+1)
SETCELL(X,Y,G) ; patch a single cell in the map string
 N ROW
 S ROW=$G(^G("map",Y))
 I $L(ROW)<(X+1) Q
 S $E(ROW,X+1)=G
 S ^G("map",Y)=ROW
 QUIT
PASS(X,Y) ; 1 if player can enter X,Y, 0 otherwise
 N G,K
 ; enemies block movement; you bump them and take damage
 I $D(^G("ent",Y,X)) Q 0
 S G=$$GLYPHAT(X,Y)
 I G="" Q 0
 S K=$$KIND^DCTYPE(G)
 I K="wall" Q 0
 I K="void" Q 0
 I K="" Q 0
 I K="door",G="+" Q $$HAS^DCINV("(")
 Q 1
REPAINT(X,Y) ; redraw whatever is at X,Y (used when player leaves a cell)
 D MOVECUR^DCTERM(X,Y)
 W $$GLYPHAT(X,Y)
 QUIT
STEP(X,Y) ; player stepped on X,Y. apply effects.
 N K,G,BEH,V
 S G=$$GLYPHAT(X,Y)
 S K=$$KIND^DCTYPE(G)
 I K="trap" D  Q
 . S V=$$FIELD^DCTYPE(K,G,2)
 . S BEH=$$FIELD^DCTYPE(K,G,3)
 . D DAMAGE^DCPLAY(V)
 . D FLASH^DCTERM($$FIELD^DCTYPE(K,G,1)_" hits you for "_V_".")
 . I BEH'="" D @BEH(X,Y)
 I K="item" D  Q
 . S BEH=$$FIELD^DCTYPE(K,G,3)
 . I BEH'="" D @BEH(X,Y)
 . D SETCELL(X,Y," ")
 I K="door",G="+" D  Q
 . D CONSUME^DCINV("(")
 . D SETCELL(X,Y,"/")
 . D FLASH^DCTERM("the door unlocks.")
 I K="exit" D  Q
 . S ^G("won")=1
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
ITEMME(X,Y) ; meat, heal 10
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
 S ^G("score")=+$G(^G("score"))+10
 D FLASH^DCTERM("you pick up gold. +10.")
 QUIT
EXITST(X,Y) ;
 QUIT
