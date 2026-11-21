# dcrawl

a dungeon crawler written in ANSI MUMPS where the player position is `$X` and `$Y` and we have the decency to admit it

a love letter to the cursor position intrinsics 

`$J` and `$H` live in the status bar and `^SCORES` remembers every run.

## running

requires a MUMPS runtime. i recommend [yottadb](https://yottadb.com/product/get-started/) or [gt.m](https://sourceforge.net/projects/fis-gtm/). source your environment first:
```
source /usr/local/etc/ydb_env_set   # or gtmprofile
```

then, from the project root, so the dungeon files load with a relative path:
```
make run-local
```

if your routine resolution is set up globally already:

```
cd src && mumps -run '^DCRAWL'
```

### docker (one-command local play or browser server)

play locally in your terminal in one command (no local MUMPS setup needed):
```
docker run -it --rm ghcr.io/jordan-lenchitz/dcrawler
```

or run the browser-playable `ttyd` server locally on port 8080:
```
docker run --rm -p 8080:8080 ghcr.io/jordan-lenchitz/dcrawler
```

to deploy the browser-playable server to Google Cloud Run (scale-to-zero, single shared `^SCORES` instance while warm):
```
./scripts/deploy-cloudrun.sh
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

stepping on `>` descends sequentially through `txt/dungeon_1.txt` to `txt/dungeon_25.txt` (auto-detected up to 99 sequential floors, falling back to `txt/dungeon.txt` if numbered files are missing). your hp, atk, gold, and unused keys carry over between floors, and clearing a floor adds +25 gold. reaching the stairs on the final floor wins the run.

## hud and high scores

below the 20x60 dungeon map, the terminal shows:

- a transient event/combat/inspect message line directly beneath the map (multiple events in a turn join cleanly with `|`)
- the main status line: hp (green, turning red below 5), atk, current floor, gold, inventory, and explicit `$X` and `$Y` coordinates
- a live intrinsics line with `$H` (`$HOROLOG`) and `$J` (current MUMPS job / process id)
- a colorized two-line glyph legend and key hint bar

completed runs (win or death) are persisted in the shared MUMPS global `^SCORES`:

- `^SCORES("seq")` holds the monotonic run id via `$INCREMENT`
- `^SCORES("run",id)` stores `score^floor^result^cause^$H^$ZUT^$J^name` (with optional 3-letter arcade initials entered on the title screen, defaulting to `---`)
- `^SCORES("idx",-score,id)` is an inverted-score collation index so `$ORDER` walks top scores highest-first natively

the title screen highlights the current `#1` high score holder from `^SCORES`. the top 8 runs appear automatically on win or death (highlighting the run you just finished, with a play-again loop), and can be viewed anytime with `t` (or `H`).

live per-session game state is isolated under `^G($J,...)` so concurrent players on the same MUMPS database never collide, while sharing one live `^SCORES` leaderboard. `QUIT` and `$ETRAP` (with `HUPENABLE`) clean up `^G($J)` automatically on normal exit or abrupt disconnect.

## dungeon generation

dungeon generation is written natively in MUMPS (`src/DCGEN.m`). to generate fresh dungeon layouts:

```
source /usr/local/etc/ydb_env_set   # or gtmprofile
make generate
```

or customize floor count / output directory with environment variables:

```
DCGEN_FLOORS=25 DCGEN_OUT=txt make generate
```

by default this writes 25 floors (`txt/dungeon_1.txt` through `txt/dungeon_25.txt`). each floor is a 20x60 grid of non-overlapping rectangular rooms connected by corridors, wrapped in stone walls and void. `DCGEN` places a locked door `+` guarding the exit room and runs BFS checks in MUMPS local arrays to guarantee the key `(` is reachable before the door, the exit `>` cannot be reached without unlocking the door, and no enemy spawns right next to `@`. deeper floors scale up room count, enemy count, goblin frequency, traps, and stronger food/weapons. `GENMAP^DCGEN(FLOOR)` also exposes direct generation into `^G("map")` for future live infinite procedural runs.

## testing

```
source /usr/local/etc/ydb_env_set   # or gtmprofile
make test
```

compiles all MUMPS routines and runs two suites against isolated temporary MUMPS databases (so tests never touch your real `^SCORES`):

- `tests/DCTEST.m` (native MUMPS test suite): verifies strict invariants & BFS reachability across all 25 on-disk `txt/dungeon_1..25.txt` files plus 50 stress-generated `DCGEN` floors and live `GENMAP^DCGEN`, `DCTYPE` lookups & idempotent `SEED`, `MAXFLOOR`/`LOAD^DCMAP`, goblin chasing, 4-hit unarmed kill, weapon stacking, 1-shot kill, combat death cause, wounded rat fleeing, bat terrain preservation, `EPASS` closed-door blocking even with a key, spike disarming, poison persistence, all vegan foods & potion healing with HP cap, multi-key inventory consumption, stairs descent trigger, `^G($J)` multi-job isolation, and `^SCORES` initials + descending collation ranking.
- `tests/test_pty_smoke.py` (30x80 ANSI PTY smoke test): verifies title screen & 3-letter arcade initials prompt, real terminal boot (`flr 1/25`, `$X`/`$Y`, `$H`/`$J`, ANSI colors), all 4 movement input schemes (CSI arrows, SS3 arrows, `wasd`, `hjkl`), wall collisions, `esc` handling, `inspect` mode cursor/exit keys, `z` help screen, `t` scores overlay, multi-floor win & play-again loop, concurrent two-player isolation on a shared MUMPS database, `$ETRAP` cleanup on abrupt PTY hangup, and `DCRAWL_IDLE_SEC` inactivity timeout.

## design notes

- `$X` and `$Y` are the ground truth for your location. they are not mirrored anywhere. the main loop reads them into locals (`PX`, `PY`) at the top of each turn, computes the move, and restores the cursor invariant at the bottom so the next iteration finds them pointing at you again.
- `DCTERM` opens `$PRINCIPAL` with `NOECHO:NOESCAPE:WIDTH=512:NOWRAP:HUPENABLE` (`NOWRAP` after `WIDTH`, since `WIDTH` re-enables wrap; `HUPENABLE` routes terminal hangup to `$ETRAP`) and draws colored glyphs via `PUTCH` which explicitly restores logical `$X` and `$Y` after ANSI escape bytes.
- terrain is a single source of truth: `^G($J,"map",row)` holds the row strings per MUMPS job. changing a cell is a `$E` replacement, repainted in color via `REPAINT^DCMAP`.
- enemies live in a per-job overlay `^G($J,"ent",y,x)=glyph^hp` so they can move and take damage without corrupting items or traps underneath. `TICK^DCENT` snapshots entity coordinates before iterating so moving enemies never corrupt `$ORDER`.
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

add the new glyph to a dungeon file in `txt/` (or `src/DCGEN.m`) and it just works.

## layout

```
src/
  DCENT.m                 entity overlay, combat hit/kill, npc strategy (ACTGOB/ACTRAT/ACTBAT)
  DCGEN.m                 native MUMPS procedural room-and-corridor dungeon generator
  DCINV.m                 inventory add / has / count / consume
  DCMAP.m                 multi-floor map load, color paint, passability, item/trap behaviors
  DCPLAY.m                player state: hp, atk, arcade initials, cause, start placement
  DCRAWL.m                entry point, main loop, bump-to-attack, hud, inspect, help, $ETRAP
  DCSCORE.m               shared ^SCORES leaderboard in MUMPS globals
  DCTERM.m                raw mode, NOWRAP, HUPENABLE, color PUTCH, ANSI READKEY, idle timeout
  DCTITLE.m               30x80 ANSI title screen, #1 leader display & 3-letter initials prompt
  DCTYPE.m                concurrency-safe type registry (label^value^behavior^color^hp)
scripts/
  docker-entrypoint.sh    container entrypoint (auto-selects ttyd web server or local CLI)
  run-session.sh          per-connection session launcher with shared DB & SIGHUP cleanup
  deploy-cloudrun.sh      one-command Google Cloud Run deployment helper
.github/workflows/
  docker-publish.yml      GHCR image publishing workflow
txt/
  dungeon_1..25.txt       25 generated room-and-corridor floors
  dungeon.txt             fallback classic dungeon
tests/
  DCTEST.m                native MUMPS unit, combat, isolation, ^SCORES & invariant test suite
  test_pty_smoke.py       30x80 ANSI PTY, title screen, concurrency & timeout smoke test
Dockerfile                container image (MUMPS runtime + ttyd + precompiled src/*.o)
.dockerignore             excludes tests, git metadata, and local artifacts from image builds
INTRINSICS.md             describes the MUMPS intrinsics used in src/
Makefile                  compile, run-local, generate, test, clean targets
```
