import { createHash, randomUUID } from "node:crypto";
import { execFile, spawn } from "node:child_process";
import { mkdir, open, readFile, readdir, rename, rm, stat, writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { JsonlTail, findRollout } from "./io";
import { consumeChild, discoveredChild, object, sidebarTokens, type ChildState } from "./projection";

const exec = promisify(execFile);
const SCRIPT = fileURLToPath(import.meta.url);
const SOURCE = "codex:herdr-subagents";
const TTL_MS = 45_000;
const REFRESH_MS = 15_000;
const PROBE_MS = 5_000;
const LOCK_WAIT_MS = 5_000;
const LOCK_STALE_MS = 10_000;
const ID = /^[a-zA-Z0-9_-]{1,128}$/;

type Owner = {
  token: string;
  sessionId: string;
  transcript: string;
  codexPid: number;
  codexIdentity: string;
  replayAfter: number;
  workerPid?: number;
  workerIdentity?: string;
  stopped?: boolean;
};

type Registration = { id: string; name: string };

async function json(path: string): Promise<any | undefined> {
  try { return JSON.parse(await readFile(path, "utf8")); }
  catch (error: any) {
    if (error.code === "ENOENT") return undefined;
    throw new Error(`Reading ${path}: ${error.message}`);
  }
}

async function atomicJson(path: string, value: unknown): Promise<void> {
  const temporary = `${path}.${randomUUID()}.tmp`;
  await writeFile(temporary, JSON.stringify(value), { mode: 0o600 });
  await rename(temporary, path);
}

function code(error: unknown): string | undefined {
  return typeof error === "object" && error !== null && "code" in error
    ? String((error as NodeJS.ErrnoException).code)
    : undefined;
}

async function withOwnerLock<T>(directory: string, action: () => Promise<T>): Promise<T> {
  const lock = join(directory, "owner.lock");
  const holderPath = join(lock, "holder.json");
  const holder = { pid: process.pid, token: randomUUID() };
  const deadline = Date.now() + LOCK_WAIT_MS;
  while (true) {
    try {
      await mkdir(lock, { mode: 0o700 });
      await writeFile(holderPath, JSON.stringify(holder), { mode: 0o600 });
      break;
    } catch (error) {
      if (code(error) !== "EEXIST") throw error;
      try {
        if (Date.now() - (await stat(lock)).mtimeMs > LOCK_STALE_MS) {
          const current = await json(holderPath);
          if (!current || typeof current.pid !== "number" || !alive(current.pid)) {
            await rm(lock, { recursive: true, force: true });
            continue;
          }
        }
      } catch (inspectionError) {
        if (code(inspectionError) !== "ENOENT") throw inspectionError;
        continue;
      }
      if (Date.now() >= deadline) throw new Error("Timed out waiting for the sidebar owner lock");
      await Bun.sleep(25);
    }
  }
  try { return await action(); }
  finally {
    const current = await json(holderPath);
    if (current?.pid === holder.pid && current?.token === holder.token) {
      await rm(lock, { recursive: true, force: true });
    }
  }
}

function alive(pid: number | undefined): boolean {
  if (!pid || pid < 2) return false;
  try { process.kill(pid, 0); return true; }
  catch (error: any) {
    if (error.code === "ESRCH") return false;
    throw error;
  }
}

async function processIdentity(pid: number): Promise<string | undefined> {
  try {
    const { stdout } = await exec("ps", ["-p", String(pid), "-o", "lstart=", "-o", "comm="], {
      timeout: 1_000,
      env: { ...process.env, LC_ALL: "C" },
    });
    return stdout.trim() || undefined;
  } catch { return undefined; }
}

async function codexAncestor(): Promise<{ pid: number; identity: string }> {
  let pid = process.ppid;
  for (let depth = 0; depth < 12 && pid > 1; depth++) {
    const { stdout } = await exec("ps", ["-p", String(pid), "-o", "ppid=", "-o", "comm="], {
      timeout: 1_000,
      env: { ...process.env, LC_ALL: "C" },
    });
    const match = stdout.trim().match(/^(\d+)\s+(.+)$/);
    if (!match) break;
    if (/^\.?codex(?:-.*)?$/.test(basename(match[2]))) {
      const identity = await processIdentity(pid);
      if (identity) return { pid, identity };
      break;
    }
    pid = Number(match[1]);
  }
  throw new Error("Cannot identify the owning Codex process; sidebar watcher was not started");
}

async function sameProcess(pid: number, identity: string): Promise<boolean> {
  return alive(pid) && await processIdentity(pid) === identity;
}

async function rootTranscript(path: string, sessionId: string): Promise<boolean> {
  try {
    const tail = new JsonlTail();
    let records: unknown[] = [];
    do records = await tail.read(path); while (records.length === 0 && !tail.caughtUp);
    const record = object(records[0]);
    const payload = object(record?.payload);
    return record?.type === "session_meta" && payload?.id === sessionId
      && typeof payload?.parent_thread_id !== "string" && typeof object(payload?.source)?.subagent !== "object";
  } catch { return false; }
}

function processStartedAt(identity: string): number {
  const parsed = Date.parse(identity.split(/\s+/).slice(0, 5).join(" "));
  return Number.isFinite(parsed) ? parsed : Date.now();
}

function environment(): { pane: string; binary: string; directory: string; sessions: string } | undefined {
  const pane = process.env.HERDR_PANE_ID;
  const socket = process.env.HERDR_SOCKET_PATH;
  if (process.env.HERDR_ENV !== "1" || !pane || !socket) return;
  const key = createHash("sha256").update(`${socket}\0${pane}`).digest("hex").slice(0, 24);
  return {
    pane,
    binary: process.env.HERDR_BIN_PATH || "herdr",
    directory: join(process.env.XDG_RUNTIME_DIR || tmpdir(), `codex-herdr-subagents-${process.getuid?.() ?? "user"}`, key),
    sessions: join(process.env.CODEX_HOME || join(homedir(), ".codex"), "sessions"),
  };
}

export async function handleHook(payload: unknown): Promise<void> {
  const env = environment();
  const hook = object(payload);
  if (!env || !hook || typeof hook.session_id !== "string" || !ID.test(hook.session_id)) return;
  const inherited = process.env.CODEX_THREAD_ID;
  if (inherited && inherited !== hook.session_id) return;
  if (!["SessionStart", "SessionEnd", "SubagentStart", "SubagentStop"].includes(hook.hook_event_name)) return;
  await mkdir(env.directory, { recursive: true, mode: 0o700 });
  const ownerPath = join(env.directory, "owner.json");
  await withOwnerLock(env.directory, async () => {
    let owner: Owner | undefined = await json(ownerPath);
    if (hook.hook_event_name === "SessionEnd") {
      if (owner?.sessionId === hook.session_id) await atomicJson(ownerPath, { ...owner, stopped: true });
      return;
    }

    const transcript = typeof hook.transcript_path === "string" && hook.transcript_path
      ? resolve(hook.transcript_path)
      : owner?.sessionId === hook.session_id ? owner.transcript : undefined;
    if (!transcript) return;
    if (owner?.sessionId === hook.session_id && owner.stopped && hook.hook_event_name !== "SessionStart") return;
    if (hook.hook_event_name === "SessionStart" && !await rootTranscript(transcript, hook.session_id)) return;
    const existingWorkerHealthy = !!owner && !owner.stopped
      && typeof owner.workerPid === "number" && typeof owner.workerIdentity === "string"
      && await sameProcess(owner.workerPid, owner.workerIdentity);
    if (owner?.sessionId !== hook.session_id && hook.hook_event_name !== "SessionStart" && existingWorkerHealthy) return;
    const workerHealthy = owner?.sessionId === hook.session_id && existingWorkerHealthy;
    const sessionCodex = hook.hook_event_name === "SessionStart" ? await codexAncestor() : undefined;
    const codexChanged = sessionCodex && (owner?.codexPid !== sessionCodex.pid || owner?.codexIdentity !== sessionCodex.identity);
    if (!workerHealthy || codexChanged) {
      const codex = sessionCodex ?? await codexAncestor();
      const replayAfter = owner?.sessionId === hook.session_id && owner.codexIdentity === codex.identity
        ? owner.replayAfter
        : processStartedAt(codex.identity) - 1_000;
      owner = {
        token: randomUUID(),
        sessionId: hook.session_id,
        transcript,
        codexPid: codex.pid,
        codexIdentity: codex.identity,
        replayAfter,
      };
      await mkdir(join(env.directory, owner.sessionId), { recursive: true, mode: 0o700 });
      await atomicJson(ownerPath, owner);
      const log = await open(join(env.directory, "watcher.log"), "a", 0o600);
      try {
        const child = spawn(process.execPath, [SCRIPT, "watch", owner.token], {
          detached: true,
          stdio: ["ignore", "ignore", log.fd],
          env: process.env,
        });
        await new Promise<void>((accept, reject) => {
          child.once("spawn", accept);
          child.once("error", reject);
        });
        owner.workerPid = child.pid;
        owner.workerIdentity = await processIdentity(child.pid!);
        await atomicJson(ownerPath, owner);
        child.unref();
      } finally { await log.close(); }
    }
    if (!owner || owner.sessionId !== hook.session_id || owner.stopped) return;
    if (["SubagentStart", "SubagentStop"].includes(hook.hook_event_name) && typeof hook.agent_id === "string" && ID.test(hook.agent_id)) {
      const registrationPath = join(env.directory, owner.sessionId, `${hook.agent_id}.json`);
      if (!await json(registrationPath)) {
        await atomicJson(registrationPath, {
          id: hook.agent_id,
          name: typeof hook.agent_type === "string" ? hook.agent_type : "subagent",
        } satisfies Registration);
      }
    }
  });
}

export async function watch(token: string): Promise<void> {
  const env = environment();
  if (!env) return;
  const ownerPath = join(env.directory, "owner.json");
  const initial: Owner | undefined = await json(ownerPath);
  if (!initial || initial.token !== token) return;
  const parent = new JsonlTail();
  const children = new Map<string, { state: ChildState; tail: JsonlTail; path?: string; nextLookup: number; verified: boolean }>();
  let published = "";
  let lastPublished = 0;
  let lastError = "";
  let unavailableSince = 0;
  let nextProbe = 0;
  let ownerProcessHealthy = true;
  const register = (entry: Registration, updateName = false) => {
    if (!ID.test(entry.id)) return;
    if (!children.has(entry.id)) children.set(entry.id, {
      state: { id: entry.id, name: entry.name, activity: "starting", active: false },
      tail: new JsonlTail(), nextLookup: 0, verified: false,
    });
    else if (updateName && entry.name !== "subagent") children.get(entry.id)!.state.name = entry.name;
  };
  const report = async (states: ChildState[]) => {
    const tokens = sidebarTokens(states);
    const serialized = JSON.stringify(tokens);
    if (serialized === published && (states.every((state) => !state.active) || Date.now() - lastPublished < REFRESH_MS)) return;
    await withOwnerLock(env.directory, async () => {
      if ((await json(ownerPath))?.token !== token) return;
      const args = ["pane", "report-metadata", env.pane, "--source", SOURCE, "--ttl-ms", String(TTL_MS)];
      for (const [key, value] of Object.entries(tokens)) args.push(...(value === null ? ["--clear-token", key] : ["--token", `${key}=${value}`]));
      try { await exec(env.binary, args, { timeout: 2_000 }); }
      catch { throw new Error("Herdr metadata update failed"); }
      published = serialized;
      lastPublished = Date.now();
    });
  };
  const verifyParent = (value: unknown): boolean | undefined => {
    const record = object(value);
    if (record?.type !== "session_meta") return;
    const payload = object(record.payload);
    const nested = object(object(object(payload?.source)?.subagent)?.thread_spawn);
    return payload?.parent_thread_id === initial.sessionId && nested?.parent_thread_id === initial.sessionId;
  };
  const staleStart = (value: unknown): boolean => {
    const record = object(value);
    const payload = object(record?.payload);
    return record?.type === "event_msg" && payload?.type === "task_started"
      && typeof payload.started_at === "number" && payload.started_at * 1_000 < initial.replayAfter;
  };
  try {
    while (true) {
      const owner: Owner | undefined = await json(ownerPath);
      if (!owner || owner.token !== token) return;
      if (owner.stopped || !ownerProcessHealthy) break;
      try {
        if (Date.now() >= nextProbe) {
          ownerProcessHealthy = await sameProcess(owner.codexPid, owner.codexIdentity);
          if (!ownerProcessHealthy) break;
          try { await exec(env.binary, ["pane", "get", env.pane], { timeout: 2_000 }); }
          catch { throw new Error("Herdr parent pane is unavailable"); }
          nextProbe = Date.now() + PROBE_MS;
        }
        for (const value of await parent.read(initial.transcript)) {
          const entry = discoveredChild(value);
          if (entry) register(entry, true);
        }
        const registrationDirectory = join(env.directory, initial.sessionId);
        for (const file of await readdir(registrationDirectory)) {
          if (!file.endsWith(".json")) continue;
          const entry = await json(join(registrationDirectory, file));
          if (typeof entry?.id === "string" && typeof entry.name === "string") register(entry);
        }
        for (const child of children.values()) {
          if (!child.path && Date.now() >= child.nextLookup) {
            child.path = await findRollout(env.sessions, child.state.id, dirname(initial.transcript));
            child.nextLookup = Date.now() + 5_000;
          }
          if (child.path) for (const value of await child.tail.read(child.path)) {
            const verified = verifyParent(value);
            if (verified === false) {
              child.path = undefined;
              child.verified = false;
              child.nextLookup = Date.now() + 5_000;
              break;
            }
            if (verified === true) child.verified = true;
            if (child.verified && !staleStart(value)) consumeChild(child.state, value);
          }
        }
        await report([...children.values()].filter((child) => child.verified && child.path && child.tail.caughtUp).map((child) => child.state));
        lastError = "";
        unavailableSince = 0;
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        if (message !== lastError) console.error(`Codex Herdr sidebar: ${message}`);
        lastError = message;
        unavailableSince ||= Date.now();
        if (Date.now() - unavailableSince >= TTL_MS) break;
      }
      await Bun.sleep(500);
    }
  } finally {
    await report([]);
  }
}

if (import.meta.main) {
  try {
    if (process.argv[2] === "watch") await watch(process.argv[3]);
    else {
      await handleHook(JSON.parse(await Bun.stdin.text()));
      process.stdout.write("{}\n");
    }
  } catch (error) {
    console.error(`Codex Herdr sidebar: ${error instanceof Error ? error.message : String(error)}`);
    if (process.argv[2] !== "watch") process.stdout.write("{}\n");
  }
}
