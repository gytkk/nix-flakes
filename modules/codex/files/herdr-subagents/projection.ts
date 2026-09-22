export type ChildState = {
  id: string;
  name: string;
  model?: string;
  activity: string;
  active: boolean;
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
export function consumeChild(state: ChildState, value: unknown): void {
  const record = object(value);
  const payload = object(record?.payload);
  if (!payload) return;
  if (record?.type === "session_meta") {
    const spawn = object(object(object(payload.source)?.subagent)?.thread_spawn);
    const path = displayText(payload.agent_path ?? spawn?.agent_path);
    state.name = (/^\/root\/[^/]+$/.test(path) ? path.slice(6) : displayText(payload.agent_nickname ?? spawn?.agent_nickname)) || state.name;
  } else if (record?.type === "turn_context") {
    state.model = displayText(payload.model) || state.model;
  } else if (record?.type === "event_msg") {
    if (payload.type === "task_started") {
      state.active = true;
      state.activity = "working";
    } else if (["task_complete", "task_failed", "turn_aborted", "shutdown_complete"].includes(payload.type)) {
      state.active = false;
    } else if (payload.type === "agent_message") {
      state.activity = displayText(payload.message) || state.activity;
    } else if (payload.type === "exec_command_begin") {
      state.activity = "running command";
    } else if (payload.type === "patch_apply_begin") {
      state.activity = "editing files";
    } else if (payload.type === "mcp_tool_call_begin") {
      state.activity = "calling tool";
    } else if (payload.type === "item_started" || payload.type === "item_completed") {
      const item = object(payload.item);
      if (!item) return;
      if (item.type === "AgentMessage") state.activity = messageText(item.content) || state.activity;
      if (item.type === "CommandExecution") state.activity = item.status === "completed" ? "command finished" : "running command";
      if (item.type === "FileChange") state.activity = "editing files";
      if (item.type === "McpToolCall") {
        state.activity = [displayText(item.server), displayText(item.tool)].filter(Boolean).join(".") || "calling tool";
      }
    }
  } else if (record?.type === "response_item" && payload.type === "message" && payload.role === "assistant") {
    state.activity = messageText(payload.content) || state.activity;
  }
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

export function sidebarTokens(children: ChildState[]): Record<string, string | null> {
  const active = children.filter((child) => child.active);
  const visible = active.length > 7 ? active.slice(0, 6) : active;
  const tokens: Record<string, string | null> = {};
  const limit = (value: string) => Array.from(value).slice(0, 80).join("");
  for (let index = 0; index < 7; index++) {
    const child = visible[index];
    tokens[`subagent_${index + 1}`] = child ? limit(`|- ${displayText(child.name)} / ${displayText(child.model) || "model pending"}`) : null;
    tokens[`subagent_${index + 1}_activity`] = child ? limit(`|  ${displayText(child.activity)}`) : null;
  }
  if (active.length > 7) tokens.subagent_7 = `|- +${active.length - visible.length} more subagents`;
  return tokens;
}
