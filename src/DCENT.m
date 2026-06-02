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
TICK(PX,PY) ; give every enemy a turn. currently static (no movement) in the basic build.
 ; the filter below (Y?1.N) keeps us safe against any non-numeric subscripts
 ; if a future extension ever adds scratch keys like ^G("ent","next",...).
 N Y,X,GL,K,BEH
 S Y=""
 F  S Y=$O(^G("ent",Y)) Q:Y=""  D
 . I Y'?1.N Q
 . S X=""
 . F  S X=$O(^G("ent",Y,X)) Q:X=""  D
 . . I X'?1.N Q
 . . S GL=^G("ent",Y,X)
 . . S K=$$KIND^DCTYPE(GL)
 . . I K'="enemy" Q
 . . ; Smarter AI: move towards player if within 5 units, else random
 . . N DX,DY,DIST,ENX,ENY,OLDX,OLDY
 . . S OLDX=X,OLDY=Y
 . . S DX=PX-X,DY=PY-Y
 . . S DIST=$ZSQR(DX*DX+DY*DY)
 . . I DIST<5 D
 . . . S ENX=X,ENY=Y
 . . . I DX>0 S ENX=X+1
 . . . E  I DX<0 S ENX=X-1
 . . . I DY>0 S ENY=Y+1
 . . . E  I DY<0 S ENY=Y-1
 . . E  D
 . . . N DIR
 . . . S DIR=$R(4) ; 0:up, 1:down, 2:left, 3:right
 . . . S ENX=X,ENY=Y
 . . . I DIR=0 S ENY=ENY-1 ; Up
 . . . I DIR=1 S ENY=ENY+1 ; Down
 . . . I DIR=2 S ENX=ENX-1 ; Left
 . . . I DIR=3 S ENX=ENX+1 ; Right
 . . ; Check if new position is valid (passable, not player, not another enemy)
 . . I $$PASS^DCMAP(ENX,ENY),'(ENX=PX&(ENY=PY)),'$D(^G("ent",ENY,ENX)) D
 . . . ; If adjacent to player, attack
 . . . I $$DIST(ENX,ENY,PX,PY)'>1 D
 . . . . D DAMAGE^DCPLAY(1) ; Simple 1 damage attack
 . . . . D FLASH^DCTERM("enemy attacks you for 1 damage.")
 . . . . Q
 . . . ; Move enemy
 . . . K ^G("ent",OLDY,OLDX)
 . . . S ^G("ent",ENY,ENX)=GL
 . . . D MOVECUR^DCTERM(OLDX,OLDY) W $$GLYPHAT^DCMAP(OLDX,OLDY) ; repaint old spot
 . . . D MOVECUR^DCTERM(ENX,ENY) W GL ; paint new spot
 . . . S X=ENX,Y=ENY ; update current X,Y for next iteration if moved
 . . S BEH=$$FIELD^DCTYPE(K,GL,3)
 . . I BEH'="" D @BEH(X,Y,PX,PY)
 QUIT
DIST(X1,Y1,X2,Y2) ; Distance formula
 N DX,DY
 S DX=X1-X2,DY=Y1-Y2
 Q $ZSQR(DX*DX+DY*DY)
