DCENT ; entity (enemy) management. entities live in ^G("ent",Y,X)=glyph.
 ; extracted from the initial map at startup so movement has a clean overlay.
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
 . . S BEH=$$FIELD^DCTYPE(K,GL,3)
 . . I BEH'="" D @BEH(X,Y,PX,PY)
 QUIT
