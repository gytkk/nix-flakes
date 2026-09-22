import { createHash, randomUUID } from "node:crypto";
import { execFileSync } from "node:child_process";
import { appendFile, chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, expect, test } from "bun:test";
import { handleHook, watch } from "../files/herdr-subagents/index";

const roots: string[] = [];
const saved = { ...process.env };

function identity(pid = process.pid): string {
  return execFileSync("ps", ["-p", String(pid), "-o", "lstart=", "-o", "comm="], { encoding: "utf8" }).trim();
}

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), "codex-herdr-runtime-"));
  roots.push(root);
  const socket = join(root, "herdr.sock");
  const pane = "pane-test";
  const key = createHash("sha256").update(`${socket}\0${pane}`).digest("hex").slice(0, 24);
  const runtime = join(root, `codex-herdr-subagents-${process.getuid?.() ?? "user"}`, key);
  const codexHome = join(root, "codex");
  const day = join(codexHome, "sessions", "2026", "09", "22");
  const log = join(root, "herdr.log");
  const herdr = join(root, "herdr");
  await mkdir(day, { recursive: true });
  await writeFile(herdr, `#!/usr/bin/env bun\nimport { appendFileSync } from "node:fs";\nappendFileSync(${JSON.stringify(log)}, JSON.stringify(process.argv.slice(2)) + "\\n");\nif (process.argv[2] === "get") console.log('{"result":{}}');\n`);
  await chmod(herdr, 0o700);
  Object.assign(process.env, {
    HERDR_ENV: "1",
    HERDR_PANE_ID: pane,
    HERDR_SOCKET_PATH: socket,
    HERDR_BIN_PATH: herdr,
    XDG_RUNTIME_DIR: root,
    CODEX_HOME: codexHome,
  });
  delete process.env.CODEX_THREAD_ID;
  return { root, runtime, day, log };
}

async function eventually(check: () => Promise<boolean>, timeout = 5_000): Promise<void> {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (await check()) return;
    await Bun.sleep(50);
  }
  throw new Error("timed out waiting for watcher state");
}

async function lines(path: string): Promise<string[]> {
  try { return (await readFile(path, "utf8")).trim().split("\n").filter(Boolean); }
  catch { return []; }
}

afterEach(async () => {
  process.env = { ...saved };
  await Promise.all(roots.splice(0).map((root) => rm(root, { recursive: true, force: true })));
});

test("hook registration is first-writer-only and late child hooks cannot replace a live owner", async () => {
  const { runtime, day } = await fixture();
  const sessionId = "root-session";
  const transcript = join(day, `rollout-${sessionId}.jsonl`);
  await writeFile(transcript, `${JSON.stringify({ type: "session_meta", payload: { id: sessionId, source: "cli" } })}\n`);
  await mkdir(join(runtime, sessionId), { recursive: true });
  const owner = {
    token: randomUUID(), sessionId, transcript, codexPid: process.pid,
    codexIdentity: identity(), replayAfter: Date.now(), workerPid: process.pid, workerIdentity: identity(),
  };
  await writeFile(join(runtime, "owner.json"), JSON.stringify(owner));

  await handleHook({ hook_event_name: "SubagentStart", session_id: sessionId, transcript_path: transcript, agent_id: "child-1", agent_type: "reviewer" });
  await handleHook({ hook_event_name: "SubagentStop", session_id: sessionId, transcript_path: transcript, agent_id: "child-1", agent_type: "replacement" });
  expect(JSON.parse(await readFile(join(runtime, sessionId, "child-1.json"), "utf8")).name).toBe("reviewer");

  await handleHook({ hook_event_name: "SubagentStart", session_id: "old-session", transcript_path: transcript, agent_id: "late-child", agent_type: "worker" });
  expect(JSON.parse(await readFile(join(runtime, "owner.json"), "utf8")).token).toBe(owner.token);

  const lock = join(runtime, "owner.lock");
  await mkdir(lock);
  await writeFile(join(lock, "holder.json"), JSON.stringify({ pid: process.pid, token: "live-holder" }));
  const release = setTimeout(() => void rm(lock, { recursive: true, force: true }), 2_200);
  await handleHook({ hook_event_name: "SubagentStart", session_id: sessionId, transcript_path: transcript, agent_id: "after-wait", agent_type: "worker" });
  clearTimeout(release);
  expect(JSON.parse(await readFile(join(runtime, sessionId, "after-wait.json"), "utf8")).name).toBe("worker");

  const childTranscript = join(day, "rollout-child-session.jsonl");
  await writeFile(childTranscript, `${JSON.stringify({ type: "session_meta", payload: { id: "child-session", parent_thread_id: sessionId, source: { subagent: {} } } })}\n`);
  await handleHook({ hook_event_name: "SessionStart", session_id: "child-session", transcript_path: childTranscript, source: "startup" });
  expect(JSON.parse(await readFile(join(runtime, "owner.json"), "utf8")).token).toBe(owner.token);

  await writeFile(join(runtime, "owner.json"), JSON.stringify({ ...owner, stopped: true }));
  await handleHook({ hook_event_name: "SubagentStop", session_id: sessionId, transcript_path: transcript, agent_id: "late-stop", agent_type: "worker" });
  expect(JSON.parse(await readFile(join(runtime, "owner.json"), "utf8")).stopped).toBe(true);
});

