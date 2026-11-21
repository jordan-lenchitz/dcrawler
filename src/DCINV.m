DCINV ; inventory management - v2.2.0
 ; ^G($J,"inv",glyph) = count
 QUIT
ADD(GLYPH,QTY) ;
 S ^G($J,"inv",GLYPH)=+$G(^G($J,"inv",GLYPH))+QTY
 QUIT
HAS(GLYPH) Q +$G(^G($J,"inv",GLYPH))>0
COUNT(GLYPH) Q +$G(^G($J,"inv",GLYPH))
CONSUME(GLYPH) ;
 N N
 S N=+$G(^G($J,"inv",GLYPH))
 I N>1 S ^G($J,"inv",GLYPH)=N-1 Q
 K ^G($J,"inv",GLYPH)
 QUIT
