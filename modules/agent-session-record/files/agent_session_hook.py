#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from datetime import UTC, datetime
from pathlib import Path

from agent_session_config import load_config


def warn(path: Path, command: str, message: str) -> None:
    line = f"{datetime.now(UTC).isoformat(timespec='seconds')} {command}: {message}\n"
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
            handle.write(line)
        path.chmod(0o600)
    except OSError:
        pass


def hook_contract(command: str) -> tuple[str, str, bool]:
    if command == "claude-session-upload":
        return "claude", "payload", False
    if command == "codex-stop-upload":
        return "codex", "payload", True
    if command == "codex-session-start-sweep":
        return "codex", "session-start-sweep", True
    raise ValueError(f"unsupported hook command: {command}")


def main(command: str | None = None) -> int:
    os.umask(0o077)
    command = command or Path(sys.argv[0]).name
    try:
        agent, mode, returns_continue = hook_contract(command)
    except ValueError as error:
        sys.stderr.write(f"{error}\n")
        return 1
    home = Path(os.environ.get("HOME", Path.home()))
    default_state_dir = Path(
        os.environ.get("XDG_STATE_HOME", home / ".local/state")
    ) / "agent-session-record"
    try:
        config = load_config(home)
    except ValueError as error:
        warn(default_state_dir / "warnings.log", command, str(error))
        if returns_continue:
            print('{"continue":true}')
        return 0
    state_dir = Path(
        config.get(
            "AGENT_SESSION_RECORD_STATE_DIR",
            Path(config.get("XDG_STATE_HOME", home / ".local/state"))
            / "agent-session-record",
        )
    )
    warning_log = state_dir / "warnings.log"
    debug_log = state_dir / "debug.log"
    worker = home / ".local/bin/agent-session-upload-worker"

    if not os.access(worker, os.X_OK):
        warn(warning_log, command, "worker command missing")
        if returns_continue:
            print('{"continue":true}')
        return 0

    try:
        descriptor, raw_payload = tempfile.mkstemp(prefix=f"{command}.")
        payload = Path(raw_payload)
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(sys.stdin.buffer.read())
    except OSError as error:
        warn(warning_log, command, f"failed to persist hook payload: {error}")
        if returns_continue:
            print('{"continue":true}')
        return 0

    arguments = [
        str(worker),
        "--mode",
        mode,
        "--agent",
        agent,
        "--payload-file",
        str(payload),
    ]
    try:
        debug_log.parent.mkdir(parents=True, exist_ok=True)
        debug_handle = debug_log.open("ab")
        debug_log.chmod(0o600)
        try:
            subprocess.Popen(
                arguments,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=debug_handle,
                start_new_session=True,
                close_fds=True,
            )
        finally:
            debug_handle.close()
    except OSError as error:
        payload.unlink(missing_ok=True)
        warn(warning_log, command, f"failed to start worker: {error}")
    if returns_continue:
        print('{"continue":true}')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
