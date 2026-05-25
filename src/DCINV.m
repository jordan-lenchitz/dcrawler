DCINV ; inventory management - v1.1.0
 ; ^G("inv",glyph) = count
 QUIT
ADD(GLYPH,QTY) ;
 S ^G("inv",GLYPH)=+$G(^G("inv",GLYPH))+QTY
 QUIT
HAS(GLYPH) Q +$G(^G("inv",GLYPH))>0
COUNT(GLYPH) Q +$G(^G("inv",GLYPH))
CONSUME(GLYPH) ;
 N N
 S N=+$G(^G("inv",GLYPH))
 I N>1 S ^G("inv",GLYPH)=N-1 Q
 K ^G("inv",GLYPH)
 QUIT
