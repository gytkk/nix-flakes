import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

import { registerSessionRecordHook } from "./session-record-hook.js";

export default definePluginEntry({
  id: "agent-session-record",
  name: "Agent Session Record",
  description: "Archives redacted OpenClaw sessions through agent-session-record.",
  register: registerSessionRecordHook,
});
