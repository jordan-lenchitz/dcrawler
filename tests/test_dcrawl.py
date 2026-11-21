#!/usr/bin/env python3
"""Comprehensive 30x80 ANSI PTY & YottaDB test suite for dcrawler v2.0."""

import os
import pty
import re
import select
import subprocess
import sys
import tempfile
import time
from collections import deque

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

CSI_UP = "\x1b[A"
CSI_DOWN = "\x1b[B"
CSI_RIGHT = "\x1b[C"
CSI_LEFT = "\x1b[D"
SS3_UP = "\x1bOA"
SS3_DOWN = "\x1bOB"
SS3_RIGHT = "\x1bOC"
SS3_LEFT = "\x1bOD"
ESC = "\x1b"


class MiniTerm:
    """30x80 ANSI terminal emulator capturing glyphs, SGR colors, and cursor state."""

    def __init__(self, rows=30, cols=80):
        self.rows = rows
        self.cols = cols
        self.grid = [[" " for _ in range(cols)] for _ in range(rows)]
        self.colors = [["" for _ in range(cols)] for _ in range(rows)]
        self.r = 0
        self.c = 0
        self.cur_sgr = ""
        self.buf = ""
        self.cursor_visible = True

    def feed(self, data: str):
        self.buf += data
        i = 0
        s = self.buf
        n = len(s)
        while i < n:
            ch = s[i]
            if ch == "\x1b":
                if i + 1 >= n:
                    break
                if s[i + 1] == "[":
                    m = re.match(r"\x1b\[([?0-9;]*)([A-Za-z])", s[i:])
                    if not m:
                        break
                    params, cmd = m.group(1), m.group(2)
                    if cmd == "H":
                        if not params:
                            self.r, self.c = 0, 0
                        else:
                            parts = params.split(";")
                            self.r = max(0, min(self.rows - 1, int(parts[0]) - 1))
                            self.c = max(
                                0,
                                min(
                                    self.cols - 1,
                                    (int(parts[1]) - 1)
                                    if len(parts) > 1 and parts[1]
                                    else 0,
                                ),
                            )
                    elif cmd == "J" and params == "2":
                        self.grid = [
                            [" " for _ in range(self.cols)] for _ in range(self.rows)
                        ]
                        self.colors = [
                            ["" for _ in range(self.cols)] for _ in range(self.rows)
                        ]
                    elif cmd == "K" and params == "2":
                        self.grid[self.r] = [" " for _ in range(self.cols)]
                        self.colors[self.r] = ["" for _ in range(self.cols)]
                    elif cmd == "m":
                        self.cur_sgr = "" if params in ("", "0") else params
                    elif cmd == "h" and params == "?25":
                        self.cursor_visible = True
                    elif cmd == "l" and params == "?25":
                        self.cursor_visible = False
                    i += m.end()
                    continue
            if ch == "\r":
                self.c = 0
            elif ch == "\n":
                self.r = min(self.rows - 1, self.r + 1)
            elif ord(ch) >= 32:
                if 0 <= self.r < self.rows and 0 <= self.c < self.cols:
                    self.grid[self.r][self.c] = ch
                    self.colors[self.r][self.c] = self.cur_sgr
                self.c += 1
            i += 1
        self.buf = s[i:]

    def line(self, row):
        return "".join(self.grid[row]).rstrip()

    def screen_text(self):
        return "\n".join(self.line(r) for r in range(self.rows))


