export type ChildPhase = "running" | "completed" | "interrupted" | "failed";

export type ChildState = {
  id: string;
  name: string;
  model?: string;
  activity: string;
  phase?: ChildPhase;
  observed: boolean;
  turnId?: string;
  endedAt?: number;
};

const TERMINAL_VISIBLE_MS = 5_000;
const STATUS = {
  running: "●",
  completed: "✓",
  interrupted: "■",
  failed: "×",
  unknown: "○",
};

export function object(value: unknown): Record<string, any> | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, any>
    : undefined;
}

export function displayText(value: unknown): string {
  return typeof value === "string"
    ? value.replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "").replace(/[\x00-\x1f\x7f-\x9f]/g, " ").replace(/\s+/g, " ").trim()
    : "";
}

function messageText(content: unknown): string {
  return Array.isArray(content)
    ? content.map((part) => displayText(object(part)?.text)).filter(Boolean).join(" ")
    : "";
}

// Rollout records are internal Codex data; this parser targets CLI 0.155.1.
export function consumeChild(state: ChildState, value: unknown): boolean {
  const record = object(value);
  const payload = object(record?.payload);
  if (!payload) return false;
  if (record?.type === "session_meta") {
    const spawn = object(object(object(payload.source)?.subagent)?.thread_spawn);
    const path = displayText(payload.agent_path ?? spawn?.agent_path);
    state.name = (/^\/root\/[^/]+$/.test(path) ? path.slice(6) : displayText(payload.agent_nickname ?? spawn?.agent_nickname)) || state.name;
  } else if (record?.type === "turn_context") {
    state.model = displayText(payload.model) || state.model;
  } else if (record?.type === "event_msg") {
    if (payload.type === "task_started") {
      state.phase = "running";
      state.observed = true;
      state.turnId = typeof payload.turn_id === "string" ? payload.turn_id : undefined;
      state.endedAt = undefined;
      state.activity = "작업 중";
      return true;
    } else if (["task_complete", "task_failed", "turn_aborted", "shutdown_complete"].includes(payload.type)) {
      if (state.turnId && typeof payload.turn_id === "string" && state.turnId !== payload.turn_id) return false;
      if (payload.type === "shutdown_complete" && state.phase !== "running") return false;
      state.phase = payload.type === "task_failed" ? "failed" : payload.type === "turn_aborted" ? "interrupted" : "completed";
      state.observed = true;
      const completedAt = typeof payload.completed_at === "number" ? payload.completed_at * 1_000 : NaN;
      const timestamp = typeof record?.timestamp === "string" ? Date.parse(record.timestamp) : NaN;
      // Replaying an old completion must not give it a new display lifetime.
      state.endedAt = Number.isFinite(completedAt) ? completedAt : Number.isFinite(timestamp) ? timestamp : 0;
      return true;
    } else if (payload.type === "agent_message") {
      state.activity = displayText(payload.message) || state.activity;
    } else if (payload.type === "exec_command_begin") {
      state.activity = "명령 실행 중";
    } else if (payload.type === "patch_apply_begin") {
      state.activity = "파일 수정 중";
    } else if (payload.type === "mcp_tool_call_begin") {
      state.activity = "도구 호출 중";
    } else if (payload.type === "item_started" || payload.type === "item_completed") {
      const item = object(payload.item);
      if (!item) return false;
      if (item.type === "AgentMessage") state.activity = messageText(item.content) || state.activity;
      if (item.type === "CommandExecution") state.activity = item.status === "completed" ? "명령 실행 완료" : "명령 실행 중";
      if (item.type === "FileChange") state.activity = "파일 수정 중";
      if (item.type === "McpToolCall") {
        state.activity = [displayText(item.server), displayText(item.tool)].filter(Boolean).join(".") || "도구 호출 중";
      }
    }
  } else if (record?.type === "response_item" && payload.type === "message" && payload.role === "assistant") {
    state.activity = messageText(payload.content) || state.activity;
  }
  return false;
}

export function discoveredChild(value: unknown): { id: string; name: string } | undefined {
  const record = object(value);
  const payload = object(record?.payload);
  const item = object(payload?.item);
  if (record?.type !== "event_msg" || payload?.type !== "item_completed" || item?.type !== "SubAgentActivity") return;
  const id = item.agent_thread_id;
  const path = item.agent_path;
  if (typeof id !== "string" || typeof path !== "string" || !/^\/root\/[^/]+$/.test(path)) return;
  return { id, name: path.slice("/root/".length) };
}

export function sidebarTokens(children: ChildState[], now = Date.now()): Record<string, string | null> {
  const running = children.filter((child) => child.phase === "running");
  const terminal = children.filter((child) => child.phase && child.phase !== "running"
    && child.endedAt !== undefined && now >= child.endedAt && now - child.endedAt < TERMINAL_VISIBLE_MS)
    .sort((left, right) => right.endedAt! - left.endedAt!);
  const candidates = [...running, ...terminal];
  const visible = candidates.length > 7 ? candidates.slice(0, 6) : candidates;
  const knownCount = running.filter((child) => child.observed).length;
  const unknownCount = running.length - knownCount;
  const count = [knownCount ? `${knownCount}개 실행 중` : "", unknownCount ? `${unknownCount}개 상태 확인 불가` : ""].filter(Boolean).join(" / ");
  const tokens: Record<string, string | null> = { subagent_count: count || null };
  const limit = (value: string) => Array.from(value).slice(0, 80).join("");
  for (let index = 0; index < 7; index++) {
    const child = visible[index];
    tokens[`subagent_${index + 1}_status`] = child ? STATUS[child.observed ? child.phase! : "unknown"] : null;
    tokens[`subagent_${index + 1}`] = child ? limit(`${displayText(child.name)} / ${displayText(child.model) || "모델 확인 중"}`) : null;
    tokens[`subagent_${index + 1}_activity`] = child ? limit(`|  ${child.observed ? "" : "마지막 활동: "}${displayText(child.activity)}`) : null;
  }
  if (candidates.length > 7) {
    tokens.subagent_7_status = "…";
    tokens.subagent_7 = `${candidates.length - visible.length}개 더`;
  }
  return tokens;
}
