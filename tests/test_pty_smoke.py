#!/usr/bin/env python3
"""30x80 ANSI PTY smoke test for dcrawl title screen, controls, multi-user isolation & timeout."""

import os
import pty
import re
import select
import shlex
import signal
import subprocess
import tempfile
import time

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CSI = ("\x1b[A", "\x1b[C", "\x1b[B", "\x1b[D")
SS3 = ("\x1bOA", "\x1bOC", "\x1bOB", "\x1bOD")
ESC = "\x1b"


def spawn_pty(workdir, ydb_dir, extra_env=None):
    master, slave = pty.openpty()
    env = {k: v for k, v in os.environ.items() if not k.startswith(("ydb_", "gtm"))}
    env["ydb_dir"] = ydb_dir
    if extra_env:
        env.update(extra_env)
    cmd = (
        "source /usr/local/etc/ydb_env_set >/dev/null && "
        f'ydb_routines="{REPO_ROOT}/src $ydb_routines" '
        f'gtmroutines="{REPO_ROOT}/src $gtmroutines" '
        "exec mumps -run '^DCRAWL'"
    )
    proc = subprocess.Popen(
        ["bash", "-c", cmd], cwd=workdir, env=env, stdin=slave, stdout=slave, stderr=slave, close_fds=True
    )
    os.close(slave)
    return proc, master


def drain(master, timeout=0.35):
    end, out = time.time() + timeout, ""
    while time.time() < end:
        if select.select([master], [], [], max(0.02, end - time.time()))[0]:
            try:
                chunk = os.read(master, 4096)
                if not chunk:
                    break
                out += chunk.decode("utf-8", errors="replace")
                end = time.time() + 0.1
            except OSError:
                break
    return out


def send_tokens(master, tokens):
    buf = ""
    for tok in tokens:
        os.write(master, tok.encode("utf-8"))
        time.sleep(0.11 if tok == ESC else 0.04)
        buf += drain(master, 0.15)
    return buf


def run_pty(workdir, ydb_dir, steps, extra_env=None, init_timeout=1.2):
    proc, master = spawn_pty(workdir, ydb_dir, extra_env=extra_env)
    chunks = {"init": drain(master, init_timeout)}
    for label, tokens in steps:
        chunks[label] = send_tokens(master, tokens)
    try:
        rc = proc.wait(timeout=4)
    except subprocess.TimeoutExpired:
        proc.kill()
        rc = -9
    os.close(master)
    return rc, chunks


def query_mumps(workdir, ydb_dir, expr):
    env = {k: v for k, v in os.environ.items() if not k.startswith(("ydb_", "gtm"))}
    env["ydb_dir"] = ydb_dir
    cmd = (
        "source /usr/local/etc/ydb_env_set >/dev/null && "
        f'ydb_routines="{REPO_ROOT}/src $ydb_routines" '
        f'gtmroutines="{REPO_ROOT}/src $gtmroutines" '
        f"mumps -run %XCMD {shlex.quote(expr)}"
    )
    out = subprocess.check_output(["bash", "-c", cmd], cwd=workdir, env=env, text=True)
    return out.strip()


def strip_ansi(s):
    return re.sub(r"\x1b\[[?0-9;]*[A-Za-z]", "", s)


