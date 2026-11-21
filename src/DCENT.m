DCENT ; entity (enemy) management & npc strategy - v2.2.0
 ; entities live in ^G($J,"ent",Y,X) = glyph^hp
 ; extracted from the initial map at startup so movement has a clean overlay
 QUIT
ENTGL(Y,X) ; enemy glyph at Y,X
 Q $P($G(^G($J,"ent",Y,X)),"^",1)
ENTHP(Y,X) ; enemy current HP at Y,X
 Q +$P($G(^G($J,"ent",Y,X)),"^",2)
DRAWENT ; pass over ^G($J,"map"), pull enemies into ^G($J,"ent"), paint them in color
 N R,C,ROW,GL,MAX,K
 K ^G($J,"ent")
 S MAX=$O(^G($J,"map",""),-1)
 F R=0:1:MAX D
 . S ROW=$G(^G($J,"map",R))
 . F C=0:1:$L(ROW)-1 D
 . . S GL=$E(ROW,C+1)
 . . S K=$$KIND^DCTYPE(GL)
 . . I K'="enemy" Q
 . . S ^G($J,"ent",R,C)=GL_"^"_$$HP^DCTYPE(GL)
 . . S $E(ROW,C+1)=" "
 . . S ^G($J,"map",R)=ROW
 . . D PUTCH^DCTERM(C,R,GL,$$COLOR^DCTYPE(GL))
 QUIT
REDRAW ; repaint all live enemies after a full screen redraw (e.g. closing leaderboard)
 N Y,X,GL
 S Y=""
 F  S Y=$O(^G($J,"ent",Y)) Q:Y=""  D
 . I Y'?1.N Q
 . S X=""
 . F  S X=$O(^G($J,"ent",Y,X)) Q:X=""  D
 . . I X'?1.N Q
 . . S GL=$$ENTGL(Y,X)
 . . D PUTCH^DCTERM(X,Y,GL,$$COLOR^DCTYPE(GL))
 QUIT
HIT(X,Y,DMG) ; player attacks enemy at X,Y for DMG. returns 1 if slain, 0 if alive.
 N GL,HP,NM,PTS
 S GL=$$ENTGL(Y,X)
 I GL="" Q 0
 S NM=$$FIELD^DCTYPE("enemy",GL,1)
 S HP=$$ENTHP(Y,X)-DMG
 I HP'>0 D  Q 1
 . K ^G($J,"ent",Y,X)
 . D REPAINT^DCMAP(X,Y)
 . S PTS=$S(GL="g":10,1:5)
 . S ^G($J,"score")=+$G(^G($J,"score"))+PTS
 . D FLASH^DCTERM("you slay the "_NM_"! (+"_PTS_" gold)")
 S ^G($J,"ent",Y,X)=GL_"^"_HP
 D FLASH^DCTERM("you hit "_NM_" for "_DMG_" ("_HP_" hp left).")
 Q 0
TICK(PX,PY) ; give every live enemy a turn via its ^TYPE behavior label
 ; snapshot positions first so moving entities never corrupts $O iteration
 N Y,X,GL,K,BEH,LIST,CNT,IDX
 S CNT=0,Y=""
 F  S Y=$O(^G($J,"ent",Y)) Q:Y=""  D
 . I Y'?1.N Q
 . S X=""
 . F  S X=$O(^G($J,"ent",Y,X)) Q:X=""  D
 . . I X'?1.N Q
 . . S CNT=CNT+1,LIST(CNT)=Y_"^"_X
 F IDX=1:1:CNT D
 . S Y=$P(LIST(IDX),"^",1),X=$P(LIST(IDX),"^",2)
 . I '$D(^G($J,"ent",Y,X)) Q
 . S GL=$$ENTGL(Y,X)
 . S K=$$KIND^DCTYPE(GL)
 . I K'="enemy" Q
 . S BEH=$$FIELD^DCTYPE(K,GL,3)
 . I BEH'="" D @(BEH_"(X,Y,PX,PY)") Q
 . D ACTGOB(X,Y,PX,PY)
 QUIT
ACTGOB(X,Y,PX,PY) ; goblin strategy: relentless pursuer within 6 tiles
 N ENX,ENY
 I $$DIST(X,Y,PX,PY)'>1 D ATTACK(X,Y,"g") Q
 I $$DIST(X,Y,PX,PY)<6,$$STEPTO(X,Y,PX,PY,PX,PY,.ENX,.ENY) D MOVE(X,Y,ENX,ENY) Q
 I $$RANDSTEP(X,Y,PX,PY,.ENX,.ENY) D MOVE(X,Y,ENX,ENY)
 QUIT
