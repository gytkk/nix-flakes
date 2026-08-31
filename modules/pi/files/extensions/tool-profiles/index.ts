import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import {
  combinedProfile,
  isToolProfile,
  OPTIONAL_TOOL_NAMES,
  type ToolProfile,
  toolsForProfile,
} from "./policy";

const STATE_TYPE = "tool-profile";

type ToolProfileState = {
  profile: ToolProfile;
  availableOptionalTools: string[];
};

function unique(names: readonly string[]): string[] {
  return [...new Set(names)];
}

function isToolProfileState(value: unknown): value is ToolProfileState {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Partial<ToolProfileState>;
  return (
    typeof candidate.profile === "string" &&
    isToolProfile(candidate.profile) &&
    Array.isArray(candidate.availableOptionalTools) &&
    candidate.availableOptionalTools.every((name) => typeof name === "string")
  );
}

export default function (pi: ExtensionAPI): void {
  let baseTools: string[] = [];
  let availableOptionalTools: string[] = [];
  let activeProfile: ToolProfile = "lite";

  const persistState = (): void => {
    pi.appendEntry(STATE_TYPE, {
      profile: activeProfile,
      availableOptionalTools,
    } satisfies ToolProfileState);
  };

  const findSavedState = (ctx: ExtensionContext): ToolProfileState | undefined => {
    const entry = [...ctx.sessionManager.getBranch()]
      .reverse()
      .find(
        (candidate) =>
          candidate.type === "custom" && candidate.customType === STATE_TYPE,
      );
    return entry?.type === "custom" && isToolProfileState(entry.data)
      ? entry.data
      : undefined;
  };

  const applyExactProfile = (profile: ToolProfile): void => {
    activeProfile = profile;
    pi.setActiveTools(
      toolsForProfile(baseTools, availableOptionalTools, activeProfile),
    );
  };

  const notifyStatus = (ctx: ExtensionContext): void => {
    const activeSet = new Set(pi.getActiveTools());
    const activeOptional = availableOptionalTools.filter((name) =>
      activeSet.has(name),
    );
    ctx.ui.notify(
      `Tool profile: ${activeProfile} (${activeOptional.length}/${availableOptionalTools.length} optional tools active)`,
      "info",
    );
  };

  pi.registerTool({
    name: "enable_tools",
    label: "Enable Optional Tools",
    description:
      "Enable optional research or delegation tools for the current Pi session. Activation is additive so supported models can defer the new tool definitions.",
    promptSnippet: "Enable optional research or delegation capabilities",
    promptGuidelines: [
      "Use enable_tools when a task requires web or MCP research, or subagent delegation, and those tools are not active.",
    ],
    parameters: Type.Object({
      group: StringEnum(["research", "delegation", "full"] as const, {
        description:
          "research enables Web Access and MCP; delegation enables subagents; full enables both groups",
      }),
    }),
    async execute(_toolCallId, params) {
      const nextProfile = combinedProfile(activeProfile, params.group);
      const targetTools = toolsForProfile(
        baseTools,
        availableOptionalTools,
        nextProfile,
      );
      const activeTools = pi.getActiveTools();
      const activeSet = new Set(activeTools);
      const added = targetTools.filter((name) => !activeSet.has(name));

      pi.setActiveTools(unique([...activeTools, ...added]));
      activeProfile = nextProfile;
      persistState();

      return {
        content: [
          {
            type: "text",
            text:
              added.length > 0
                ? `Enabled ${params.group} tools: ${added.join(", ")}`
                : `${params.group} tools are already active.`,
          },
        ],
        details: { profile: activeProfile, added },
      };
    },
  });

  pi.registerCommand("tool-profile", {
    description: "Show or switch the active tool profile",
    handler: async (args, ctx) => {
      const requested = args.trim();
      if (requested === "" || requested === "status") {
        notifyStatus(ctx);
        return;
      }
      if (!isToolProfile(requested)) {
        ctx.ui.notify(
          "Usage: /tool-profile [lite|research|delegation|full|status]",
          "warning",
        );
        return;
      }

      applyExactProfile(requested);
      persistState();
      notifyStatus(ctx);
    },
  });

  pi.on("session_start", (event, ctx) => {
    const allToolNames = new Set(pi.getAllTools().map((tool) => tool.name));
    const initiallyActive = pi.getActiveTools();
    const restored = findSavedState(ctx);

    availableOptionalTools = unique([
      ...(event.reason === "reload"
        ? (restored?.availableOptionalTools ?? [])
        : []),
      ...initiallyActive.filter((name) => OPTIONAL_TOOL_NAMES.has(name)),
    ]).filter((name) => allToolNames.has(name));
    baseTools = initiallyActive.filter((name) => !OPTIONAL_TOOL_NAMES.has(name));

    applyExactProfile(restored?.profile ?? "lite");
    if (!restored) persistState();
  });

  pi.on("session_tree", (_event, ctx) => {
    applyExactProfile(findSavedState(ctx)?.profile ?? "lite");
  });
}
