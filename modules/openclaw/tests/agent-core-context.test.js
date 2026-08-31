import assert from "node:assert/strict";
import test from "node:test";

import {
  createAgentCoreContextHandler,
  registerAgentCoreContextHook,
} from "../files/extensions/agent-core-context/context-hook.js";

const api = { logger: {} };
const count = (value, marker) => value.split(marker).length - 1;

test("prepends the rendered instructions as system context", async () => {
  const handler = createAgentCoreContextHandler(api, {
    getInstructionPath: () => "/managed/AGENTS.core.md",
    loadInstructions: async () => "portable instructions\n",
  });

  assert.deepEqual(await handler(), {
    prependSystemContext: "portable instructions\n",
  });
});

test("fails when the instruction path is unavailable", async () => {
  const handler = createAgentCoreContextHandler(api, {
    getInstructionPath: () => undefined,
  });

  await assert.rejects(handler(), /AGENT_CORE_OPENCLAW_INSTRUCTIONS is not set/);
});

test("fails when the rendered instructions cannot be read", async () => {
  const handler = createAgentCoreContextHandler(api, {
    getInstructionPath: () => "/missing",
    loadInstructions: async () => {
      throw new Error("missing");
    },
  });

  await assert.rejects(handler(), /could not read \/missing: missing/);
});

test("fails when the rendered instructions are empty", async () => {
  const handler = createAgentCoreContextHandler(api, {
    getInstructionPath: () => "/managed/AGENTS.core.md",
    loadInstructions: async () => " \n",
  });

  await assert.rejects(handler(), /rendered instructions are empty/);
});

test("registers exactly one before_prompt_build hook", () => {
  const registrations = [];
  registerAgentCoreContextHook({
    logger: {},
    on: (name, handler) => registrations.push({ name, handler }),
  });

  assert.equal(registrations.length, 1);
  assert.equal(registrations[0].name, "before_prompt_build");
  assert.equal(typeof registrations[0].handler, "function");
});

test("keeps core before each workspace context without duplication", async () => {
  const coreMarker = "agent-core-marker";
  const handler = createAgentCoreContextHandler(api, {
    getInstructionPath: () => "/managed/AGENTS.core.md",
    loadInstructions: async () => coreMarker,
  });
  const workspaces = [
    { agentId: "main", marker: "workspace-main-marker" },
    { agentId: "sol", marker: "workspace-sol-marker" },
  ];

  for (const workspace of workspaces) {
    const result = await handler(
      { messages: [], prompt: "test" },
      { agentId: workspace.agentId, workspaceDir: `/workspace/${workspace.agentId}` },
    );
    const systemPrompt = `${result.prependSystemContext}\n${workspace.marker}`;

    assert.ok(systemPrompt.indexOf(coreMarker) < systemPrompt.indexOf(workspace.marker));
    assert.equal(count(systemPrompt, coreMarker), 1);
    assert.equal(count(systemPrompt, workspace.marker), 1);
    for (const other of workspaces.filter((item) => item !== workspace)) {
      assert.equal(count(systemPrompt, other.marker), 0);
    }
  }
});
