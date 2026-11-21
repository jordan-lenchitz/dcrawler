# dcrawl

a dungeon crawler written in ANSI MUMPS where the player position is `$X` and `$Y` and we have the decency to admit it /// a love letter to the cursor position intrinsics /// `$J` gets a cameo in the status bar and `^SCORES` persists your glory (and deaths) in YottaDB.

## running

requires YottaDB (or GT.M). source your environment first, then:

```bash
source /usr/local/etc/ydb_env_set   # or gtmprofile
make run-local
```

from the project root, so the dungeon files load with a relative path.

### generating dungeons

```bash
make generate
```

generates 10 room-and-corridor floors (`txt/dungeon_1.txt` .. `txt/dungeon_10.txt`) with BFS-verified key/door/exit progression and scaling difficulty.

### running automated tests

```bash
source /usr/local/etc/ydb_env_set
make test
```

runs the 24×80 ANSI PTY test suite in [tests/test_dcrawl.py](tests/test_dcrawl.py) using an isolated temporary `ydb_dir`.

## controls

| key | action |
|---|---|
| arrow keys / `h j k l` / `w a s d` | move or bump-attack adjacent enemy |
| `i` | inspect mode (arrow keys / `hjkl` / `wasd` to look around, `i`/`q`/`Enter`/`Space`/`Esc` to exit) |
| `t` (or `H`) | view persistent `^SCORES` high score leaderboard |
| `z` (or `?`) | help screen & MUMPS intrinsics guide |
| `q` | quit |

each move or attack is one turn.

## glyphs

| glyph | meaning |
|-------|---------|
| `@` | you (starts at 10 HP, 1 ATK) |
| `#` | impassable stone wall |
| `.` | impassable void |
| ` ` | floor |
| `+` | closed door (needs a key) |
| `/` | open door |
| `g` | goblin — 4 HP, 2 dmg, pursues relentlessly (`ACTGOB`) |
| `r` | rat — 2 HP, 1 dmg, scurries in and flees when wounded (`ACTRAT`) |
| `b` | bat — 2 HP, 1 dmg, flutters erratically (`ACTBAT`) |
| `^` | spike trap — 3 dmg, one-shot disarmed after trigger |
| `~` | poison tile — 1 dmg every step |
| `!` | potion (+5 hp) |
| `M` | vegan meat (+10 hp) |
| `A` | apple (+3 hp) |
| `B` | bread (+7 hp) |
| `T` | tofu (+15 hp) |
| `)` | dagger (+1 atk) |
| `}` | sword (+2 atk) |
| `(` | key |
| `$` | gold (+10 score) |
| `>` | stairs — descend to next floor (+25 score), or escape on the final floor to win |

## design notes

- `$X` and `$Y` are the ground truth for the player's location. `DCTERM` keeps `$X`/`$Y` exact even when emitting ANSI color escapes (`PUTCH` + `NOWRAP`).
- terrain is a single source of truth: `^G("map",row)` holds the row strings.
- enemies live in an overlay `^G("ent",y,x)=glyph^hp` so they can move and take damage without corrupting terrain underneath.
- `^SCORES` persists completed runs in YottaDB with an inverted-score collation index (`^SCORES("idx",-score,id)`) plus `$HOROLOG`, `$ZUT`, `$J`, floor, and cause of death.

## extensibility

every glyph's meaning, color, behavior, and enemy HP is one row in `^TYPE` (`SEED^DCTYPE`):

```mumps
; ^TYPE(kind,glyph) = label^value^behavior^color[^hp]
 S ^TYPE("enemy","Z")="zombie^2^ACTGOB^1;32^6"
 S ^TYPE("trap","*")="caltrops^1^TRAPSP^1;31"
 S ^TYPE("item","?")="scroll^0^ITEMSC^1;34"
```

## layout

```
src/
  DCENT.m                 entity overlay, combat hit/kill, enemy logic (ACTGOB/ACTRAT/ACTBAT)
  DCINV.m                 inventory add / has / count / consume
  DCMAP.m                 multi-floor map load, color paint, passability, item/trap behaviors
  DCPLAY.m                player state: hp, atk, damage cause, placement
  DCRAWL.m                entry point, main loop, bump-to-attack, status bar, inspect
  DCSCORE.m               persistent ^SCORES leaderboard in YottaDB globals
  DCTERM.m                raw mode, NOWRAP, color PUTCH, ANSI arrow-key READKEY
  DCTYPE.m                type registry (label^value^behavior^color^hp)
txt/
  dungeon_1..10.txt       generated multi-floor room-and-corridor dungeons
  dungeon.txt             fallback classic dungeon
tests/
  test_dcrawl.py          automated 24x80 PTY & generator test suite
INTRINSICS.md             describes the MUMPS intrinsics used in src/
Makefile                  compile, run-local, generate, test, clean targets
generate_dungeons.py      room-and-corridor procedural dungeon generator
```
