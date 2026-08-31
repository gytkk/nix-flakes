import { readFile } from "node:fs/promises";

const instructionPath = () =>
  process.env.AGENT_CORE_OPENCLAW_INSTRUCTIONS;

export const createAgentCoreContextHandler = (
  api,
  {
    loadInstructions = (path) => readFile(path, "utf8"),
    getInstructionPath = instructionPath,
  } = {},
) => {
  let warned = false;

  return async () => {
    const path = getInstructionPath();
    if (!path) {
      if (!warned) {
        api.logger.warn?.(
          "agent-core-context: AGENT_CORE_OPENCLAW_INSTRUCTIONS is not set",
        );
        warned = true;
      }
      return;
    }

    try {
      const instructions = await loadInstructions(path);
      if (instructions.trim().length === 0) {
        return;
      }
      return { prependSystemContext: instructions };
    } catch (error) {
      if (!warned) {
        const message = error instanceof Error ? error.message : String(error);
        api.logger.warn?.(
          `agent-core-context: could not read ${path}: ${message}`,
        );
        warned = true;
      }
    }
  };
};

export const registerAgentCoreContextHook = (api) => {
  api.on("before_prompt_build", createAgentCoreContextHandler(api));
};
