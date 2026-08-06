import type { Usage } from "@earendil-works/pi-ai";
import {
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { sep } from "node:path";

const STATE_TYPE = "codex-fast-mode";
const DEFAULT_ENABLED = true;

type FastModeState = {
  enabled: boolean;
};

type TokenTotals = {
  input: number;
  output: number;
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

function addUsage(totals: TokenTotals, usage: Usage): void {
  totals.input += usage.input;
  totals.output += usage.output;
}

function getTokenTotals(ctx: ExtensionContext): TokenTotals {
  const totals: TokenTotals = { input: 0, output: 0 };

  for (const entry of ctx.sessionManager.getEntries()) {
    if (entry.type === "message") {
      if (entry.message.role === "assistant") {
        addUsage(totals, entry.message.usage);
      } else if (entry.message.role === "toolResult" && entry.message.usage) {
        addUsage(totals, entry.message.usage);
      }
    } else if (
      (entry.type === "branch_summary" || entry.type === "compaction") &&
      entry.usage
    ) {
      addUsage(totals, entry.usage);
    }
  }

  return totals;
}

function formatTokens(count: number): string {
  if (count < 1_000) return count.toString();
  if (count < 1_000_000) {
    const value =
      count < 10_000 ? (count / 1_000).toFixed(1) : Math.round(count / 1_000);
    return `${value}k`;
  }

  const value =
    count < 10_000_000
      ? (count / 1_000_000).toFixed(1)
      : Math.round(count / 1_000_000);
  return `${value}M`;
}

function formatCwd(cwd: string): string {
  const home = process.env.HOME ?? process.env.USERPROFILE;
  if (!home) return cwd;
  if (cwd === home) return "~";
  if (cwd.startsWith(`${home}${sep}`)) return `~${cwd.slice(home.length)}`;
  return cwd;
}

function sanitizeStatusText(text: string): string {
  return text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
}

export default function (pi: ExtensionAPI) {
  let enabled = DEFAULT_ENABLED;
  let requestRender: (() => void) | undefined;

  const installFooter = (ctx: ExtensionContext): void => {
    if (ctx.mode !== "tui") return;

    ctx.ui.setFooter((tui, theme, footerData) => {
      requestRender = () => tui.requestRender();
      const unsubscribe = footerData.onBranchChange(() => tui.requestRender());

      return {
        render: (width: number): string[] => {
          const separator = ` ${theme.fg("dim", "|")} `;
          const sections: string[] = [];

          sections.push(theme.fg("accent", formatCwd(ctx.sessionManager.getCwd())));

          const branch = footerData.getGitBranch();
          if (branch) sections.push(theme.fg("text", sanitizeStatusText(branch)));

          const modelParts = [sanitizeStatusText(ctx.model?.id ?? "no-model")];
          if (ctx.model?.reasoning) modelParts.push(ctx.thinkingLevel ?? "off");
          if (supportsFastMode(ctx)) modelParts.push(`fast(${enabled ? "on" : "off"})`);
          const modelStatus = theme.fg("text", modelParts.join(" · "));

          const contextUsage = ctx.getContextUsage();
          const percent = contextUsage?.percent;
          if (percent === null || percent === undefined) {
            sections.push(`${theme.fg("dim", "----------")} ?%`);
          } else {
            const boundedPercent = Math.max(0, Math.min(100, percent));
            const filled = Math.floor((boundedPercent * 10) / 100);
            const contextColor =
              boundedPercent >= 90
                ? "error"
                : boundedPercent >= 70
                  ? "warning"
                  : "success";
            const bar =
              theme.fg(contextColor, "#".repeat(filled)) +
              theme.fg("dim", "-".repeat(10 - filled));
            sections.push(`${bar} ${Math.floor(boundedPercent)}%`);
          }

          const totals = getTokenTotals(ctx);
          sections.push(
            `${theme.fg("dim", "tokens")} ${theme.fg("accent", `↓${formatTokens(totals.input)}`)} ${theme.fg("warning", `↑${formatTokens(totals.output)}`)}`,
          );

          for (const status of footerData.getExtensionStatuses().values()) {
            const sanitized = sanitizeStatusText(status);
            if (sanitized) sections.push(sanitized);
          }

          const left = sections.join(separator);
          const modelWidth = visibleWidth(modelStatus);
          const ellipsis = theme.fg("dim", "...");
          if (modelWidth + 2 > width) {
            return [truncateToWidth(modelStatus, width, ellipsis)];
          }

          const availableLeft = width - modelWidth - 2;
          const truncatedLeft = truncateToWidth(left, availableLeft, ellipsis);
          const padding = " ".repeat(width - visibleWidth(truncatedLeft) - modelWidth);
          return [truncatedLeft + padding + modelStatus];
        },
        invalidate: () => {},
        dispose: () => {
          requestRender = undefined;
          unsubscribe();
        },
      };
    });
  };

  const setEnabled = (next: boolean): void => {
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

  pi.on("thinking_level_select", () => {
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
        setEnabled(!enabled);
      } else if (action === "on") {
        setEnabled(true);
      } else if (action === "off") {
        setEnabled(false);
      } else {
        ctx.ui.notify("Usage: /fast [on|off|status]", "warning");
        return;
      }

      ctx.ui.notify(`Codex fast mode ${enabled ? "enabled" : "disabled"}.`, "info");
    },
  });
}
