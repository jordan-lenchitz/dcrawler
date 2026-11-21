DCTEST ; native MUMPS test suite for dcrawl - v2.2.0
 ; runs against an isolated temporary MUMPS database (see Makefile `make test`)
 ; verifies:
 ;   - all 25 on-disk txt/dungeon_1..25.txt files + 50 freshly generated DCGEN floors
 ;   - MAXFLOOR & LOAD^DCMAP + live GENMAP^DCGEN
 ;   - DCTYPE registry lookups & concurrency-safe idempotent SEED
 ;   - enemy AI & combat: rat flee, goblin chase/4-hit/1-shot/death, weapon stacking,
 ;     EPASS closed-door blocking, bat terrain overlay preservation
 ;   - traps, vegan foods, potions, HP cap, multi-key inventory, locked doors
 ;   - multi-floor descent state, ^G($J) job isolation & ^SCORES persistence/initials/leader
 N PASSCNT,FAILCNT,NULLDEV
 S PASSCNT=0,FAILCNT=0
 U $P:(WIDTH=512:NOWRAP)
 S NULLDEV="/dev/null"
 O NULLDEV:(APPEND):5 E  W "[FAIL] cannot open /dev/null",! ZHALT 1
 D SEED^DCTYPE
 D TTYPE
 D TVERREPO
 D TGENSTRESS
 D TMAXFLOOR
 D TRATFLEE
 D TGOBCOMBAT
 D TWEAPEPASS
 D TCOMBATDIE
 D TBATOVER
 D TITEMS
 D TDESCEND
 D TISOL
 D TSCORES
 C NULLDEV
 U $P
 I FAILCNT>0 D  ZHALT 1
 . W !,"MUMPS TEST SUITE FAILED: ",FAILCNT," failure(s), ",PASSCNT," passed.",!
 W !,"ALL NATIVE MUMPS TESTS PASSED! (",PASSCNT,"/",PASSCNT," assertions)",!
 ZHALT 0
 ;
ASSERT(COND,MSG) ; record an assertion result
 I COND S PASSCNT=PASSCNT+1 QUIT
 S FAILCNT=FAILCNT+1
 U $P
 W "[FAIL] ",MSG,!
 QUIT
 ;
RESETRUN(ROWS,MAXR) ; load an in-memory map ROWS(0..MAXR) and initialize player/entities silently
 N R
 K ^G($J)
 S ^G($J,"floor")=1,^G($J,"maxfloor")=1
 F R=0:1:MAXR S ^G($J,"map",R)=ROWS(R)
 U NULLDEV
 D DRAWENT^DCENT
 D INIT^DCPLAY
 U $P
 QUIT
 ;
LOADFILE(PATH,ROWS,MAXR) ; read a dungeon text file into ROWS(0..MAXR)
 N L
 K ROWS
 S MAXR=-1
 O PATH:(READONLY):5 E  Q 0
 U PATH
 F  D  Q:$ZEOF
 . R L:5
 . I $ZEOF Q
 . S MAXR=MAXR+1,ROWS(MAXR)=L
 C PATH
 U $P
 Q 1
 ;
