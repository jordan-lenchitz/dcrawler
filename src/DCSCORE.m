DCSCORE ; persistent high score leaderboard in MUMPS global ^SCORES - v2.2.0
 ; ^SCORES("seq")         = monotonic run ID (atomic via $INCREMENT)
 ; ^SCORES("run",id)      = score^floor^result^cause^$H^$ZUT^$J^name
 ; ^SCORES("idx",-score,id) = ""  (collation-sorted highest score first)
 QUIT
RECORD(RESULT) ; record finished run in ^SCORES, return run ID
 N ID,SCORE,FLOOR,CAUSE,NOW,ZUT,NM
 S SCORE=+$G(^G($J,"score"))
 S FLOOR=+$G(^G($J,"floor"),1)
 S CAUSE=$S(RESULT="WIN":"reached final stairs",1:$$CAUSE^DCPLAY)
 S NOW=$H,ZUT=$ZUT
 S NM=$$NAME^DCPLAY
 S ID=$I(^SCORES("seq"))
 S ^SCORES("run",ID)=SCORE_"^"_FLOOR_"^"_RESULT_"^"_CAUSE_"^"_NOW_"^"_ZUT_"^"_$J_"^"_NM
 S ^SCORES("idx",-SCORE,ID)=""
 D PRUNE(200)
 Q ID
PRUNE(LIMIT) ; keep at most LIMIT top-scoring runs to bound in-memory DB growth
 N CNT,NEG,ID
 L +^SCORES("prune"):1 E  Q
 S CNT=0,NEG=""
 F  S NEG=$O(^SCORES("idx",NEG)) Q:NEG=""  D
 . S ID=""
 . F  S ID=$O(^SCORES("idx",NEG,ID)) Q:ID=""  D
 . . S CNT=CNT+1
 . . I CNT>LIMIT K ^SCORES("idx",NEG,ID),^SCORES("run",ID)
 L -^SCORES("prune")
 QUIT
LEADER() ; return "name^score^floor^result" for current #1 in ^SCORES, or "" if empty
 N NEG,ID,REC,NM
 S NEG=$O(^SCORES("idx",""))
 I NEG="" Q ""
 S ID=$O(^SCORES("idx",NEG,""))
 I ID="" Q ""
 S REC=$G(^SCORES("run",ID))
 I REC="" Q ""
 S NM=$P(REC,"^",8)
 I NM="" S NM="---"
 Q NM_"^"_$P(REC,"^",1)_"^"_$P(REC,"^",2)_"^"_$P(REC,"^",3)
SHOW(CURID,BANNER,WAITSEC,REPLAY) ; render top 8 high scores from ^SCORES
 ; when REPLAY=1, prompts to play again or quit and returns "AGAIN", "QUIT", or "TIMEOUT"
 N NEG,ID,RANK,REC,SCORE,FLR,RES,CAUSE,DT,NM,ROW,CH
 D CLEAR^DCTERM
 I $G(BANNER)'="" D
 . D MOVECUR^DCTERM(0,1)
 . W $C(27)_"[1;33m",BANNER,$C(27)_"[0m"
 D MOVECUR^DCTERM(0,3)
 W $C(27)_"[1;36m=== DCRAWL HIGH SCORES (^SCORES) ====",$C(27)_"[0m"
 D MOVECUR^DCTERM(0,5)
 W $C(27)_"[1m  #  TAG  SCORE  FLR  RES   CAUSE                     DATE",$C(27)_"[0m"
 D MOVECUR^DCTERM(0,6)
 W "----------------------------------------------------------------------------"
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
 . . S CAUSE=$E($P(REC,"^",4),1,24)
 . . S DT=$ZDATE($P(REC,"^",5),"YYYY-MM-DD 24:60")
 . . S NM=$E($P(REC,"^",8),1,3)
 . . I NM="" S NM="---"
 . . D MOVECUR^DCTERM(0,ROW)
 . . I ID=CURID W $C(27)_"[1;36m>"
 . . E  W " "
 . . W $J(RANK,2),"  ",NM,$J("",3-$L(NM)),"  ",$J(SCORE,5),"  ",$J(FLR,3),"  "
 . . W RES,$J("",5-$L(RES))," "
 . . W CAUSE,$J("",25-$L(CAUSE))," ",DT
 . . I ID=CURID W $C(27)_"[0m"
 . . S ROW=ROW+1
 I RANK=0 D
 . D MOVECUR^DCTERM(2,7)
 . W "(no completed runs recorded yet)"
 D MOVECUR^DCTERM(0,18)
 I +$G(REPLAY) W "press [enter]/[space] to play again, or [q] to quit..."
 E  W "press any key to continue..."
 S CH=$$READCH^DCTERM(+$G(WAITSEC))
 I CH=-2 Q "TIMEOUT"
 I CH=-1 Q "QUIT"
 I +$G(REPLAY) Q $S((CH=113)!(CH=81):"QUIT",1:"AGAIN")
 Q ""
