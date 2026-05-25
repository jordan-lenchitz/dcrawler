# dcrawl

a basic dungeon crawler written in ANSI MUMPS where the player position is `$X` and `$Y` and we have the decency to admit it /// a love letter to the cursor position intrinsics /// $J gets a cameo in the status bar

## running

requires gt.m (or yottadb). source your gtmprofile first, then:

```
make run-local
```

from the project root, so the dungeon file loads with a relative path.

if your routine resolution is set up globally already:

```
cd src && mumps -run '^DCRAWL'
```

### Dungeon Generation

To generate new dungeon layouts, use the `generate_dungeons.py` script:

```
python3 generate_dungeons.py
```

This will create `dungeon_N.txt` files in the `txt/` directory. The `DCMAP.m` routine can be modified to load these new dungeons (e.g., randomly selecting one).

## controls

`h j k l` or `w a s d` to move, `q` to quit. each keypress is one turn.

## glyphs

| glyph | meaning                                      |
|-------|----------------------------------------------|
| `@`   | you                                          |
| `#`   | impassable stone wall                        |
| `.`   | impassable void                              |
| ` `   | floor to walk on silently per marshall       |
| `+`   | closed door needs a key                      |
| `/`   | open door                                    |
| `g r b` | goblin rat bat = damage on bump            |
| `^`   | spike trap one-shot disarmed after trigger   |
| `~`   | poison tile = damage every step              |
| `!`   | potion = +5 hp                               |
| `M`   | 'meat' [vegan] +10 hp                        |
| `A`   | apple = +3 hp                                |
| `B`   | bread = +7 hp                                |
| `T`   | tofu = +15 hp                                |
| `(`   | key                                          |
| `$`   | gold = +10 score                             |
| `>`   | stairs = reach to win                        |

there is no combat. you dodge.

## design note

- `$X` and `$Y` are the ground truth for the player's location. they are not
  mirrored anywhere. the main loop reads them into locals (PX, PY) at the top
  of each turn, computes the move, and restores the cursor invariant at the
  bottom so the next iteration finds them pointing at the player again.
- terrain is a single source of truth: `^G("map",row)` holds the row string.
  changing a cell is a `$E` replacement, repainted by moving the cursor there
  and writing the one glyph.
- enemies live in an overlay `^G("ent",y,x)=glyph`. they are not in the map
  string so they can move without corrupting terrain underneath. in this
  basic build they are static; extending `TICK^DCENT` with per-glyph behavior
  labels is the natural next step.

## extensibility

every glyph's meaning is one row in `^TYPE`. adding a new enemy, trap, item, or
door is one SET in `SEED^DCTYPE`:

```
 S ^TYPE("enemy","Z")="zombie^2^"          ; 2 contact damage
 S ^TYPE("trap","*")="caltrops^1^TRAPSP"   ; reuses spike behavior: one-shot
 S ^TYPE("item","?")="scroll^0^ITEMSC"     ; then add ITEMSC in DCMAP.m
```

the behavior field (the third caret-separated slot) is a label in `DCMAP.m`
for items, traps, and doors; for enemies it's a label in `DCENT.m` invoked
on each tick with `(X,Y,PX,PY)`. indirection via `D @BEH` handles dispatch.

add the new glyph to `data/dungeon.txt` and it just works.

## layout

```
src/
  DCENT.m                 entity overlay, tick loop (subscript-filtered, safe to extend)
  DCINV.m                 inventory add / has / count / consume
  DCMAP.m                 map load, paint, passability, step effects, item/trap behaviors
  DCPLAY.m                player state: hp, start position, alive check
  DCRAWL.m                entry point, main loop, status bar
  DCTERM.m                raw mode, cursor, escape sequences
  DCTYPE.m                type registry and lookup helpers
txt/
  dungeon*.txt            dungeon files
INTRINSICS.md             describes all the MUMPS intrinsics used in src/
Makefile                  compile and run targets
generate_dungeons.py      dungeon generation script
```
