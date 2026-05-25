DCTYPE ; type registry 
 ; v1.1.0
 ; one place to declare what glyphs mean
 ; ^TYPE(kind,glyph) = label^value^behavior
 ;   kind     one of: wall void floor door enemy trap item exit
 ;   label    human-readable name
 ;   value    damage amount (traps, enemies), heal amount (potions), score (gold)
 ;   behavior routine label in DCMAP to dispatch on step (empty = no side effect)
 ; adding a new enemy, trap, item, or door: one SET.
 QUIT
SEED ;
 K ^TYPE
 ; terrain
 S ^TYPE("wall","#")="stone wall^0^"
 S ^TYPE("void",".")="void^0^"
 S ^TYPE("floor"," ")="floor^0^"
 ; doors, value 1 means "needs key"
 S ^TYPE("door","+")="closed door^1^"
 S ^TYPE("door","/")="open door^0^"
 ; enemies, value = contact damage
 S ^TYPE("enemy","g")="goblin^2^"
 S ^TYPE("enemy","r")="rat^1^"
 S ^TYPE("enemy","b")="bat^1^"
 ; traps, value = damage on step
 S ^TYPE("trap","^")="spike trap^3^TRAPSP"
 S ^TYPE("trap","~")="poison tile^1^TRAPPO"
 ; items, value = heal or score amount
 S ^TYPE("item","!")="potion^5^ITEMPO"
 S ^TYPE("item","M")="vegan meat^10^ITEMME"
 S ^TYPE("item","A")="apple^3^ITEMAP"
 S ^TYPE("item","B")="bread^7^ITEMBR"
 S ^TYPE("item","T")="tofu^15^ITEMTO"
 S ^TYPE("item","(")= "key^0^ITEMKE"
 S ^TYPE("item","$")="gold^10^ITEMGO"
 ; exit
 S ^TYPE("exit",">")="stairs^0^EXITST"
 QUIT
KIND(GLYPH) ; reverse lookup, returns kind for a glyph, "" if unknown
 N K
 S K=""
 F  S K=$O(^TYPE(K)) Q:K=""  I $D(^TYPE(K,GLYPH)) Q
 Q K
FIELD(KIND,GLYPH,N) ; nth caret-delimited field of the type record
 Q $P($G(^TYPE(KIND,GLYPH)),"^",N)