def run_dcrawl_session(workdir, ydb_dir, key_steps):
    """Spawn dcrawler in a real PTY with an isolated ydb_dir and run scripted inputs."""
    master, slave = pty.openpty()
    child_env = {
        k: v
        for k, v in os.environ.items()
        if not k.startswith(("ydb_", "gtm"))
    }
    child_env["ydb_dir"] = ydb_dir
    env_cmd = (
        f"source /usr/local/etc/ydb_env_set >/dev/null && "
        f'ydb_routines="{REPO_ROOT}/src $ydb_routines" '
        f'gtmroutines="{REPO_ROOT}/src $gtmroutines" '
        f"mumps -run '^DCRAWL'"
    )
    proc = subprocess.Popen(
        ["bash", "-c", env_cmd],
        cwd=workdir,
        env=child_env,
        stdin=slave,
        stdout=slave,
        stderr=slave,
        close_fds=True,
    )
    os.close(slave)

    term = MiniTerm()

    def drain(timeout=0.35):
        end = time.time() + timeout
        out = ""
        while time.time() < end:
            r, _, _ = select.select([master], [], [], max(0.02, end - time.time()))
            if r:
                try:
                    chunk = os.read(master, 4096)
                    if not chunk:
                        break
                    text = chunk.decode("utf-8", errors="replace")
                    out += text
                    term.feed(text)
                    end = time.time() + 0.1
                except OSError:
                    break
        return out

    def snapshot(label):
        return {
            "label": label,
            "screen": term.screen_text(),
            "lines": [term.line(r) for r in range(term.rows)],
            "flash": term.line(20),
            "status": term.line(22),
            "meta": term.line(23),
            "r": term.r,
            "c": term.c,
            "visible": term.cursor_visible,
            "colors": [row[:] for row in term.colors],
            "grid": [row[:] for row in term.grid],
        }

    raw = drain(1.2)
    snapshots = [snapshot("init")]

    for label, tokens in key_steps:
        for tok in tokens:
            os.write(master, tok.encode("utf-8"))
            # Wait long enough for ESC timeout (80ms) when sending standalone ESC
            time.sleep(0.11 if tok == ESC else 0.04)
            raw += drain(0.15)
        snapshots.append(snapshot(label))

    try:
        rc = proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        proc.kill()
        rc = -9
    os.close(master)
    return rc, snapshots, raw


def _verify_dungeon_grid(rows, label):
    valid_glyphs = set("@#. +/grb^~!MABT($)}>")
    assert len(rows) == 20, f"{label}: expected 20 rows, got {len(rows)}"
    assert all(len(r) == 60 for r in rows), f"{label}: non-60 column row found"

    # Outer border must never leak walkable tiles
    for c in range(60):
        assert rows[0][c] in (".", "#"), f"{label}: open top border at col {c}"
        assert rows[19][c] in (".", "#"), f"{label}: open bottom border at col {c}"
    for r in range(20):
        assert rows[r][0] in (".", "#"), f"{label}: open left border at row {r}"
        assert rows[r][59] in (".", "#"), f"{label}: open right border at row {r}"

    counts = {}
    positions = {}
    enemies = []
    for r, line in enumerate(rows):
        for c, ch in enumerate(line):
            assert ch in valid_glyphs, f"{label}: unknown glyph {ch!r} at ({r},{c})"
            counts[ch] = counts.get(ch, 0) + 1
            if ch in ("@", ">", "+", "("):
                positions[ch] = (r, c)
            if ch in ("g", "r", "b"):
                enemies.append((r, c))
            # No walkable tile may touch '.' void orthogonally
            if ch not in (".", "#"):
                for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    assert rows[r + dr][c + dc] != ".", (
                        f"{label}: cell {ch!r} at ({r},{c}) borders void '.'"
                    )

    assert counts.get("@", 0) == 1, f"{label}: expected exactly 1 '@'"
    assert counts.get(">", 0) == 1, f"{label}: expected exactly 1 '>'"
    assert counts.get("(", 0) >= 1, f"{label}: missing key '('"
    assert counts.get("+", 0) >= 1, f"{label}: missing locked door '+'"

    # No enemy adjacent to player start
    pr, pc = positions["@"]
    for er, ec in enemies:
        assert abs(er - pr) + abs(ec - pc) > 2, (
            f"{label}: enemy at ({er},{ec}) too close to start ({pr},{pc})"
        )

    pass_no_door = valid_glyphs - {"#", ".", "+"}

    def reach(passable):
        q = deque([positions["@"]])
        vis = {positions["@"]}
        while q:
            rr, cc = q.popleft()
            for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                nr, nc = rr + dr, cc + dc
                if 0 <= nr < 20 and 0 <= nc < 60 and (nr, nc) not in vis and rows[nr][nc] in passable:
                    vis.add((nr, nc))
                    q.append((nr, nc))
        return vis

    r_no = reach(pass_no_door)
    r_yes = reach(pass_no_door | {"+"})
    assert positions["("] in r_no, f"{label}: key unreachable before door"
    assert positions[">"] not in r_no, f"{label}: exit reachable without unlocking door"
    assert positions[">"] in r_yes, f"{label}: exit unreachable even with key"


