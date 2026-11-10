"""Run installer scripts inside a pseudo-terminal.

A pty (not a pipe) makes the child see a real terminal: colours stay on,
output is line-buffered, and ``sudo`` / ``read -p`` prompts appear in the
stream instead of blocking forever. The TUI answers prompts by writing to
the pty, so passwords go straight to the child and are never stored.
"""

from __future__ import annotations

import asyncio
import codecs
import fcntl
import os
import re
import signal
import struct
import subprocess
import termios
from collections.abc import Sequence
from pathlib import Path

ANSI_RE = re.compile(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[@-Z\\-_]|\x1b\[[0-?]*[ -/]*[@-~]")
PASSWORD_RE = re.compile(r"(password|passphrase|passcode)\b[^\n]*[:?]\s*$", re.IGNORECASE)
# A partial line that ends like a question is probably waiting for input.
PROMPT_RE = re.compile(r"[:?>\]\)]\s*$")


def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


def looks_like_password(prompt: str) -> bool:
    return bool(PASSWORD_RE.search(strip_ansi(prompt)))


def looks_like_prompt(prompt: str) -> bool:
    plain = strip_ansi(prompt).rstrip("\r")
    return bool(plain.strip()) and (bool(PROMPT_RE.search(plain)) or looks_like_password(plain))


class LineSplitter:
    """Turn raw pty bytes into complete lines plus the current partial line.

    Carriage returns overwrite (progress bars), so only the text after the
    last ``\\r`` in a line survives. The pty turns ``\\n`` into ``\\r\\n``.
    """

    def __init__(self) -> None:
        self._decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
        self._partial = ""

    @staticmethod
    def _collapse(line: str) -> str:
        line = line.rstrip("\r")
        return line.rsplit("\r", 1)[-1]

    def feed(self, data: bytes) -> list[str]:
        text = self._partial + self._decoder.decode(data)
        *lines, self._partial = text.split("\n")
        return [self._collapse(line) for line in lines]

    def flush(self) -> list[str]:
        rest = self._partial + self._decoder.decode(b"", final=True)
        self._partial = ""
        return [self._collapse(rest)] if rest.strip("\r") else []

    @property
    def partial(self) -> str:
        return self._collapse(self._partial)


def _make_controlling_tty() -> None:  # runs in the child between fork and exec
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)


class PtyProcess:
    """One child process attached to a fresh pty."""

    def __init__(
        self,
        argv: Sequence[str],
        *,
        cwd: Path | None = None,
        env: dict[str, str] | None = None,
        cols: int = 100,
        rows: int = 40,
    ) -> None:
        self.argv = list(argv)
        self.cwd = cwd
        self.env = env
        self.cols = cols
        self.rows = rows
        self._master: int | None = None
        self._proc: subprocess.Popen[bytes] | None = None
        self._queue: asyncio.Queue[bytes | None] = asyncio.Queue()
        self._loop: asyncio.AbstractEventLoop | None = None

    async def start(self) -> None:
        self._loop = asyncio.get_running_loop()
        master, slave = os.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", self.rows, self.cols, 0, 0))
        try:
            self._proc = subprocess.Popen(
                self.argv,
                stdin=slave,
                stdout=slave,
                stderr=slave,
                cwd=self.cwd,
                env=self.env,
                preexec_fn=_make_controlling_tty,
                close_fds=True,
            )
        except BaseException:
            os.close(master)
            raise
        finally:
            os.close(slave)
        os.set_blocking(master, False)
        self._master = master
        self._loop.add_reader(master, self._on_readable)

    def _on_readable(self) -> None:
        assert self._master is not None
        try:
            data = os.read(self._master, 65536)
        except BlockingIOError:
            return
        except OSError:  # EIO: every slave fd closed, child is gone
            data = b""
        if data:
            self._queue.put_nowait(data)
        else:
            self._stop_reading()
            self._queue.put_nowait(None)

    def _stop_reading(self) -> None:
        if self._master is not None and self._loop is not None:
            self._loop.remove_reader(self._master)

    async def read(self) -> bytes | None:
        """Next chunk of output, or None at end of output."""
        return await self._queue.get()

    def write(self, text: str) -> None:
        if self._master is not None:
            os.write(self._master, text.encode())

    @property
    def pid(self) -> int | None:
        return self._proc.pid if self._proc else None

    def signal_group(self, sig: int) -> None:
        if self._proc is None or self._proc.poll() is not None:
            return
        try:
            os.killpg(self._proc.pid, sig)
        except ProcessLookupError:
            pass

    async def terminate(self, grace: float = 5.0) -> None:
        """SIGTERM the whole process group, SIGKILL after ``grace`` seconds."""
        self.signal_group(signal.SIGTERM)
        try:
            await asyncio.wait_for(self.wait(), grace)
        except asyncio.TimeoutError:
            self.signal_group(signal.SIGKILL)

    async def wait(self) -> int:
        assert self._proc is not None
        return await asyncio.to_thread(self._proc.wait)

    def close(self) -> None:
        self._stop_reading()
        if self._master is not None:
            try:
                os.close(self._master)
            except OSError:
                pass
            self._master = None
