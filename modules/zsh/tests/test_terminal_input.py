"""Run with uv run --no-project -m unittest discover -s modules/zsh/tests -v."""

import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import signal
import time
import unittest


GUARD = Path(__file__).resolve().parents[1] / "files" / "terminal-input.zsh"


def collect(fd, seconds=0.15):
    output = b""
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if select.select([fd], [], [], 0.01)[0]:
            try:
                output += os.read(fd, 65536)
            except OSError:
                break
    return output


def replay(sequence, mode="viins"):
    pid, fd = pty.fork()
    if pid == 0:
        os.execvpe(
            "zsh",
            ["zsh", "-f", "-i"],
            dict(os.environ, TERM="xterm-256color", EDITOR="nvim", VISUAL="nvim"),
        )
    try:
        collect(fd)
        source = shlex.quote(os.environ.get("ZSH_INPUT_GUARD", str(GUARD)))
        keymap = "emacs" if mode == "emacs" else "viins"
        init = (
            "zle-line-init() { zle -K vicmd; }; zle -N zle-line-init; "
            if mode == "vicmd"
            else ""
        )
        setup = (
            "HISTFILE=/dev/null; PS1='READY> '; "
            f"bindkey -A {keymap} main; source {source}; {init}"
            "dump-buffer() { print -r -- \"BUFFER=$BUFFER\"; BUFFER=''; zle accept-line; }; "
            "zle -N dump-buffer; "
            "for map in viins vicmd emacs; do bindkey -M $map '^M' dump-buffer; done; "
            "bindkey $'\\e[3~' delete-char\r"
        )
        os.write(fd, setup.encode())
        ready = collect(fd, 0.3)
        if b"READY> " not in ready:
            raise AssertionError(f"Zsh did not initialize: {ready!r}")
        chunks = [(0, sequence)] if isinstance(sequence, bytes) else sequence
        output = b""
        for delay, chunk in chunks:
            output += collect(fd, delay)
            os.write(fd, chunk)
        return output + collect(fd, 0.3)
    finally:
        os.kill(pid, signal.SIGKILL)
        os.close(fd)
        os.waitpid(pid, 0)


@unittest.skipUnless(shutil.which("zsh"), "requires Zsh and a PTY")
class TerminalInputTest(unittest.TestCase):
    def test_late_terminal_responses_preserve_input(self):
        responses = [
            b"\x1b[99;5:3u",
            b"\x1b[99:67;5:3u",
            b"\x1b[57442;1:3u",
            b"\x1b[57448;1:3u",
            b"\x1b[20;9R",
            b"\x1b]11;rgb:2121/2121/2121\x1b\\",
            b"\x1b]10;rgb:ffff/ffff/ffff\x07",
        ]
        for mode in ["viins", "vicmd", "emacs"]:
            for response in responses:
                with self.subTest(mode=mode, response=response):
                    typing = b"ihello\r" if mode == "vicmd" else b"hello\r"
                    output = replay(response + typing, mode)
                    self.assertNotIn(b"execute:", output)
                    self.assertIn(b"BUFFER=hello", output)

    def test_existing_key_bindings(self):
        for sequence, expected in [
            (b"ac\x1b[Db\r", b"BUFFER=abc"),
            (b"abc\x1b[D\x1b[D\x1b[3~\r", b"BUFFER=ac"),
            (b"\x1b[200~paste\x1b[201~\r", b"BUFFER=paste"),
            (b"\x1b:", b"execute:"),
        ]:
            with self.subTest(sequence=sequence):
                self.assertIn(expected, replay(sequence))

    def test_fragmented_and_incomplete_responses(self):
        for chunks in [
            [(0, b"\x1b[99;5:"), (0.01, b"3uhello\r")],
            [(0, b"\x1b]11;rgb:2121/2121/2121\x1b"), (0.01, b"\\hello\r")],
            [(0, b"\x1b[99;"), (0.15, b"hello\r")],
            [(0, b"\x1b]11;rgb:"), (0.15, b"hello\r")],
        ]:
            with self.subTest(chunks=chunks):
                output = replay(chunks)
                self.assertNotIn(b"execute:", output)
                self.assertIn(b"BUFFER=hello", output)


if __name__ == "__main__":
    unittest.main()
