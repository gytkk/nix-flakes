import { describe, expect, test } from "bun:test";
import {
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
    expect(formatWeeklyStatus(snapshot)).toContain("week 59% left");
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