def test_generator_and_repo_floors():
    """Verify all 25 on-disk repo dungeons AND 50 freshly generated floors across seeds."""
    sys.path.insert(0, REPO_ROOT)
    import generate_dungeons as gd

    assert gd.NUM_DUNGEONS == 25, f"Expected NUM_DUNGEONS=25, got {gd.NUM_DUNGEONS}"

    # Verify all 25 committed/generated repo dungeons on disk
    for floor in range(1, 26):
        path = os.path.join(REPO_ROOT, "txt", f"dungeon_{floor}.txt")
        assert os.path.exists(path), f"Missing repo floor file: {path}"
        with open(path) as f:
            rows = [line.rstrip("\r\n") for line in f]
        _verify_dungeon_grid(rows, f"repo dungeon_{floor}.txt")

    # Stress-test 2 seeds x 25 floors = 50 procedural floors
    for seed in (7, 42):
        rng = gd.random.Random(seed)
        for floor in range(1, 26):
            rows = gd.generate_dungeon(floor=floor, rng=rng)
            _verify_dungeon_grid(rows, f"seed={seed} floor={floor}")

    # Verify MUMPS MAXFLOOR detects all 25 repo floors at boot
    with tempfile.TemporaryDirectory() as ydb:
        rc, snaps, raw = run_dcrawl_session(REPO_ROOT, ydb, [("quit", ["q"])])
        assert rc == 0, f"repo boot rc={rc}\n{raw[-400:]}"
        assert "flr 1/25" in snaps[0]["status"], f"Expected flr 1/25 on repo boot: {snaps[0]['status']}"

    print("[PASS] generator: all 25 repo floors + 50 stress-generated floors & flr 1/25 boot verified")


