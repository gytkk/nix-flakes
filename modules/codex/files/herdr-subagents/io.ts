import { lstat, open, readdir } from "node:fs/promises";
import { isAbsolute, join, relative, resolve, sep } from "node:path";

const READ_LIMIT = 1024 * 1024;
const MAX_LINE = 8 * 1024 * 1024;

type TailState = {
  identity: string;
  offset: number;
  line: Buffer;
  lineOffset: number;
  dropping: boolean;
};

function context(error: unknown, action: string): Error {
  const detail = error instanceof Error ? error.message : String(error);
  return new Error(`${action}: ${detail}`, { cause: error });
}

function isCode(error: unknown, code: string): boolean {
  return typeof error === "object" && error !== null && "code" in error
    && (error as NodeJS.ErrnoException).code === code;
}

export class JsonlTail {
  readonly #states = new Map<string, TailState>();
  readonly #diagnose: (message: string) => void;
  caughtUp = true;
  available = false;
  reset = false;
  hasGaps = false;

  constructor(diagnose: (message: string) => void = console.warn) {
    this.#diagnose = diagnose;
  }

  async read(path: string): Promise<unknown[]> {
    this.available = false;
    this.reset = false;
    this.hasGaps = false;
    let file;
    try {
      file = await open(path, "r");
    } catch (error) {
      if (isCode(error, "ENOENT")) {
        this.#states.delete(path);
        this.caughtUp = true;
        return [];
      }
      throw context(error, `cannot open JSONL file ${path}`);
    }

    try {
      const stat = await file.stat();
      if (!stat.isFile()) throw new Error("path is not a regular file");
      this.available = true;

      const identity = `${stat.dev}:${stat.ino}`;
      let state = this.#states.get(path);
      if (!state || state.identity !== identity || stat.size < state.offset) {
        this.reset = true;
        state = { identity, offset: 0, line: Buffer.alloc(0), lineOffset: 0, dropping: false };
        this.#states.set(path, state);
      }

      const length = Math.min(READ_LIMIT, Math.max(0, stat.size - state.offset));
      if (length === 0) {
        this.caughtUp = true;
        return [];
      }

      const chunk = Buffer.allocUnsafe(length);
      const chunkOffset = state.offset;
      const { bytesRead } = await file.read(chunk, 0, length, state.offset);
      state.offset += bytesRead;
      this.caughtUp = state.offset >= stat.size;
      return this.#records(path, state, chunk.subarray(0, bytesRead), chunkOffset);
    } catch (error) {
      this.available = false;
      throw context(error, `cannot read JSONL file ${path}`);
    } finally {
      await file.close();
    }
  }

  #records(path: string, state: TailState, chunk: Buffer, chunkOffset: number): unknown[] {
    const records: unknown[] = [];
    let cursor = 0;
    while (cursor < chunk.length) {
      const newline = chunk.indexOf(0x0a, cursor);
      const end = newline < 0 ? chunk.length : newline;
      const segment = chunk.subarray(cursor, end);

      if (!state.dropping) {
        if (state.line.length + segment.length > MAX_LINE) {
          state.line = Buffer.alloc(0);
          state.dropping = true;
          this.hasGaps = true;
          this.#diagnose(`skipping oversized JSONL record in ${path} at byte ${state.lineOffset}`);
        } else if (segment.length > 0) {
          state.line = Buffer.concat([state.line, segment]);
        }
      }

      if (newline < 0) break;
      if (state.dropping) {
        state.dropping = false;
      } else {
        try {
          const text = new TextDecoder("utf-8", { fatal: true }).decode(state.line);
          records.push(JSON.parse(text));
        } catch {
          this.hasGaps = true;
          this.#diagnose(`skipping malformed JSONL record in ${path} at byte ${state.lineOffset}`);
        }
        state.line = Buffer.alloc(0);
      }
      cursor = newline + 1;
      state.lineOffset = chunkOffset + cursor;
    }
    return records;
  }
}

async function entries(path: string) {
  try {
    const stat = await lstat(path);
    if (!stat.isDirectory() || stat.isSymbolicLink()) return [];
    return await readdir(path, { withFileTypes: true });
  } catch (error) {
    if (isCode(error, "ENOENT")) return [];
    throw context(error, `cannot scan rollout directory ${path}`);
  }
}

function within(root: string, candidate: string): boolean {
  const path = relative(root, candidate);
  return path === "" || (!path.startsWith("..") && !isAbsolute(path));
}

async function safeDirectory(root: string, candidate: string): Promise<boolean> {
  if (!within(root, candidate)) return false;
  let current = root;
  const paths = [root];
  for (const part of relative(root, candidate).split(sep).filter(Boolean)) {
    current = join(current, part);
    paths.push(current);
  }
  for (const path of paths) {
    try {
      const stat = await lstat(path);
      if (!stat.isDirectory() || stat.isSymbolicLink()) return false;
    } catch (error) {
      if (isCode(error, "ENOENT")) return false;
      throw context(error, `cannot inspect rollout directory ${path}`);
    }
  }
  return true;
}

async function match(dir: string, suffix: string): Promise<string | undefined> {
  const names = (await entries(dir))
    .filter((entry) => entry.isFile() && entry.name.endsWith(suffix))
    .map((entry) => entry.name)
    .sort()
    .reverse();
  return names[0] ? resolve(dir, names[0]) : undefined;
}

export async function findRollout(
  sessionsDir: string,
  agentId: string,
  preferredDir?: string,
): Promise<string | undefined> {
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]*$/.test(agentId)) {
    throw new Error(`invalid rollout agent id: ${agentId}`);
  }
  const root = resolve(sessionsDir);
  const suffix = `-${agentId}.jsonl`;
  if (preferredDir) {
    const preferred = resolve(preferredDir);
    if (await safeDirectory(root, preferred)) {
      const found = await match(preferred, suffix);
      if (found) return found;
    }
  }

  const years = (await entries(root)).filter((entry) => entry.isDirectory() && /^\d{4}$/.test(entry.name));
  for (const year of years.sort((a, b) => b.name.localeCompare(a.name))) {
    const yearDir = resolve(root, year.name);
    const months = (await entries(yearDir)).filter((entry) => entry.isDirectory() && /^(0[1-9]|1[0-2])$/.test(entry.name));
    for (const month of months.sort((a, b) => b.name.localeCompare(a.name))) {
      const monthDir = resolve(yearDir, month.name);
      const days = (await entries(monthDir)).filter((entry) => entry.isDirectory() && /^(0[1-9]|[12]\d|3[01])$/.test(entry.name));
      for (const day of days.sort((a, b) => b.name.localeCompare(a.name))) {
        const found = await match(resolve(monthDir, day.name), suffix);
        if (found) return found;
      }
    }
  }
  return undefined;
}
