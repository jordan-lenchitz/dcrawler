DCGEN ; procedural room-and-corridor dungeon generator - v2.1.0
 ; ANSI MUMPS (tested on YottaDB & GT.M)
 ; CLI:      mumps -run '^DCGEN'  (env: DCGEN_FLOORS, DCGEN_OUT)
 ; library:  D GENALL^DCGEN(25,"txt")
 ;           S OK=$$GENFLOOR^DCGEN(FLOOR,.ROWS)
 ;           S OK=$$GENMAP^DCGEN(FLOOR)   ; live procedural load into ^G("map")
 N FLOORS,OUTDIR
 S FLOORS=+$ZTRNLNM("DCGEN_FLOORS")
 I FLOORS'>0 S FLOORS=25
 S OUTDIR=$ZTRNLNM("DCGEN_OUT")
 I OUTDIR="" S OUTDIR="txt"
 D GENALL(FLOORS,OUTDIR)
 QUIT
 ;
GENALL(FLOORS,OUTDIR) ; generate FLOORS sequential dungeon files into OUTDIR
 N I,ROWS,OK,PATH
 F I=1:1:FLOORS D
 . K ROWS
 . S OK=$$GENFLOOR(I,.ROWS)
 . I 'OK W "Failed to generate connected dungeon for floor ",I,! ZHALT 1
 . S PATH=OUTDIR_"/dungeon_"_I_".txt"
 . D WRITEDUN(PATH,.ROWS)
 . W "Generated ",PATH," (floor ",I,")",!
 W "Generated ",FLOORS," dungeon(s) in ",OUTDIR,!
 QUIT
 ;
GENMAP(FLOOR) ; generate a floor directly into ^G("map",0..19) for live procedural play
 N ROWS,R,OK
 S OK=$$GENFLOOR(FLOOR,.ROWS)
 I 'OK Q 0
 K ^G("map")
 F R=0:1:19 S ^G("map",R)=ROWS(R)
 Q 1
 ;
GENFLOOR(FLOOR,ROWS) ; retry up to 200 times to build a valid floor into ROWS(0..19)
 N TRY,OK
 S OK=0
 F TRY=1:1:200 D  Q:OK
 . K ROWS
 . S OK=$$TRYGEN(FLOOR,.ROWS)
 Q OK
 ;
WRITEDUN(PATH,ROWS) ; write 20x60 dungeon rows to disk with clean LF line endings
 N R
 O PATH:(NEWVERSION:NOWRAP):5 E  W "Cannot open ",PATH,! ZHALT 1
 U PATH
 F R=0:1:19 W ROWS(R),!
 C PATH
 U $P
 QUIT
 ;
