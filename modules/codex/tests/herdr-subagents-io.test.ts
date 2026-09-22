import { afterEach, describe, expect, test } from "bun:test";
import { appendFile, mkdir, mkdtemp, rename, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { findRollout, JsonlTail } from "../files/herdr-subagents/io";

const roots: string[] = [];

async function fixture(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "codex-rollout-"));
  roots.push(root);
  return root;
}

afterEach(async () => {
  await Promise.all(roots.splice(0).map((root) => rm(root, { recursive: true, force: true })));
});

describe("JsonlTail", () => {
  test("waits for a complete UTF-8 JSON line", async () => {
    const root = await fixture();
    const path = join(root, "rollout.jsonl");
    const bytes = Buffer.from(JSON.stringify({ text: "한글" }));
    const split = bytes.indexOf(Buffer.from("한")) + 1;
    await writeFile(path, bytes.subarray(0, split));

    const tail = new JsonlTail();
    expect(await tail.read(path)).toEqual([]);
    expect(tail.caughtUp).toBe(true);

    await appendFile(path, Buffer.concat([bytes.subarray(split), Buffer.from("\n")]));
    expect(await tail.read(path)).toEqual([{ text: "한글" }]);
  });

  test("bounds each read and reports when historical replay catches up", async () => {
    const root = await fixture();
    const path = join(root, "large.jsonl");
    const line = `${JSON.stringify({ value: "x".repeat(1024) })}\n`;
    await writeFile(path, line.repeat(1200));

    const tail = new JsonlTail();
    expect((await tail.read(path)).length).toBeGreaterThan(0);
    expect(tail.caughtUp).toBe(false);
    expect((await tail.read(path)).length).toBeGreaterThan(0);
    expect(tail.caughtUp).toBe(true);
  });

  test("resets after truncation and file replacement", async () => {
    const root = await fixture();
    const path = join(root, "rollout.jsonl");
    const replacement = join(root, "replacement.jsonl");
    const tail = new JsonlTail();

    await writeFile(path, `${JSON.stringify({ value: "long initial value" })}\n`);
    expect(await tail.read(path)).toEqual([{ value: "long initial value" }]);
    await writeFile(path, "1\n");
    expect(await tail.read(path)).toEqual([1]);

    await writeFile(replacement, "2\n");
    await rename(replacement, path);
    expect(await tail.read(path)).toEqual([2]);
  });

  test("handles a missing file", async () => {
    const root = await fixture();
    const path = join(root, "missing.jsonl");
    const tail = new JsonlTail();
    expect(await tail.read(path)).toEqual([]);
  });

  test("skips malformed records without losing adjacent records or leaking content", async () => {
    const root = await fixture();
    const path = join(root, "rollout.jsonl");
    const diagnostics: string[] = [];
    const started = '{"type":"task_started"}\n';
    await writeFile(path, `${started}{"secret":"do-not-log",}\n{"type":"task_complete"}\n`);

    const tail = new JsonlTail((message) => diagnostics.push(message));
    expect(await tail.read(path)).toEqual([
      { type: "task_started" },
      { type: "task_complete" },
    ]);
    expect(diagnostics).toEqual([
      `skipping malformed JSONL record in ${path} at byte ${Buffer.byteLength(started)}`,
    ]);
    expect(diagnostics.join(" ")).not.toContain("do-not-log");
  });

  test("skips an oversized record and resumes at its newline", async () => {
    const root = await fixture();
    const path = join(root, "oversized.jsonl");
    await writeFile(path, `${"x".repeat(8 * 1024 * 1024 + 1)}\n{"recovered":true}\n`);

    const diagnostics: string[] = [];
    const tail = new JsonlTail((message) => diagnostics.push(message));
    const records: unknown[] = [];
    do records.push(...await tail.read(path)); while (!tail.caughtUp);
    expect(records).toEqual([{ recovered: true }]);
    expect(diagnostics).toEqual([`skipping oversized JSONL record in ${path} at byte 0`]);
  });
});

describe("findRollout", () => {
  test("prefers an immediate directory and matches the exact agent suffix", async () => {
    const root = await fixture();
    const oldDay = join(root, "2025", "12", "31");
    const preferred = join(root, "2026", "01", "02");
    await mkdir(oldDay, { recursive: true });
    await mkdir(preferred, { recursive: true });
    await writeFile(join(oldDay, "rollout-agent-12.jsonl"), "");
    await writeFile(join(preferred, "rollout-agent-1.jsonl"), "");
    await writeFile(join(preferred, "rollout-agent-11.jsonl"), "");

    expect(await findRollout(root, "agent-1", preferred)).toBe(join(preferred, "rollout-agent-1.jsonl"));
    expect(await findRollout(root, "agent-12")).toBe(join(oldDay, "rollout-agent-12.jsonl"));
  });

  test("rejects traversal ids and does not follow symlinked date directories", async () => {
    const root = await fixture();
    const outside = await fixture();
    const month = join(root, "2026", "01");
    await mkdir(month, { recursive: true });
    await writeFile(join(outside, "rollout-agent-1.jsonl"), "");
    await symlink(outside, join(month, "02"));

    await expect(findRollout(root, "../agent-1")).rejects.toThrow("invalid rollout agent id");
    expect(await findRollout(root, "agent-1")).toBeUndefined();
    expect(await findRollout(root, "agent-1", join(month, "02"))).toBeUndefined();
  });
});
