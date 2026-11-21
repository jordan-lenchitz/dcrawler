DCPLAY ; player state - v2.2.0
 ; hp, attack, cause of damage, start placement, alive check, arcade initials
 ; scoped per MUMPS job under ^G($J,...) for multi-user concurrency
 ; as always player position is $X and $Y = not stored here
 ; PX and PY are read out of $X and $Y at the top of every turn
 QUIT
INIT ; initialize new run stats and place player at @ (preserves ^G($J,"name"))
 K ^G($J,"inv"),^G($J,"score"),^G($J,"won"),^G($J,"descend"),^G($J,"cause")
 S ^G($J,"player","hp")=10
 S ^G($J,"player","hpmax")=10
 S ^G($J,"player","atk")=1
 D PLACE
 QUIT
PLACE ; find @ in current loaded map, replace with floor, draw @ and set $X/$Y
 N SX,SY
 D FINDSTART(.SX,.SY)
 I '$D(SX) W "no @ in dungeon map" Q
 D SETCELL^DCMAP(SX,SY," ")
 D PUTCH^DCTERM(SX,SY,"@",$$COLOR^DCTYPE("@"))
 D MOVECUR^DCTERM(SX,SY)
 QUIT
FINDSTART(X,Y) ; scan map for @, return X and Y by reference
 N R,C,ROW,MAX
 S MAX=$O(^G($J,"map",""),-1)
 F R=0:1:MAX D  Q:$D(X)
 . S ROW=$G(^G($J,"map",R))
 . F C=0:1:$L(ROW)-1 D  Q:$D(X)
 . . I $E(ROW,C+1)="@" S X=C,Y=R
 QUIT
DAMAGE(AMT,CAUSE) ; reduce player HP and record cause
 S ^G($J,"player","hp")=$G(^G($J,"player","hp"))-AMT
 I $G(CAUSE)'="" S ^G($J,"cause")=CAUSE
 QUIT
HEAL(AMT) ;
 S ^G($J,"player","hp")=$G(^G($J,"player","hp"))+AMT
 I ^G($J,"player","hp")>^G($J,"player","hpmax") S ^G($J,"player","hp")=^G($J,"player","hpmax")
 QUIT
UPATK(AMT) ; upgrade player attack damage
 S ^G($J,"player","atk")=+$G(^G($J,"player","atk"),1)+AMT
 QUIT
SETNAME(NM) ; set 3-letter arcade initials for this session (empty -> "---")
 N CLEAN
 S CLEAN=$TR($E($G(NM),1,3),"^","")
 S ^G($J,"name")=$S(CLEAN'="":CLEAN,1:"---")
 QUIT
NAME() Q $G(^G($J,"name"),"---")
HP() Q +$G(^G($J,"player","hp"))
HPMAX() Q +$G(^G($J,"player","hpmax"))
ATK() Q +$G(^G($J,"player","atk"),1)
CAUSE() Q $G(^G($J,"cause"),"unknown")
ALIVE() Q +$G(^G($J,"player","hp"))>0
PX() Q $X
PY() Q $Y
