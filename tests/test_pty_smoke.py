#!/usr/bin/env python3
"""Minimal 30x80 ANSI PTY smoke test for dcrawl terminal I/O and key handling."""

import os
import pty
import re
import select
import subprocess
import tempfile
import time

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CSI = ("\x1b[A", "\x1b[C", "\x1b[B", "\x1b[D")
SS3 = ("\x1bOA", "\x1bOC", "\x1bOB", "\x1bOD")
ESC = "\x1b"


def run_pty(workdir, ydb_dir, steps):
    master, slave = pty.openpty()
    env = {k: v for k, v in os.environ.items() if not k.startswith(("ydb_", "gtm"))}
    env["ydb_dir"] = ydb_dir
    cmd = (
        "source /usr/local/etc/ydb_env_set >/dev/null && "
        f'ydb_routines="{REPO_ROOT}/src $ydb_routines" '
        f'gtmroutines="{REPO_ROOT}/src $gtmroutines" '
        "mumps -run '^DCRAWL'"
    )
    proc = subprocess.Popen(
        ["bash", "-c", cmd], cwd=workdir, env=env, stdin=slave, stdout=slave, stderr=slave, close_fds=True
    )
    os.close(slave)

    def drain(timeout=0.35):
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

    chunks = {"init": drain(1.2)}
    for label, tokens in steps:
        buf = ""
        for tok in tokens:
            os.write(master, tok.encode("utf-8"))
            time.sleep(0.11 if tok == ESC else 0.04)
            buf += drain(0.15)
        chunks[label] = buf

    try:
        rc = proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        proc.kill()
        rc = -9
    os.close(master)
    return rc, chunks


def strip_ansi(s):
    return re.sub(r"\x1b\[[?0-9;]*[A-Za-z]", "", s)


def main():
    # 1) Boot against repo's 25 floors: verify flr 1/25, $X/$Y, $H/$J, ANSI color, clean quit
    with tempfile.TemporaryDirectory() as ydb:
        rc, out = run_pty(REPO_ROOT, ydb, [("quit", ["q"])])
        assert rc == 0, f"repo boot rc={rc}"
        plain = strip_ansi(out["init"])
        assert "flr 1/25" in plain and "$X " in plain and "$Y " in plain and "$H " in plain and "$J " in plain
        assert "\x1b[" in out["init"] and "\x1b[?25h" in out["quit"]

    # 2) Full PTY controls, inspect, help, scores, 2-floor descent & win
    with tempfile.TemporaryDirectory() as tmp:
        txt, ydb = os.path.join(tmp, "txt"), os.path.join(tmp, "ydb")
        os.makedirs(txt)
        os.makedirs(ydb)
        f1 = ["............", ".##########.", ".#        #.", ".#  @  >  #.", ".#        #.", ".##########.", "............"]
        f2 = ["..........", ".########.", ".#@ >   #.", ".########.", ".........."]
        open(os.path.join(txt, "dungeon_1.txt"), "w").write("\n".join(f1) + "\n")
        open(os.path.join(txt, "dungeon_2.txt"), "w").write("\n".join(f2) + "\n")

        steps = [
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
            ("done", [" "]),
        ]
        rc, out = run_pty(tmp, ydb, steps)
        assert rc == 0, f"controls/win rc={rc}"
        for k in ("csi", "ss3", "wasd", "hjkl"):
            assert "$X 4" in strip_ansi(out[k]) and "$Y 3" in strip_ansi(out[k]), f"bad pos after {k}"
        assert "$X 2" in strip_ansi(out["wall"]), "wall bump failed"
        assert "press q to quit" in strip_ansi(out["esc"]), "ESC hint missing"
        assert "\x1b[?25h" in out["inspect"] and "\x1b[?25l" in out["inspect"], "inspect cursor toggle"
        assert "current MUMPS job" in strip_ansi(out["help"]) and "floors 1-2" in strip_ansi(out["help"])
        assert "DCRAWL HIGH SCORES" in strip_ansi(out["scores"])
        assert "flr 2/2" in strip_ansi(out["descend"]) and "gold 25" in strip_ansi(out["descend"])
        assert "YOU ESCAPED ALL 2 FLOORS!" in strip_ansi(out["win"])

    print("[PASS] PTY smoke test: ANSI boot (1/25), CSI/SS3/wasd/hjkl, ESC, inspect, help, scores & win")


if __name__ == "__main__":
    main()
