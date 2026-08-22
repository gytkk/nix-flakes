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


def read_shell_config(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, raw_value = line.split("=", 1)
        try:
            parsed = shlex.split(raw_value, posix=True)
        except ValueError:
            continue
        if len(parsed) == 1:
            values[key] = parsed[0]
    return values


def load_config(home: Path) -> dict[str, str]:
    values = dict(os.environ)
    config_dir = home / ".config/agent-session-record"
    json_path = config_dir / "config.json"
    if json_path.is_file():
        try:
            config = json.loads(json_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            config = {}
        if isinstance(config, dict):
            values.update(
                {key: value for key, value in config.items() if isinstance(value, str)}
            )
        return values
    values.update(read_shell_config(config_dir / "config.sh"))
    return values


def jsonl_objects(path: Path) -> list[dict[str, Any]]:
    objects: list[dict[str, Any]] = []
    try:
        with path.open(encoding="utf-8") as handle:
            for line in handle:
                try:
                    value = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(value, dict):
                    objects.append(value)
    except OSError:
        pass
    return objects


def discover_transcripts(projects_dir: Path) -> list[Path]:
    transcripts = set(projects_dir.rglob("*.jsonl"))
    direct = {path for path in transcripts if "subagents" not in path.parts}
    orphans: set[Path] = set()
    for path in transcripts:
        if path.parent.name != "subagents" or not path.name.startswith("agent-"):
            continue
        parent_transcript = path.parent.parent.with_suffix(".jsonl")
        if not parent_transcript.is_file():
            orphans.add(path)
    return sorted(direct | orphans)


def transcript_metadata(path: Path) -> tuple[str, str, str]:
    objects = jsonl_objects(path)
    if path.parent.name == "subagents":
        session_id = next(
            (
                item["agentId"]
                for item in objects
                if isinstance(item.get("agentId"), str) and item["agentId"]
            ),
            "",
        )
    else:
        session_id = path.stem
    cwd = next(
        (
            item["cwd"]
            for item in objects
            if isinstance(item.get("cwd"), str) and item["cwd"]
        ),
        "",
    )
    reason = next(
        (
            summary.get("stop_reason") or summary.get("reason")
            for item in objects
            if item.get("type") == "summary"
            and isinstance((summary := item.get("summary")), dict)
            and (summary.get("stop_reason") or summary.get("reason"))
        ),
        "",
    )
    return session_id, cwd, str(reason)


def main() -> int:
    os.umask(0o077)
    home = Path(os.environ.get("HOME", Path.home()))
    config = load_config(home)
    state_dir = Path(
        config.get(
            "AGENT_SESSION_RECORD_STATE_DIR",
            Path(config.get("XDG_STATE_HOME", home / ".local/state"))
            / "agent-session-record",
        )
    )
    projects_dir = home / ".claude/projects"
    worker = home / ".local/bin/agent-session-upload-worker"
    session_state_dir = state_dir / "sessions"
    temp_dir = state_dir / "tmp"
    if not os.access(worker, os.X_OK):
        sys.stderr.write(f"worker command missing: {worker}\n")
        return 1
    if not projects_dir.is_dir():
        sys.stderr.write(f"claude projects directory missing: {projects_dir}\n")
        return 1
    session_state_dir.mkdir(parents=True, exist_ok=True)
    temp_dir.mkdir(parents=True, exist_ok=True)
    session_state_dir.chmod(0o700)
    temp_dir.chmod(0o700)

    transcripts = discover_transcripts(projects_dir)
    if not transcripts:
        print(f"No Claude session transcripts found under {projects_dir}")
        return 0

    uploaded = 0
    failed = 0
    for transcript in transcripts:
        session_id, cwd, reason = transcript_metadata(transcript)
        if not session_id:
            sys.stderr.write(f"skip (missing session id): {transcript}\n")
            failed += 1
            continue
        state_file = session_state_dir / f"claude-{session_id}.json"
        state_file.unlink(missing_ok=True)
        payload = {
            "session_id": session_id,
            "transcript_path": str(transcript),
            "cwd": cwd,
            "hook_event_name": "ManualReplay",
            "reason": reason,
        }
        descriptor, raw_payload = tempfile.mkstemp(
            dir=temp_dir, prefix="claude-upload-"
        )
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
                    "claude",
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

    print(f"\nprocessed: {len(transcripts)}")
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
        / "claude"
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