TRYGEN(FLOOR,ROWS) ; single generation attempt; returns 1 on success, 0 on retry
 N GRID,R,C,TARGET,RCNT,ATT,H,W,RR,CC,OV,I,J
 N RM,RC,RMC,STARTI,EXITI,BESTV,VAL,D
 N MAIN,MCNT,CONN,REM,REMCNT,BESTD,BA,BB,AI,BI,IDX
 N NEARI,EXITCELL,MAINCELL,BRIDGE,BLEN
 N PR,PC,ER,EC,DOORR,DOORC,HCHOKE,VCHOKE,RNO,RYES
 N KEYALL,KACNT,KEYNON,KNCNT,KR,KC,USED
 N RSPOTS,RSLEN,SSPOTS,SSLEN,WPOOL,WLEN,TPOOL,TLEN
 N WP,WGL,NPOT,NFOOD,FPOOL,FLEN,NGOLD,GMIN,GMAX
 N NEN,EPOOL,ELEN,NTRAP,P,LINE,STARTCELL
 ; initialize 20x60 grid with void '.'
 F R=0:1:19 F C=0:1:59 S GRID(R,C)="."
 ; place non-overlapping rectangular rooms
 S TARGET=5+(FLOOR\2)
 I TARGET>8 S TARGET=8
 S RCNT=0
 F ATT=1:1:200 Q:RCNT'<TARGET  D
 . S H=4+$R(3)
 . S W=6+$R(7)
 . S RR=2+$R(17-H)
 . S CC=2+$R(57-W)
 . S OV=0
 . F I=1:1:RCNT I $$INTERSECT(RR,CC,H,W,RM(I,"r"),RM(I,"c"),RM(I,"h"),RM(I,"w"),2) S OV=1 Q
 . I OV Q
 . S RCNT=RCNT+1
 . S RM(RCNT,"r")=RR,RM(RCNT,"c")=CC,RM(RCNT,"h")=H,RM(RCNT,"w")=W
 . S RC(RCNT)=RR+(H\2),RMC(RCNT)=CC+(W\2)
 . D CARVERM(.GRID,RR,CC,H,W)
 I RCNT<4 Q 0
 ; pick start room (leftmost-ish) and exit room (farthest Manhattan from start)
 S STARTI=1,BESTV=999999
 F I=1:1:RCNT D
 . S VAL=RMC(I)+($R(9)-4)
 . I VAL<BESTV S BESTV=VAL,STARTI=I
 S EXITI=0,BESTV=-1
 F I=1:1:RCNT D
 . I I=STARTI Q
 . S D=$$MDIST(RC(I),RMC(I),RC(STARTI),RMC(STARTI))
 . I D>BESTV S BESTV=D,EXITI=I
 ; collect non-exit (main) rooms
 S MCNT=0
 F I=1:1:RCNT I I'=EXITI S MCNT=MCNT+1,MAIN(MCNT)=I
 ; connect main rooms via nearest-neighbor spanning tree
 S CONN(STARTI)=1,REMCNT=0
 F I=1:1:MCNT S J=MAIN(I) I J'=STARTI S REM(J)=1,REMCNT=REMCNT+1
 F  Q:REMCNT'>0  D
 . S BESTD=999999,BA=0,BB=0
 . S AI="" F  S AI=$O(CONN(AI)) Q:AI=""  D
 . . S BI="" F  S BI=$O(REM(BI)) Q:BI=""  D
 . . . S D=$$MDIST(RC(AI),RMC(AI),RC(BI),RMC(BI))
 . . . I D<BESTD S BESTD=D,BA=AI,BB=BI
 . D CARVECOR(.GRID,RC(BA),RMC(BA),RC(BB),RMC(BB))
 . S CONN(BB)=1 K REM(BB) S REMCNT=REMCNT-1
 ; optional extra loop among main rooms
 I MCNT'<4 D
 . S AI=MAIN(1+$R(MCNT))
 . F  S BI=MAIN(1+$R(MCNT)) Q:BI'=AI
 . D CARVECOR(.GRID,RC(AI),RMC(AI),RC(BI),RMC(BI))
 ; connect exit room via a single bridge corridor from nearest main room
 S NEARI=MAIN(1),BESTD=999999
 F I=1:1:MCNT D
 . S J=MAIN(I)
 . S D=$$MDIST(RC(J),RMC(J),RC(EXITI),RMC(EXITI))
 . I D<BESTD S BESTD=D,NEARI=J
 D MARKRM(.RM,EXITI,.EXITCELL)
 D MARKRM(.RM,STARTI,.STARTCELL)
 F I=1:1:MCNT D MARKRM(.RM,MAIN(I),.MAINCELL)
 S BLEN=0
 D CARVECOR(.GRID,RC(NEARI),RMC(NEARI),RC(EXITI),RMC(EXITI),.BRIDGE,.BLEN)
 D WRAPWALL(.GRID)
 S PR=RC(STARTI),PC=RMC(STARTI)
 S ER=RC(EXITI),EC=RMC(EXITI)
 ; place closed door '+' on a bridge chokepoint separating @ from >
 S DOORR=-1,DOORC=-1
 F I=BLEN:-1:1 D  Q:DOORR'<0
 . S R=$P(BRIDGE(I),"^",1),C=$P(BRIDGE(I),"^",2)
 . I $D(EXITCELL(R,C))!$D(MAINCELL(R,C)) Q
 . S HCHOKE=($G(GRID(R-1,C))="#")&($G(GRID(R+1,C))="#")
 . S VCHOKE=($G(GRID(R,C-1))="#")&($G(GRID(R,C+1))="#")
 . I '(HCHOKE!VCHOKE) Q
 . S GRID(R,C)="+"
 . D BFS(.GRID,PR,PC," ",.RNO)
 . D BFS(.GRID,PR,PC," +",.RYES)
 . I '$D(RNO(ER,EC)),$D(RYES(ER,EC)) S DOORR=R,DOORC=C Q
 . S GRID(R,C)=" "
 I DOORR<0 Q 0
 ; place player start and stairs
 S GRID(PR,PC)="@",GRID(ER,EC)=">"
 S USED(PR,PC)=1,USED(ER,EC)=1,USED(DOORR,DOORC)=1
 ; place key '(' in a reachable main room cell (prefer non-start room)
 S KACNT=0,KNCNT=0
 S R="" F  S R=$O(RNO(R)) Q:R=""  D
 . S C="" F  S C=$O(RNO(R,C)) Q:C=""  D
 . . I $D(USED(R,C)) Q
 . . I '$D(MAINCELL(R,C)) Q
 . . I GRID(R,C)'=" " Q
 . . S KACNT=KACNT+1,KEYALL(KACNT)=R_"^"_C
 . . I '$D(STARTCELL(R,C)) S KNCNT=KNCNT+1,KEYNON(KNCNT)=R_"^"_C
 I KACNT=0 Q 0
 I KNCNT>0 S P=KEYNON(1+$R(KNCNT))
 E  S P=KEYALL(1+$R(KACNT))
 S KR=$P(P,"^",1),KC=$P(P,"^",2)
 S GRID(KR,KC)="(",USED(KR,KC)=1
 ; build shuffled room spot pools
 S RSLEN=0,SSLEN=0
 F I=1:1:RCNT D
 . F R=RM(I,"r"):1:(RM(I,"r")+RM(I,"h")-1) D
 . . F C=RM(I,"c"):1:(RM(I,"c")+RM(I,"w")-1) D
 . . . I $D(USED(R,C)) Q
 . . . I GRID(R,C)'=" " Q
 . . . S RSLEN=RSLEN+1,RSPOTS(RSLEN)=R_"^"_C
 . . . I $$MDIST(R,C,PR,PC)>2 S SSLEN=SSLEN+1,SSPOTS(SSLEN)=R_"^"_C
 D SHUFFLE(.RSPOTS,RSLEN)
 D SHUFFLE(.SSPOTS,SSLEN)
 ; weapon spawn scaled by floor (dagger 1-6, sword 7+) on player side of door
 S WGL=$S(FLOOR'>6:")",1:"}")
 S WLEN=0
 F I=1:1:RSLEN D
 . S R=$P(RSPOTS(I),"^",1),C=$P(RSPOTS(I),"^",2)
 . I $D(RNO(R,C)),'$D(USED(R,C)) S WLEN=WLEN+1,WPOOL(WLEN)=R_"^"_C
 I WLEN>0 D
 . S WP=WPOOL(1+$R(WLEN))
 . S R=$P(WP,"^",1),C=$P(WP,"^",2)
 . S GRID(R,C)=WGL,USED(R,C)=1
 ; healing potions '!' (2-3)
 S NPOT=2+$R(2)
 F I=1:1:NPOT D
 . S P=$$POPSPOT(.RSPOTS,.RSLEN,.GRID,.USED)
 . I P'="" S GRID($P(P,"^",1),$P(P,"^",2))="!"
 ; vegan foods scaled by floor (2-4)
 I FLOOR'>6 S FPOOL(1)="A",FPOOL(2)="B",FLEN=2
 E  I FLOOR'>15 S FPOOL(1)="B",FPOOL(2)="M",FPOOL(3)="T",FLEN=3
 E  S FPOOL(1)="M",FPOOL(2)="T",FLEN=2
 S NFOOD=2+$R(3)
 F I=1:1:NFOOD D
 . S P=$$POPSPOT(.RSPOTS,.RSLEN,.GRID,.USED)
 . I P'="" S GRID($P(P,"^",1),$P(P,"^",2))=FPOOL(1+$R(FLEN))
 ; gold '$' scaled by floor
 S GMIN=4+(FLOOR\4)
 S GMAX=6+(FLOOR\2) I GMAX>16 S GMAX=16
 I GMAX<GMIN S GMAX=GMIN
 S NGOLD=GMIN+$R((GMAX-GMIN)+1)
 F I=1:1:NGOLD D
 . S P=$$POPSPOT(.RSPOTS,.RSLEN,.GRID,.USED)
 . I P'="" S GRID($P(P,"^",1),$P(P,"^",2))="$"
 ; enemies scaled by floor (never within Manhattan distance <=2 of @)
 S NEN=2+(FLOOR\2) I NEN>15 S NEN=15
 I FLOOR'>6 S EPOOL(1)="r",EPOOL(2)="r",EPOOL(3)="b",EPOOL(4)="g",ELEN=4
 E  I FLOOR'>15 S EPOOL(1)="r",EPOOL(2)="b",EPOOL(3)="g",EPOOL(4)="g",ELEN=4
 E  S EPOOL(1)="b",EPOOL(2)="g",EPOOL(3)="g",EPOOL(4)="g",ELEN=4
 F I=1:1:NEN D
 . S P=$$POPSPOT(.SSPOTS,.SSLEN,.GRID,.USED)
 . I P'="" S GRID($P(P,"^",1),$P(P,"^",2))=EPOOL(1+$R(ELEN))
 ; traps scaled by floor (keep clear of start and doorway)
 S TLEN=0
 F I=1:1:SSLEN D
 . S R=$P(SSPOTS(I),"^",1),C=$P(SSPOTS(I),"^",2)
 . I '$D(USED(R,C)),GRID(R,C)=" ",$$MDIST(R,C,DOORR,DOORC)>1 S TLEN=TLEN+1,TPOOL(TLEN)=R_"^"_C
 S NTRAP=1+(FLOOR\2) I NTRAP>12 S NTRAP=12
 F I=1:1:NTRAP D
 . S P=$$POPSPOT(.TPOOL,.TLEN,.GRID,.USED)
 . I P'="" S GRID($P(P,"^",1),$P(P,"^",2))=$S($R(2)=0:"^",1:"~")
 ; pack 20x60 grid into ROWS(0..19)
 F R=0:1:19 D
 . S LINE=""
 . F C=0:1:59 S LINE=LINE_GRID(R,C)
 . S ROWS(R)=LINE
 Q 1
 ;
INTERSECT(R1,C1,H1,W1,R2,C2,H2,W2,PAD) ; 1 if padded rectangles overlap
 I ((R1+H1+PAD)'>R2)!((R2+H2+PAD)'>R1)!((C1+W1+PAD)'>C2)!((C2+W2+PAD)'>C1) Q 0
 Q 1
 ;
MDIST(R1,C1,R2,C2) ; Manhattan distance between (R1,C1) and (R2,C2)
 N DR,DC
 S DR=R1-R2 I DR<0 S DR=-DR
 S DC=C1-C2 I DC<0 S DC=-DC
 Q DR+DC
 ;
CARVERM(GRID,R,C,H,W) ; carve floor tiles for a rectangle room
 N RR,CC
 F RR=R:1:(R+H-1) F CC=C:1:(C+W-1) S GRID(RR,CC)=" "
 QUIT
 ;
MARKRM(RM,IDX,CELLS) ; mark all (r,c) cells belonging to room IDX
 N RR,CC
 F RR=RM(IDX,"r"):1:(RM(IDX,"r")+RM(IDX,"h")-1) D
 . F CC=RM(IDX,"c"):1:(RM(IDX,"c")+RM(IDX,"w")-1) D
 . . S CELLS(RR,CC)=1
 QUIT
 ;
CARVECOR(GRID,R1,C1,R2,C2,PATH,PLEN) ; carve L-shaped corridor, optionally recording path
 N STEP,R,C,REC
 S REC=$D(PLEN)
 I $R(2)=0 D
 . S STEP=$S(C2'<C1:1,1:-1)
 . F C=C1:STEP:C2 S GRID(R1,C)=" " I REC S PLEN=PLEN+1,PATH(PLEN)=R1_"^"_C
 . S STEP=$S(R2'<R1:1,1:-1)
 . F R=R1:STEP:R2 S GRID(R,C2)=" " I REC S PLEN=PLEN+1,PATH(PLEN)=R_"^"_C2
 E  D
 . S STEP=$S(R2'<R1:1,1:-1)
 . F R=R1:STEP:R2 S GRID(R,C1)=" " I REC S PLEN=PLEN+1,PATH(PLEN)=R_"^"_C1
 . S STEP=$S(C2'<C1:1,1:-1)
 . F C=C1:STEP:C2 S GRID(R2,C)=" " I REC S PLEN=PLEN+1,PATH(PLEN)=R2_"^"_C
 QUIT
 ;
WRAPWALL(GRID) ; turn void '.' adjacent (8-way) to floor ' ' into stone wall '#'
 N R,C,DR,DC,NR,NC,FOUND
 F R=0:1:19 D
 . F C=0:1:59 D
 . . I GRID(R,C)'="." Q
 . . S FOUND=0
 . . F DR=-1:1:1 Q:FOUND  D
 . . . F DC=-1:1:1 Q:FOUND  D
 . . . . S NR=R+DR,NC=C+DC
 . . . . I NR'<0,NR<20,NC'<0,NC<60,GRID(NR,NC)=" " S FOUND=1
 . . I FOUND S GRID(R,C)="#"
 QUIT
 ;
BFS(GRID,SR,SC,PASSSTR,VIS) ; 4-neighbor BFS from (SR,SC) across glyphs in PASSSTR
 N Q,HEAD,TAIL,R,C,D,NR,NC,DR,DC
 K VIS
 S Q(1)=SR_"^"_SC,VIS(SR,SC)=1,HEAD=1,TAIL=1
 S DR(1)=-1,DC(1)=0,DR(2)=1,DC(2)=0,DR(3)=0,DC(3)=-1,DR(4)=0,DC(4)=1
 F  Q:HEAD>TAIL  D
 . S R=$P(Q(HEAD),"^",1),C=$P(Q(HEAD),"^",2),HEAD=HEAD+1
 . F D=1:1:4 D
 . . S NR=R+DR(D),NC=C+DC(D)
 . . I NR<0!(NR>19)!(NC<0)!(NC>59) Q
 . . I $D(VIS(NR,NC)) Q
 . . I PASSSTR[GRID(NR,NC) S VIS(NR,NC)=1,TAIL=TAIL+1,Q(TAIL)=NR_"^"_NC
 QUIT
 ;
SHUFFLE(ARR,CNT) ; Fisher-Yates shuffle on 1..CNT array
 N I,J,TMP
 F I=CNT:-1:2 D
 . S J=1+$R(I)
 . S TMP=ARR(I),ARR(I)=ARR(J),ARR(J)=TMP
 QUIT
 ;
POPSPOT(POOL,LEN,GRID,USED) ; pop next unused floor cell from POOL(1..LEN)
 N P,R,C,FOUND
 S FOUND=""
 F  Q:(LEN'>0)!(FOUND'="")  D
 . S P=POOL(LEN),LEN=LEN-1
 . S R=$P(P,"^",1),C=$P(P,"^",2)
 . I '$D(USED(R,C)),GRID(R,C)=" " S USED(R,C)=1,FOUND=P
 Q FOUND
