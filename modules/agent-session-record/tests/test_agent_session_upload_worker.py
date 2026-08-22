#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///

from __future__ import annotations

import hashlib
import json
import os
import shutil
import socket
import stat
import subprocess
import tempfile
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

SUBJECT = (
    Path(__file__).resolve().parent / ".." / "files" / "agent_session_upload_worker.py"
)
UV = shutil.which("uv") or "uv"


class AgentSessionUploadWorkerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="agent-session-worker-test-")
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.state = self.root / "state"
        self.archive = self.root / "archive"
        self.fixtures = self.root / "fixtures"
        self.fake_ssh_dir = self.root / "fake-ssh-bin"
        self.fake_rsync_dir = self.root / "fake-rsync-bin"
        self.observation = self.root / "transport-observation"
        self.ssh_log = self.root / "ssh.log"
        for path in (
            self.home,
            self.state,
            self.archive,
            self.fixtures,
            self.fake_ssh_dir,
            self.fake_rsync_dir,
        ):
            path.mkdir(parents=True)
        self.write_fake_transports()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write_fake_transports(self) -> None:
        ssh = self.fake_ssh_dir / "ssh"
        ssh.write_text(
            """#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
import os
import sys
from pathlib import Path

log = Path(os.environ["AGENT_SESSION_TEST_SSH_LOG"])
with log.open("a", encoding="utf-8") as handle:
    handle.write(" ".join(sys.argv[1:]) + "\\n")
queue = Path(os.environ["AGENT_SESSION_TEST_STATE_DIR"]) / "queue"
status = "queue-present" if any(queue.iterdir()) else "queue-absent"
with Path(os.environ["AGENT_SESSION_TEST_TRANSPORT_OBSERVATION"]).open(
    "a", encoding="utf-8"
) as handle:
    handle.write(status + "\\n")
raise SystemExit(1)
""",
            encoding="utf-8",
        )
        rsync = self.fake_rsync_dir / "rsync"
        rsync.write_text(
            """#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
raise SystemExit(1)
""",
            encoding="utf-8",
        )
        ssh.chmod(0o755)
        rsync.chmod(0o755)

    def environment(
        self, *, failed_transport: bool = False, scope: str = "personal"
    ) -> dict[str, str]:
        env = dict(os.environ)
        env.update(
            {
                "HOME": str(self.home),
                "AGENT_SESSION_RECORD_REMOTE_BASE_PATH": str(self.archive),
                "AGENT_SESSION_RECORD_LOCAL_SHORT_CIRCUIT_HOST": (
                    "not-this-host"
                    if failed_transport
                    else socket.gethostname().split(".", 1)[0]
                ),
                "AGENT_SESSION_RECORD_STATE_DIR": str(self.state),
                "AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR": str(
                    self.fixtures / "codex-sessions"
                ),
                "AGENT_SESSION_RECORD_SCOPE": scope,
            }
        )
        if failed_transport:
            env.update(
                {
                    "AGENT_SESSION_RECORD_REMOTE_HOST": "unreachable.test",
                    "AGENT_SESSION_RECORD_SSH_BIN": str(self.fake_ssh_dir),
                    "AGENT_SESSION_RECORD_RSYNC_BIN": str(self.fake_rsync_dir),
                    "AGENT_SESSION_TEST_STATE_DIR": str(self.state),
                    "AGENT_SESSION_TEST_TRANSPORT_OBSERVATION": str(self.observation),
                    "AGENT_SESSION_TEST_SSH_LOG": str(self.ssh_log),
                }
            )
        return env

    def worker_command(
        self, agent: str, payload: Path | None = None, *, sweep: bool = False
    ) -> list[str]:
        command = [
            UV,
            "run",
            "--script",
            str(SUBJECT),
            "--mode",
            "session-start-sweep" if sweep else "payload",
            "--agent",
            agent,
        ]
        if payload is not None:
            command.extend(("--payload-file", str(payload)))
        return command

    def run_worker(
        self,
        agent: str,
        payload: Path | None = None,
        *,
        failed_transport: bool = False,
        sweep: bool = False,
        scope: str = "personal",
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            self.worker_command(agent, payload, sweep=sweep),
            env=self.environment(failed_transport=failed_transport, scope=scope),
            check=True,
            capture_output=True,
            text=True,
        )

    @staticmethod
    def write_json(path: Path, value: Any) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value) + "\n", encoding="utf-8")

    @staticmethod
    def write_jsonl(path: Path, *values: Any) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "".join(json.dumps(value) + "\n" for value in values), encoding="utf-8"
        )

    def payload(
        self,
        name: str,
        session_id: str,
        transcript: Path,
        **extra: Any,
    ) -> Path:
        path = self.fixtures / f"{name}-payload.json"
        self.write_json(
            path,
            {
                "session_id": session_id,
                "transcript_path": str(transcript),
                "cwd": extra.pop("cwd", "/workspace/example"),
                **extra,
            },
        )
        return path

    def find_meta(self, session_id: str) -> Path:
        for path in self.archive.rglob("*.meta.json"):
            if (
                json.loads(path.read_text(encoding="utf-8"))["provider_session_id"]
                == session_id
            ):
                return path
        self.fail(f"metadata not found for {session_id}")

    def assert_mode(self, path: Path, expected: int) -> None:
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), expected)

    def test_claude_direct_capture_uses_common_manifest_and_redacts(self) -> None:
        transcript = self.fixtures / "claude-direct.jsonl"
        secret = "sk-test-abcdefghijklmnopqrstuvwxyz123456"
        email = "person@example.test"
        jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature12345678"
        self.write_jsonl(
            transcript,
            {
                "type": "user",
                "sessionId": "claude-direct",
                "cwd": "/workspace/example",
                "timestamp": "2026-08-22T00:00:00Z",
                "message": {
                    "content": f"email {email} token {secret} jwt {jwt}\n"
                    "-----BEGIN PRIVATE KEY-----\nprivate-material\n"
                    "-----END PRIVATE KEY-----",
                    "refresh_token": "refresh-value-that-must-not-leak",
                },
            },
            {
                "type": "assistant",
                "sessionId": "claude-direct",
                "timestamp": "2026-08-22T00:01:00Z",
                "message": {"model": "claude-test", "content": []},
            },
        )
        payload = self.payload(
            "direct",
            "claude-direct",
            transcript,
            hook_event_name="SessionEnd",
            reason="completed",
        )
        self.run_worker("claude", payload)

        meta_path = self.find_meta("claude-direct")
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        self.assertRegex(meta["run_id"], r"^run_[0-9a-f]{32}$")
        self.assertEqual(meta["provider"], "claude")
        self.assertIsNone(meta["parent_run_id"])
        self.assertEqual(meta["relationship_status"], "direct")
        self.assertEqual(meta["model"], "claude-test")
        self.assertEqual(meta["scope"], "personal")
        self.assertEqual(meta["redaction_status"], "succeeded")
        self.assertTrue(meta["eligible_for_derivation"])
        self.assertEqual(meta["capture_receipt"]["status"], "stored")
        archive = meta_path.parent / f"{meta['run_id']}.jsonl"
        content = archive.read_text(encoding="utf-8")
        for sensitive in (secret, email, jwt, "private-material", "refresh-value"):
            self.assertNotIn(sensitive, content)
        self.assertIn("[REDACTED_SECRET]", content)
        self.assertIn("[REDACTED_EMAIL]", content)
        self.assert_mode(archive, 0o600)
        self.assert_mode(meta_path, 0o600)
        hooks = [
            json.loads(line)
            for line in (self.state / "attempts/hooks.jsonl")
            .read_text(encoding="utf-8")
            .splitlines()
        ]
        self.assertEqual(
            {
                item["status"]
                for item in hooks
                if item["provider_session_id"] == "claude-direct"
            },
            {"received", "accepted"},
        )

    def test_codex_hook_adapter_returns_continue_and_starts_worker(self) -> None:
        transcript = self.fixtures / "codex-sessions/rollout-hook.jsonl"
        self.write_jsonl(
            transcript,
            {
                "type": "session_meta",
                "payload": {
                    "id": "codex-hook",
                    "timestamp": "2026-08-22T00:30:00Z",
                    "cwd": "/workspace/hook",
                    "source": {},
                },
            },
        )
        local_bin = self.home / ".local/bin"
        local_bin.mkdir(parents=True)
        (local_bin / "agent-session-upload-worker").symlink_to(SUBJECT)
        installed_hook = local_bin / "codex-stop-upload"
        installed_hook.symlink_to(SUBJECT.parent / "codex_stop_upload.py")
        payload = {
            "session_id": "codex-hook",
            "transcript_path": str(transcript),
            "cwd": "/workspace/hook",
            "hook_event_name": "Stop",
        }
        result = subprocess.run(
            [str(installed_hook)],
            input=json.dumps(payload),
            env=self.environment(),
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertEqual(json.loads(result.stdout), {"continue": True})
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            try:
                self.find_meta("codex-hook")
                break
            except AssertionError:
                time.sleep(0.05)
        else:
            self.fail("Codex hook did not produce an archived session")

    def test_claude_history_replay_captures_direct_and_orphan_sessions(self) -> None:
        projects = self.home / ".claude/projects/project"
        parent = projects / "history-parent.jsonl"
        child = parent.with_suffix("") / "subagents/agent-history-child.jsonl"
        orphan = projects / "history-orphan/subagents/agent-history-orphan.jsonl"
        self.write_jsonl(
            parent,
            {
                "type": "user",
                "sessionId": "history-parent",
                "cwd": "/workspace/history",
                "timestamp": "2026-08-22T00:40:00Z",
            },
        )
        self.write_jsonl(
            child,
            {
                "type": "assistant",
                "sessionId": "history-parent",
                "agentId": "history-child",
                "cwd": "/workspace/history",
                "timestamp": "2026-08-22T00:41:00Z",
                "message": {"model": "claude-test"},
            },
        )
        self.write_jsonl(
            orphan,
            {
                "type": "assistant",
                "agentId": "history-orphan",
                "cwd": "/workspace/history",
                "timestamp": "2026-08-22T00:42:00Z",
                "message": {"model": "claude-test"},
            },
        )
        local_bin = self.home / ".local/bin"
        local_bin.mkdir(parents=True)
        (local_bin / "agent-session-upload-worker").symlink_to(SUBJECT)
        env = self.environment()
        env.update(
            {
                "AGENT_SESSION_RECORD_SSH_BIN": str(self.fake_ssh_dir),
                "AGENT_SESSION_TEST_STATE_DIR": str(self.state),
                "AGENT_SESSION_TEST_TRANSPORT_OBSERVATION": str(self.observation),
                "AGENT_SESSION_TEST_SSH_LOG": str(self.ssh_log),
            }
        )
        history = SUBJECT.parent / "claude_upload_all_history_once.py"
        subprocess.run(
            [UV, "run", "--script", str(history)],
            env=env,
            check=True,
            capture_output=True,
            text=True,
        )
        self.find_meta("history-parent")
        self.find_meta("history-child")
        self.find_meta("history-orphan")
        self.assert_mode(self.state / "sessions", 0o700)
        self.assert_mode(self.state / "tmp", 0o700)

    def test_claude_captures_identified_subagent(self) -> None:
        parent_id = "claude-parent"
        child_id = "child-agent"
        parent = self.fixtures / "claude-project" / f"{parent_id}.jsonl"
        child = parent.with_suffix("") / "subagents" / f"agent-{child_id}.jsonl"
        self.write_jsonl(
            parent,
            {
                "type": "user",
                "sessionId": parent_id,
                "cwd": "/workspace/parent",
                "timestamp": "2026-08-22T01:00:00Z",
            },
        )
        self.write_jsonl(
            child,
            {
                "type": "assistant",
                "sessionId": parent_id,
                "agentId": child_id,
                "cwd": "/workspace/parent",
                "timestamp": "2026-08-22T01:00:30Z",
                "message": {"model": "claude-child-model", "content": []},
            },
        )
        self.run_worker("claude", self.payload("parent", parent_id, parent))
        parent_meta = json.loads(self.find_meta(parent_id).read_text(encoding="utf-8"))
        child_meta = json.loads(self.find_meta(child_id).read_text(encoding="utf-8"))
        self.assertEqual(child_meta["relationship_status"], "identified")
        self.assertEqual(child_meta["parent_run_id"], parent_meta["run_id"])
        self.assertEqual(child_meta["agent_role"], "subagent")

    def test_scope_selects_a_physically_separate_archive(self) -> None:
        transcript = self.fixtures / "organization.jsonl"
        self.write_jsonl(
            transcript,
            {"type": "user", "timestamp": "2026-08-22T01:30:00Z"},
        )
        self.run_worker(
            "claude",
            self.payload("organization", "organization-session", transcript),
            scope="organization",
        )
        meta = self.find_meta("organization-session")
        self.assertEqual(meta.relative_to(self.archive).parts[0], "organization")
        self.assertEqual(
            json.loads(meta.read_text(encoding="utf-8"))["scope"], "organization"
        )

    def test_codex_child_reserves_stable_parent_run_id(self) -> None:
        directory = self.fixtures / "codex-sessions/2026/08/22"
        child = directory / "rollout-child-codex-child.jsonl"
        parent = directory / "rollout-parent-codex-parent.jsonl"
        self.write_jsonl(
            child,
            {
                "type": "session_meta",
                "payload": {
                    "id": "codex-child",
                    "timestamp": "2026-08-22T02:00:00Z",
                    "cwd": "/workspace/codex",
                    "source": {
                        "subagent": {
                            "thread_spawn": {"parent_thread_id": "codex-parent"}
                        }
                    },
                },
            },
            {"type": "turn_context", "payload": {"model": "gpt-test"}},
        )
        self.run_worker(
            "codex", self.payload("child", "codex-child", child, cwd="/workspace/codex")
        )
        child_meta = json.loads(
            self.find_meta("codex-child").read_text(encoding="utf-8")
        )
        self.write_jsonl(
            parent,
            {
                "type": "session_meta",
                "payload": {
                    "id": "codex-parent",
                    "timestamp": "2026-08-22T01:59:00Z",
                    "cwd": "/workspace/codex",
                    "source": {},
                },
            },
        )
        self.run_worker("codex", self.payload("parent", "codex-parent", parent))
        parent_meta = json.loads(
            self.find_meta("codex-parent").read_text(encoding="utf-8")
        )
        self.assertEqual(child_meta["parent_run_id"], parent_meta["run_id"])

    def test_failed_transport_is_queued_then_replayed_with_receipt(self) -> None:
        transcript = self.fixtures / "durable.jsonl"
        self.write_jsonl(
            transcript, {"type": "user", "timestamp": "2026-08-22T03:00:00Z"}
        )
        self.run_worker(
            "claude",
            self.payload("durable", "durable-claude", transcript),
            failed_transport=True,
        )
        self.assertEqual(
            self.observation.read_text(encoding="utf-8").splitlines()[0],
            "queue-present",
        )
        command_log = self.ssh_log.read_text(encoding="utf-8")
        self.assertIn("umask 077 && mkdir -p", command_log)
        self.assertIn("chmod 0700", command_log)
        queue_items = list((self.state / "queue").iterdir())
        self.assertEqual(len(queue_items), 1)
        self.assert_mode(queue_items[0], 0o700)
        self.run_worker("codex", sweep=True)
        self.assertEqual(list((self.state / "queue").iterdir()), [])
        meta = json.loads(self.find_meta("durable-claude").read_text(encoding="utf-8"))
        self.assertEqual(meta["capture_receipt"]["status"], "stored")
        attempts = {
            json.loads(line)["status"]
            for line in (self.state / f"attempts/{meta['run_id']}.jsonl")
            .read_text(encoding="utf-8")
            .splitlines()
        }
        self.assertEqual(attempts, {"queued", "stored"})

    def test_replay_quarantines_modified_queue_transcript(self) -> None:
        transcript = self.fixtures / "modified.jsonl"
        self.write_jsonl(
            transcript, {"type": "user", "timestamp": "2026-08-22T03:30:00Z"}
        )
        self.run_worker(
            "claude",
            self.payload("modified", "modified-queue", transcript),
            failed_transport=True,
        )
        item = next((self.state / "queue").iterdir())
        with (item / "transcript.jsonl").open("a", encoding="utf-8") as handle:
            handle.write('{"type":"user","message":{"content":"modified"}}\n')
        self.run_worker("codex", sweep=True)
        self.assertFalse(item.exists())
        with self.assertRaises(AssertionError):
            self.find_meta("modified-queue")
        self.assertTrue(any((self.state / "quarantine").iterdir()))

    def test_concurrent_duplicate_hooks_publish_one_queue_item(self) -> None:
        transcript = self.fixtures / "concurrent.jsonl"
        self.write_jsonl(
            transcript, {"type": "user", "timestamp": "2026-08-22T03:45:00Z"}
        )
        payloads = [
            self.payload(f"concurrent-{index}", "concurrent-duplicate", transcript)
            for index in range(2)
        ]
        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(
                executor.map(
                    lambda payload: self.run_worker(
                        "claude", payload, failed_transport=True
                    ),
                    payloads,
                )
            )
        self.assertTrue(all(result.returncode == 0 for result in results))
        self.assertEqual(len(list((self.state / "queue").iterdir())), 1)

    def test_unknown_codex_relationship_is_not_inferred(self) -> None:
        transcript = self.fixtures / "codex-sessions/rollout-unknown.jsonl"
        self.write_jsonl(
            transcript,
            {
                "type": "session_meta",
                "payload": {
                    "id": "codex-unknown-child",
                    "timestamp": "2026-08-22T04:00:00Z",
                    "source": {"subagent": {"thread_spawn": {}}},
                },
            },
        )
        self.run_worker(
            "codex", self.payload("unknown-codex", "codex-unknown-child", transcript)
        )
        meta = json.loads(
            self.find_meta("codex-unknown-child").read_text(encoding="utf-8")
        )
        self.assertEqual(meta["relationship_status"], "unknown")
        self.assertIsNone(meta["parent_run_id"])

    def test_unknown_claude_relationship_is_not_inferred(self) -> None:
        transcript = self.fixtures / "orphan/subagents/agent-orphan.jsonl"
        self.write_jsonl(
            transcript,
            {
                "type": "assistant",
                "agentId": "orphan-agent",
                "timestamp": "2026-08-22T04:30:00Z",
                "message": {"model": "claude-test"},
            },
        )
        self.run_worker("claude", self.payload("orphan", "hook-session", transcript))
        meta = json.loads(self.find_meta("orphan-agent").read_text(encoding="utf-8"))
        self.assertEqual(meta["relationship_status"], "unknown")
        self.assertIsNone(meta["parent_run_id"])

    def test_redaction_failure_archives_raw_but_marks_ineligible(self) -> None:
        transcript = self.fixtures / "redaction-failure.jsonl"
        transcript.write_text(
            "not-json sk-test-secret-value-that-is-long\n", encoding="utf-8"
        )
        self.run_worker(
            "claude", self.payload("redaction-failure", "redaction-failure", transcript)
        )
        meta_path = self.find_meta("redaction-failure")
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        self.assertEqual(meta["redaction_status"], "failed")
        self.assertFalse(meta["eligible_for_derivation"])
        archive = meta_path.parent / f"{meta['run_id']}.jsonl"
        self.assertIn("sk-test-secret", archive.read_text(encoding="utf-8"))
        self.assertNotIn(
            "sk-test-secret", (self.state / "warnings.log").read_text(encoding="utf-8")
        )

    def test_codex_session_start_sweep_uses_capture_contract(self) -> None:
        transcript = self.fixtures / "codex-sessions/rollout-sweep.jsonl"
        self.write_jsonl(
            transcript,
            {
                "type": "session_meta",
                "payload": {
                    "id": "codex-sweep",
                    "timestamp": "2026-08-22T05:00:00Z",
                    "cwd": "/workspace/sweep",
                    "source": {},
                },
            },
            {"type": "turn_context", "payload": {"model": "gpt-sweep"}},
        )
        self.run_worker("codex", sweep=True)
        meta = json.loads(self.find_meta("codex-sweep").read_text(encoding="utf-8"))
        self.assertEqual(meta["hook_event_name"], "SessionStart")
        self.assertEqual(meta["model"], "gpt-sweep")
        self.assertEqual(meta["redaction_status"], "succeeded")

    def test_legacy_queue_is_migrated_and_redacted(self) -> None:
        session_id = "legacy-session"
        transcript = self.state / "queue/legacy-item/transcript.jsonl"
        self.write_jsonl(
            transcript,
            {
                "type": "user",
                "sessionId": session_id,
                "cwd": "/workspace/legacy",
                "message": {"content": "legacy@example.test"},
            },
        )
        fingerprint = hashlib.sha256(transcript.read_bytes()).hexdigest()
        self.write_json(
            transcript.parent / "manifest.json",
            {
                "agent": "claude",
                "session_id": session_id,
                "cwd": "/workspace/legacy",
                "snapshot_mtime_ns": str(transcript.stat().st_mtime_ns),
                "snapshot_fingerprint": fingerprint,
            },
        )
        self.run_worker("codex", sweep=True)
        self.assertFalse(transcript.parent.exists())
        meta_path = self.find_meta(session_id)
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        archive = meta_path.parent / f"{meta['run_id']}.jsonl"
        self.assertNotIn("legacy@example.test", archive.read_text(encoding="utf-8"))

    def test_failed_redaction_state_does_not_block_reprocessing(self) -> None:
        session_id = "redaction-reprocess"
        transcript = self.fixtures / f"{session_id}.jsonl"
        self.write_jsonl(
            transcript,
            {
                "type": "user",
                "sessionId": session_id,
                "timestamp": "2026-08-22T07:00:00Z",
                "message": {"content": "retry@example.test"},
            },
        )
        fingerprint = hashlib.sha256(transcript.read_bytes()).hexdigest()
        self.write_json(
            self.state / f"sessions/claude-{session_id}.json",
            {
                "snapshot_mtime_ns": str(transcript.stat().st_mtime_ns),
                "snapshot_fingerprint": fingerprint,
                "redaction_status": "failed",
                "redaction_policy_version": "builtin-v1",
            },
        )
        self.run_worker("claude", self.payload("reprocess", session_id, transcript))
        meta = json.loads(self.find_meta(session_id).read_text(encoding="utf-8"))
        self.assertEqual(meta["redaction_status"], "succeeded")
        self.assertTrue(meta["eligible_for_derivation"])

    def test_invalid_and_incomplete_queue_items_are_quarantined(self) -> None:
        invalid = self.state / "queue/invalid-manifest"
        incomplete = self.state / "queue/incomplete-item"
        self.write_json(invalid / "manifest.json", {"schema_version": 1})
        self.write_json(invalid / "transcript.jsonl", {"type": "user"})
        incomplete.mkdir(parents=True)
        self.run_worker("codex", sweep=True)
        self.assertFalse(invalid.exists())
        self.assertFalse(incomplete.exists())
        self.assertGreaterEqual(len(list((self.state / "quarantine").iterdir())), 2)
        self.assert_mode(self.state / "quarantine", 0o700)


if __name__ == "__main__":
    unittest.main(verbosity=2)
