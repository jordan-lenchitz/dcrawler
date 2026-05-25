DCPLAY ; player state - v1.1.0
 ; hp, position entry, death check
 ; as always player position is $X and $Y = not stored here
 ; PX and PY are read out of $X and $Y at the top of every turn
 QUIT
INIT ; find @ in the loaded map, set hp, place player
 N SX,SY
 K ^G("inv"),^G("score"),^G("won")
 S ^G("player","hp")=10
 S ^G("player","hpmax")=10
 D FINDSTART(.SX,.SY)
 I '$D(SX) W "no @ in dungeon.txt" Q
 D SETCELL^DCMAP(SX,SY," ")
 D MOVECUR^DCTERM(SX,SY)
 W "@"
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
DAMAGE(AMT) ;
 S ^G("player","hp")=$G(^G("player","hp"))-AMT
 QUIT
HEAL(AMT) ;
 S ^G("player","hp")=$G(^G("player","hp"))+AMT
 I ^G("player","hp")>^G("player","hpmax") S ^G("player","hp")=^G("player","hpmax")
 QUIT
HP() Q +$G(^G("player","hp"))
HPMAX() Q +$G(^G("player","hpmax"))
ALIVE() Q +$G(^G("player","hp"))>0
PX() Q $X
PY() Q $Y
