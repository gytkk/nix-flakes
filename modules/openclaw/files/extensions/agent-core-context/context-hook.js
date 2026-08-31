import { readFile } from "node:fs/promises";

const instructionPath = () =>
  process.env.AGENT_CORE_OPENCLAW_INSTRUCTIONS;

export const createAgentCoreContextHandler = (
  _api,
  {
    loadInstructions = (path) => readFile(path, "utf8"),
    getInstructionPath = instructionPath,
  } = {},
) => {
  return async () => {
    const path = getInstructionPath();
    if (!path) {
      throw new Error(
        "agent-core-context: AGENT_CORE_OPENCLAW_INSTRUCTIONS is not set",
      );
    }

    try {
      const instructions = await loadInstructions(path);
      if (instructions.trim().length === 0) {
        throw new Error(`agent-core-context: rendered instructions are empty: ${path}`);
      }
      return { prependSystemContext: instructions };
    } catch (error) {
      if (
        error instanceof Error &&
        error.message.startsWith("agent-core-context:")
      ) {
        throw error;
      }
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`agent-core-context: could not read ${path}: ${message}`);
    }
  };
};

export const registerAgentCoreContextHook = (api) => {
  api.on("before_prompt_build", createAgentCoreContextHandler(api));
};
