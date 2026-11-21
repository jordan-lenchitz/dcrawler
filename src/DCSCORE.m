DCSCORE ; persistent high score leaderboard in YottaDB global ^SCORES - v2.0.0
 ; ^SCORES("seq")         = monotonic run ID
 ; ^SCORES("run",id)      = score^floor^result^cause^$H^$ZUT^$J
 ; ^SCORES("idx",-score,id) = ""  (collation-sorted highest score first)
 QUIT
RECORD(RESULT) ; record finished run in ^SCORES, return run ID
 N ID,SCORE,FLOOR,CAUSE,NOW,ZUT
 S SCORE=+$G(^G("score"))
 S FLOOR=+$G(^G("floor"),1)
 S CAUSE=$S(RESULT="WIN":"reached final stairs",1:$$CAUSE^DCPLAY)
 S NOW=$H,ZUT=$ZUT
 S ID=$I(^SCORES("seq"))
 S ^SCORES("run",ID)=SCORE_"^"_FLOOR_"^"_RESULT_"^"_CAUSE_"^"_NOW_"^"_ZUT_"^"_$J
 S ^SCORES("idx",-SCORE,ID)=""
 Q ID
SHOW(CURID,BANNER,WAITSEC) ; render top 8 high scores from ^SCORES
 N NEG,ID,RANK,REC,SCORE,FLR,RES,CAUSE,DT,ROW,CH
 D CLEAR^DCTERM
 I $G(BANNER)'="" D
 . D MOVECUR^DCTERM(0,1)
 . W $C(27)_"[1;33m",BANNER,$C(27)_"[0m"
 D MOVECUR^DCTERM(0,3)
 W $C(27)_"[1;36m=== DCRAWL HIGH SCORES (^SCORES) ====",$C(27)_"[0m"
 D MOVECUR^DCTERM(0,5)
 W $C(27)_"[1m  #  SCORE  FLR  RES   CAUSE                      DATE",$C(27)_"[0m"
 D MOVECUR^DCTERM(0,6)
 W "------------------------------------------------------------------------"
 S RANK=0,ROW=7,NEG=""
 F  S NEG=$O(^SCORES("idx",NEG)) Q:NEG=""!(RANK'<8)  D
 . S ID=""
 . F  S ID=$O(^SCORES("idx",NEG,ID)) Q:ID=""!(RANK'<8)  D
 . . S REC=$G(^SCORES("run",ID))
 . . I REC="" Q
 . . S RANK=RANK+1
 . . S SCORE=$P(REC,"^",1)
 . . S FLR=$P(REC,"^",2)
 . . S RES=$P(REC,"^",3)
 . . S CAUSE=$E($P(REC,"^",4),1,25)
 . . S DT=$ZDATE($P(REC,"^",5),"YYYY-MM-DD 24:60")
 . . D MOVECUR^DCTERM(0,ROW)
 . . I ID=CURID W $C(27)_"[1;36m>"
 . . E  W " "
 . . W $J(RANK,2),"  ",$J(SCORE,5),"  ",$J(FLR,3),"  "
 . . W RES,$J("",5-$L(RES))," "
 . . W CAUSE,$J("",26-$L(CAUSE))," ",DT
 . . I ID=CURID W $C(27)_"[0m"
 . . S ROW=ROW+1
 I RANK=0 D
 . D MOVECUR^DCTERM(2,7)
 . W "(no completed runs recorded yet)"
 D MOVECUR^DCTERM(0,18)
 W "press any key to continue..."
 I +$G(WAITSEC)>0 R *CH:WAITSEC
 E  R *CH
 QUIT