VERIFY(ROWS,LABEL) ; verify all 20x60 dungeon invariants & BFS reachability
 N VALID,R,C,CH,CNT,PR,PC,ER,EC,KR,KC,DR,DC,D,NR,NC
 N ENCNT,ENR,ENC,GRID,RNO,RYES,PASSNO,PASSYES,I,MD
 S VALID="@#. +/grb^~!MABT($)}>"
 D ASSERT($O(ROWS(""),-1)=19,LABEL_": expected 20 rows (0..19)")
 F R=0:1:19 D
 . D ASSERT($L($G(ROWS(R)))=60,LABEL_": row "_R_" not 60 cols")
 . F C=0:1:59 S GRID(R,C)=$E($G(ROWS(R)),C+1)
 ; closed outer border
 F C=0:1:59 D
 . D ASSERT(".#"[GRID(0,C),LABEL_": open top border col "_C)
 . D ASSERT(".#"[GRID(19,C),LABEL_": open bottom border col "_C)
 F R=0:1:19 D
 . D ASSERT(".#"[GRID(R,0),LABEL_": open left border row "_R)
 . D ASSERT(".#"[GRID(R,59),LABEL_": open right border row "_R)
 S DR(1)=-1,DC(1)=0,DR(2)=1,DC(2)=0,DR(3)=0,DC(3)=-1,DR(4)=0,DC(4)=1
 S ENCNT=0,PR=-1,ER=-1,KR=-1
 F R=0:1:19 F C=0:1:59 D
 . S CH=GRID(R,C)
 . D ASSERT(VALID[CH,LABEL_": unknown glyph '"_CH_"' at ("_R_","_C_")")
 . S CNT(CH)=$G(CNT(CH))+1
 . I CH="@" S PR=R,PC=C
 . I CH=">" S ER=R,EC=C
 . I CH="(" S KR=R,KC=C
 . I "grb"[CH S ENCNT=ENCNT+1,ENR(ENCNT)=R,ENC(ENCNT)=C
 . I ".#"'[CH D
 . . F D=1:1:4 D
 . . . S NR=R+DR(D),NC=C+DC(D)
 . . . D ASSERT($G(GRID(NR,NC))'=".",LABEL_": cell '"_CH_"' at ("_R_","_C_") borders void")
 D ASSERT($G(CNT("@"))=1,LABEL_": expected exactly 1 '@'")
 D ASSERT($G(CNT(">"))=1,LABEL_": expected exactly 1 '>'")
 D ASSERT($G(CNT("("))'<1,LABEL_": missing key '('")
 D ASSERT($G(CNT("+"))'<1,LABEL_": missing locked door '+'")
 ; no enemy adjacent to player start (Manhattan > 2)
 F I=1:1:ENCNT D
 . S MD=$$MDIST^DCGEN(ENR(I),ENC(I),PR,PC)
 . D ASSERT(MD>2,LABEL_": enemy too close to start (dist="_MD_")")
 ; BFS reachability before & after unlocking '+'
 S PASSNO="@ /grb^~!MABT($)}>"
 S PASSYES=PASSNO_"+"
 D BFS^DCGEN(.GRID,PR,PC,PASSNO,.RNO)
 D BFS^DCGEN(.GRID,PR,PC,PASSYES,.RYES)
 D ASSERT($D(RNO(KR,KC)),LABEL_": key unreachable before door")
 D ASSERT('$D(RNO(ER,EC)),LABEL_": exit reachable without unlocking door")
 D ASSERT($D(RYES(ER,EC)),LABEL_": exit unreachable even with key")
 QUIT
 ;
TTYPE ; verify DCTYPE registry lookups
 D ASSERT($$KIND^DCTYPE("#")="wall","DCTYPE wall kind")
 D ASSERT($$KIND^DCTYPE("g")="enemy","DCTYPE goblin kind")
 D ASSERT($$KIND^DCTYPE("T")="item","DCTYPE tofu kind")
 D ASSERT($$KIND^DCTYPE("?")="","DCTYPE unknown glyph")
 D ASSERT($$COLOR^DCTYPE("@")="1;36","DCTYPE player color")
 D ASSERT($$HP^DCTYPE("g")=4,"DCTYPE goblin hp=4")
 D ASSERT($$HP^DCTYPE("r")=2,"DCTYPE rat hp=2")
 D ASSERT($$HP^DCTYPE("b")=2,"DCTYPE bat hp=2")
 D ASSERT($$FIELD^DCTYPE("enemy","g",3)="ACTGOB","DCTYPE goblin strategy")
 U $P W "[PASS] DCTYPE: registry kind/color/hp/behavior lookups",!
 QUIT
 ;
TVERREPO ; verify all 25 on-disk txt/dungeon_1..25.txt files
 N FLR,ROWS,MAXR,OK,PATH
 F FLR=1:1:25 D
 . S PATH="txt/dungeon_"_FLR_".txt"
 . S OK=$$LOADFILE(PATH,.ROWS,.MAXR)
 . D ASSERT(OK,"missing repo floor file: "_PATH)
 . I OK D VERIFY(.ROWS,"repo dungeon_"_FLR_".txt")
 U $P W "[PASS] repo dungeons: all 25 on-disk txt/dungeon_1..25.txt invariants & BFS verified",!
 QUIT
 ;
TGENSTRESS ; stress-test 50 freshly generated floors via DCGEN + GENMAP live load
 N RUN,FLR,ROWS,OK
 F RUN=1:1:2 D
 . F FLR=1:1:25 D
 . . K ROWS
 . . S OK=$$GENFLOOR^DCGEN(FLR,.ROWS)
 . . D ASSERT(OK,"DCGEN failed run="_RUN_" floor="_FLR)
 . . I OK D VERIFY(.ROWS,"DCGEN run="_RUN_" floor="_FLR)
 S OK=$$GENMAP^DCGEN(12)
 D ASSERT(OK,"GENMAP^DCGEN live load failed")
 D ASSERT($O(^G($J,"map",""),-1)=19,"GENMAP did not populate 20 rows in ^G($J,'map')")
 U $P W "[PASS] DCGEN: 50 stress-generated floors & live GENMAP^DCGEN verified",!
 QUIT
 ;
TMAXFLOOR ; verify MAXFLOOR & LOAD^DCMAP against repo txt/
 N MF
 S MF=$$MAXFLOOR^DCMAP
 D ASSERT(MF=25,"MAXFLOOR expected 25, got "_MF)
 K ^G($J,"map")
 D LOAD^DCMAP(1)
 D ASSERT($L($G(^G($J,"map",0)))=60,"LOAD^DCMAP(1) row 0 length 60")
 D LOAD^DCMAP(25)
 D ASSERT($L($G(^G($J,"map",19)))=60,"LOAD^DCMAP(25) row 19 length 60")
 U $P W "[PASS] DCMAP: MAXFLOOR=25 and floor 1/25 loading verified",!
 QUIT
 ;
TRATFLEE ; wounded rat flees instead of attacking
 N ROWS,KILLED
 S ROWS(0)="......................"
 S ROWS(1)=".####################."
 S ROWS(2)=".#@r    #           #."
 S ROWS(3)=".####################."
 S ROWS(4)="......................"
 D RESETRUN(.ROWS,4)
 U NULLDEV
 D CLRFLASH^DCTERM
 S KILLED=$$HIT^DCENT(3,2,$$ATK^DCPLAY)
 D TICK^DCENT(2,2)
 U $P
 D ASSERT(KILLED=0,"rat should survive 1 dmg")
 D ASSERT($G(^G($J,"msg"))["you hit rat for 1 (1 hp left).","rat hit flash: "_$G(^G($J,"msg")))
 D ASSERT('$D(^G($J,"ent",2,3)),"rat did not leave (3,2)")
 D ASSERT($$ENTGL^DCENT(2,4)="r","wounded rat did not flee to (4,2)")
 D ASSERT($$ENTHP^DCENT(2,4)=1,"fled rat lost hp metadata")
 D ASSERT($$HP^DCPLAY=10,"wounded rat attacked instead of fleeing")
 U $P W "[PASS] ACTRAT: wounded rat flees without retaliating",!
 QUIT
 ;
TGOBCOMBAT ; goblin chase within 6 tiles, 4-hit unarmed kill & retaliation
 N ROWS,KILLED
 S ROWS(0)="................."
 S ROWS(1)=".###############."
 S ROWS(2)=".#@    g       #."
 S ROWS(3)=".###############."
 S ROWS(4)="................."
 D RESETRUN(.ROWS,4)
 U NULLDEV
 ; player moves (2,2)->(3,2), goblin chases (7,2)->(6,2)
 D TICK^DCENT(3,2)
 U $P
 D ASSERT($$ENTGL^DCENT(2,6)="g","goblin failed to chase 7->6")
 U NULLDEV
 ; player moves (3,2)->(4,2), goblin chases (6,2)->(5,2)
 D TICK^DCENT(4,2)
 U $P
 D ASSERT($$ENTGL^DCENT(2,5)="g","goblin failed to chase 6->5")
 ; bump 1: g hp 3, retaliates -> player hp 8
 U NULLDEV D CLRFLASH^DCTERM S KILLED=$$HIT^DCENT(5,2,1) D TICK^DCENT(4,2) U $P
 D ASSERT(KILLED=0,"goblin alive after hit 1")
 D ASSERT($G(^G($J,"msg"))["3 hp left","hit 1 flash missing 3 hp left")
 D ASSERT($G(^G($J,"msg"))["goblin attacks you for 2","goblin failed to retaliate")
 D ASSERT($$HP^DCPLAY=8,"player hp should be 8 after hit 1")
 ; bump 2 & 3 -> player hp 6, then 4
 U NULLDEV D CLRFLASH^DCTERM S KILLED=$$HIT^DCENT(5,2,1) D TICK^DCENT(4,2) U $P
 D ASSERT($$HP^DCPLAY=6,"player hp should be 6 after hit 2")
 U NULLDEV D CLRFLASH^DCTERM S KILLED=$$HIT^DCENT(5,2,1) D TICK^DCENT(4,2) U $P
 D ASSERT($$HP^DCPLAY=4,"player hp should be 4 after hit 3")
 ; bump 4 -> SLAIN (+10 gold), no retaliation!
 U NULLDEV D CLRFLASH^DCTERM S KILLED=$$HIT^DCENT(5,2,1) D TICK^DCENT(4,2) U $P
 D ASSERT(KILLED=1,"goblin should die on hit 4")
 D ASSERT('$D(^G($J,"ent",2,5)),"dead goblin still in ^G($J,'ent')")
 D ASSERT($G(^G($J,"msg"))["you slay the goblin! (+10 gold)","slay flash missing")
 D ASSERT($$HP^DCPLAY=4,"slain goblin should not retaliate")
 D ASSERT(+$G(^G($J,"score"))=10,"goblin slay should award +10 gold")
 U $P W "[PASS] ACTGOB & combat: chase, 4-hit unarmed kill, retaliation & gold verified",!
 QUIT
 ;
TWEAPEPASS ; weapon stacking ()+}=4 atk), 1-shot goblin, EPASS blocks enemy behind '+' even with key
 N ROWS,KILLED
 S ROWS(0)=".............."
 S ROWS(1)=".############."
 S ROWS(2)=".#})(@   g  #."
 S ROWS(3)=".###+########."
 S ROWS(4)=".###g########."
 S ROWS(5)=".############."
 S ROWS(6)=".............."
 D RESETRUN(.ROWS,6)
 ; step onto key '(' at (4,2) -> g2 at (4,4) must stay blocked by '+' at (4,3)
 U NULLDEV
 D STEP^DCMAP(4,2)
 D TICK^DCENT(4,2)
 U $P
 D ASSERT($$HAS^DCINV("(")=1,"player should hold key")
 D ASSERT($$EPASS^DCMAP(4,3)=0,"EPASS must block closed door '+' even when player holds key")
 D ASSERT($$GLYPHAT^DCMAP(4,3)="+","closed door '+' should remain closed")
 D ASSERT($$ENTGL^DCENT(4,4)="g","enemy behind '+' phased through door")
 D ASSERT($$ENTGL^DCENT(2,8)="g","g1 should chase to (8,2)")
 ; equip dagger ')' (+1 -> atk 2) and sword '}' (+2 -> atk 4)
 U NULLDEV
 D STEP^DCMAP(3,2)
 D TICK^DCENT(3,2)
 U $P
 D ASSERT($$ATK^DCPLAY=2,"dagger should set atk=2")
 U NULLDEV
 D STEP^DCMAP(2,2)
 D TICK^DCENT(2,2)
 U $P
 D ASSERT($$ATK^DCPLAY=4,"sword + dagger should stack to atk=4")
 ; walk right to (4,2) while g1 reaches (5,2), then 1-shot g1 with atk=4
 U NULLDEV
 D TICK^DCENT(3,2)
 D TICK^DCENT(4,2)
 D CLRFLASH^DCTERM
 S KILLED=$$HIT^DCENT(5,2,$$ATK^DCPLAY)
 U $P
 D ASSERT(KILLED=1,"atk=4 should 1-shot 4-HP goblin")
 D ASSERT($G(^G($J,"msg"))["you slay the goblin! (+10 gold)","1-shot slay flash")
 U $P W "[PASS] weapons & EPASS: dagger+sword stacking (atk=4), 1-shot kill & door block verified",!
 QUIT
 ;
TCOMBATDIE ; 3 spikes (-9 hp -> 1 hp) then goblin retaliation -> combat death cause
 N ROWS
 S ROWS(0)="................"
 S ROWS(1)=".##############."
 S ROWS(2)=".#@^^^        #."
 S ROWS(3)=".#####g########."
 S ROWS(4)=".##############."
 S ROWS(5)="................"
 D RESETRUN(.ROWS,5)
 U NULLDEV
 D STEP^DCMAP(3,2),TICK^DCENT(3,2)
 D STEP^DCMAP(4,2),TICK^DCENT(4,2)
 D STEP^DCMAP(5,2),TICK^DCENT(5,2)
 D STEP^DCMAP(6,2),TICK^DCENT(6,2)
 U $P
 D ASSERT($$ALIVE^DCPLAY=0,"player should be dead after spikes + goblin")
 D ASSERT($$CAUSE^DCPLAY="slain by goblin","expected cause 'slain by goblin', got '"_$$CAUSE^DCPLAY_"'")
 U $P W "[PASS] combat death: spike damage + goblin retaliation death cause verified",!
 QUIT
 ;
TBATOVER ; bat flutters over gold & poison without corrupting underlying ^G("map")
 N ROWS,TURN,Y,X,BCNT,GL,TCNT
 S ROWS(0)=".............."
 S ROWS(1)=".############."
 S ROWS(2)=".#@ # $b$   #."
 S ROWS(3)=".#  # ~~~   #."
 S ROWS(4)=".############."
 S ROWS(5)=".............."
 D RESETRUN(.ROWS,5)
 U NULLDEV
 F TURN=1:1:12 D TICK^DCENT($S(TURN#2=1:3,1:2),2)
 U $P
 S BCNT=0,Y=""
 F  S Y=$O(^G($J,"ent",Y)) Q:Y=""  D
 . S X="" F  S X=$O(^G($J,"ent",Y,X)) Q:X=""  I $$ENTGL^DCENT(Y,X)="b" S BCNT=BCNT+1
 D ASSERT(BCNT=1,"bat disappeared or duplicated (count="_BCNT_")")
 S TCNT=0
 F Y=2:1:3 F X=5:1:11 D
 . S GL=$$GLYPHAT^DCMAP(X,Y)
 . I (GL="$")!(GL="~") S TCNT=TCNT+1
 D ASSERT(TCNT=5,"bat corrupted underlying terrain in ^G($J,'map'): expected 5 items/traps, got "_TCNT)
 U $P W "[PASS] ACTBAT: 12 turns over $ and ~ with zero terrain corruption",!
 QUIT
 ;
TITEMS ; spike disarm, poison persistence, vegan foods & HP cap, multi-key consume, locked door
 N ROWS
 S ROWS(0)="........................"
 S ROWS(1)=".######################."
 S ROWS(2)=".#@^~A!BMT((+         #."
 S ROWS(3)=".######################."
 S ROWS(4)="........................"
 D RESETRUN(.ROWS,4)
 ; locked door '+' blocked with 0 keys
 D ASSERT($$PASS^DCMAP(12,2)=0,"locked door should block player without key")
 ; spike at (3,2) -> -3 hp (7), disarms to ' '
 U NULLDEV D CLRFLASH^DCTERM,STEP^DCMAP(3,2) U $P
 D ASSERT($$HP^DCPLAY=7,"spike should leave hp=7")
 D ASSERT($$GLYPHAT^DCMAP(3,2)=" ","spike should disarm to floor")
 ; poison at (4,2) -> -1 hp (6), persists
 U NULLDEV D CLRFLASH^DCTERM,STEP^DCMAP(4,2) U $P
 D ASSERT($$HP^DCPLAY=6,"poison should leave hp=6")
 D ASSERT($$GLYPHAT^DCMAP(4,2)="~","poison should persist")
 ; re-step disarmed (3,2) -> still 6, re-step poison (4,2) -> 5
 U NULLDEV D STEP^DCMAP(3,2) U $P
 D ASSERT($$HP^DCPLAY=6,"disarmed spike should deal 0 dmg")
 U NULLDEV D STEP^DCMAP(4,2) U $P
 D ASSERT($$HP^DCPLAY=5,"re-stepping poison should leave hp=5")
 ; apple A (+3 -> 8), potion ! (+5 -> capped 10), B/M/T (stay 10)
 U NULLDEV D CLRFLASH^DCTERM,STEP^DCMAP(5,2) U $P
 D ASSERT($$HP^DCPLAY=8,"apple should heal to 8")
 D ASSERT($G(^G($J,"msg"))["apple","apple flash")
 U NULLDEV D CLRFLASH^DCTERM,STEP^DCMAP(6,2) U $P
 D ASSERT($$HP^DCPLAY=10,"potion should cap at 10")
 U NULLDEV D CLRFLASH^DCTERM,STEP^DCMAP(7,2),CLRFLASH^DCTERM,STEP^DCMAP(8,2),CLRFLASH^DCTERM,STEP^DCMAP(9,2) U $P
 D ASSERT($$HP^DCPLAY=10,"B/M/T should stay capped at 10")
 D ASSERT($G(^G($J,"msg"))["tofu","tofu flash")
 ; two keys -> count 2, unlock '+' -> count 1, door becomes '/'
 U NULLDEV D STEP^DCMAP(10,2),STEP^DCMAP(11,2) U $P
 D ASSERT($$COUNT^DCINV("(")=2,"expected 2 keys")
 D ASSERT($$PASS^DCMAP(12,2)=1,"locked door should be passable with key")
 U NULLDEV D CLRFLASH^DCTERM,STEP^DCMAP(12,2) U $P
 D ASSERT($$COUNT^DCINV("(")=1,"unlocking door should consume 1 key")
 D ASSERT($$GLYPHAT^DCMAP(12,2)="/","unlocked door should turn into '/'")
 D ASSERT($G(^G($J,"msg"))["the door unlocks.","unlock flash")
 U $P W "[PASS] items & traps: spike disarm, poison persist, vegan foods, HP cap & multi-key doors",!
 QUIT
 ;
TDESCEND ; stairs trigger ^G($J,"descend") and state carries across floor transitions
 N ROWS
 S ROWS(0)=".........."
 S ROWS(1)=".########."
 S ROWS(2)=".#@$>   #."
 S ROWS(3)=".########."
 S ROWS(4)=".........."
 D RESETRUN(.ROWS,4)
 U NULLDEV
 D STEP^DCMAP(3,2) ; gold +10
 D STEP^DCMAP(4,2) ; stairs -> descend flag
 U $P
 D ASSERT(+$G(^G($J,"score"))=10,"gold +10 before stairs")
 D ASSERT(+$G(^G($J,"descend"))=1,"stepping on '>' should set ^G($J,'descend')=1")
 U $P W "[PASS] progression: gold pickup & stairs descent trigger verified",!
 QUIT
 ;
TISOL ; multi-job isolation in ^G($J), CLEANUP^DCRAWL, and idempotent SEED^DCTYPE
 N OTHER
 S OTHER=$J+999999
 S ^G(OTHER,"score")=777,^G(OTHER,"floor")=9,^G(OTHER,"player","hp")=5
 S ^G($J,"score")=15,^G($J,"floor")=2
 D SETNAME^DCPLAY("JRD")
 D ASSERT($$NAME^DCPLAY="JRD","SETNAME/NAME should store JRD")
 D ASSERT(^G(OTHER,"score")=777,"other job score unaffected")
 D CLEANUP^DCRAWL($J)
 D ASSERT('$D(^G($J)),"CLEANUP^DCRAWL($J) must remove current job state")
 D ASSERT(^G(OTHER,"score")=777,"CLEANUP^DCRAWL($J) must not touch other job state")
 K ^G(OTHER)
 ; verify SEED^DCTYPE is idempotent and does not wipe custom sentinel when version matches
 S ^TYPE("test_sentinel","Z")="ok"
 D SEED^DCTYPE
 D ASSERT($G(^TYPE("test_sentinel","Z"))="ok","idempotent SEED^DCTYPE should not wipe ^TYPE when version matches")
 K ^TYPE("test_sentinel")
 U $P W "[PASS] isolation: ^G($J) scoping, CLEANUP^DCRAWL & idempotent SEED^DCTYPE verified",!
 QUIT
 ;
TSCORES ; persistent ^SCORES recording, 3-letter initials, LEADER & descending collation
 N ID1,ID2,ID3,ID4,NEG,ID,RANK,RES,REC,LEAD
 K ^SCORES
 D ASSERT($$LEADER^DCSCORE="","empty ^SCORES should have empty LEADER")
 ; Run A: score 10, DEAD, poison tile, default empty initials -> "---"
 K ^G($J) S ^G($J,"score")=10,^G($J,"floor")=1,^G($J,"cause")="poison tile"
 D SETNAME^DCPLAY("")
 S ID1=$$RECORD^DCSCORE("DEAD")
 ; Run B: score 50, WIN, reached final stairs, initials "JRD"
 K ^G($J) S ^G($J,"score")=50,^G($J,"floor")=3,^G($J,"cause")=""
 D SETNAME^DCPLAY("JRD")
 S ID2=$$RECORD^DCSCORE("WIN")
 ; Run C: score 20, DEAD, spike trap, initials "MAX" (caret stripped if present)
 K ^G($J) S ^G($J,"score")=20,^G($J,"floor")=2,^G($J,"cause")="spike trap"
 D SETNAME^DCPLAY("M^X")
 S ID3=$$RECORD^DCSCORE("DEAD")
 ; Run D: legacy 7-piece record without piece 8
 S ID4=$I(^SCORES("seq"))
 S ^SCORES("run",ID4)="5^1^DEAD^legacy^"_$H_"^"_$ZUT_"^"_$J
 S ^SCORES("idx",-5,ID4)=""
 ; walk inverted index ^SCORES("idx",-score,id)
 S RANK=0,NEG=""
 F  S NEG=$O(^SCORES("idx",NEG)) Q:NEG=""  D
 . S ID="" F  S ID=$O(^SCORES("idx",NEG,ID)) Q:ID=""  D
 . . S RANK=RANK+1
 . . S RES(RANK)=$G(^SCORES("run",ID))
 D ASSERT(RANK=4,"expected 4 rows in ^SCORES, got "_RANK)
 D ASSERT($P(RES(1),"^",1)=50,"rank 1 score expected 50")
 D ASSERT($P(RES(1),"^",3)="WIN","rank 1 result expected WIN")
 D ASSERT($P(RES(1),"^",4)="reached final stairs","rank 1 cause")
 D ASSERT($P(RES(1),"^",8)="JRD","rank 1 initials expected JRD")
 D ASSERT($P(RES(2),"^",1)=20,"rank 2 score expected 20")
 D ASSERT($P(RES(2),"^",4)="spike trap","rank 2 cause")
 D ASSERT($P(RES(2),"^",8)="MX","caret should be stripped from initials")
 D ASSERT($P(RES(3),"^",1)=10,"rank 3 score expected 10")
 D ASSERT($P(RES(3),"^",4)="poison tile","rank 3 cause")
 D ASSERT($P(RES(3),"^",8)="---","empty initials should default to ---")
 S LEAD=$$LEADER^DCSCORE
 D ASSERT(LEAD="JRD^50^3^WIN","LEADER expected JRD^50^3^WIN, got "_LEAD)
 S REC=RES(1)
 D ASSERT($P(REC,"^",5)[",","^SCORES should store $H")
 D ASSERT(+$P(REC,"^",6)>0,"^SCORES should store $ZUT")
 D ASSERT(+$P(REC,"^",7)>0,"^SCORES should store $J")
 K ^G($J)
 U $P W "[PASS] ^SCORES: 4-run persistence, 3-char initials, LEADER & descending collation verified",!
 QUIT
