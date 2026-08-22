#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///

from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import hashlib
import json
import os
import re
import secrets
import shlex
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from collections.abc import Iterator
from pathlib import Path
from typing import Any

from agent_session_config import load_config

SCHEMA_VERSION = 2
REDACTION_POLICY_VERSION = "builtin-v1"
PRIVACY_POLICY_VERSION = "builtin-pii-v1"
RUN_ID_PATTERN = re.compile(r"^run_[0-9a-f]{32}$")
FINGERPRINT_PATTERN = re.compile(r"^[0-9a-f]{64}$")
QUEUE_ITEM_PATTERN = re.compile(
    r"^(personal|organization)-(claude|codex)-(run_[0-9a-f]{32})-([0-9a-f]{64})$"
)
SECRET_KEY_PATTERN = re.compile(
    r"(api[_-]?key|access[_-]?token|auth[_-]?token|refresh[_-]?token|"
    r"session[_-]?token|id[_-]?token|password|secret|private[_-]?key|credential)",
    re.IGNORECASE,
)
PII_KEY_PATTERN = re.compile(
    r"(^|[_-])(full[_-]?name|display[_-]?name|first[_-]?name|last[_-]?name|"
    r"employee[_-]?id|customer[_-]?id|account[_-]?id|person[_-]?id|"
    r"user[_-]?id|username)([_-]|$)",
    re.IGNORECASE,
)
SECRET_STRING_REDACTIONS = (
    (
        re.compile(
            r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----",
            re.DOTALL,
        ),
        "[REDACTED_PRIVATE_KEY]",
    ),
    (re.compile(r"sk-[a-z0-9_-]{20,}", re.IGNORECASE), "[REDACTED_SECRET]"),
    (re.compile(r"gh[pousr]_[A-Za-z0-9_]{20,}"), "[REDACTED_SECRET]"),
    (re.compile(r"AKIA[0-9A-Z]{16}"), "[REDACTED_SECRET]"),
    (re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"), "[REDACTED_SECRET]"),
    (
        re.compile(r"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"),
        "[REDACTED_SECRET]",
    ),
    (
        re.compile(r"Bearer\s+[A-Za-z0-9._~+/-]{20,}={0,2}", re.IGNORECASE),
        "Bearer [REDACTED_SECRET]",
    ),
)
PRIVACY_STRING_REDACTIONS = (
    (
        re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
        "[REDACTED_EMAIL]",
    ),
    (
        re.compile(r"(?<!\d)(?:\+?82[- ]?)?0?1[016789][- ]?\d{3,4}[- ]?\d{4}(?!\d)"),
        "[REDACTED_PHONE]",
    ),
    (re.compile(r"\b\d{6}-?[1-4]\d{6}\b"), "[REDACTED_NATIONAL_ID]"),
)
STRING_REDACTIONS = SECRET_STRING_REDACTIONS + PRIVACY_STRING_REDACTIONS


def utc_now() -> str:
    return dt.datetime.now(dt.UTC).isoformat(timespec="seconds")


class Recorder:
    def __init__(self, agent: str, environ: dict[str, str] | None = None) -> None:
        env = dict(os.environ if environ is None else environ)
        home = Path(env.get("HOME", str(Path.home())))
        env = load_config(home, env)
        xdg_state = Path(env.get("XDG_STATE_HOME", home / ".local/state"))

        self.agent = agent
        self.home = home
        self.remote_host = env.get("AGENT_SESSION_RECORD_REMOTE_HOST", "pylv-onyx")
        self.remote_user = env.get("AGENT_SESSION_RECORD_REMOTE_USER", "gytkk")
        self.remote_base = Path(
            env.get(
                "AGENT_SESSION_RECORD_REMOTE_BASE_PATH",
                "/home/gytkk/agent-sessions",
            )
        )
        self.local_short_circuit_host = env.get(
            "AGENT_SESSION_RECORD_LOCAL_SHORT_CIRCUIT_HOST", "pylv-onyx"
        )
        self.state_dir = Path(
            env.get(
                "AGENT_SESSION_RECORD_STATE_DIR", xdg_state / "agent-session-record"
            )
        )
        self.codex_sessions_dir = Path(
            env.get("AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR", home / ".codex/sessions")
        )
        self.scope = env.get("AGENT_SESSION_RECORD_SCOPE", "personal")
        self.ssh = Path(env.get("AGENT_SESSION_RECORD_SSH_BIN", "/usr/bin")) / "ssh"
        self.rsync = (
            Path(env.get("AGENT_SESSION_RECORD_RSYNC_BIN", "/usr/bin")) / "rsync"
        )
        self.current_host = socket.gethostname().split(".", 1)[0]

        self.queue_dir = self.state_dir / "queue"
        self.lock_dir = self.state_dir / "locks"
        self.session_state_dir = self.state_dir / "sessions"
        self.tmp_dir = self.state_dir / "tmp"
        self.run_dir = self.state_dir / "runs"
        self.attempt_dir = self.state_dir / "attempts"
        self.manifest_dir = self.state_dir / "manifests"
        self.quarantine_dir = self.state_dir / "quarantine"
        self.warning_log = self.state_dir / "warnings.log"
        self.ensure_dirs()

    def ensure_dirs(self) -> None:
        for path in (
            self.state_dir,
            self.queue_dir,
            self.lock_dir,
            self.session_state_dir,
            self.tmp_dir,
            self.run_dir,
            self.attempt_dir,
            self.manifest_dir,
            self.quarantine_dir,
        ):
            path.mkdir(parents=True, exist_ok=True, mode=0o700)
            path.chmod(0o700)

    def warn(self, message: str) -> None:
        line = f"{utc_now()} agent-session-upload-worker: {message}\n"
        try:
            with self.warning_log.open("a", encoding="utf-8") as handle:
                handle.write(line)
            self.warning_log.chmod(0o600)
        except OSError:
            pass
        sys.stderr.write(line)

    @contextlib.contextmanager
    def lock(self, path: Path) -> Iterator[None]:
        started = time.monotonic()
        while True:
            try:
                path.mkdir(mode=0o700)
                (path / "pid").write_text(f"{os.getpid()}\n", encoding="utf-8")
                (path / "created_epoch").write_text(
                    f"{int(time.time())}\n", encoding="utf-8"
                )
                break
            except FileExistsError:
                if self._lock_is_stale(path):
                    shutil.rmtree(path, ignore_errors=True)
                    continue
                if time.monotonic() - started >= 15:
                    raise TimeoutError(f"timed out acquiring lock {path.name}")
                time.sleep(0.1)
        try:
            yield
        finally:
            shutil.rmtree(path, ignore_errors=True)

    def _lock_is_stale(self, path: Path) -> bool:
        try:
            owner = int((path / "pid").read_text(encoding="utf-8").strip())
        except (OSError, ValueError):
            owner = 0
        if owner:
            try:
                os.kill(owner, 0)
            except ProcessLookupError:
                return True
            except PermissionError:
                pass
        try:
            created = int((path / "created_epoch").read_text(encoding="utf-8").strip())
        except (OSError, ValueError):
            created = int(path.stat().st_mtime)
        return time.time() - created > 300

    @staticmethod
    def fingerprint(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()

    @staticmethod
    def mtime_ns(path: Path) -> int:
        return path.stat().st_mtime_ns

    @staticmethod
    def file_timestamp(mtime_ns: int) -> str:
        return dt.datetime.fromtimestamp(mtime_ns / 1_000_000_000, dt.UTC).isoformat()

    @staticmethod
    def read_json(path: Path) -> dict[str, Any] | None:
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return None
        return value if isinstance(value, dict) else None

    @staticmethod
    def write_json(path: Path, value: dict[str, Any]) -> None:
        path.write_text(
            json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )
        path.chmod(0o600)

    @staticmethod
    def jsonl_objects(path: Path) -> Iterator[dict[str, Any]]:
        with path.open(encoding="utf-8") as handle:
            for line in handle:
                try:
                    value = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(value, dict):
                    yield value

    @staticmethod
    def nested(value: dict[str, Any], *keys: str) -> Any:
        current: Any = value
        for key in keys:
            if not isinstance(current, dict):
                return None
            current = current.get(key)
        return current

    def first_jsonl_value(self, path: Path, reader: Any) -> str:
        try:
            for item in self.jsonl_objects(path):
                value = reader(item)
                if isinstance(value, str) and value:
                    return value
        except OSError:
            pass
        return ""

    def first_jsonl_object(self, path: Path) -> dict[str, Any]:
        try:
            return next(self.jsonl_objects(path), {})
        except OSError:
            return {}

    def session_state_file(self, scope: str, provider: str, session_id: str) -> Path:
        return self.session_state_dir / f"{scope}-{provider}-{session_id}.json"

    def allocate_run_id(self, provider: str, provider_identity: str) -> str:
        registry_key = hashlib.sha256(
            f"{provider}\0{provider_identity}".encode()
        ).hexdigest()
        registry_file = self.run_dir / f"{provider}-{registry_key}.json"
        registry_lock = self.lock_dir / f"run-{provider}-{registry_key}.lock"
        with self.lock(registry_lock):
            if registry_file.is_file():
                entry = self.read_json(registry_file)
                run_id = entry.get("run_id") if entry else None
                if (
                    entry
                    and entry.get("provider") == provider
                    and entry.get("provider_identity") == provider_identity
                    and isinstance(run_id, str)
                    and RUN_ID_PATTERN.fullmatch(run_id)
                ):
                    return run_id
                raise ValueError(f"invalid run registry entry: {registry_file.name}")

            run_id = f"run_{secrets.token_hex(16)}"
            self.atomic_json(
                registry_file,
                {
                    "run_id": run_id,
                    "provider": provider,
                    "provider_identity": provider_identity,
                },
            )
            return run_id

    def atomic_json(self, destination: Path, value: dict[str, Any]) -> None:
        fd, raw_path = tempfile.mkstemp(dir=self.tmp_dir, prefix="json-")
        os.close(fd)
        temp_path = Path(raw_path)
        try:
            self.write_json(temp_path, value)
            os.replace(temp_path, destination)
        finally:
            temp_path.unlink(missing_ok=True)

    def append_jsonl(self, path: Path, value: dict[str, Any], lock_name: str) -> None:
        with self.lock(self.lock_dir / lock_name):
            with path.open("a", encoding="utf-8") as handle:
                handle.write(
                    json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n"
                )
            path.chmod(0o600)

    def append_hook_attempt(self, payload_path: Path, status: str) -> None:
        payload = self.read_json(payload_path) or {}
        self.append_jsonl(
            self.attempt_dir / "hooks.jsonl",
            {
                "schema_version": 1,
                "provider": self.agent,
                "provider_session_id": payload.get("session_id"),
                "hook_event_name": payload.get("hook_event_name"),
                "status": status,
                "recorded_at": utc_now(),
            },
            "hook-attempts.lock",
        )

    def append_capture_attempt(self, manifest: dict[str, Any], status: str) -> None:
        run_id = manifest["run_id"]
        self.append_jsonl(
            self.attempt_dir / f"{run_id}.jsonl",
            {
                "schema_version": manifest["schema_version"],
                "run_id": run_id,
                "provider": manifest["provider"],
                "provider_session_id": manifest["provider_session_id"],
                "transcript_fingerprint": manifest["transcript_fingerprint"],
                "redaction_status": manifest["redaction_status"],
                "privacy_check_status": manifest["privacy_check_status"],
                "status": status,
                "recorded_at": utc_now(),
            },
            f"attempt-{run_id}.lock",
        )

    def redact_secret_value(self, value: Any) -> Any:
        if isinstance(value, dict):
            return {
                key: (
                    "[REDACTED_SECRET]"
                    if SECRET_KEY_PATTERN.search(key)
                    else self.redact_secret_value(item)
                )
                for key, item in value.items()
            }
        if isinstance(value, list):
            return [self.redact_secret_value(item) for item in value]
        if isinstance(value, str):
            for pattern, replacement in SECRET_STRING_REDACTIONS:
                value = pattern.sub(replacement, value)
        return value

    def redact_privacy_value(self, value: Any) -> Any:
        if isinstance(value, dict):
            return {
                key: (
                    "[REDACTED_PERSONAL_DATA]"
                    if PII_KEY_PATTERN.search(key)
                    else self.redact_privacy_value(item)
                )
                for key, item in value.items()
            }
        if isinstance(value, list):
            return [self.redact_privacy_value(item) for item in value]
        if isinstance(value, str):
            for pattern, replacement in PRIVACY_STRING_REDACTIONS:
                value = pattern.sub(replacement, value)
        return value

    def redact_value(self, value: Any) -> Any:
        return self.redact_privacy_value(self.redact_secret_value(value))

    def contains_sensitive_string(self, value: Any) -> bool:
        if isinstance(value, dict):
            return any(self.contains_sensitive_string(item) for item in value.values())
        if isinstance(value, list):
            return any(self.contains_sensitive_string(item) for item in value)
        if isinstance(value, str):
            return any(pattern.search(value) for pattern, _ in STRING_REDACTIONS)
        return False

    def redact_transcript(self, source: Path, destination: Path) -> bool:
        try:
            with (
                source.open(encoding="utf-8") as input_handle,
                destination.open("w", encoding="utf-8") as output_handle,
            ):
                for line in input_handle:
                    value = json.loads(line)
                    redacted = self.redact_value(value)
                    if self.contains_sensitive_string(redacted):
                        return False
                    output_handle.write(
                        json.dumps(
                            redacted,
                            ensure_ascii=False,
                            separators=(",", ":"),
                        )
                        + "\n"
                    )
            destination.chmod(0o600)
            return True
        except (OSError, json.JSONDecodeError, UnicodeError):
            destination.unlink(missing_ok=True)
            return False

    def build_manifest(
        self,
        *,
        provider: str,
        session_id: str,
        cwd: str,
        hook_event_name: str,
        transcript_path: Path,
        source: str,
        run_id: str,
        parent_run_id: str | None,
        relationship_status: str,
        model: str,
        agent_role: str,
        started_at: str,
        termination_status: str,
        end_reason: str = "",
        turn_id: str = "",
        stop_hook_active: bool = False,
        last_assistant_message: str = "",
    ) -> dict[str, Any]:
        mtime_ns = self.mtime_ns(transcript_path)
        fingerprint = self.fingerprint(transcript_path)
        empty_transcript = transcript_path.stat().st_size == 0
        manifest: dict[str, Any] = {
            "schema_version": SCHEMA_VERSION,
            "run_id": run_id,
            "provider": provider,
            "provider_session_id": session_id,
            "parent_run_id": parent_run_id,
            "relationship_status": relationship_status,
            "model": model or None,
            "agent_role": agent_role,
            "repository": cwd or None,
            "scope": self.scope,
            "knowledge_commit": None,
            "started_at": started_at or None,
            "ended_at": self.file_timestamp(mtime_ns),
            "termination_status": termination_status,
            "transcript_fingerprint": fingerprint,
            "redaction_status": "pending",
            "redaction_policy_version": REDACTION_POLICY_VERSION,
            "privacy_check_status": "pending",
            "privacy_policy_version": PRIVACY_POLICY_VERSION,
            "redacted_transcript_fingerprint": None,
            "eligible_for_derivation": False,
            "summary_status": "excluded" if empty_transcript else "not_started",
            "derivation_exclusion_reason": (
                "empty_transcript" if empty_transcript else None
            ),
            "capture_receipt": {
                "status": "pending",
                "stored_at": None,
                "target_dir": None,
            },
            "agent": provider,
            "session_id": session_id,
            "hostname": self.current_host,
            "cwd": cwd,
            "hook_event_name": hook_event_name,
            "transcript_path": str(transcript_path),
            "source": source,
            "snapshot_mtime_ns": str(mtime_ns),
            "snapshot_fingerprint": fingerprint,
        }
        if provider == "claude":
            manifest["end_reason"] = end_reason
        else:
            manifest.update(
                {
                    "turn_id": turn_id or None,
                    "stop_hook_active": stop_hook_active,
                    "last_assistant_message": last_assistant_message or None,
                }
            )
        return manifest

    def build_claude_manifest(self, payload: dict[str, Any]) -> dict[str, Any]:
        session_id = payload.get("session_id")
        transcript_raw = payload.get("transcript_path")
        if not isinstance(session_id, str) or not isinstance(transcript_raw, str):
            raise TypeError("Claude payload missing session_id or transcript_path")
        transcript = Path(transcript_raw)
        if not transcript.is_file():
            raise ValueError(f"Claude transcript missing: {transcript}")
        if "subagents" in transcript.parts:
            parent_id = self.first_jsonl_value(
                transcript, lambda item: item.get("sessionId")
            )
            return self.build_claude_subagent_manifest(transcript, parent_id)

        model = self.first_jsonl_value(
            transcript,
            lambda item: (
                self.nested(item, "message", "model")
                if item.get("type") == "assistant"
                else None
            ),
        )
        started_at = self.first_jsonl_value(
            transcript, lambda item: item.get("timestamp")
        )
        raw_end_reason = payload.get("reason")
        end_reason: str = raw_end_reason if isinstance(raw_end_reason, str) else ""
        raw_cwd = payload.get("cwd")
        cwd: str = raw_cwd if isinstance(raw_cwd, str) else ""
        return self.build_manifest(
            provider="claude",
            session_id=session_id,
            cwd=cwd,
            hook_event_name=str(payload.get("hook_event_name") or "SessionEnd"),
            transcript_path=transcript,
            source="session-end",
            run_id=self.allocate_run_id("claude", session_id),
            parent_run_id=None,
            relationship_status="direct",
            model=model,
            agent_role="direct",
            started_at=started_at,
            termination_status=end_reason or "captured",
            end_reason=end_reason,
        )

    def find_codex_rollout(self, session_id: str) -> Path | None:
        if not self.codex_sessions_dir.is_dir():
            return None
        candidates = list(
            self.codex_sessions_dir.rglob(f"rollout-*-{session_id}.jsonl")
        )
        if not candidates:
            return None
        return max(candidates, key=lambda path: path.stat().st_mtime_ns)

    def build_codex_manifest(self, payload: dict[str, Any]) -> dict[str, Any]:
        session_id = payload.get("session_id")
        if not isinstance(session_id, str) or not session_id:
            raise ValueError("Codex payload missing session_id")
        transcript_raw = payload.get("transcript_path")
        transcript = Path(transcript_raw) if isinstance(transcript_raw, str) else None
        if transcript is None or not transcript.is_file():
            transcript = self.find_codex_rollout(session_id)
        if transcript is None or not transcript.is_file():
            raise ValueError(f"Codex transcript missing for session {session_id}")

        first = self.first_jsonl_object(transcript)
        transcript_session_id = self.nested(first, "payload", "id")
        if isinstance(transcript_session_id, str) and transcript_session_id:
            session_id = transcript_session_id
        source = self.nested(first, "payload", "source")
        parent_id = self.nested(
            first, "payload", "source", "subagent", "thread_spawn", "parent_thread_id"
        ) or self.nested(first, "payload", "parent_thread_id")
        is_subagent = (
            isinstance(source, dict) and source.get("subagent") is not None
        ) or self.nested(first, "payload", "parent_thread_id") is not None
        parent_run_id = None
        relationship = "direct"
        role = "direct"
        if is_subagent:
            role = "subagent"
            relationship = "unknown"
            if isinstance(parent_id, str) and parent_id:
                parent_run_id = self.allocate_run_id("codex", parent_id)
                relationship = "identified"

        model = self.first_jsonl_value(
            transcript,
            lambda item: (
                self.nested(item, "payload", "model")
                if item.get("type") == "turn_context"
                else None
            ),
        )
        started_at = self.nested(first, "payload", "timestamp")
        raw_cwd = payload.get("cwd")
        cwd: str = raw_cwd if isinstance(raw_cwd, str) else ""
        return self.build_manifest(
            provider="codex",
            session_id=session_id,
            cwd=cwd,
            hook_event_name=str(payload.get("hook_event_name") or "Stop"),
            transcript_path=transcript,
            source="stop",
            run_id=self.allocate_run_id("codex", session_id),
            parent_run_id=parent_run_id,
            relationship_status=relationship,
            model=model,
            agent_role=role,
            started_at=started_at if isinstance(started_at, str) else "",
            termination_status="snapshot",
            turn_id=str(payload.get("turn_id") or ""),
            stop_hook_active=payload.get("stop_hook_active") is True,
            last_assistant_message=str(payload.get("last_assistant_message") or ""),
        )

    def build_claude_subagent_manifest(
        self, transcript: Path, parent_session_id: str
    ) -> dict[str, Any]:
        agent_id = self.first_jsonl_value(transcript, lambda item: item.get("agentId"))
        if not agent_id and transcript.stem.startswith("agent-"):
            agent_id = transcript.stem.removeprefix("agent-")
        if not agent_id:
            raise ValueError(
                f"Claude subagent transcript missing agent id: {transcript}"
            )
        parent_run_id = None
        relationship = "unknown"
        if parent_session_id:
            parent_run_id = self.allocate_run_id("claude", parent_session_id)
            relationship = "identified"
        model = self.first_jsonl_value(
            transcript,
            lambda item: (
                self.nested(item, "message", "model")
                if item.get("type") == "assistant"
                else None
            ),
        )
        cwd = self.first_jsonl_value(transcript, lambda item: item.get("cwd"))
        started_at = self.first_jsonl_value(
            transcript, lambda item: item.get("timestamp")
        )
        identity = f"{parent_session_id or 'unknown'}:{agent_id}"
        return self.build_manifest(
            provider="claude",
            session_id=agent_id,
            cwd=cwd,
            hook_event_name="SubagentSweep",
            transcript_path=transcript,
            source="claude-subagent",
            run_id=self.allocate_run_id("claude", identity),
            parent_run_id=parent_run_id,
            relationship_status=relationship,
            model=model,
            agent_role="subagent",
            started_at=started_at,
            termination_status="captured",
        )

    @staticmethod
    def validate_manifest(manifest: dict[str, Any]) -> bool:
        run_id = manifest.get("run_id")
        parent_run_id = manifest.get("parent_run_id")
        relationship = manifest.get("relationship_status")
        receipt = manifest.get("capture_receipt")
        redaction_status = manifest.get("redaction_status")
        privacy_check_status = manifest.get("privacy_check_status")
        summary_status = manifest.get("summary_status")
        exclusion_reason = manifest.get("derivation_exclusion_reason")
        return all(
            (
                manifest.get("schema_version") == SCHEMA_VERSION,
                isinstance(run_id, str) and RUN_ID_PATTERN.fullmatch(run_id),
                manifest.get("provider") in {"claude", "codex"},
                isinstance(manifest.get("provider_session_id"), str)
                and bool(manifest["provider_session_id"]),
                (
                    relationship == "identified"
                    and isinstance(parent_run_id, str)
                    and RUN_ID_PATTERN.fullmatch(parent_run_id)
                )
                or (relationship in {"direct", "unknown"} and parent_run_id is None),
                manifest.get("agent_role") in {"direct", "subagent"},
                manifest.get("scope") in {"personal", "organization"},
                "model" in manifest
                and (manifest["model"] is None or isinstance(manifest["model"], str)),
                "repository" in manifest
                and (
                    manifest["repository"] is None
                    or isinstance(manifest["repository"], str)
                ),
                "knowledge_commit" in manifest
                and (
                    manifest["knowledge_commit"] is None
                    or isinstance(manifest["knowledge_commit"], str)
                ),
                "started_at" in manifest
                and (
                    manifest["started_at"] is None
                    or isinstance(manifest["started_at"], str)
                ),
                isinstance(manifest.get("ended_at"), str)
                and bool(manifest["ended_at"]),
                isinstance(manifest.get("termination_status"), str)
                and bool(manifest["termination_status"]),
                isinstance(manifest.get("transcript_fingerprint"), str)
                and FINGERPRINT_PATTERN.fullmatch(manifest["transcript_fingerprint"]),
                redaction_status in {"succeeded", "failed"},
                manifest.get("redaction_policy_version") == REDACTION_POLICY_VERSION,
                privacy_check_status in {"succeeded", "failed"},
                manifest.get("privacy_policy_version") == PRIVACY_POLICY_VERSION,
                privacy_check_status == redaction_status,
                isinstance(manifest.get("redacted_transcript_fingerprint"), str)
                and FINGERPRINT_PATTERN.fullmatch(
                    manifest["redacted_transcript_fingerprint"]
                ),
                manifest.get("eligible_for_derivation")
                == (
                    redaction_status == "succeeded"
                    and summary_status == "not_started"
                ),
                summary_status in {"not_started", "excluded"},
                (
                    summary_status == "excluded"
                    and exclusion_reason == "empty_transcript"
                )
                or (summary_status == "not_started" and exclusion_reason is None),
                isinstance(receipt, dict)
                and receipt.get("status") == "pending"
                and receipt.get("stored_at") is None
                and receipt.get("target_dir") is None,
            )
        )

    def state_is_stale(
        self,
        scope: str,
        provider: str,
        session_id: str,
        mtime_ns: int,
        fingerprint: str,
    ) -> bool:
        state = self.read_json(self.session_state_file(scope, provider, session_id))
        if not state:
            return False
        if (
            state.get("redaction_status") != "succeeded"
            or state.get("redaction_policy_version") != REDACTION_POLICY_VERSION
            or state.get("privacy_check_status") != "succeeded"
            or state.get("privacy_policy_version") != PRIVACY_POLICY_VERSION
        ):
            return False
        if state.get("snapshot_fingerprint") == fingerprint:
            return True
        try:
            return mtime_ns < int(state.get("snapshot_mtime_ns", 0))
        except (TypeError, ValueError):
            return False

    def queue_item(self, manifest: dict[str, Any]) -> Path:
        return self.queue_dir / (
            f"{manifest['scope']}-{manifest['provider']}-{manifest['run_id']}-"
            f"{manifest['transcript_fingerprint']}"
        )

    def queue_lock(self, item: Path) -> Path:
        match = QUEUE_ITEM_PATTERN.fullmatch(item.name)
        if match:
            scope, provider, run_id, fingerprint = match.groups()
            return self.lock_dir / (
                f"queue-{scope}-{provider}-{run_id}-{fingerprint}.lock"
            )
        key = hashlib.sha256(item.name.encode()).hexdigest()
        return self.lock_dir / f"queue-legacy-{key}.lock"

    def quarantine(self, item: Path) -> None:
        suffix = f"{int(time.time())}.{os.getpid()}"
        target = self.quarantine_dir / f"{item.name}.{suffix}"
        sequence = 0
        while target.exists():
            sequence += 1
            target = self.quarantine_dir / f"{item.name}.{suffix}.{sequence}"
        os.replace(item, target)

    def queue_snapshot(self, manifest: dict[str, Any], transcript: Path) -> Path:
        item = self.queue_item(manifest)
        manifest_path = item / "manifest.json"
        transcript_path = item / "transcript.jsonl"
        expected_redacted = manifest["redacted_transcript_fingerprint"]
        with self.lock(self.queue_lock(item)):
            existing = self.read_json(manifest_path)
            if (
                existing
                and transcript_path.is_file()
                and self.validate_manifest(existing)
                and self.fingerprint(transcript_path) == expected_redacted
                and all(
                    existing.get(key) == manifest.get(key)
                    for key in (
                        "scope",
                        "provider",
                        "run_id",
                        "transcript_fingerprint",
                        "redaction_status",
                        "redaction_policy_version",
                        "privacy_check_status",
                        "privacy_policy_version",
                        "redacted_transcript_fingerprint",
                    )
                )
            ):
                return item
            if item.exists():
                self.warn(
                    f"quarantining incomplete queue entry for "
                    f"{manifest['provider']}/{manifest['provider_session_id']}"
                )
                self.quarantine(item)

            stage = Path(tempfile.mkdtemp(dir=self.tmp_dir, prefix="queue-stage-"))
            stage.chmod(0o700)
            try:
                self.write_json(stage / "manifest.json", manifest)
                shutil.copyfile(transcript, stage / "transcript.jsonl")
                (stage / "transcript.jsonl").chmod(0o600)
                if (
                    not self.validate_manifest(manifest)
                    or self.fingerprint(stage / "transcript.jsonl") != expected_redacted
                ):
                    raise ValueError(
                        f"failed to validate queue entry for "
                        f"{manifest['provider']}/{manifest['provider_session_id']}"
                    )
                os.replace(stage, item)
            finally:
                shutil.rmtree(stage, ignore_errors=True)
        return item

    def write_session_state(
        self,
        manifest: dict[str, Any],
        uploaded_at: str,
        target_dir: Path,
    ) -> None:
        self.atomic_json(
            self.session_state_file(
                manifest["scope"],
                manifest["provider"],
                manifest["provider_session_id"],
            ),
            {
                "session_id": manifest["provider_session_id"],
                "run_id": manifest["run_id"],
                "provider": manifest["provider"],
                "scope": manifest["scope"],
                "snapshot_mtime_ns": manifest["snapshot_mtime_ns"],
                "snapshot_fingerprint": manifest["snapshot_fingerprint"],
                "transcript_fingerprint": manifest["transcript_fingerprint"],
                "redaction_status": manifest["redaction_status"],
                "redaction_policy_version": REDACTION_POLICY_VERSION,
                "privacy_check_status": manifest["privacy_check_status"],
                "privacy_policy_version": PRIVACY_POLICY_VERSION,
                "uploaded_at": uploaded_at,
                "target_dir": str(target_dir),
                "capture_receipt": {
                    "status": "stored",
                    "stored_at": uploaded_at,
                    "target_dir": str(target_dir),
                },
            },
        )

    def render_remote_manifest(
        self, manifest: dict[str, Any], uploaded_at: str, target_dir: Path
    ) -> dict[str, Any]:
        remote = dict(manifest)
        remote.pop("transcript_path", None)
        if "last_assistant_message" in remote:
            remote["last_assistant_message"] = None
        remote["uploaded_at"] = uploaded_at
        remote["capture_receipt"] = {
            "status": "stored",
            "stored_at": uploaded_at,
            "target_dir": str(target_dir),
        }
        return remote

    def append_manifest_ledger(self, manifest: dict[str, Any]) -> None:
        seconds = int(manifest["snapshot_mtime_ns"]) / 1_000_000_000
        date = dt.datetime.fromtimestamp(seconds, dt.UTC)
        ledger = (
            self.manifest_dir
            / manifest["scope"]
            / manifest["provider"]
            / date.strftime("%Y/%m")
            / f"{date:%d}.jsonl"
        )
        ledger.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        key = (
            manifest["scope"],
            manifest["provider"],
            manifest["run_id"],
            manifest["transcript_fingerprint"],
            manifest["redaction_policy_version"],
            manifest["privacy_policy_version"],
        )
        lock_name = (
            f"manifest-{manifest['scope']}-{manifest['provider']}-{date:%Y%m%d}.lock"
        )
        with self.lock(self.lock_dir / lock_name):
            if ledger.is_file():
                for entry in self.jsonl_objects(ledger):
                    if (
                        entry.get("scope"),
                        entry.get("provider"),
                        entry.get("run_id"),
                        entry.get("transcript_fingerprint"),
                        entry.get("redaction_policy_version"),
                        entry.get("privacy_policy_version"),
                    ) == key:
                        return
            with ledger.open("a", encoding="utf-8") as handle:
                handle.write(
                    json.dumps(manifest, ensure_ascii=False, separators=(",", ":"))
                    + "\n"
                )
            ledger.chmod(0o600)

    def upload_snapshot(self, manifest: dict[str, Any], transcript: Path) -> bool:
        seconds = int(manifest["snapshot_mtime_ns"]) / 1_000_000_000
        date_path = dt.datetime.fromtimestamp(seconds, dt.UTC).strftime("%Y/%m/%d")
        target_dir = (
            self.remote_base / manifest["scope"] / manifest["provider"] / date_path
        )
        uploaded_at = utc_now()
        stored_manifest = self.render_remote_manifest(
            manifest, uploaded_at, target_dir
        )
        fd, raw_meta = tempfile.mkstemp(dir=self.tmp_dir, prefix="meta-")
        os.close(fd)
        meta_path = Path(raw_meta)
        self.write_json(
            meta_path,
            stored_manifest,
        )
        try:
            if self.current_host == self.local_short_circuit_host:
                self.upload_local(transcript, meta_path, target_dir, manifest)
            else:
                self.upload_remote(transcript, meta_path, target_dir, manifest)
            self.append_manifest_ledger(stored_manifest)
            self.write_session_state(manifest, uploaded_at, target_dir)
            return True
        except (OSError, subprocess.SubprocessError) as error:
            detail = str(error)
            if isinstance(error, subprocess.CalledProcessError):
                output = error.stderr or error.stdout or ""
                for pattern, replacement in STRING_REDACTIONS:
                    output = pattern.sub(replacement, output)
                output = " ".join(output.split())[:2000]
                if output:
                    detail = f"{detail}; output: {output}"
            self.warn(
                f"upload transport failed for {manifest['provider']}/"
                f"{manifest['provider_session_id']}: {detail}"
            )
            return False
        finally:
            meta_path.unlink(missing_ok=True)

    def upload_local(
        self,
        transcript: Path,
        meta_path: Path,
        target_dir: Path,
        manifest: dict[str, Any],
    ) -> None:
        target_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        target_dir.chmod(0o700)
        run_id = manifest["run_id"]
        fingerprint = manifest["transcript_fingerprint"]
        transcript_temp = target_dir / f"{run_id}.{fingerprint}.jsonl.tmp"
        meta_temp = target_dir / f"{run_id}.{fingerprint}.meta.json.tmp"
        shutil.copyfile(transcript, transcript_temp)
        shutil.copyfile(meta_path, meta_temp)
        transcript_temp.chmod(0o600)
        meta_temp.chmod(0o600)
        os.replace(transcript_temp, target_dir / f"{run_id}.jsonl")
        os.replace(meta_temp, target_dir / f"{run_id}.meta.json")

    def upload_remote(
        self,
        transcript: Path,
        meta_path: Path,
        target_dir: Path,
        manifest: dict[str, Any],
    ) -> None:
        remote = f"{self.remote_user}@{self.remote_host}"
        run_id = manifest["run_id"]
        fingerprint = manifest["transcript_fingerprint"]
        transcript_temp = target_dir / f"{run_id}.{fingerprint}.jsonl.tmp"
        meta_temp = target_dir / f"{run_id}.{fingerprint}.meta.json.tmp"
        transcript_target = target_dir / f"{run_id}.jsonl"
        meta_target = target_dir / f"{run_id}.meta.json"
        quoted_dir = shlex.quote(str(target_dir))
        self.run_checked(
            self.ssh,
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=10",
            remote,
            f"umask 077 && mkdir -p {quoted_dir} && chmod 0700 {quoted_dir}",
        )
        self.run_checked(self.rsync, "-az", transcript, f"{remote}:{transcript_temp}")
        self.run_checked(self.rsync, "-az", meta_path, f"{remote}:{meta_temp}")
        command = (
            f"mv {shlex.quote(str(transcript_temp))} "
            f"{shlex.quote(str(transcript_target))} && "
            f"mv {shlex.quote(str(meta_temp))} {shlex.quote(str(meta_target))}"
        )
        self.run_checked(
            self.ssh,
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=10",
            remote,
            command,
        )

    @staticmethod
    def run_checked(*arguments: Any) -> None:
        subprocess.run(
            [str(argument) for argument in arguments],
            check=True,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
        )

    def process_queued_item(self, item: Path) -> bool:
        manifest_path = item / "manifest.json"
        transcript = item / "transcript.jsonl"
        manifest = self.read_json(manifest_path)
        if not manifest:
            return False
        provider = manifest.get("provider") or manifest.get("agent")
        session_id = manifest.get("provider_session_id") or manifest.get("session_id")
        scope = manifest.get("scope")
        try:
            mtime_ns = int(manifest.get("snapshot_mtime_ns", 0))
        except (TypeError, ValueError):
            return False
        fingerprint = manifest.get("snapshot_fingerprint")
        if (
            not isinstance(provider, str)
            or not isinstance(session_id, str)
            or scope not in {"personal", "organization"}
            or not mtime_ns
            or not isinstance(fingerprint, str)
        ):
            return False
        session_lock = self.lock_dir / f"{scope}-{provider}-{session_id}.lock"
        with self.lock(session_lock):
            if self.state_is_stale(
                scope, provider, session_id, mtime_ns, fingerprint
            ):
                shutil.rmtree(item, ignore_errors=True)
                return True
            if self.upload_snapshot(manifest, transcript):
                shutil.rmtree(item, ignore_errors=True)
                return True
        return False

    def process_capture(self, manifest: dict[str, Any]) -> bool:
        transcript = Path(manifest["transcript_path"])
        fd, raw_redacted = tempfile.mkstemp(
            dir=self.tmp_dir, prefix="redacted-transcript-"
        )
        os.close(fd)
        redacted = Path(raw_redacted)
        try:
            if self.redact_transcript(transcript, redacted):
                archive = redacted
                manifest["redaction_status"] = "succeeded"
                manifest["privacy_check_status"] = "succeeded"
                redacted_fingerprint = self.fingerprint(redacted)
            else:
                self.warn(
                    f"redaction failed for {manifest['provider']}/"
                    f"{manifest['provider_session_id']}; archiving original snapshot"
                )
                archive = transcript
                manifest["redaction_status"] = "failed"
                manifest["privacy_check_status"] = "failed"
                redacted_fingerprint = manifest["transcript_fingerprint"]
            manifest["redaction_policy_version"] = REDACTION_POLICY_VERSION
            manifest["privacy_policy_version"] = PRIVACY_POLICY_VERSION
            manifest["redacted_transcript_fingerprint"] = redacted_fingerprint
            manifest["eligible_for_derivation"] = (
                manifest["redaction_status"] == "succeeded"
                and manifest["summary_status"] == "not_started"
            )
            if not self.validate_manifest(manifest):
                self.warn(
                    f"manifest validation failed for {manifest['provider']}/"
                    f"{manifest['provider_session_id']}"
                )
                return False
            item = self.queue_snapshot(manifest, archive)
            self.append_capture_attempt(manifest, "queued")
            if self.process_queued_item(item):
                self.append_capture_attempt(manifest, "stored")
            else:
                self.warn(
                    f"upload failed for {manifest['provider']}/"
                    f"{manifest['provider_session_id']}; snapshot remains queued"
                )
            return True
        except (OSError, TimeoutError, TypeError, ValueError) as error:
            self.warn(
                f"capture failed for {manifest.get('provider')}/"
                f"{manifest.get('provider_session_id')}: {error}"
            )
            return False
        finally:
            redacted.unlink(missing_ok=True)

    def scan_claude_subagents(self, parent: Path, parent_session_id: str) -> None:
        directory = parent.with_suffix("") / "subagents"
        if not directory.is_dir():
            return
        for transcript in sorted(directory.glob("agent-*.jsonl")):
            try:
                self.process_capture(
                    self.build_claude_subagent_manifest(transcript, parent_session_id)
                )
            except (OSError, TimeoutError, TypeError, ValueError) as error:
                self.warn(str(error))

    def process_payload(self, payload_path: Path) -> None:
        try:
            self.append_hook_attempt(payload_path, "received")
        except (OSError, TimeoutError, TypeError, ValueError) as error:
            self.warn(
                f"failed to record received hook attempt for {self.agent}: {error}"
            )
        payload = self.read_json(payload_path)
        if payload is None:
            self.record_failed_hook(payload_path, "payload is not a JSON object")
            return
        try:
            manifest = (
                self.build_claude_manifest(payload)
                if self.agent == "claude"
                else self.build_codex_manifest(payload)
            )
            accepted = self.process_capture(manifest)
        except (OSError, TimeoutError, TypeError, ValueError) as error:
            self.record_failed_hook(payload_path, str(error))
            return
        try:
            self.append_hook_attempt(payload_path, "accepted" if accepted else "failed")
        except (OSError, TimeoutError, TypeError, ValueError) as error:
            self.warn(
                f"failed to record hook result for {self.agent}/"
                f"{manifest['provider_session_id']}: {error}"
            )
        if (
            accepted
            and self.agent == "claude"
            and "subagents" not in Path(manifest["transcript_path"]).parts
        ):
            self.scan_claude_subagents(
                Path(manifest["transcript_path"]), manifest["provider_session_id"]
            )

    def record_failed_hook(self, payload_path: Path, reason: str) -> None:
        self.warn(reason)
        try:
            self.append_hook_attempt(payload_path, "failed")
        except (OSError, TimeoutError, TypeError, ValueError):
            pass

    def migrate_legacy_queue(self, item: Path, manifest: dict[str, Any]) -> None:
        provider = manifest.get("provider") or manifest.get("agent")
        session_id = manifest.get("provider_session_id") or manifest.get("session_id")
        scope = manifest.get("scope", self.scope)
        if provider not in {"claude", "codex"} or not isinstance(session_id, str):
            self.warn(f"legacy queue item cannot be migrated: {item.name}")
            self.quarantine(item)
            return
        payload: dict[str, Any] = {
            "session_id": session_id,
            "transcript_path": str(item / "transcript.jsonl"),
            "cwd": manifest.get("cwd") or "",
            "hook_event_name": "QueueMigration",
            "reason": "captured",
            "stop_hook_active": False,
        }
        try:
            migrated = (
                self.build_claude_manifest(payload)
                if provider == "claude"
                else self.build_codex_manifest(payload)
            )
            if scope in {"personal", "organization"}:
                migrated["scope"] = scope
            if self.process_capture(migrated):
                shutil.rmtree(item, ignore_errors=True)
        except (OSError, TimeoutError, TypeError, ValueError) as error:
            self.warn(f"legacy queue migration failed for {item.name}: {error}")
            self.quarantine(item)

    def replay_queue(self) -> None:
        for item in sorted(self.queue_dir.iterdir()):
            if not item.is_dir():
                continue
            try:
                with self.lock(self.queue_lock(item)):
                    manifest_path = item / "manifest.json"
                    transcript = item / "transcript.jsonl"
                    if not manifest_path.is_file() or not transcript.is_file():
                        self.warn(f"queue item is incomplete: {item}")
                        self.quarantine(item)
                        continue
                    manifest = self.read_json(manifest_path)
                    if not manifest:
                        self.warn(f"queued manifest is invalid JSON: {item.name}")
                        self.quarantine(item)
                        continue
                    if (
                        manifest.get("schema_version") != SCHEMA_VERSION
                        or manifest.get("redaction_policy_version")
                        != REDACTION_POLICY_VERSION
                        or manifest.get("privacy_policy_version")
                        != PRIVACY_POLICY_VERSION
                    ):
                        self.migrate_legacy_queue(item, manifest)
                        continue
                    if not self.validate_manifest(manifest):
                        self.warn(f"queued manifest validation failed: {item.name}")
                        self.quarantine(item)
                        continue
                    if self.fingerprint(transcript) != manifest.get(
                        "redacted_transcript_fingerprint"
                    ):
                        self.warn(
                            f"queued transcript fingerprint mismatch: {item.name}"
                        )
                        self.quarantine(item)
                        continue
                    attempt_manifest = dict(manifest)
                    if self.process_queued_item(item):
                        self.append_capture_attempt(attempt_manifest, "stored")
                    else:
                        self.warn(f"queue replay failed for {item.name}")
            except (OSError, TimeoutError, TypeError, ValueError) as error:
                self.warn(f"queue replay failed for {item.name}: {error}")

    def scan_codex_rollouts(self) -> None:
        if not self.codex_sessions_dir.is_dir():
            return
        for transcript in sorted(self.codex_sessions_dir.rglob("rollout-*.jsonl")):
            if transcript.stat().st_size == 0:
                continue
            first = self.first_jsonl_object(transcript)
            session_id = self.nested(first, "payload", "id")
            if not isinstance(session_id, str) or not session_id:
                continue
            fingerprint = self.fingerprint(transcript)
            mtime_ns = self.mtime_ns(transcript)
            if self.state_is_stale(
                self.scope, "codex", session_id, mtime_ns, fingerprint
            ):
                continue
            cwd = self.nested(first, "payload", "cwd")
            payload = {
                "session_id": session_id,
                "transcript_path": str(transcript),
                "cwd": cwd if isinstance(cwd, str) else "",
                "hook_event_name": "SessionStart",
                "turn_id": "",
                "stop_hook_active": False,
                "last_assistant_message": "",
            }
            try:
                self.process_capture(self.build_codex_manifest(payload))
            except (OSError, TimeoutError, TypeError, ValueError) as error:
                self.warn(f"Codex sweep failed for {session_id}: {error}")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mode", choices=("payload", "session-start-sweep"), default="payload"
    )
    parser.add_argument("--agent", choices=("claude", "codex"), required=True)
    parser.add_argument("--payload-file", type=Path)
    arguments = parser.parse_args()
    if arguments.mode == "payload" and arguments.payload_file is None:
        parser.error("--payload-file is required in payload mode")
    return arguments


def main() -> int:
    os.umask(0o077)
    arguments = parse_arguments()
    payload_file: Path | None = arguments.payload_file
    try:
        try:
            recorder = Recorder(arguments.agent)
        except (OSError, ValueError) as error:
            sys.stderr.write(f"agent-session-upload-worker: {error}\n")
            return 1
        if arguments.mode == "payload" and payload_file is not None:
            recorder.process_payload(payload_file)
        else:
            recorder.scan_codex_rollouts()
        recorder.replay_queue()
        return 0
    finally:
        if payload_file is not None:
            payload_file.unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
