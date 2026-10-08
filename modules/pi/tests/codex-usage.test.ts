import { describe, expect, mock, test } from "bun:test";
import codexUsage, {
  formatResetTime,
  formatUsageSummary,
  formatWeeklyStatus,
  parseCodexUsagePayload,
} from "../files/extensions/codex-usage";

const WEEK_SECONDS = 7 * 24 * 60 * 60;

describe("Codex usage parsing", () => {
  test("finds a weekly primary window and reports remaining capacity", () => {
    const snapshot = parseCodexUsagePayload({
      plan_type: "prolite",
      rate_limit: {
        primary_window: {
          used_percent: 41,
          limit_window_seconds: WEEK_SECONDS,
          reset_at: 1_800_000_000,
        },
        secondary_window: null,
      },
    });

    expect(snapshot.planType).toBe("prolite");
    expect(snapshot.weekly?.usedPercent).toBe(41);
    expect(snapshot.weekly?.remainingPercent).toBe(59);
    expect(formatWeeklyStatus(snapshot)).toMatch(
      /^#####----- 59% ⏳\d{2}\/\d{2} \d{2}:\d{2}$/,
    );
  });

  test("finds the weekly window when it is secondary", () => {
    const snapshot = parseCodexUsagePayload({
      rate_limit: {
        primary_window: {
          used_percent: 25,
          limit_window_seconds: 5 * 60 * 60,
          reset_at: 1_800_000_000,
        },
        secondary_window: {
          used_percent: 12.5,
          limit_window_seconds: WEEK_SECONDS,
          reset_at: 1_800_100_000,
        },
      },
    });

    expect(snapshot.windows).toHaveLength(2);
    expect(snapshot.weekly?.remainingPercent).toBe(87.5);
    expect(formatUsageSummary(snapshot)).toContain("5h: 75% left");
    expect(formatUsageSummary(snapshot)).toContain("Weekly: 87.5% left");
    expect(formatUsageSummary(snapshot)).not.toContain("\n");
  });

  test("clamps provider percentages before calculating remaining capacity", () => {
    const over = parseCodexUsagePayload({
      rate_limit: {
        primary_window: {
          used_percent: 125,
          limit_window_seconds: WEEK_SECONDS,
          reset_at: 1_800_000_000,
        },
      },
    });
    const under = parseCodexUsagePayload({
      rate_limit: {
        primary_window: {
          used_percent: -10,
          limit_window_seconds: WEEK_SECONDS,
          reset_at: 1_800_000_000,
        },
      },
    });

    expect(over.weekly?.remainingPercent).toBe(0);
    expect(under.weekly?.remainingPercent).toBe(100);
    expect(formatWeeklyStatus(over)).toStartWith("---------- 0% ⏳");
    expect(formatWeeklyStatus(under)).toStartWith("########## 100% ⏳");
  });

  test("rejects responses without usable rate-limit windows", () => {
    expect(() => parseCodexUsagePayload({ rate_limit: {} })).toThrow(
      "did not include rate-limit windows",
    );
  });
});

test("reset times use a compact local date and time", () => {
  expect(formatResetTime(1_800_000_000)).toMatch(/^\d{2}\/\d{2} \d{2}:\d{2}$/);
});

describe("ChatGPT provider migration", () => {
  function fixture() {
    const handlers = new Map<string, Function>();
    const commands = new Map<string, { handler: Function }>();
    const getProviderAuth = mock(async () => undefined);
    const ctx = {
      model: { provider: "openai" },
      modelRegistry: { getProviderAuth },
      ui: { setStatus: mock(() => {}), notify: mock(() => {}) },
    };
    codexUsage({
      on: (event: string, handler: Function) => handlers.set(event, handler),
      registerCommand: (name: string, command: { handler: Function }) => commands.set(name, command),
    } as never);
    return { handlers, commands, getProviderAuth, ctx };
  }

  test("does not automatically query Codex limits for the new OpenAI provider", () => {
    const { handlers, ctx, getProviderAuth } = fixture();
    for (const event of ["session_start", "model_select", "agent_settled"]) {
      handlers.get(event)!({}, ctx);
    }
    expect(getProviderAuth).not.toHaveBeenCalled();
    expect(ctx.ui.setStatus).toHaveBeenCalledWith("codex-usage", undefined);
  });

  test("explicit usage commands resolve only the legacy credential", async () => {
    const { handlers, commands, ctx, getProviderAuth } = fixture();
    handlers.get("session_start")!({}, ctx);
    await commands.get("codex-usage")!.handler("", ctx);
    expect(getProviderAuth).toHaveBeenCalledTimes(1);
    expect(getProviderAuth).toHaveBeenCalledWith("openai-codex");
    expect(ctx.ui.notify).toHaveBeenCalledWith(
      "Codex usage: OpenAI Codex is not authenticated. Run /login first.",
      "error",
    );
  });
});