def test_enemy_logic_and_combat():
    """Verify goblin chase & 4-hit kill, wounded rat fleeing, weapon stacking, EPASS door block, and combat death."""
    with tempfile.TemporaryDirectory() as tmpdir:
        txt_dir = os.path.join(tmpdir, "txt")
        ydb_dir = os.path.join(tmpdir, "ydb")
        os.makedirs(txt_dir)
        os.makedirs(ydb_dir)

        # 1) Wounded rat flees + weapon stacking () -> } -> atk=4) + 1-shot goblin + EPASS door blocks enemy even with key
        # Row 2: .#@r   #
        # When @ (2,2) bumps right into r (3,2) with atk=1: rat drops to 1 hp -> ACTRAT flees right to (4,2)!
        # Row 4: isolated test room for EPASS & weapon stacking? Let's put them in one deterministic map:
        #   col: 012345678901234567890
        # r2:    .#@r    #           #
        # r3:    .##################.#
        floor_rat_flee = [
            "......................",
            ".####################.",
            ".#@r    #           #.",
            ".####################.",
            "......................",
        ]
        with open(os.path.join(txt_dir, "dungeon_1.txt"), "w") as f:
            f.write("\n".join(floor_rat_flee) + "\n")

        rc, snaps, raw = run_dcrawl_session(
            tmpdir,
            ydb_dir,
            [
                ("bump_rat_once", [CSI_RIGHT]),  # hit rat for 1 -> 1 hp left -> rat MUST flee to (4,2)!
                ("quit", ["q"]),
            ],
        )
        assert rc == 0, f"rat flee test rc={rc}\n{raw[-500:]}"
        assert "you hit rat for 1 (1 hp left)." in snaps[1]["flash"], f"bad hit flash: {snaps[1]['flash']}"
        # Rat fled right from col 3 to col 4 instead of attacking player!
        assert snaps[1]["grid"][2][3] == " ", f"Expected empty cell at (3,2) after rat fled, got {snaps[1]['grid'][2][3]!r}"
        assert snaps[1]["grid"][2][4] == "r", f"Expected wounded rat to flee to (4,2), got row={snaps[1]['lines'][2]!r}"
        assert "hp 10/10" in snaps[1]["status"], f"Wounded rat should flee instead of attacking: {snaps[1]['status']}"

        # 2) Goblin chase (within 6 tiles), unarmed multi-hit kill & combat retaliation death
        #   col: 012345678901234
        # r2:    .#@    g      #.
        # Distance = 5 (< 6): on player step left into wall? No, move right to (3,2), goblin at (7,2) steps left to (6,2)!
        floor_goblin = [
            ".................",
            ".###############.",
            ".#@    g       #.",
            ".###############.",
            ".................",
        ]
        with open(os.path.join(txt_dir, "dungeon_1.txt"), "w") as f:
            f.write("\n".join(floor_goblin) + "\n")

        rc, snaps, raw = run_dcrawl_session(
            tmpdir,
            ydb_dir,
            [
                ("approach1", [CSI_RIGHT]),  # @ (2,2)->(3,2), g (7,2)->(6,2)
                ("approach2", [CSI_RIGHT]),  # @ (3,2)->(4,2), g (6,2)->(5,2)
                ("bump1", [CSI_RIGHT]),      # hit g (3 hp), g retaliates (-2 -> hp 8/10)
                ("bump2", [CSI_RIGHT]),      # hit g (2 hp), g retaliates (-2 -> hp 6/10)
                ("bump3", [CSI_RIGHT]),      # hit g (1 hp), g retaliates (-2 -> hp 4/10)
                ("bump4_kill", [CSI_RIGHT]), # hit g (0 hp) -> SLAIN! (+10 gold), no retaliation!
                ("quit", ["q"]),
            ],
        )
        assert rc == 0, f"goblin combat test rc={rc}\n{raw[-500:]}"
        assert snaps[1]["grid"][2][6] == "g", f"Goblin failed to chase from col 7 to col 6: {snaps[1]['lines'][2]!r}"
        assert snaps[2]["grid"][2][5] == "g", f"Goblin failed to chase to col 5: {snaps[2]['lines'][2]!r}"
        assert "3 hp left" in snaps[3]["flash"] and "goblin attacks you for 2" in snaps[3]["flash"]
        assert "hp 8/10" in snaps[3]["status"]
        assert "hp 6/10" in snaps[4]["status"]
        assert "hp 4/10" in snaps[5]["status"]
        assert "you slay the goblin! (+10 gold)" in snaps[6]["flash"]
        assert "hp 4/10" in snaps[6]["status"] and "gold 10" in snaps[6]["status"]

        # 3) Weapon stacking () +1, } +2 => atk=4) one-shots 4-HP goblin, AND EPASS blocks enemy behind '+' even when player holds key '('
        # Deterministic trace:
        # r2: col2=}, col3=), col4=(, col5=@, col9=g1 (dist always 5<6 while walking left, so g1 always chases left!)
        # r3: col4=+ (closed door directly above g2!)
        # r4: col4=g2 (walled L/R/B, only exit is UP through '+' at (4,3) -> EPASS must block even with key!)
        floor_weapons_epass = [
            "..............",
            ".############.",
            ".#})(@   g  #.",
            ".###+########.",
            ".###g########.",
            ".############.",
            "..............",
        ]
        # Verify cols:
        # r2: 0='.',1='#',2='}',3=')',4='(',5='@',6=' ',7=' ',8=' ',9='g'
        # r3: 0='.',1='#',2='#',3='#',4='+',5='#'
        # r4: 0='.',1='#',2='#',3='#',4='g',5='#'
        with open(os.path.join(txt_dir, "dungeon_1.txt"), "w") as f:
            f.write("\n".join(floor_weapons_epass) + "\n")

        rc, snaps, raw = run_dcrawl_session(
            tmpdir,
            ydb_dir,
            [
                ("get_key", [CSI_LEFT]),        # @ (4,2) '(', g2 blocked by '+' at (4,3), g1 -> (8,2)
                ("get_dagger", [CSI_LEFT]),     # @ (3,2) ')' -> atk 2, g1 -> (7,2)
                ("get_sword", [CSI_LEFT]),      # @ (2,2) '}' -> atk 4, g1 -> (6,2)
                ("meet_goblin", [CSI_RIGHT, CSI_RIGHT]),  # @ -> (3,2)->(4,2), g1 -> (5,2) attacks (-2 -> hp 8/10)
                ("oneshot_g", [CSI_RIGHT]),     # bump right into g1 at (5,2) with atk=4 -> 1-SHOT KILL!
                ("quit", ["q"]),
            ],
        )
        assert rc == 0, f"weapon/epass test rc={rc}\n{raw[-500:]}"
        assert snaps[1]["grid"][3][4] == "+" and snaps[1]["grid"][4][4] == "g", (
            "Enemy phased through closed door '+' while player held key!"
        )
        assert "atk 2" in snaps[2]["status"], f"Expected atk 2: {snaps[2]['status']}"
        assert "atk 4" in snaps[3]["status"], f"Expected atk 4: {snaps[3]['status']}"
        assert "you slay the goblin! (+10 gold)" in snaps[5]["flash"], (
            f"Expected 1-shot goblin slay with atk=4: {snaps[5]['flash']!r}"
        )

        # 4) Combat retaliation death: player hits 3 spikes (-9 HP -> 1 HP), then bumps goblin -> goblin retaliates -> DEATH!
        floor_combat_death = [
            "................",
            ".##############.",
            ".#@^^^        #.",
            ".#####g########.",
            ".##############.",
            "................",
        ]
        # r2: 2=@, 3=^, 4=^, 5=^, 6=' '
        # r3: 6=g (walled on left/right/bottom!)
        # Wait: when player steps to (5,2), HP=1; then player steps to (6,2), goblin at (6,3) is adjacent and attacks for 2 -> DEATH!
        with open(os.path.join(txt_dir, "dungeon_1.txt"), "w") as f:
            f.write("\n".join(floor_combat_death) + "\n")

        rc, snaps, raw = run_dcrawl_session(
            tmpdir,
            ydb_dir,
            [
                ("take_spikes_and_die_to_goblin", [CSI_RIGHT, CSI_RIGHT, CSI_RIGHT, CSI_RIGHT]),
                ("dismiss", [" "]),
            ],
        )
        assert rc == 0, f"combat death rc={rc}\n{raw[-500:]}"
        assert "YOU DIED (slain by goblin)" in snaps[1]["screen"], (
            f"Expected goblin death banner:\n{snaps[1]['screen']}"
        )

        # 5) Bat strategy (ACTBAT) moves over items/traps without corrupting underlying terrain
        floor_bat = [
            "............",
            ".##########.",
            ".#@#  b   #.",
            ".### $~   #.",
            ".##########.",
            "............",
        ]
        # Player at (2,2) is walled off from bat at (6,2); wait by bumping wall 6 times?
        # No: bumping a wall doesn't run TICK; give player 1-tile step left/right at (2,2)-(3,2) walled off from bat room!
        floor_bat = [
            "..............",
            ".############.",
            ".#@ # $b$   #.",
            ".#  # ~~~   #.",
            ".############.",
            "..............",
        ]
        with open(os.path.join(txt_dir, "dungeon_1.txt"), "w") as f:
            f.write("\n".join(floor_bat) + "\n")
        rc, snaps, raw = run_dcrawl_session(
            tmpdir,
            ydb_dir,
            [
                ("pace_6_turns", [CSI_RIGHT, CSI_LEFT, CSI_RIGHT, CSI_LEFT, CSI_RIGHT, CSI_LEFT]),
                ("quit", ["q"]),
            ],
        )
        assert rc == 0, f"bat terrain test rc={rc}\n{raw[-500:]}"
        # Count '$' + '~' + 'b' across the entire bat room (rows 2..3, cols 5..11)
        bat_room_chars = [snaps[1]["grid"][r][c] for r in (2, 3) for c in range(5, 12)]
        assert bat_room_chars.count("b") == 1, f"Bat disappeared or duplicated: {bat_room_chars}"
        assert bat_room_chars.count("$") + bat_room_chars.count("~") >= 4, (
            f"Bat corrupted terrain underneath it: {bat_room_chars}"
        )

    print("[PASS] combat & enemy logic: goblin chase/4-hit/1-shot/death, wounded rat flee, bat overlay, weapon stacking & EPASS")


