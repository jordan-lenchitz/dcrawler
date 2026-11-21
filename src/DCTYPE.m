DCTYPE ; type registry - v2.2.0
 ; one place to declare what glyphs mean
 ; ^TYPE(kind,glyph) = label^value^behavior^color^hp
 ;   kind     one of: wall void floor door enemy trap item exit
 ;   label    human-readable name
 ;   value    damage amount (traps, enemies), heal/atk/score (items)
 ;   behavior routine label in DCMAP (items/traps) or DCENT (enemy logic)
 ;   color    ANSI SGR code (e.g. "1;31"), empty for default terminal color
 ;   hp       enemy max HP (enemies only)
 ; adding a new enemy, trap, item, or door: one SET.
 QUIT
SEED ; concurrency-safe idempotent seed (never wipes ^TYPE while other jobs read)
 I $G(^TYPEVER)="2.2.0",$D(^TYPE("exit",">")) QUIT
 L +^TYPEVER:5
 I $G(^TYPEVER)="2.2.0",$D(^TYPE("exit",">")) L -^TYPEVER QUIT
 TSTART ():SERIAL
 K ^TYPE
 ; terrain
 S ^TYPE("wall","#")="stone wall^0^^90"
 S ^TYPE("void",".")="void^0^^2;90"
 S ^TYPE("floor"," ")="floor^0^^"
 ; doors, value 1 means "needs key"
 S ^TYPE("door","+")="closed door^1^^33"
 S ^TYPE("door","/")="open door^0^^2;33"
 ; enemies: label^damage^strategy_label^color^max_hp
 S ^TYPE("enemy","g")="goblin^2^ACTGOB^1;32^4"
 S ^TYPE("enemy","r")="rat^1^ACTRAT^33^2"
 S ^TYPE("enemy","b")="bat^1^ACTBAT^1;35^2"
 ; traps: label^damage^behavior^color
 S ^TYPE("trap","^")="spike trap^3^TRAPSP^1;31"
 S ^TYPE("trap","~")="poison tile^1^TRAPPO^32"
 ; items: label^value^behavior^color
 S ^TYPE("item","!")="potion^5^ITEMPO^1;35"
 S ^TYPE("item","M")="vegan meat^10^ITEMME^32"
 S ^TYPE("item","A")="apple^3^ITEMAP^31"
 S ^TYPE("item","B")="bread^7^ITEMBR^33"
 S ^TYPE("item","T")="tofu^15^ITEMTO^1;36"
 S ^TYPE("item","(")="key^0^ITEMKE^1;33"
 S ^TYPE("item","$")="gold^10^ITEMGO^1;33"
 S ^TYPE("item",")")="dagger^1^ITEMDG^1;37"
 S ^TYPE("item","}")="sword^2^ITEMSW^1;37"
 ; exit
 S ^TYPE("exit",">")="stairs^0^EXITST^1;37"
 S ^TYPEVER="2.2.0"
 TCOMMIT
 L -^TYPEVER
 QUIT
KIND(GLYPH) ; reverse lookup, returns kind for a glyph, "" if unknown
 N K
 S K=""
 F  S K=$O(^TYPE(K)) Q:K=""  I $D(^TYPE(K,GLYPH)) Q
 Q K
FIELD(KIND,GLYPH,N) ; nth caret-delimited field of the type record
 Q $P($G(^TYPE(KIND,GLYPH)),"^",N)
COLOR(GLYPH) ; ANSI SGR color code for any glyph (including player @)
 I GLYPH="@" Q "1;36"
 N K
 S K=$$KIND(GLYPH)
 I K="" Q ""
 Q $$FIELD(K,GLYPH,4)
HP(GLYPH) ; starting HP for an enemy glyph
 N V
 S V=+$$FIELD("enemy",GLYPH,5)
 Q $S(V>0:V,1:1)