def main():
    # 1) Boot against repo's 25 floors: title screen, 3-char arcade initials, game HUD, clean quit
    with tempfile.TemporaryDirectory() as ydb:
        rc, out = run_pty(
            REPO_ROOT,
            ydb,
            [
                ("prompt", ["\r"]),
                ("start", ["j", "r", "d", "\r"]),
                ("quit", ["q"]),
            ],
        )
        assert rc == 0, f"repo boot rc={rc}"
        title_plain = strip_ansi(out["init"])
        assert "where YOU are $X and $Y" in title_plain, f"missing tagline in title: {title_plain!r}"
        assert "25 floors" in title_plain and "#1 HIGH SCORE" in title_plain
        assert "ARCADE INITIALS" in strip_ansi(out["prompt"])
        game_plain = strip_ansi(out["start"])
        assert "flr 1/25" in game_plain and "tag JRD" in game_plain
        assert "$X " in game_plain and "$Y " in game_plain and "$H " in game_plain and "$J " in game_plain
        assert "\x1b[" in out["start"] and "\x1b[?25h" in out["quit"]
        # verify clean QUIT removed ^G($J)
        assert query_mumps(REPO_ROOT, ydb, 'W $D(^G)') == "0", "^G not cleaned up on QUIT"

    # 2) Full PTY title menu, initials backspace/esc, controls, inspect, help, scores, 2-floor win & replay
    with tempfile.TemporaryDirectory() as tmp:
        txt, ydb = os.path.join(tmp, "txt"), os.path.join(tmp, "ydb")
        os.makedirs(txt)
        os.makedirs(ydb)
        f1 = ["............", ".##########.", ".#        #.", ".#  @  >  #.", ".#        #.", ".##########.", "............"]
        f2 = ["..........", ".########.", ".#@ >   #.", ".########.", ".........."]
        open(os.path.join(txt, "dungeon_1.txt"), "w").write("\n".join(f1) + "\n")
        open(os.path.join(txt, "dungeon_2.txt"), "w").write("\n".join(f2) + "\n")

        steps = [
            ("title_scores", ["t"]),
            ("title_scores_close", [" "]),
            ("title_help", ["z"]),
            ("title_help_close", [" "]),
            ("prompt_cancel", ["\r", "x", ESC]),
            ("start", ["\r", "a", "b", "x", "\x7f", "c", "\r"]),
            ("csi", list(CSI)),
            ("ss3", list(SS3)),
            ("wasd", ["w", "d", "s", "a"]),
            ("hjkl", ["k", "l", "j", "h"]),
            ("wall", ["a", "a", "a", "a"]),
            ("esc", [ESC]),
            ("inspect", ["i", CSI[1], "\r", "i", SS3[1], " ", "i", CSI[3], ESC]),
            ("help", ["z"]),
            ("help_close", [" "]),
            ("scores", ["t"]),
            ("scores_close", [" "]),
            ("descend", [CSI[1]] * 5),
            ("win", [CSI[1], CSI[1]]),
            ("replay_title", [" "]),
            ("quit_title", ["q"]),
        ]
        rc, out = run_pty(tmp, ydb, steps)
        assert rc == 0, f"controls/win rc={rc}"
        assert "DCRAWL HIGH SCORES" in strip_ansi(out["title_scores"])
        assert "DCRAWL HELP" in strip_ansi(out["title_help"])
        assert "tag ABC" in strip_ansi(out["start"]), f"backspace initials failed: {strip_ansi(out['start'])!r}"
        for k in ("csi", "ss3", "wasd", "hjkl"):
            assert "$X 4" in strip_ansi(out[k]) and "$Y 3" in strip_ansi(out[k]), f"bad pos after {k}"
        assert "$X 2" in strip_ansi(out["wall"]), "wall bump failed"
        assert "press q to quit" in strip_ansi(out["esc"]), "ESC hint missing"
        assert "\x1b[?25h" in out["inspect"] and "\x1b[?25l" in out["inspect"], "inspect cursor toggle"
        assert "current MUMPS job" in strip_ansi(out["help"]) and "floors 1-2" in strip_ansi(out["help"])
        assert "DCRAWL HIGH SCORES" in strip_ansi(out["scores"])
        assert "flr 2/2" in strip_ansi(out["descend"]) and "gold 25" in strip_ansi(out["descend"])
        win_plain = strip_ansi(out["win"])
        assert "YOU ESCAPED ALL 2 FLOORS!" in win_plain and "ABC" in win_plain
        replay_plain = strip_ansi(out["replay_title"])
        assert "#1 HIGH SCORE:  ABC | 25 gold" in replay_plain, f"leader missing on replay title: {replay_plain!r}"

    # 3) Two concurrent players on one shared MUMPS database + abrupt PTY hangup ($ETRAP cleanup)
    with tempfile.TemporaryDirectory() as tmp:
        txt, ydb = os.path.join(tmp, "txt"), os.path.join(tmp, "ydb")
        os.makedirs(txt)
        os.makedirs(ydb)
        f1 = ["..........", ".########.", ".#@ $>  #.", ".########.", ".........."]
        open(os.path.join(txt, "dungeon_1.txt"), "w").write("\n".join(f1) + "\n")

        # Initialize DB once before spawning concurrent players
        query_mumps(tmp, ydb, 'D SEED^DCTYPE')

        proc_a, master_a = spawn_pty(tmp, ydb)
        proc_b, master_b = spawn_pty(tmp, ydb)
        drain(master_a, 1.0)
        drain(master_b, 1.0)

        out_a = send_tokens(master_a, ["\r", "a", "a", "a", "\r"])
        out_b = send_tokens(master_b, ["\r", "b", "b", "b", "\r"])
        assert "tag AAA" in strip_ansi(out_a) and "tag BBB" in strip_ansi(out_b)

        # Player A collects gold ($ at x=4) and wins (> at x=5) while Player B stays at start
        win_a = send_tokens(master_a, ["d", "d", "d"])
        assert "YOU ESCAPED ALL 1 FLOORS!" in strip_ansi(win_a)
        send_tokens(master_a, ["q"])
        assert proc_a.wait(timeout=4) == 0
        os.close(master_a)

        # Player B still has isolated state (gold 0, $X 2) and sees AAA on live shared ^SCORES
        scores_b = send_tokens(master_b, ["t"])
        assert "AAA" in strip_ansi(scores_b), f"Player B did not see AAA in shared ^SCORES: {strip_ansi(scores_b)!r}"
        back_b = send_tokens(master_b, [" "])
        assert "gold 0" in strip_ansi(back_b) and "$X 2" in strip_ansi(back_b)

        # Simulate abrupt browser/terminal disconnect (SIGHUP like ttyd, then close PTY) -> TRAP^DCRAWL must clean up ^G($J)
        os.kill(proc_b.pid, signal.SIGHUP)
        rc_b = proc_b.wait(timeout=4)
        os.close(master_b)
        assert rc_b == 0, f"abrupt PTY disconnect rc={rc_b}"
        assert query_mumps(tmp, ydb, 'W $D(^G)') == "0", "^G($J) leaked after abrupt PTY disconnect"
        assert "AAA^10^1^WIN" in query_mumps(tmp, ydb, 'W $$LEADER^DCSCORE'), "shared ^SCORES lost AAA"

    # 4) Inactivity timeout (DCRAWL_IDLE_SEC=1) exits cleanly and cleans up ^G($J)
    with tempfile.TemporaryDirectory() as ydb:
        proc, master = spawn_pty(REPO_ROOT, ydb, extra_env={"DCRAWL_IDLE_SEC": "1"})
        out_buf = ""
        deadline = time.time() + 3.5
        while time.time() < deadline:
            if select.select([master], [], [], 0.1)[0]:
                try:
                    chunk = os.read(master, 4096)
                    if not chunk:
                        break
                    out_buf += chunk.decode("utf-8", errors="replace")
                except OSError:
                    break
            elif proc.poll() is not None:
                break
        rc = proc.wait(timeout=3)
        os.close(master)
        assert rc == 0, f"idle timeout rc={rc}"
        assert "session timed out" in strip_ansi(out_buf), f"missing timeout msg: {strip_ansi(out_buf)!r}"
        assert query_mumps(REPO_ROOT, ydb, 'W $D(^G)') == "0", "^G($J) leaked after idle timeout"

    print("[PASS] PTY smoke test: title screen, 3-char initials, controls, concurrent ^G($J)/^SCORES, $ETRAP & timeout")


if __name__ == "__main__":
    main()