test("SessionStart creates an owner from an empty runtime and SessionEnd stops it", async () => {
  const { root, runtime, day } = await fixture();
  const fakeBin = join(root, "bin");
  await mkdir(fakeBin);
  await writeFile(join(fakeBin, "ps"), `#!/bin/sh\ncase "$*" in *"ppid="*) echo "1 codex";; *) echo "Tue Sep 22 10:15:40 2026 codex";; esac\n`);
  await chmod(join(fakeBin, "ps"), 0o700);
  process.env.PATH = `${fakeBin}:${process.env.PATH}`;
  const sessionId = "fresh-session";
  const transcript = join(day, `rollout-${sessionId}.jsonl`);
  await writeFile(transcript, `${JSON.stringify({ type: "session_meta", payload: { id: sessionId, source: "cli" } })}\n`);

  await handleHook({ hook_event_name: "SessionStart", session_id: sessionId, transcript_path: transcript, source: "startup" });
  const owner = JSON.parse(await readFile(join(runtime, "owner.json"), "utf8"));
  expect(owner.sessionId).toBe(sessionId);
  expect(owner.workerPid).toBeNumber();
  await handleHook({ hook_event_name: "SessionEnd", session_id: sessionId, transcript_path: transcript, reason: "other" });
  await eventually(async () => {
    try { process.kill(owner.workerPid, 0); return false; }
    catch { return true; }
  });
});

test("watcher validates parentage, follows terminal reuse, and cannot clear a replacement owner", async () => {
  const { runtime, day, log } = await fixture();
  const sessionId = "root-session";
  const token = randomUUID();
  const transcript = join(day, `rollout-${sessionId}.jsonl`);
  const childId = "child-good";
  const foreignId = "child-foreign";
  const activity = (id: string, name: string) => ({
    type: "event_msg", payload: { type: "item_completed", item: { type: "SubAgentActivity", kind: "started", agent_thread_id: id, agent_path: `/root/${name}` } },
  });
  await writeFile(transcript, [activity(childId, "authoritative"), activity(foreignId, "foreign")].map((value) => JSON.stringify(value)).join("\n") + "\n");
  const meta = (parent: string, id: string) => ({ type: "session_meta", payload: {
    id, parent_thread_id: parent, agent_path: `/root/${id}`, source: { subagent: { thread_spawn: { parent_thread_id: parent } } },
  } });
  const started = () => ({ type: "event_msg", payload: { type: "task_started", started_at: Date.now() / 1_000, turn_id: randomUUID() } });
  const goodPath = join(day, `rollout-${childId}.jsonl`);
  await writeFile(goodPath, [meta(sessionId, childId), { type: "turn_context", payload: { model: "gpt-test" } }, started()].map((value) => JSON.stringify(value)).join("\n") + "\n");
  await writeFile(join(day, `rollout-${foreignId}.jsonl`), [meta("another-parent", foreignId), started()].map((value) => JSON.stringify(value)).join("\n") + "\n");
  await mkdir(join(runtime, sessionId), { recursive: true });
  await writeFile(join(runtime, "owner.json"), JSON.stringify({
    token, sessionId, transcript, codexPid: process.pid, codexIdentity: identity(), replayAfter: Date.now() - 2_000,
  }));

  const running = watch(token);
  let ownsLock = false;
  try {
    await eventually(async () => (await lines(log)).some((line) => line.includes("child-good") && line.includes("gpt-test")));
    expect((await lines(log)).join("\n")).not.toContain("child-foreign");

    const beforeCompletion = (await lines(log)).length;
    await appendFile(goodPath, `${JSON.stringify({ type: "event_msg", payload: { type: "task_complete", turn_id: "one" } })}\n`);
    await eventually(async () => (await lines(log)).slice(beforeCompletion).some((line) => {
      const args = JSON.parse(line);
      return args.some((value: string, index: number) => value === "--clear-token" && args[index + 1] === "subagent_1");
    }));
    const beforeReuse = (await lines(log)).length;
    await appendFile(goodPath, `${JSON.stringify(started())}\n`);
    await eventually(async () => (await lines(log)).slice(beforeReuse).some((line) => line.includes("child-good")));

    await eventually(async () => {
      try { await mkdir(join(runtime, "owner.lock")); return true; }
      catch (error: any) { if (error.code === "EEXIST") return false; throw error; }
    });
    ownsLock = true;
    const replacement = { token: randomUUID(), sessionId: "new-session", transcript, codexPid: process.pid, codexIdentity: identity(), replayAfter: Date.now() };
    await writeFile(join(runtime, "owner.json"), JSON.stringify(replacement));
    const countAtReplacement = (await lines(log)).length;
    await rm(join(runtime, "owner.lock"), { recursive: true });
    ownsLock = false;
    await running;
    expect((await lines(log)).length).toBe(countAtReplacement);
  } finally {
    const current = JSON.parse(await readFile(join(runtime, "owner.json"), "utf8"));
    await writeFile(join(runtime, "owner.json"), JSON.stringify({ ...current, stopped: true }));
    if (ownsLock) await rm(join(runtime, "owner.lock"), { recursive: true, force: true });
    await running;
  }
}, 15_000);
