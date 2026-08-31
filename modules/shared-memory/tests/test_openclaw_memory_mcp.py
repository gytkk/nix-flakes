#!/usr/bin/env python3

import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SERVER = REPO_ROOT / "modules/shared-memory/files/openclaw_memory_mcp.py"


class OpenClawMemoryMcpTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.workspace = self.root / "ws"
        (self.workspace / "memory").mkdir(parents=True)
        (self.workspace / "USER.md").write_text("user line\n", encoding="utf-8")
        (self.workspace / "MEMORY.md").write_text(
            "first line\nsecond line\nthird line\n", encoding="utf-8"
        )
        (self.workspace / "memory/2026-08-31.md").write_text(
            "daily note\n", encoding="utf-8"
        )
        (self.root / "outside.md").write_text("private\n", encoding="utf-8")
        self.argv_log = self.root / "argv.json"
        self.fake_openclaw = self.root / "fake-openclaw"
        self.fake_openclaw.write_text(
            textwrap.dedent(
                f"""\
                #!{sys.executable}
                import json
                import os
                import sys
                import time
                from pathlib import Path

                Path(os.environ["FAKE_OPENCLAW_LOG"]).write_text(
                    json.dumps(sys.argv[1:]), encoding="utf-8"
                )
                query = sys.argv[sys.argv.index("--query") + 1]
                if query == "fail":
                    print("credential=do-not-leak", file=sys.stderr)
                    raise SystemExit(7)
                if query == "slow":
                    time.sleep(1)
                workspace = Path(os.environ["OPENCLAW_MEMORY_WORKSPACE"])
                print(json.dumps({{
                    "results": [
                        {{"path": "MEMORY.md", "startLine": 1, "endLine": 2, "score": 0.9, "snippet": "allowed", "source": "memory"}},
                        {{"path": str(workspace / "memory/2026-08-31.md"), "startLine": 1, "endLine": 1, "score": 0.8, "snippet": "allowed daily", "source": "memory"}},
                        {{"path": "MEMORY.md", "startLine": 1, "endLine": 1, "score": 1.0, "snippet": "blocked session", "source": "sessions"}},
                        {{"path": "../outside.md", "startLine": 1, "endLine": 1, "score": 1.0, "snippet": "blocked", "source": "memory"}},
                        {{"path": "/tmp/unrelated.md", "startLine": 1, "endLine": 1, "score": 1.0, "snippet": "blocked absolute", "source": "memory"}}
                    ]
                }}))
                """
            ),
            encoding="utf-8",
        )
        self.fake_openclaw.chmod(0o700)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def run_server(
        self, messages: list[dict[str, object]], *, timeout_seconds: str = "2"
    ) -> tuple[list[dict[str, object]], str]:
        env = os.environ.copy()
        env.update(
            {
                "FAKE_OPENCLAW_LOG": str(self.argv_log),
                "OPENCLAW_MEMORY_AGENT": "main",
                "OPENCLAW_MEMORY_COMMAND": str(self.fake_openclaw),
                "OPENCLAW_MEMORY_TIMEOUT_SECONDS": timeout_seconds,
                "OPENCLAW_MEMORY_WORKSPACE": str(self.workspace),
            }
        )
        process = subprocess.run(
            [sys.executable, str(SERVER)],
            input="".join(json.dumps(message) + "\n" for message in messages),
            text=True,
            capture_output=True,
            env=env,
            timeout=5,
            check=False,
        )
        self.assertEqual(process.returncode, 0, process.stderr)
        responses = [json.loads(line) for line in process.stdout.splitlines()]
        return responses, process.stderr

    @staticmethod
    def initialize(request_id: int = 1) -> dict[str, object]:
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": "initialize",
            "params": {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "test", "version": "1"},
            },
        }

    @staticmethod
    def tool_call(
        request_id: int, name: str, arguments: dict[str, object]
    ) -> dict[str, object]:
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": "tools/call",
            "params": {"name": name, "arguments": arguments},
        }

    def test_initialize_and_list_read_only_tools(self) -> None:
        responses, stderr = self.run_server(
            [
                self.initialize(),
                {
                    "jsonrpc": "2.0",
                    "method": "notifications/initialized",
                    "params": {},
                },
                {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
            ]
        )

        self.assertEqual(stderr, "")
        self.assertEqual(len(responses), 2)
        initialized = responses[0]["result"]
        self.assertEqual(initialized["protocolVersion"], "2025-06-18")
        self.assertIn("explicit", initialized["instructions"].lower())
        tools = responses[1]["result"]["tools"]
        self.assertEqual(
            [tool["name"] for tool in tools], ["memory_search", "memory_get"]
        )
        for tool in tools:
            self.assertEqual(
                tool["annotations"],
                {
                    "readOnlyHint": True,
                    "destructiveHint": False,
                    "idempotentHint": True,
                    "openWorldHint": False,
                },
            )

    def test_search_uses_openclaw_and_filters_noncanonical_paths(self) -> None:
        responses, _ = self.run_server(
            [
                self.tool_call(
                    1,
                    "memory_search",
                    {"query": "router decision", "maxResults": 4, "minScore": 0.25},
                )
            ]
        )

        result = responses[0]["result"]
        self.assertNotIn("isError", result)
        self.assertEqual(
            [item["path"] for item in result["structuredContent"]["results"]],
            ["MEMORY.md", "memory/2026-08-31.md"],
        )
        self.assertEqual(
            json.loads(self.argv_log.read_text(encoding="utf-8")),
            [
                "memory",
                "search",
                "--agent",
                "main",
                "--query",
                "router decision",
                "--max-results",
                "4",
                "--min-score",
                "0.25",
                "--json",
            ],
        )

    def test_get_reads_only_bounded_canonical_memory(self) -> None:
        responses, _ = self.run_server(
            [
                self.tool_call(
                    1,
                    "memory_get",
                    {"path": "MEMORY.md", "startLine": 2, "lineCount": 2},
                ),
                self.tool_call(
                    2,
                    "memory_get",
                    {"path": "../outside.md", "startLine": 1, "lineCount": 1},
                ),
            ]
        )

        allowed = responses[0]["result"]["structuredContent"]
        self.assertEqual(
            allowed,
            {
                "path": "MEMORY.md",
                "startLine": 2,
                "endLine": 3,
                "text": "second line\nthird line",
            },
        )
        blocked = responses[1]["result"]
        self.assertTrue(blocked["isError"])
        self.assertIn("canonical memory", blocked["content"][0]["text"])
        self.assertNotIn("private", json.dumps(blocked))

    def test_search_failure_and_timeout_do_not_leak_stderr(self) -> None:
        failed, _ = self.run_server(
            [self.tool_call(1, "memory_search", {"query": "fail"})]
        )
        failure = failed[0]["result"]
        self.assertTrue(failure["isError"])
        self.assertIn("exit status 7", failure["content"][0]["text"])
        self.assertNotIn("do-not-leak", json.dumps(failure))

        timed_out, _ = self.run_server(
            [self.tool_call(1, "memory_search", {"query": "slow"})],
            timeout_seconds="0.05",
        )
        timeout = timed_out[0]["result"]
        self.assertTrue(timeout["isError"])
        self.assertIn("timed out", timeout["content"][0]["text"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
