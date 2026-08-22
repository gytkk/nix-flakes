#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///

from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
import tempfile
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from agent_session_config import load_config


def first_record(path: Path) -> dict[str, Any]:
    try:
        with path.open(encoding="utf-8") as handle:
            value = json.loads(handle.readline())
    except (OSError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def nested(value: dict[str, Any], *keys: str) -> Any:
    current: Any = value
    for key in keys:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current


def main() -> int:
    os.umask(0o077)
    home = Path(os.environ.get("HOME", Path.home()))
    try:
        config = load_config(home)
    except ValueError as error:
        sys.stderr.write(f"{error}\n")
        return 1
    state_dir = Path(
        config.get(
            "AGENT_SESSION_RECORD_STATE_DIR",
            Path(config.get("XDG_STATE_HOME", home / ".local/state"))
            / "agent-session-record",
        )
    )
    sessions_dir = Path(
        config.get("AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR", home / ".codex/sessions")
    )
    worker = home / ".local/bin/agent-session-upload-worker"
    session_state_dir = state_dir / "sessions"
    temp_dir = state_dir / "tmp"
    scope = config.get("AGENT_SESSION_RECORD_SCOPE", "personal")
    if not os.access(worker, os.X_OK):
        sys.stderr.write(f"worker command missing: {worker}\n")
        return 1
    if not sessions_dir.is_dir():
        sys.stderr.write(f"codex sessions directory missing: {sessions_dir}\n")
        return 1
    session_state_dir.mkdir(parents=True, exist_ok=True)
    temp_dir.mkdir(parents=True, exist_ok=True)
    session_state_dir.chmod(0o700)
    temp_dir.chmod(0o700)
    rollouts = sorted(sessions_dir.rglob("rollout-*.jsonl"))
    if not rollouts:
        print(f"No Codex rollout files found under {sessions_dir}")
        return 0

    uploaded = 0
    failed = 0
    for transcript in rollouts:
        first = first_record(transcript)
        session_id = nested(first, "payload", "id")
        cwd = nested(first, "payload", "cwd")
        if not isinstance(session_id, str) or not session_id:
            sys.stderr.write(f"skip (missing session id): {transcript}\n")
            failed += 1
            continue
        state_file = session_state_dir / f"{scope}-codex-{session_id}.json"
        state_file.unlink(missing_ok=True)
        payload = {
            "session_id": session_id,
            "transcript_path": str(transcript),
            "cwd": cwd if isinstance(cwd, str) else "",
            "hook_event_name": "ManualReplay",
            "turn_id": "",
            "stop_hook_active": False,
            "last_assistant_message": "",
        }
        descriptor, raw_payload = tempfile.mkstemp(dir=temp_dir, prefix="codex-upload-")
        os.close(descriptor)
        payload_path = Path(raw_payload)
        try:
            payload_path.write_text(
                json.dumps(payload, ensure_ascii=False) + "\n", encoding="utf-8"
            )
            result = subprocess.run(
                [
                    str(worker),
                    "--mode",
                    "payload",
                    "--agent",
                    "codex",
                    "--payload-file",
                    str(payload_path),
                ],
                stdin=subprocess.DEVNULL,
                check=False,
            )
            if result.returncode == 0 and state_file.is_file():
                print(f"uploaded: {session_id}")
                uploaded += 1
            else:
                sys.stderr.write(
                    f"upload not confirmed (queued or failed): {session_id}\n"
                )
                failed += 1
        finally:
            payload_path.unlink(missing_ok=True)

    print(f"\nprocessed: {len(rollouts)}")
    print(f"uploaded: {uploaded}")
    print(f"failed: {failed}")
    ssh = Path(config.get("AGENT_SESSION_RECORD_SSH_BIN", "/usr/bin")) / "ssh"
    remote = (
        f"{config.get('AGENT_SESSION_RECORD_REMOTE_USER', 'gytkk')}@"
        f"{config.get('AGENT_SESSION_RECORD_REMOTE_HOST', 'pylv-onyx')}"
    )
    remote_dir = (
        Path(
            config.get(
                "AGENT_SESSION_RECORD_REMOTE_BASE_PATH", "/home/gytkk/agent-sessions"
            )
        )
        / config.get("AGENT_SESSION_RECORD_SCOPE", "personal")
        / "codex"
    )
    remote_result = subprocess.run(
        [
            str(ssh),
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=10",
            remote,
            (
                f"find {shlex.quote(str(remote_dir))} -type f -name '*.jsonl' "
                "2>/dev/null | wc -l"
            ),
        ],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
    )
    if remote_result.returncode == 0 and remote_result.stdout.strip():
        print(f"remote jsonl count: {remote_result.stdout.strip()}")
    else:
        print("remote jsonl count: unavailable")
    print(f"completed at: {datetime.now(UTC).isoformat(timespec='seconds')}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