def test_items_traps_doors_and_hp_cap():
    """Verify spike disarm, poison persistence, all vegan foods & HP cap, multi-key consume, and locked door block."""
    floor_items = [
        "........................",
        ".######################.",
        ".#@^~A!BMT((+         #.",
        ".######################.",
        "........................",
    ]
    # r2: 2=@, 3=^, 4=~, 5=A(+3), 6=!(+5), 7=B(+7), 8=M(+10), 9=T(+15), 10=(, 11=(, 12=+
    with tempfile.TemporaryDirectory() as tmpdir:
        txt_dir = os.path.join(tmpdir, "txt")
        ydb_dir = os.path.join(tmpdir, "ydb")
        os.makedirs(txt_dir)
        os.makedirs(ydb_dir)
        with open(os.path.join(txt_dir, "dungeon_1.txt"), "w") as f:
            f.write("\n".join(floor_items) + "\n")

        rc, snaps, raw = run_dcrawl_session(
            tmpdir,
            ydb_dir,
            [
                ("step_spike", [CSI_RIGHT]),          # (3,2) ^ -> hp 7/10, disarms!
                ("step_poison", [CSI_RIGHT]),         # (4,2) ~ -> hp 6/10, persists!
                ("back_on_disarmed", [CSI_LEFT]),     # (3,2) now floor -> STILL hp 6/10!
                ("retrigger_poison", [CSI_RIGHT]),    # (4,2) ~ again -> hp 5/10!
                ("eat_apple", [CSI_RIGHT]),           # (5,2) A (+3) -> hp 8/10
                ("drink_potion_cap", [CSI_RIGHT]),    # (6,2) ! (+5) -> capped at hp 10/10!
                ("eat_bread_meat_tofu", [CSI_RIGHT, CSI_RIGHT, CSI_RIGHT]),  # B, M, T -> stays 10/10!
                ("two_keys", [CSI_RIGHT, CSI_RIGHT]), # (, ( -> inv ((2)
                ("unlock_door", [CSI_RIGHT]),         # + -> consumes 1 key -> inv ((1), unlocks '/'
                ("quit", ["q"]),
            ],
        )
        assert rc == 0, f"items/traps rc={rc}\n{raw[-500:]}"
        assert "hp 7/10" in snaps[1]["status"]
        assert "hp 6/10" in snaps[2]["status"]
        assert "hp 6/10" in snaps[3]["status"], f"Spike trap did not disarm: {snaps[3]['status']}"
        assert "hp 5/10" in snaps[4]["status"], f"Poison tile did not persist: {snaps[4]['status']}"
        assert "hp 8/10" in snaps[5]["status"] and "apple" in snaps[5]["flash"]
        assert "hp 10/10" in snaps[6]["status"], f"HP exceeded cap or failed heal: {snaps[6]['status']}"
        assert "hp 10/10" in snaps[7]["status"] and "tofu" in snaps[7]["flash"]
        assert "inv ((2)" in snaps[8]["status"], f"Expected 2 keys in inv: {snaps[8]['status']}"
        assert "inv ((1)" in snaps[9]["status"] and "the door unlocks" in snaps[9]["flash"], (
            f"Expected 1 key left after unlocking door: {snaps[9]['status']} | {snaps[9]['flash']}"
        )

    print("[PASS] items & traps: spike disarm, poison persistence, vegan foods, HP cap & multi-key inventory")


