import assert from "node:assert/strict";
import test from "node:test";

import { createAgentCoreContextHandler } from "../files/extensions/agent-core-context/context-hook.js";

const logger = () => {
  const warnings = [];
  return {
    api: { logger: { warn: (message) => warnings.push(message) } },
    warnings,
  };
};

test("prepends the rendered instructions as system context", async () => {
  const { api, warnings } = logger();
  const handler = createAgentCoreContextHandler(api, {
    getInstructionPath: () => "/managed/AGENTS.core.md",
    loadInstructions: async () => "portable instructions\n",
  });

  assert.deepEqual(await handler(), {
    prependSystemContext: "portable instructions\n",
  });
  assert.deepEqual(warnings, []);
});

test("warns once when the instruction path is unavailable", async () => {
  const { api, warnings } = logger();
  const handler = createAgentCoreContextHandler(api, {
    getInstructionPath: () => undefined,
  });

  assert.equal(await handler(), undefined);
  assert.equal(await handler(), undefined);
  assert.equal(warnings.length, 1);
});

test("warns once when the rendered instructions cannot be read", async () => {
  const { api, warnings } = logger();
  const handler = createAgentCoreContextHandler(api, {
    getInstructionPath: () => "/missing",
    loadInstructions: async () => {
      throw new Error("missing");
    },
  });

  assert.equal(await handler(), undefined);
  assert.equal(await handler(), undefined);
  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /could not read \/missing: missing/);
});
