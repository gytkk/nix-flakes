from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Protocol


@dataclass(frozen=True)
class HookContract:
    mode: str
    returns_continue: bool


@dataclass(frozen=True)
class ReplaySession:
    session_id: str
    transcript: Path
    cwd: str
    reason: str = ""


class ProviderAdapter(Protocol):
    name: str
    hook_events: tuple[str, ...]

    def hook_contract(self, event: str) -> HookContract: ...

    def sessions_dir(self, home: Path, config: dict[str, str]) -> Path: ...

    def discover_replay_sessions(
        self, home: Path, config: dict[str, str]
    ) -> list[ReplaySession]: ...

    def replay_payload(self, session: ReplaySession) -> dict[str, Any]: ...


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


class ClaudeProvider:
    name = "claude"
    hook_events = ("session-end",)

    def hook_contract(self, event: str) -> HookContract:
        if event == "session-end":
            return HookContract(mode="payload", returns_continue=False)
        raise ValueError(f"unsupported Claude hook event: {event}")

    def sessions_dir(self, home: Path, config: dict[str, str]) -> Path:
        return home / ".claude/projects"

    def discover_replay_sessions(
        self, home: Path, config: dict[str, str]
    ) -> list[ReplaySession]:
        projects_dir = self.sessions_dir(home, config)
        transcripts = set(projects_dir.rglob("*.jsonl"))
        direct = {path for path in transcripts if "subagents" not in path.parts}
        orphans: set[Path] = set()
        for path in transcripts:
            if path.parent.name != "subagents" or not path.name.startswith("agent-"):
                continue
            parent_transcript = path.parent.parent.with_suffix(".jsonl")
            if not parent_transcript.is_file():
                orphans.add(path)

        sessions: list[ReplaySession] = []
        for transcript in sorted(direct | orphans):
            objects = jsonl_objects(transcript)
            if transcript.parent.name == "subagents":
                session_id = next(
                    (
                        item["agentId"]
                        for item in objects
                        if isinstance(item.get("agentId"), str) and item["agentId"]
                    ),
                    "",
                )
                if not session_id and transcript.stem.startswith("agent-"):
                    session_id = transcript.stem.removeprefix("agent-")
            else:
                session_id = transcript.stem
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
            sessions.append(
                ReplaySession(
                    session_id=session_id,
                    transcript=transcript,
                    cwd=cwd,
                    reason=str(reason),
                )
            )
        return sessions

    def replay_payload(self, session: ReplaySession) -> dict[str, Any]:
        return {
            "session_id": session.session_id,
            "transcript_path": str(session.transcript),
            "cwd": session.cwd,
            "hook_event_name": "ManualReplay",
            "reason": session.reason,
        }


class CodexProvider:
    name = "codex"
    hook_events = ("session-start", "stop")

    def hook_contract(self, event: str) -> HookContract:
        if event == "stop":
            return HookContract(mode="payload", returns_continue=True)
        if event == "session-start":
            return HookContract(mode="session-start-sweep", returns_continue=True)
        raise ValueError(f"unsupported Codex hook event: {event}")

    def sessions_dir(self, home: Path, config: dict[str, str]) -> Path:
        return Path(
            config.get(
                "AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR", home / ".codex/sessions"
            )
        )

    def discover_replay_sessions(
        self, home: Path, config: dict[str, str]
    ) -> list[ReplaySession]:
        sessions: list[ReplaySession] = []
        for transcript in sorted(
            self.sessions_dir(home, config).rglob("rollout-*.jsonl")
        ):
            first = first_record(transcript)
            session_id = nested(first, "payload", "id")
            cwd = nested(first, "payload", "cwd")
            sessions.append(
                ReplaySession(
                    session_id=session_id if isinstance(session_id, str) else "",
                    transcript=transcript,
                    cwd=cwd if isinstance(cwd, str) else "",
                )
            )
        return sessions

    def replay_payload(self, session: ReplaySession) -> dict[str, Any]:
        return {
            "session_id": session.session_id,
            "transcript_path": str(session.transcript),
            "cwd": session.cwd,
            "hook_event_name": "ManualReplay",
            "turn_id": "",
            "stop_hook_active": False,
            "last_assistant_message": "",
        }


PROVIDERS: dict[str, ProviderAdapter] = {
    "claude": ClaudeProvider(),
    "codex": CodexProvider(),
}


def get_provider(name: str) -> ProviderAdapter:
    try:
        return PROVIDERS[name]
    except KeyError as error:
        raise ValueError(f"unsupported provider: {name}") from error
