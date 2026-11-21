# dcrawl

a dungeon crawler written in ANSI MUMPS where the player position is `$X` and `$Y` and we have the decency to admit it /// a love letter to the cursor position intrinsics /// `$J` and `$H` live in the status bar and `^SCORES` remembers every run.

## running

requires a MUMPS runtime. i recommend [yottadb](https://yottadb.com/product/get-started/) or [gt.m](https://sourceforge.net/projects/fis-gtm/). source your environment first, then:

```
source /usr/local/etc/ydb_env_set   # or gtmprofile
make run-local
```

from the project root, so the dungeon files load with a relative path.

if your routine resolution is set up globally already:

```
cd src && mumps -run '^DCRAWL'
```

## controls

| key | action |
|-----|--------|
| arrow keys / `h j k l` / `w a s d` | move or bump-attack an adjacent enemy |
| `i` | inspect mode (move cursor with arrows / `hjkl` / `wasd`; exit with `i`, `q`, `enter`, `space`, or `esc`) |
| `t` (or `H`) | view the persistent `^SCORES` high score leaderboard |
| `z` (or `?`) | help screen and MUMPS intrinsics reference |
| `q` | quit |

each move or bump-attack is one turn. both standard CSI arrow sequences (`ESC [ A/B/C/D`) and application-mode SS3 sequences (`ESC O A/B/C/D`) are supported.

## glyphs

everything on the map is colorized with ANSI escapes driven by `^TYPE`.

| glyph | meaning |
|-------|---------|
| `@` | you (starts at 10 hp, 1 atk) |
| `#` | impassable stone wall |
| `.` | impassable void |
| ` ` | floor to walk on silently per marshall |
| `+` | closed door, needs a key |
| `/` | open door |
| `g` | goblin = 4 hp, 2 dmg, pursues within 6 tiles (`ACTGOB`) |
| `r` | rat = 2 hp, 1 dmg, scurries in when healthy and flees when wounded (`ACTRAT`) |
| `b` | bat = 2 hp, 1 dmg, flutters erratically and swoops (`ACTBAT`) |
| `^` | spike trap = 3 dmg, one-shot disarmed after trigger |
| `~` | poison tile = 1 dmg every step, persists |
| `!` | potion = +5 hp |
| `M` | 'meat' [vegan] = +10 hp |
| `A` | apple = +3 hp |
| `B` | bread = +7 hp |
| `T` | tofu = +15 hp |
| `)` | dagger = +1 atk |
| `}` | sword = +2 atk |
| `(` | key |
| `$` | gold = +10 score |
| `>` | stairs = descend to next floor (+25 score), or escape on the final floor to win |

## combat and progression

there is combat now. bumping into an adjacent enemy hits it for your current `atk` (starting at 1, upgraded by picking up daggers and swords). if it survives, enemies still take their turn, so it can hit back. slaying a goblin awards +10 gold; rats and bats award +5 gold. healing items never exceed max hp (10).

stepping on `>` descends sequentially through `txt/dungeon_1.txt` to `txt/dungeon_10.txt` (auto-detected up to 99 sequential floors, falling back to `txt/dungeon.txt` if numbered files are missing). your hp, atk, gold, and unused keys carry over between floors, and clearing a floor adds +25 gold. reaching the stairs on the final floor wins the run.

## hud and high scores

below the 20x60 dungeon map, the terminal shows:

- a transient event/combat/inspect message line directly beneath the map (multiple events in a turn join cleanly with `|`)
- the main status line: hp (green, turning red below 5), atk, current floor, gold, inventory, and explicit `$X` and `$Y` coordinates
- a live intrinsics line with `$H` (`$HOROLOG`) and `$J` (current MUMPS job / process id)
- a colorized two-line glyph legend and key hint bar

completed runs (win or death) are persisted in the MUMPS global `^SCORES`:

- `^SCORES("seq")` holds the monotonic run id via `$INCREMENT`
- `^SCORES("run",id)` stores `score^floor^result^cause^$H^$ZUT^$J`
- `^SCORES("idx",-score,id)` is an inverted-score collation index so `$ORDER` walks top scores highest-first natively

the top 8 runs appear automatically on win or death (highlighting the run you just finished), and can be viewed mid-run with `t` (or `H`).

## dungeon generation

to generate fresh dungeon layouts:

```
make generate
```

or run the generator directly with optional flags:

```
python3 generate_dungeons.py --floors 10 --out txt --seed 42
```

by default this writes 10 floors (`txt/dungeon_1.txt` through `txt/dungeon_10.txt`). each floor is a 20x60 grid of non-overlapping rectangular rooms connected by corridors, wrapped in stone walls and void. the generator places a locked door `+` guarding the exit room and runs BFS checks to guarantee the key `(` is reachable before the door, the exit `>` cannot be reached without unlocking the door, and no enemy spawns right next to `@`. deeper floors scale up room count, enemy count, goblin frequency, traps, and stronger food/weapons.

## testing

```
source /usr/local/etc/ydb_env_set   # or gtmprofile
make test
```

compiles all MUMPS routines and runs `tests/test_dcrawl.py`, an automated 30x80 ANSI PTY test suite using an isolated temporary database directory (so tests never touch your real `^SCORES`). it checks:

- strict invariants across all 10 on-disk `txt/dungeon_1..10.txt` files plus 30 stress-generated floors
- goblin chasing, 4-hit unarmed kill, weapon stacking, 1-shot kill, combat death cause, wounded rat fleeing, bat terrain preservation, and `EPASS` blocking enemies behind closed doors even when the player holds a key
- spike trap disarming, poison persistence, all vegan foods and potion healing with hp cap, and multi-key inventory consumption
- full 10-floor sequential descent and win, all 4 movement input schemes (CSI arrows, SS3 arrows, `wasd`, `hjkl`), wall collisions, `esc` handling, `inspect` exit keys, and `z` help screen
- multi-session `^SCORES` persistence and descending collation ranking across 3 separate runs

## design notes

- `$X` and `$Y` are the ground truth for the player's location. they are not mirrored anywhere. the main loop reads them into locals (`PX`, `PY`) at the top of each turn, computes the move, and restores the cursor invariant at the bottom so the next iteration finds them pointing at the player again.
- `DCTERM` opens `$PRINCIPAL` with `NOECHO:NOESCAPE:WIDTH=512:NOWRAP` (`NOWRAP` after `WIDTH`, since `WIDTH` re-enables wrap) and draws colored glyphs via `PUTCH` which explicitly restores logical `$X` and `$Y` after ANSI escape bytes.
- terrain is a single source of truth: `^G("map",row)` holds the row strings. changing a cell is a `$E` replacement, repainted in color via `REPAINT^DCMAP`.
- enemies live in an overlay `^G("ent",y,x)=glyph^hp` so they can move and take damage without corrupting items or traps underneath. `TICK^DCENT` snapshots entity coordinates before iterating so moving enemies never corrupt `$ORDER`.
- arithmetic expressions like `((DX*DX)+(DY*DY))**0.5` are explicitly parenthesized to respect MUMPS strict left-to-right operator precedence.

## extensibility

every glyph's meaning, color, strategy/behavior, and enemy hp is one row in `^TYPE` inside `SEED^DCTYPE`:

```
; ^TYPE(kind,glyph) = label^value^behavior^color[^hp]
 S ^TYPE("enemy","Z")="zombie^2^ACTGOB^1;32^6"   ; 2 dmg, chases like goblin, 6 hp
 S ^TYPE("trap","*")="caltrops^1^TRAPSP^1;31"    ; reuses spike behavior: one-shot
 S ^TYPE("item","?")="scroll^0^ITEMSC^1;34"      ; then add ITEMSC in DCMAP.m
```

the behavior field (third caret-separated slot) is a label in `DCMAP.m` for items, traps, and exits, or a strategy label in `DCENT.m` invoked on each tick with `(X,Y,PX,PY)`. parenthesized indirection via `D @(BEH_"(...)")` handles dispatch.

add the new glyph to a dungeon file in `txt/` (or `generate_dungeons.py`) and it just works.

## layout

```
src/
  DCENT.m                 entity overlay, combat hit/kill, npc strategy (ACTGOB/ACTRAT/ACTBAT)
  DCINV.m                 inventory add / has / count / consume
  DCMAP.m                 multi-floor map load, color paint, passability, item/trap behaviors
  DCPLAY.m                player state: hp, atk, damage cause, start placement, alive check
  DCRAWL.m                entry point, main loop, bump-to-attack, hud, inspect, help
  DCSCORE.m               persistent ^SCORES leaderboard in MUMPS globals
  DCTERM.m                raw mode, NOWRAP, color PUTCH, ANSI arrow-key READKEY
  DCTYPE.m                type registry (label^value^behavior^color^hp) and lookup helpers
txt/
  dungeon_1..10.txt       10 generated room-and-corridor floors
  dungeon.txt             fallback classic dungeon
tests/
  test_dcrawl.py          automated 30x80 ANSI PTY and generator test suite
INTRINSICS.md             describes the MUMPS intrinsics used in src/
Makefile                  compile, run-local, generate, test, clean targets
generate_dungeons.py      room-and-corridor dungeon generator
```