def test_ten_floor_descent_and_controls():
    """Verify full 10-floor sequential descent, all 4 key schemes (CSI/SS3/wasd/hjkl), ESC/double-ESC, inspect & z-help."""
    with tempfile.TemporaryDirectory() as tmpdir:
        txt_dir = os.path.join(tmpdir, "txt")
        ydb_dir = os.path.join(tmpdir, "ydb")
        os.makedirs(txt_dir)
        os.makedirs(ydb_dir)

        # Create 10 simple floors (dungeon_1.txt .. dungeon_10.txt) to verify MAXFLOOR=10 and full 10-floor escape!
        simple_floor = [
            "..........",
            ".########.",
            ".#@ >   #.",
            ".#      #.",
            ".########.",
            "..........",
        ]
        # Floor 1 has extra room for testing movement + wall bump + inspect + help + scores
        floor1 = [
            "............",
            ".##########.",
            ".#        #.",
            ".#  @  >  #.",
            ".#        #.",
            ".##########.",
            "............",
        ]
        with open(os.path.join(txt_dir, "dungeon_1.txt"), "w") as f:
            f.write("\n".join(floor1) + "\n")
        for flr in range(2, 11):
            with open(os.path.join(txt_dir, f"dungeon_{flr}.txt"), "w") as f:
                f.write("\n".join(simple_floor) + "\n")

        steps = [
            # Test all 4 input schemes (returning to start @ at (4,3))
            ("csi_arrows", [CSI_UP, CSI_RIGHT, CSI_DOWN, CSI_LEFT]),
            ("ss3_arrows", [SS3_UP, SS3_RIGHT, SS3_DOWN, SS3_LEFT]),
            ("wasd", ["w", "d", "s", "a"]),
            ("hjkl", ["k", "l", "j", "h"]),
            # Wall collision check: bump left wall repeatedly from (4,3) -> stops at x=2, never enters '#'
            ("wall_bump", ["a", "a", "a", "a"]),
            # Standalone ESC & double-tap ESC in MLOOP -> flashes help hint, doesn't crash or move
            ("esc_single", [ESC]),
            ("esc_double", [ESC + ESC]),
            # Inspect mode: enter with 'i', move with SS3/CSI arrows, exit with Enter, Space, and ESC
            ("inspect_enter_exit", ["i", CSI_RIGHT, "\r"]),
            ("inspect_space_exit", ["i", SS3_RIGHT, " "]),
            ("inspect_esc_exit", ["i", CSI_LEFT, ESC]),
            # Lowercase 'z' help screen -> verify "current MUMPS job" & "floors 1-10"
            ("help_z", ["z"]),
            ("help_close", [" "]),
            # Walk to '>' on floor 1: currently at (2,3), '>' is at (7,3) -> 5 rights => descends to floor 2 (+25)
            ("descend_to_2", [CSI_RIGHT] * 5),
            # Descend floors 2..9 (each has @ at (2,2), '>' at (4,2) -> 2 rights each) -> reaches floor 10 (+225 total!)
            ("descend_to_10", [CSI_RIGHT, CSI_RIGHT] * 8),
            # Reach stairs on floor 10 -> WIN ALL 10 FLOORS!
            ("win_10", [CSI_RIGHT, CSI_RIGHT]),
            ("dismiss_win", [" "]),
        ]
        rc, snaps, raw = run_dcrawl_session(tmpdir, ydb_dir, steps)
        assert rc == 0, f"10-floor/controls test rc={rc}\n{raw[-800:]}"

        by_label = {s["label"]: s for s in snaps}
        assert "flr 1/10" in by_label["init"]["status"], f"Expected flr 1/10: {by_label['init']['status']}"
        assert "$X 4" in by_label["csi_arrows"]["status"] and "$Y 3" in by_label["csi_arrows"]["status"]
        assert "$X 4" in by_label["ss3_arrows"]["status"] and "$Y 3" in by_label["ss3_arrows"]["status"]
        assert "$X 4" in by_label["wasd"]["status"] and "$Y 3" in by_label["wasd"]["status"]
        assert "$X 4" in by_label["hjkl"]["status"] and "$Y 3" in by_label["hjkl"]["status"]
        assert "$X 2" in by_label["wall_bump"]["status"], f"Wall collision failed: {by_label['wall_bump']['status']}"
        assert "press q to quit" in by_label["esc_single"]["flash"]
        assert "press q to quit" in by_label["esc_double"]["flash"]
        assert by_label["inspect_enter_exit"]["visible"] is False
        assert by_label["inspect_space_exit"]["visible"] is False
        assert by_label["inspect_esc_exit"]["visible"] is False
        assert "current MUMPS job" in by_label["help_z"]["screen"], (
            f"Missing MUMPS job wording in help:\n{by_label['help_z']['screen']}"
        )
        assert "floors 1-10" in by_label["help_z"]["screen"], (
            f"Missing dynamic floors 1-10 in help:\n{by_label['help_z']['screen']}"
        )
        assert "flr 2/10" in by_label["descend_to_2"]["status"] and "gold 25" in by_label["descend_to_2"]["status"]
        assert "flr 10/10" in by_label["descend_to_10"]["status"] and "gold 225" in by_label["descend_to_10"]["status"]
        assert "YOU ESCAPED ALL 10 FLOORS!" in by_label["win_10"]["screen"], (
            f"Missing 10-floor win banner:\n{by_label['win_10']['screen']}"
        )

    print("[PASS] 10-floor descent & controls: CSI/SS3/wasd/hjkl, ESC, inspect exits, z-help & 10/10 win")


