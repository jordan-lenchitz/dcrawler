DCENT ; entity (enemy) management - v1.1.0
 ; entities live in ^G("ent",Y,X)=glyph
 ; extracted from the initial map at startup so movement has a clean overlay
 QUIT
DRAWENT ; pass over ^G("map"), pull enemies into ^G("ent"), repaint those cells as floor
 N R,C,ROW,GL,MAX,K
 K ^G("ent")
 S MAX=$O(^G("map",""),-1)
 F R=0:1:MAX D
 . S ROW=$G(^G("map",R))
 . F C=0:1:$L(ROW)-1 D
 . . S GL=$E(ROW,C+1)
 . . S K=$$KIND^DCTYPE(GL)
 . . I K'="enemy" Q
 . . S ^G("ent",R,C)=GL
 . . S $E(ROW,C+1)=" "
 . . S ^G("map",R)=ROW
 . . D MOVECUR^DCTERM(C,R)
 . . W GL
 QUIT
TICK(PX,PY) ; give every enemy a turn
 ; snapshot positions first so moving entities never corrupts $O iteration
 ; the filter below (Y?1.N) keeps us safe against any non-numeric subscripts
 N Y,X,GL,K,BEH,LIST,CNT,IDX
 S CNT=0,Y=""
 F  S Y=$O(^G("ent",Y)) Q:Y=""  D
 . I Y'?1.N Q
 . S X=""
 . F  S X=$O(^G("ent",Y,X)) Q:X=""  D
 . . I X'?1.N Q
 . . S CNT=CNT+1,LIST(CNT)=Y_"^"_X
 F IDX=1:1:CNT D
 . S Y=$P(LIST(IDX),"^",1),X=$P(LIST(IDX),"^",2)
 . I '$D(^G("ent",Y,X)) Q
 . S GL=^G("ent",Y,X)
 . S K=$$KIND^DCTYPE(GL)
 . I K'="enemy" Q
 . ; If already cardinally adjacent to player, attack using ^TYPE damage
 . I $$DIST(X,Y,PX,PY)'>1 D  Q
 . . N DMG,NM
 . . S DMG=+$$FIELD^DCTYPE(K,GL,2)
 . . S NM=$$FIELD^DCTYPE(K,GL,1)
 . . D DAMAGE^DCPLAY(DMG)
 . . D FLASH^DCTERM(NM_" attacks you for "_DMG_".")
 . ; Smarter logic: move towards player if within 5 units, else random
 . N DX,DY,ADX,ADY,DIST,ENX,ENY,MOVED
 . S DX=PX-X,DY=PY-Y
 . S ADX=$S(DX<0:-DX,1:DX),ADY=$S(DY<0:-DY,1:DY)
 . S DIST=$$DIST(X,Y,PX,PY)
 . S ENX=X,ENY=Y,MOVED=0
 . I DIST<5 D
 . . ; Try primary axis toward player first, fall back to secondary axis
 . . N TX,TY
 . . I ADX'<ADY D
 . . . S TX=X+$S(DX>0:1,DX<0:-1,1:0),TY=Y
 . . . I $$CANMOVE(TX,TY,PX,PY) S ENX=TX,ENY=TY,MOVED=1 Q
 . . . I DY'=0 S TX=X,TY=Y+$S(DY>0:1,1:-1) I $$CANMOVE(TX,TY,PX,PY) S ENX=TX,ENY=TY,MOVED=1
 . . E  D
 . . . S TX=X,TY=Y+$S(DY>0:1,DY<0:-1,1:0)
 . . . I $$CANMOVE(TX,TY,PX,PY) S ENX=TX,ENY=TY,MOVED=1 Q
 . . . I DX'=0 S TX=X+$S(DX>0:1,1:-1),TY=Y I $$CANMOVE(TX,TY,PX,PY) S ENX=TX,ENY=TY,MOVED=1
 . E  D
 . . N DIR,TX,TY
 . . S DIR=$R(4) ; 0:up, 1:down, 2:left, 3:right
 . . S TX=X,TY=Y
 . . I DIR=0 S TY=TY-1 ; Up
 . . I DIR=1 S TY=TY+1 ; Down
 . . I DIR=2 S TX=TX-1 ; Left
 . . I DIR=3 S TX=TX+1 ; Right
 . . I $$CANMOVE(TX,TY,PX,PY) S ENX=TX,ENY=TY,MOVED=1
 . I MOVED D
 . . K ^G("ent",Y,X)
 . . S ^G("ent",ENY,ENX)=GL
 . . D MOVECUR^DCTERM(X,Y) W $$GLYPHAT^DCMAP(X,Y) ; repaint old spot
 . . D MOVECUR^DCTERM(ENX,ENY) W GL ; paint new spot
 . . S X=ENX,Y=ENY
 . S BEH=$$FIELD^DCTYPE(K,GL,3)
 . I BEH'="" D @(BEH_"(X,Y,PX,PY)")
 QUIT
CANMOVE(X,Y,PX,PY) ; 1 if enemy can move to X,Y
 I X=PX,Y=PY Q 0
 I $D(^G("ent",Y,X)) Q 0
 Q $$EPASS^DCMAP(X,Y)
DIST(X1,Y1,X2,Y2) ; Euclidean distance (parenthesized for MUMPS left-to-right precedence)
 N DX,DY
 S DX=X1-X2,DY=Y1-Y2
 Q ((DX*DX)+(DY*DY))**0.5