ACTRAT(X,Y,PX,PY) ; rat strategy: scurries in when healthy, flees when wounded (hp<=1)
 N ENX,ENY,HP,D
 S HP=$$ENTHP(Y,X),D=$$DIST(X,Y,PX,PY)
 I HP'>1,D<5 D  Q
 . I $$FLEE(X,Y,PX,PY,.ENX,.ENY) D MOVE(X,Y,ENX,ENY) Q
 . I D'>1 D ATTACK(X,Y,"r")
 I D'>1 D ATTACK(X,Y,"r") Q
 I D<4,$$STEPTO(X,Y,PX,PY,PX,PY,.ENX,.ENY) D MOVE(X,Y,ENX,ENY) Q
 I $$RANDSTEP(X,Y,PX,PY,.ENX,.ENY) D MOVE(X,Y,ENX,ENY)
 QUIT
ACTBAT(X,Y,PX,PY) ; bat strategy: erratic flutterer (50% random jitter, 50% swoop)
 N ENX,ENY
 I $$DIST(X,Y,PX,PY)'>1 D ATTACK(X,Y,"b") Q
 I $R(2)=0,$$RANDSTEP(X,Y,PX,PY,.ENX,.ENY) D MOVE(X,Y,ENX,ENY) Q
 I $$DIST(X,Y,PX,PY)<7,$$STEPTO(X,Y,PX,PY,PX,PY,.ENX,.ENY) D MOVE(X,Y,ENX,ENY) Q
 I $$RANDSTEP(X,Y,PX,PY,.ENX,.ENY) D MOVE(X,Y,ENX,ENY)
 QUIT
ATTACK(X,Y,GL) ; enemy attacks adjacent player
 N DMG,NM
 S DMG=+$$FIELD^DCTYPE("enemy",GL,2)
 S NM=$$FIELD^DCTYPE("enemy",GL,1)
 D DAMAGE^DCPLAY(DMG,"slain by "_NM)
 D FLASH^DCTERM(NM_" attacks you for "_DMG_".")
 QUIT
MOVE(X,Y,ENX,ENY) ; move entity from X,Y to ENX,ENY preserving glyph and HP
 N REC,GL
 S REC=$G(^G($J,"ent",Y,X))
 I REC="" Q
 S GL=$P(REC,"^",1)
 K ^G($J,"ent",Y,X)
 S ^G($J,"ent",ENY,ENX)=REC
 D REPAINT^DCMAP(X,Y)
 D PUTCH^DCTERM(ENX,ENY,GL,$$COLOR^DCTYPE(GL))
 QUIT
STEPTO(X,Y,GX,GY,PX,PY,ENX,ENY) ; choose a valid step toward (GX,GY). 1 if found.
 N DX,DY,ADX,ADY,TX,TY
 S DX=GX-X,DY=GY-Y
 S ADX=$S(DX<0:-DX,1:DX),ADY=$S(DY<0:-DY,1:DY)
 I ADX'<ADY D  Q $D(ENX)
 . I DX'=0 S TX=X+$S(DX>0:1,1:-1),TY=Y I $$CANMOVE(TX,TY,PX,PY) S ENX=TX,ENY=TY Q
 . I DY'=0 S TX=X,TY=Y+$S(DY>0:1,1:-1) I $$CANMOVE(TX,TY,PX,PY) S ENX=TX,ENY=TY
 I DY'=0 S TX=X,TY=Y+$S(DY>0:1,1:-1) I $$CANMOVE(TX,TY,PX,PY) S ENX=TX,ENY=TY Q 1
 I DX'=0 S TX=X+$S(DX>0:1,1:-1),TY=Y I $$CANMOVE(TX,TY,PX,PY) S ENX=TX,ENY=TY Q 1
 Q 0
FLEE(X,Y,PX,PY,ENX,ENY) ; choose a valid step away from (PX,PY). 1 if found.
 N GX,GY
 S GX=X+(X-PX),GY=Y+(Y-PY)
 Q $$STEPTO(X,Y,GX,GY,PX,PY,.ENX,.ENY)
RANDSTEP(X,Y,PX,PY,ENX,ENY) ; try a random cardinal step. 1 if valid.
 N DIR,TX,TY
 S DIR=$R(4),TX=X,TY=Y
 I DIR=0 S TY=TY-1
 I DIR=1 S TY=TY+1
 I DIR=2 S TX=TX-1
 I DIR=3 S TX=TX+1
 I $$CANMOVE(TX,TY,PX,PY) S ENX=TX,ENY=TY Q 1
 Q 0
CANMOVE(X,Y,PX,PY) ; 1 if enemy can move to X,Y
 I X=PX,Y=PY Q 0
 I $D(^G($J,"ent",Y,X)) Q 0
 Q $$EPASS^DCMAP(X,Y)
DIST(X1,Y1,X2,Y2) ; Euclidean distance (parenthesized for MUMPS left-to-right precedence)
 N DX,DY
 S DX=X1-X2,DY=Y1-Y2
 Q ((DX*DX)+(DY*DY))**0.5
