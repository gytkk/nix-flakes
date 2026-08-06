import {
  FooterComponent,
  SettingsManager,
  type AgentSession,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const STATE_TYPE = "codex-fast-mode";
const DEFAULT_ENABLED = true;

type FastModeState = {
  enabled: boolean;
};

function isFastModeState(value: unknown): value is FastModeState {
  if (!value || typeof value !== "object") return false;
  return typeof (value as { enabled?: unknown }).enabled === "boolean";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function supportsFastMode(ctx: ExtensionContext): boolean {
  return ctx.model?.provider === "openai-codex";
}

export default function (pi: ExtensionAPI) {
  let enabled = DEFAULT_ENABLED;
  let requestRender: (() => void) | undefined;

  const installFooter = (ctx: ExtensionContext): void => {
    if (ctx.mode !== "tui") return;

    ctx.ui.setFooter((tui, _theme, footerData) => {
      requestRender = () => tui.requestRender();

      const session = {
        get state() {
          const model = ctx.model;
          const thinkingLevel = ctx.thinkingLevel ?? "off";
          if (!model || !supportsFastMode(ctx)) return { model, thinkingLevel };

          const fastStatus = `fast(${enabled ? "on" : "off"})`;
          if (!model.reasoning) {
            return {
              model: { ...model, id: `${model.id} • ${fastStatus}` },
              thinkingLevel,
            };
          }
          if (thinkingLevel === "off") {
            return {
              model: {
                ...model,
                id: `${model.id} • thinking off • ${fastStatus}`,
                reasoning: false,
              },
              thinkingLevel,
            };
          }
          return { model, thinkingLevel: `${thinkingLevel} • ${fastStatus}` };
        },
        sessionManager: ctx.sessionManager,
        getContextUsage: () => ctx.getContextUsage(),
        modelRuntime: {
          isUsingOAuth: (provider: string) =>
            ctx.model?.provider === provider && ctx.modelRegistry.isUsingOAuth(ctx.model),
        },
      } as unknown as AgentSession;

      const footer = new FooterComponent(session, footerData);
      const settings = SettingsManager.create(ctx.cwd, undefined, {
        projectTrusted: ctx.isProjectTrusted(),
      });
      footer.setAutoCompactEnabled(settings.getCompactionEnabled());

      return {
        render: (width: number) => footer.render(width),
        invalidate: () => footer.invalidate(),
        dispose: () => {
          requestRender = undefined;
          footer.dispose();
        },
      };
    });
  };

  const setEnabled = (next: boolean, ctx: ExtensionContext): void => {
    enabled = next;
    pi.appendEntry(STATE_TYPE, { enabled } satisfies FastModeState);
    requestRender?.();
  };

  pi.on("session_start", (_event, ctx) => {
    enabled = DEFAULT_ENABLED;
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type !== "custom" || entry.customType !== STATE_TYPE) continue;
      if (isFastModeState(entry.data)) enabled = entry.data.enabled;
    }
    installFooter(ctx);
  });

  pi.on("model_select", () => {
    requestRender?.();
  });

  pi.on("before_provider_request", (event, ctx) => {
    if (!enabled || ctx.model?.provider !== "openai-codex") return;
    if (!isRecord(event.payload)) return;

    return {
      ...event.payload,
      service_tier: "priority",
    };
  });

  pi.registerCommand("fast", {
    description: "Toggle OpenAI Codex fast mode (on, off, or status)",
    handler: async (args, ctx) => {
      const action = args.trim().toLowerCase();

      if (action === "status") {
        ctx.ui.notify(`Codex fast mode is ${enabled ? "on" : "off"}.`, "info");
        return;
      }

      if (action === "" || action === "toggle") {
        setEnabled(!enabled, ctx);
      } else if (action === "on") {
        setEnabled(true, ctx);
      } else if (action === "off") {
        setEnabled(false, ctx);
      } else {
        ctx.ui.notify("Usage: /fast [on|off|status]", "warning");
        return;
      }

      ctx.ui.notify(`Codex fast mode ${enabled ? "enabled" : "disabled"}.`, "info");
    },
  });
}
