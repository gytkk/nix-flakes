import assert from "node:assert/strict";
import test from "node:test";

import { createSessionEndHandler } from "../files/extensions/agent-session-record/session-record-hook.js";

test("session_end reads the 2.0 transcript by session identity", async () => {
  const warnings = [];
  const writes = [];
  const invocations = [];
  const transcriptReads = [];
  const transcriptEvents = [
    { type: "session", id: "session-123" },
    { type: "message", message: { role: "user", content: "hello" } },
  ];
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
    readTranscript: async (target) => {
      transcriptReads.push(target);
      return transcriptEvents;
    },
  });

  await handler(
    {
      sessionId: "session-123",
      sessionKey: "agent:main:discord:subagent:raw-channel-id",
      reason: "reset",
      messageCount: 7,
      durationMs: 1234,
      transcriptArchived: true,
    },
    { agentId: "main", senderId: "raw-user-id" },
  );

  assert.equal(warnings.length, 0);
  assert.deepEqual(transcriptReads, [
    {
      agentId: "main",
      sessionId: "session-123",
      sessionKey: "agent:main:discord:subagent:raw-channel-id",
    },
  ]);
  assert.equal(invocations[0][0], "/tmp/fake-recorder");
  assert.deepEqual(invocations[0][1], ["hook", "openclaw", "session-end"]);
  const payload = JSON.parse(writes[0]);
  assert.equal(payload.session_id, "session-123");
  assert.deepEqual(payload.transcript_events, transcriptEvents);
  assert.equal(payload.transcript_path, undefined);
  assert.equal(payload.agent_role, "subagent");
  assert.match(payload.session_key_hash, /^[0-9a-f]{64}$/);
  assert.doesNotMatch(writes[0], /raw-channel-id|raw-user-id/);
});

test("session_end is skipped when the 2.0 transcript read fails", async () => {
  const warnings = [];
  const api = { logger: { warn: (message) => warnings.push(message) } };
  const handler = createSessionEndHandler(api, {
    spawnProcess: () => assert.fail("spawn must not run"),
    readTranscript: async () => {
      throw new Error("missing session");
    },
  });

  await handler(
    { sessionId: "missing", sessionKey: "agent:main:missing", messageCount: 0 },
    { agentId: "main" },
  );

  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /transcript read failed: missing session/);
});
