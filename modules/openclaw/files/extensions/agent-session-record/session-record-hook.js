import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { homedir } from "node:os";
import { join } from "node:path";

const defaultRecorder = () =>
  process.env.AGENT_SESSION_RECORD_BIN ??
  join(homedir(), ".local", "bin", "agent-session-record");

const sessionKeyHash = (sessionKey) =>
  typeof sessionKey === "string" && sessionKey.length > 0
    ? createHash("sha256").update(sessionKey).digest("hex")
    : undefined;

const agentRole = (sessionKey) =>
  typeof sessionKey === "string" &&
  (sessionKey.includes(":subagent:") || sessionKey.includes(":acp:"))
    ? "subagent"
    : "direct";

export const createSessionEndHandler = (
  api,
  { spawnProcess = spawn, recorder = defaultRecorder } = {},
) =>
  (event, context) => {
    if (typeof event.sessionFile !== "string" || event.sessionFile.length === 0) {
      api.logger.warn?.(
        `agent-session-record: session_end omitted sessionFile for ${event.sessionId}`,
      );
      return;
    }

    const sessionKey = event.sessionKey ?? context.sessionKey;
    const child = spawnProcess(
      recorder(),
      ["hook", "openclaw", "session-end"],
      {
        detached: true,
        stdio: ["pipe", "ignore", "ignore"],
      },
    );
    child.once("error", (error) => {
      api.logger.warn?.(
        `agent-session-record: recorder spawn failed: ${error.message}`,
      );
    });
    child.stdin.once("error", (error) => {
      api.logger.warn?.(
        `agent-session-record: recorder input failed: ${error.message}`,
      );
    });
    child.stdin.end(
      `${JSON.stringify({
        session_id: event.sessionId,
        transcript_path: event.sessionFile,
        hook_event_name: "session_end",
        reason: event.reason,
        message_count: event.messageCount,
        duration_ms: event.durationMs,
        transcript_archived: event.transcriptArchived === true,
        agent_id: context.agentId,
        agent_role: agentRole(sessionKey),
        session_key_hash: sessionKeyHash(sessionKey),
      })}\n`,
    );
    child.unref();
  };

export const registerSessionRecordHook = (api) => {
  api.on("session_end", createSessionEndHandler(api));
};
