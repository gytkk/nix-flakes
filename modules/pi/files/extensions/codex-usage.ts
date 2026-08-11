import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

export const CODEX_USAGE_STATUS_KEY = "codex-usage";

const PROVIDER_ID = "openai-codex";
const USAGE_URL = "https://chatgpt.com/backend-api/wham/usage";
const FETCH_TIMEOUT_MS = 10_000;
const CACHE_TTL_MS = 60_000;
const WEEK_SECONDS = 7 * 24 * 60 * 60;
const JWT_CLAIM_PATH = "https://api.openai.com/auth";

type UsageWindow = {
  usedPercent: number;
  remainingPercent: number;
  windowSeconds: number;
  resetsAt: number;
};

export type CodexUsageSnapshot = {
  planType?: string;
  windows: UsageWindow[];
  weekly?: UsageWindow;
};

type CachedSnapshot = {
  fetchedAt: number;
  snapshot: CodexUsageSnapshot;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function finiteNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value)
    ? value
    : undefined;
}

function parseWindow(value: unknown): UsageWindow | undefined {
  if (!isRecord(value)) return undefined;

  const usedPercent = finiteNumber(value.used_percent);
  const windowSeconds = finiteNumber(value.limit_window_seconds);
  const resetsAt = finiteNumber(value.reset_at);
  if (
    usedPercent === undefined ||
    windowSeconds === undefined ||
    resetsAt === undefined ||
    windowSeconds <= 0 ||
    resetsAt <= 0
  ) {
    return undefined;
  }

  const boundedUsed = Math.max(0, Math.min(100, usedPercent));
  return {
    usedPercent: boundedUsed,
    remainingPercent: Math.max(0, Math.min(100, 100 - boundedUsed)),
    windowSeconds,
    resetsAt,
  };
}

export function parseCodexUsagePayload(payload: unknown): CodexUsageSnapshot {
  if (!isRecord(payload) || !isRecord(payload.rate_limit)) {
    throw new Error("Codex usage response did not include rate-limit data.");
  }

  const windows = [
    parseWindow(payload.rate_limit.primary_window),
    parseWindow(payload.rate_limit.secondary_window),
  ].filter((window): window is UsageWindow => window !== undefined);

  if (windows.length === 0) {
    throw new Error("Codex usage response did not include rate-limit windows.");
  }

  return {
    planType:
      typeof payload.plan_type === "string" ? payload.plan_type : undefined,
    windows,
    weekly: windows.find(
      (window) => Math.round(window.windowSeconds) === WEEK_SECONDS,
    ),
  };
}

function twoDigits(value: number): string {
  return value.toString().padStart(2, "0");
}

export function formatResetTime(resetsAt: number): string {
  const date = new Date(resetsAt * 1_000);
  if (Number.isNaN(date.getTime())) return "unknown";
  return (
    `${twoDigits(date.getMonth() + 1)}/${twoDigits(date.getDate())} ` +
    `${twoDigits(date.getHours())}:${twoDigits(date.getMinutes())}`
  );
}

function formatRemainingPercent(value: number): string {
  const rounded = Math.round(value * 10) / 10;
  return Number.isInteger(rounded) ? rounded.toFixed(0) : rounded.toFixed(1);
}

function windowLabel(windowSeconds: number): string {
  if (Math.round(windowSeconds) === WEEK_SECONDS) return "Weekly";
  const hours = windowSeconds / (60 * 60);
  if (Number.isInteger(hours)) return `${hours}h`;
  return `${Math.round(windowSeconds / 60)}m`;
}

function formatWindow(window: UsageWindow): string {
  const remaining = formatRemainingPercent(window.remainingPercent);
  return `${windowLabel(window.windowSeconds)}: ${remaining}% left · resets ${formatResetTime(window.resetsAt)}`;
}

export function formatWeeklyStatus(
  snapshot: CodexUsageSnapshot,
): string | undefined {
  const weekly = snapshot.weekly;
  if (!weekly) return undefined;
  const remaining = formatRemainingPercent(weekly.remainingPercent);
  const filled = Math.floor((weekly.remainingPercent * 10) / 100);
  const bar = "#".repeat(filled) + "-".repeat(10 - filled);
  return `${bar} ${remaining}% ⏳${formatResetTime(weekly.resetsAt)}`;
}

export function formatUsageSummary(snapshot: CodexUsageSnapshot): string {
  const heading = snapshot.planType
    ? `Codex usage (${snapshot.planType})`
    : "Codex usage";
  return [heading, ...snapshot.windows.map(formatWindow)].join(" · ");
}

