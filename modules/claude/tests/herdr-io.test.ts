import { expect, test } from "bun:test";
import { appendFile, mkdir, mkdtemp, rename, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { childTranscripts, JsonlTail, teammateRemoved } from "../files/herdr-subagents/io";

test("team removal requires native child metadata and a matching leader session", async () => {
  const root = await mkdtemp(join(tmpdir(), "claude-herdr-team-"));
  const transcript = join(root, "agent-child.jsonl");
  const metadata = join(root, "agent-child.meta.json");
  const teams = join(root, "teams");
  const config = join(teams, "team-test", "config.json");
  const team = { name: "team-test", leadSessionId: "parent", members: [{ agentId: "team-lead@team-test" }] };
  try {
    expect(await teammateRemoved(transcript, teams, "parent")).toBeFalse();
    await writeFile(metadata, JSON.stringify({ name: "reviewer", teamName: "team-test" }));
    expect(await teammateRemoved(transcript, teams, "parent")).toBeFalse();
    await mkdir(join(teams, "team-test"), { recursive: true });
    await writeFile(config, JSON.stringify(team));
    expect(await teammateRemoved(transcript, teams, "parent")).toBeTrue();
    expect(await teammateRemoved(transcript, teams, "another-session")).toBeFalse();
    await writeFile(config, JSON.stringify({ ...team, members: [...team.members, { agentId: "reviewer@team-test" }] }));
    expect(await teammateRemoved(transcript, teams, "parent")).toBeFalse();
    await writeFile(config, JSON.stringify({ ...team, name: "another-team" }));
    expect(await teammateRemoved(transcript, teams, "parent")).toBeFalse();
    await writeFile(metadata, JSON.stringify({ name: "reviewer", teamName: "../outside" }));
    expect(await teammateRemoved(transcript, teams, "parent")).toBeFalse();
  } finally { await rm(root, { recursive: true, force: true }); }
});

test("invalid team files are diagnosed rather than interpreted as removal", async () => {
  const root = await mkdtemp(join(tmpdir(), "claude-herdr-team-invalid-"));
  const transcript = join(root, "agent-child.jsonl");
  const teams = join(root, "teams");
  const config = join(teams, "team-test", "config.json");
  try {
    await writeFile(join(root, "agent-child.meta.json"), JSON.stringify({ name: "reviewer", teamName: "team-test" }));
    await mkdir(join(teams, "team-test"), { recursive: true });
    await writeFile(config, "private malformed content");
    await expect(teammateRemoved(transcript, teams, "parent")).rejects.toThrow("cannot read teammate membership");
    await writeFile(config, JSON.stringify({ name: "team-test", leadSessionId: "parent", members: [{}] }));
    await expect(teammateRemoved(transcript, teams, "parent")).rejects.toThrow("invalid team member list");
    await rm(config);
    await mkdir(config);
    await expect(teammateRemoved(transcript, teams, "parent")).rejects.toThrow("cannot read teammate membership");
  } finally { await rm(root, { recursive: true, force: true }); }
});

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
