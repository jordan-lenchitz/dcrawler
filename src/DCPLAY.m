DCPLAY ; player state - v2.0.0
 ; hp, attack, cause of damage, start placement, alive check
 ; as always player position is $X and $Y = not stored here
 ; PX and PY are read out of $X and $Y at the top of every turn
 QUIT
INIT ; initialize new run stats and place player at @
 K ^G("inv"),^G("score"),^G("won"),^G("descend"),^G("cause")
 S ^G("player","hp")=10
 S ^G("player","hpmax")=10
 S ^G("player","atk")=1
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
 S MAX=$O(^G("map",""),-1)
 F R=0:1:MAX D  Q:$D(X)
 . S ROW=$G(^G("map",R))
 . F C=0:1:$L(ROW)-1 D  Q:$D(X)
 . . I $E(ROW,C+1)="@" S X=C,Y=R
 QUIT
DAMAGE(AMT,CAUSE) ; reduce player HP and record cause
 S ^G("player","hp")=$G(^G("player","hp"))-AMT
 I $G(CAUSE)'="" S ^G("cause")=CAUSE
 QUIT
HEAL(AMT) ;
 S ^G("player","hp")=$G(^G("player","hp"))+AMT
 I ^G("player","hp")>^G("player","hpmax") S ^G("player","hp")=^G("player","hpmax")
 QUIT
UPATK(AMT) ; upgrade player attack damage
 S ^G("player","atk")=+$G(^G("player","atk"),1)+AMT
 QUIT
HP() Q +$G(^G("player","hp"))
HPMAX() Q +$G(^G("player","hpmax"))
ATK() Q +$G(^G("player","atk"),1)
CAUSE() Q $G(^G("cause"),"unknown")
ALIVE() Q +$G(^G("player","hp"))>0
PX() Q $X
PY() Q $Y
