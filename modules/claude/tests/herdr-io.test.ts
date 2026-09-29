import { expect, test } from "bun:test";
import { appendFile, mkdir, mkdtemp, rename, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { childTranscripts, JsonlTail } from "../files/herdr-subagents/io";

test("JSONL tail handles partial Unicode, append, replacement, truncation and missing files", async () => {
  const root = await mkdtemp(join(tmpdir(), "claude-herdr-jsonl-"));
  const path = join(root, "child.jsonl");
  try {
    const tail = new JsonlTail();
    expect(await tail.read(path)).toEqual([]);
    expect(tail.available).toBeFalse();
    const record = Buffer.from(JSON.stringify({ text: "한🙂" }) + "\n");
    const split = record.indexOf(Buffer.from("한")) + 1;
    await writeFile(path, record.subarray(0, split));
    expect(await tail.read(path)).toEqual([]);
    await appendFile(path, record.subarray(split));
    expect(await tail.read(path)).toEqual([{ text: "한🙂" }]);
    expect(await tail.read(path)).toEqual([]);
    await writeFile(`${path}.new`, '{"replacement":true}\n');
    await rename(`${path}.new`, path);
    expect(await tail.read(path)).toEqual([{ replacement: true }]);
    expect(tail.reset).toBeTrue();
    await writeFile(path, '{}\n');
    expect(await tail.read(path)).toEqual([{}]);
    expect(tail.reset).toBeTrue();
    await rm(path);
    expect(await tail.read(path)).toEqual([]);
    expect(tail.available).toBeFalse();
  } finally { await rm(root, { recursive: true, force: true }); }
});

test("malformed records are diagnosed without exposing record contents", async () => {
  const root = await mkdtemp(join(tmpdir(), "claude-herdr-invalid-"));
  try {
    const path = join(root, "child.jsonl");
    const diagnostics: string[] = [];
    const tail = new JsonlTail(message => diagnostics.push(message));
    await writeFile(path, 'private malformed content\n{"valid":true}\n');
    expect(await tail.read(path)).toEqual([{ valid: true }]);
    expect(tail.hasGaps).toBeTrue();
    expect(diagnostics).toHaveLength(1);
    expect(diagnostics[0]).toContain("byte 0");
    expect(diagnostics[0]).not.toContain("private malformed content");
  } finally { await rm(root, { recursive: true, force: true }); }
});

test("discovers child files in session subdirectories without following symlinks", async () => {
  const root = await mkdtemp(join(tmpdir(), "claude-herdr-lookup-"));
  try {
    const children = join(root, "subagents");
    await mkdir(join(children, "nested"), { recursive: true });
    await mkdir(join(root, "outside"));
    await writeFile(join(children, "agent-one.jsonl"), "");
    await writeFile(join(children, "nested", "agent-two.jsonl"), "");
    await writeFile(join(root, "outside", "agent-three.jsonl"), "");
    await symlink(join(root, "outside"), join(children, "linked"));
    await symlink(join(root, "outside", "agent-three.jsonl"), join(children, "agent-four.jsonl"));
    const found = await childTranscripts(children);
    expect([...found.keys()].sort()).toEqual(["one", "two"]);
    expect(await childTranscripts(join(root, "missing"))).toEqual(new Map());
  } finally { await rm(root, { recursive: true, force: true }); }
});
