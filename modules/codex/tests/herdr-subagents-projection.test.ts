import { describe, expect, test } from "bun:test";
import { consumeChild, discoveredChild, sidebarTokens, type ChildState } from "../files/herdr-subagents/projection";

const child = (id = "child"): ChildState => ({ id, name: id, activity: "starting", active: false });
const event = (type: string, fields = {}) => ({ type: "event_msg", payload: { type, ...fields } });

describe("Codex 0.155.1 rollout projection", () => {
  test("uses the task name and actual child model, and reactivates reused children", () => {
    const state = child();
    consumeChild(state, { type: "session_meta", payload: { agent_path: "/root/check_tests", agent_nickname: "Popper" } });
    consumeChild(state, { type: "turn_context", payload: { model: "gpt-5.6-sol" } });
    consumeChild(state, event("task_started"));
    consumeChild(state, event("item_completed", { item: { type: "AgentMessage", content: [{ type: "text", text: "Checking the tests" }] } }));
    expect(sidebarTokens([state]).subagent_1).toBe("|- check_tests / gpt-5.6-sol");
    expect(sidebarTokens([state]).subagent_1_activity).toBe("|  Checking the tests");
    consumeChild(state, event("task_complete"));
    expect(sidebarTokens([state]).subagent_1).toBeNull();
    consumeChild(state, event("task_started"));
    expect(state.active).toBe(true);
    expect(state.activity).toBe("working");
    consumeChild(state, event("turn_aborted"));
    expect(state.active).toBe(false);
  });

  test("never displays reasoning, encrypted records, prompts, or raw commands", () => {
    const state = child();
    consumeChild(state, event("task_started"));
    for (const value of [
      event("item_completed", { item: { type: "Reasoning", summary_text: ["private reasoning"] } }),
      event("user_message", { message: "private task" }),
      { type: "response_item", payload: { type: "agent_message", encrypted_content: "ciphertext" } },
    ]) consumeChild(state, value);
    expect(state.activity).toBe("working");
    consumeChild(state, event("item_completed", { item: { type: "CommandExecution", command: "secret command", status: "completed" } }));
    expect(state.activity).toBe("command finished");
    consumeChild(state, event("item_completed", { item: { type: "McpToolCall", server: "docs", tool: "search" } }));
    expect(state.activity).toBe("docs.search");
  });

  test("discovers only direct children from parent activity", () => {
    const record = (path: string) => event("item_completed", { item: { type: "SubAgentActivity", kind: "interacted", agent_thread_id: "child", agent_path: path } });
    expect(discoveredChild(record("/root/tests"))).toEqual({ id: "child", name: "tests" });
    expect(discoveredChild(record("/root/tests/nested"))).toBeUndefined();
    expect(discoveredChild(null)).toBeUndefined();
  });

  test("bounds rows and text and clears overflow on shrink", () => {
    const children = Array.from({ length: 9 }, (_, index) => ({ ...child(String(index)), active: true }));
    const overflow = sidebarTokens(children);
    expect(Object.keys(overflow)).toHaveLength(14);
    expect(overflow.subagent_7).toBe("|- +3 more subagents");
    expect(overflow.subagent_7_activity).toBeNull();
    const one = sidebarTokens([{ ...children[0], name: "\u001b[31mhello\nworld", activity: "🙂".repeat(100) }]);
    expect(one.subagent_1).toBe("|- hello world / model pending");
    expect(Array.from(one.subagent_1_activity!)).toHaveLength(80);
    expect(one.subagent_7).toBeNull();
    expect(Object.values(sidebarTokens([])).every((value) => value === null)).toBe(true);
  });
});
