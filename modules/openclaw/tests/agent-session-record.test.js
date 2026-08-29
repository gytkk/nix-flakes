import assert from "node:assert/strict";
import test from "node:test";

import { createSessionEndHandler } from "../files/extensions/agent-session-record/session-record-hook.js";

test("session_end forwards only capture metadata", () => {
  const warnings = [];
  const writes = [];
  const invocations = [];
  const api = { logger: { warn: (message) => warnings.push(message) } };
  const spawnProcess = (...arguments_) => {
    invocations.push(arguments_);
    return {
      once() {},
      stdin: {
        once() {},
        end(value) {
          writes.push(value);
        },
      },
      unref() {},
    };
  };
  const handler = createSessionEndHandler(api, {
    spawnProcess,
    recorder: () => "/tmp/fake-recorder",
  });

  handler(
    {
      sessionId: "session-123",
      sessionKey: "agent:main:discord:subagent:raw-channel-id",
      sessionFile: "/tmp/session-123.jsonl",
      reason: "reset",
      messageCount: 7,
      durationMs: 1234,
      transcriptArchived: true,
    },
    { agentId: "main", senderId: "raw-user-id" },
  );

  assert.equal(warnings.length, 0);
  assert.equal(invocations[0][0], "/tmp/fake-recorder");
  assert.deepEqual(invocations[0][1], ["hook", "openclaw", "session-end"]);
  const payload = JSON.parse(writes[0]);
  assert.equal(payload.session_id, "session-123");
  assert.equal(payload.transcript_path, "/tmp/session-123.jsonl");
  assert.equal(payload.agent_role, "subagent");
  assert.match(payload.session_key_hash, /^[0-9a-f]{64}$/);
  assert.doesNotMatch(writes[0], /raw-channel-id|raw-user-id/);
});

test("session_end without a transcript path is skipped", () => {
  const warnings = [];
  const api = { logger: { warn: (message) => warnings.push(message) } };
  const handler = createSessionEndHandler(api, {
    spawnProcess: () => assert.fail("spawn must not run"),
  });

  handler({ sessionId: "missing", messageCount: 0 }, {});

  assert.equal(warnings.length, 1);
});