def test_scores_persistence_and_ranking():
    """Verify ^SCORES persists across 3 YottaDB sessions in strict descending score order with exact causes."""
    with tempfile.TemporaryDirectory() as tmpdir:
        txt_dir = os.path.join(tmpdir, "txt")
        ydb_dir = os.path.join(tmpdir, "ydb")
        os.makedirs(txt_dir)
        os.makedirs(ydb_dir)

        # Run A: pick up 1 gold (+10) then die on poison tiles (10 steps back-and-forth on '~')
        floor_poison = [
            "..............",
            ".############.",
            ".#@$~       #.",
            ".############.",
            "..............",
        ]
        with open(os.path.join(txt_dir, "dungeon_1.txt"), "w") as f:
            f.write("\n".join(floor_poison) + "\n")
        # @ (2,2) -> (3,2) $=+10 -> (4,2) ~ (-1) -> back/forth 9 more times on ~ -> DEAD!
        poison_moves = [CSI_RIGHT, CSI_RIGHT] + [CSI_LEFT, CSI_RIGHT] * 9
        rcA, snapsA, _ = run_dcrawl_session(tmpdir, ydb_dir, [("die_poison", poison_moves), ("ok", [" "])])
        assert rcA == 0
        assert "YOU DIED (poison tile)" in snapsA[1]["screen"]

        # Run B: pick up 5 gold (+50) and WIN
        floor_win50 = [
            "..............",
            ".############.",
            ".#@$$$$$>   #.",
            ".############.",
            "..............",
        ]
        with open(os.path.join(txt_dir, "dungeon_1.txt"), "w") as f:
            f.write("\n".join(floor_win50) + "\n")
        rcB, snapsB, _ = run_dcrawl_session(tmpdir, ydb_dir, [("win50", [CSI_RIGHT] * 6), ("ok", [" "])])
        assert rcB == 0
        assert "score=50" in snapsB[1]["screen"]

        # Run C: pick up 2 gold (+20) then die on 4 spike traps -> score 20
        floor_spike20 = [
            "................",
            ".##############.",
            ".#@$$^^^^     #.",
            ".##############.",
            "................",
        ]
        with open(os.path.join(txt_dir, "dungeon_1.txt"), "w") as f:
            f.write("\n".join(floor_spike20) + "\n")
        rcC, snapsC, _ = run_dcrawl_session(tmpdir, ydb_dir, [("die20", [CSI_RIGHT] * 6), ("ok", [" "])])
        assert rcC == 0

        screen = snapsC[1]["screen"]
        lines = [ln for ln in screen.splitlines() if re.search(r"^\s*[> ]\s*[1-3]\s+\d+", ln)]
        assert len(lines) == 3, f"Expected 3 ranked rows in ^SCORES, got:\n{screen}"
        # Verify strict descending score collation: 50 (WIN), 20 (DEAD spike trap, highlighted '>'), 10 (DEAD poison tile)
        assert "50" in lines[0] and "WIN" in lines[0] and "reached final stairs" in lines[0], f"Bad rank 1: {lines[0]}"
        assert lines[1].startswith(">") and "20" in lines[1] and "spike trap" in lines[1], f"Bad rank 2: {lines[1]}"
        assert "10" in lines[2] and "poison tile" in lines[2], f"Bad rank 3: {lines[2]}"

    print("[PASS] ^SCORES persistence: 3-session collation ranking (50 > 20 > 10), causes & current-run highlight")


if __name__ == "__main__":
    test_generator_and_repo_floors()
    test_enemy_logic_and_combat()
    test_items_traps_doors_and_hp_cap()
    test_ten_floor_descent_and_controls()
    test_scores_persistence_and_ranking()
    print("ALL DCRAWLER TESTS PASSED!")