function extractAccountId(accessToken: string): string {
  const parts = accessToken.split(".");
  if (parts.length !== 3 || !parts[1]) {
    throw new Error("OpenAI Codex OAuth token is not a valid JWT.");
  }

  try {
    const payload = JSON.parse(
      Buffer.from(parts[1], "base64url").toString("utf8"),
    ) as unknown;
    if (!isRecord(payload) || !isRecord(payload[JWT_CLAIM_PATH])) {
      throw new Error("missing auth claim");
    }
    const accountId = payload[JWT_CLAIM_PATH].chatgpt_account_id;
    if (typeof accountId !== "string" || accountId.length === 0) {
      throw new Error("missing account ID");
    }
    return accountId;
  } catch {
    throw new Error("Could not read the ChatGPT account ID from Codex OAuth.");
  }
}

function isSubagentProcess(): boolean {
  return process.env.PI_SUBAGENT_CHILD === "1";
}

function shouldShowStatus(ctx: ExtensionContext): boolean {
  return ctx.model?.provider === PROVIDER_ID && !isSubagentProcess();
}

async function fetchUsage(ctx: ExtensionContext): Promise<CodexUsageSnapshot> {
  const auth = await ctx.modelRegistry.getProviderAuth(PROVIDER_ID);
  const accessToken = auth?.auth.apiKey;
  if (!accessToken) {
    throw new Error("OpenAI Codex is not authenticated. Run /login first.");
  }

  const response = await fetch(USAGE_URL, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "ChatGPT-Account-Id": extractAccountId(accessToken),
    },
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });

  if (!response.ok) {
    throw new Error(`Codex usage request failed with HTTP ${response.status}.`);
  }

  return parseCodexUsagePayload((await response.json()) as unknown);
}

export default function(pi: ExtensionAPI): void {
  let cache: CachedSnapshot | undefined;
  let refreshPromise: Promise<CodexUsageSnapshot> | undefined;
  let sessionActive = false;

  const updateStatus = (ctx: ExtensionContext): void => {
    if (!sessionActive || !shouldShowStatus(ctx)) {
      ctx.ui.setStatus(CODEX_USAGE_STATUS_KEY, undefined);
      return;
    }
    ctx.ui.setStatus(
      CODEX_USAGE_STATUS_KEY,
      cache ? formatWeeklyStatus(cache.snapshot) : undefined,
    );
  };

  const refresh = async (
    ctx: ExtensionContext,
    options: { force: boolean; notifyError: boolean },
  ): Promise<CodexUsageSnapshot | undefined> => {
    if (
      !options.force &&
      cache &&
      Date.now() - cache.fetchedAt < CACHE_TTL_MS
    ) {
      updateStatus(ctx);
      return cache.snapshot;
    }

    if (!refreshPromise) {
      refreshPromise = fetchUsage(ctx)
        .then((snapshot) => {
          cache = { fetchedAt: Date.now(), snapshot };
          if (sessionActive) updateStatus(ctx);
          return snapshot;
        })
        .finally(() => {
          refreshPromise = undefined;
        });
    }

    try {
      return await refreshPromise;
    } catch (error: unknown) {
      if (options.notifyError && sessionActive) {
        const message =
          error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`Codex usage: ${message}`, "error");
      }
      return undefined;
    }
  };

  pi.on("session_start", (_event, ctx) => {
    sessionActive = true;
    updateStatus(ctx);
    if (shouldShowStatus(ctx)) {
      void refresh(ctx, { force: false, notifyError: false });
    }
  });

  pi.on("model_select", (_event, ctx) => {
    updateStatus(ctx);
    if (shouldShowStatus(ctx)) {
      void refresh(ctx, { force: false, notifyError: false });
    }
  });

  pi.on("agent_settled", (_event, ctx) => {
    if (shouldShowStatus(ctx)) {
      void refresh(ctx, { force: true, notifyError: false });
    }
  });

  pi.on("session_shutdown", (_event, ctx) => {
    sessionActive = false;
    ctx.ui.setStatus(CODEX_USAGE_STATUS_KEY, undefined);
  });

  pi.registerCommand("codex-usage", {
    description: "Show current OpenAI Codex usage limits",
    handler: async (_args, ctx) => {
      const snapshot = await refresh(ctx, {
        force: true,
        notifyError: true,
      });
      if (snapshot) ctx.ui.notify(formatUsageSummary(snapshot), "info");
    },
  });
}
