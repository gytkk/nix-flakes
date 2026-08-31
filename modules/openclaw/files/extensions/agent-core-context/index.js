import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

import { registerAgentCoreContextHook } from "./context-hook.js";

export default definePluginEntry({
  id: "agent-core-context",
  name: "Agent Core Context",
  description: "Prepends shared agent-core instructions to each prompt.",
  register: registerAgentCoreContextHook,
});
