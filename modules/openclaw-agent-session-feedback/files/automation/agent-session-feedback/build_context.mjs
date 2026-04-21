#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';

function parseArgs(argv) {
  const result = {};
  for (let index = 2; index < argv.length; index += 1) {
    const current = argv[index];
    if (!current.startsWith('--')) {
      continue;
    }
    const key = current.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith('--')) {
      result[key] = true;
      continue;
    }
    result[key] = next;
    index += 1;
  }
  return result;
}

function formatDateInTimeZone(date, timeZone) {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(date);
}

async function safeReadDir(dirPath) {
  try {
    return await fs.readdir(dirPath, { withFileTypes: true });
  } catch (error) {
    if (error && error.code === 'ENOENT') {
      return [];
    }
    throw error;
  }
}

async function safeReadJson(filePath) {
  try {
    return JSON.parse(await fs.readFile(filePath, 'utf8'));
  } catch (error) {
    return null;
  }
}

async function collectSessionsForDate(sessionRoot, agent, parts) {
  const dirPath = path.join(sessionRoot, agent, parts.year, parts.month, parts.day);
  const entries = await safeReadDir(dirPath);
  const metaFiles = entries
    .filter((entry) => entry.isFile() && entry.name.endsWith('.meta.json'))
    .map((entry) => entry.name)
    .sort();

  const sessions = [];
  for (const metaFile of metaFiles) {
    const metaPath = path.join(dirPath, metaFile);
    const meta = await safeReadJson(metaPath);
    if (!meta) {
      continue;
    }
    const sessionId = meta.session_id || path.basename(metaFile, '.meta.json');
    sessions.push({
      agent,
      sessionId,
      cwd: meta.cwd || null,
      hostname: meta.hostname || null,
      source: meta.source || null,
      transcriptPath: meta.transcript_path || null,
      metaPath,
      jsonlPath: path.join(dirPath, `${sessionId}.jsonl`),
      uploadedAt: meta.uploaded_at || null,
    });
  }

  return {
    dirPath,
    count: sessions.length,
    sessions,
  };
}

async function collectPriorSummaryFiles(outputsRoot, targetDate) {
  const summaryDir = path.join(outputsRoot, 'summaries', 'daily');
  const entries = await safeReadDir(summaryDir);
  return entries
    .filter((entry) => entry.isFile() && /^\d{4}-\d{2}-\d{2}\.md$/.test(entry.name))
    .map((entry) => entry.name)
    .filter((name) => name.slice(0, 10) < targetDate)
    .sort()
    .reverse()
    .slice(0, 14)
    .map((name) => path.join(summaryDir, name));
}

function buildMarkdown(context) {
  const lines = [];
  lines.push(`# Agent Session Feedback Context (${context.date})`);
  lines.push('');
  lines.push(`- Generated at: ${context.generatedAt}`);
  lines.push(`- Session root: ${context.paths.sessionRoot}`);
  lines.push(`- Repo root: ${context.paths.repoRoot}`);
  lines.push(`- Workspace root: ${context.paths.workspaceRoot}`);
  lines.push('');
  lines.push('## Current day sessions');
  lines.push('');

  for (const agent of ['codex', 'claude']) {
    const info = context.currentDay[agent];
    lines.push(`### ${agent}`);
    lines.push('');
    lines.push(`- Count: ${info.count}`);
    lines.push(`- Directory: ${info.dirPath}`);
    for (const session of info.sessions) {
      lines.push(`- ${session.sessionId} | ${session.hostname || 'unknown-host'} | ${session.cwd || 'unknown-cwd'}`);
    }
    lines.push('');
  }

  lines.push('## Prior summaries');
  lines.push('');
  if (context.priorSummaryFiles.length === 0) {
    lines.push('- none');
  } else {
    for (const filePath of context.priorSummaryFiles) {
      lines.push(`- ${filePath}`);
    }
  }
  lines.push('');

  lines.push('## Rule targets');
  lines.push('');
  for (const [label, filePath] of Object.entries(context.ruleTargets)) {
    lines.push(`- ${label}: ${filePath}`);
  }
  lines.push('');

  lines.push('## Output targets');
  lines.push('');
  for (const [label, filePath] of Object.entries(context.outputTargets)) {
    lines.push(`- ${label}: ${filePath}`);
  }
  lines.push('');

  return `${lines.join('\n')}\n`;
}

async function ensureDir(dirPath) {
  await fs.mkdir(dirPath, { recursive: true });
}

async function main() {
  const args = parseArgs(process.argv);
  const timeZone = args.tz || 'Asia/Seoul';
  const home = os.homedir();
  const sessionRoot = args['session-root'] || path.join(home, 'agent-sessions');
  const repoRoot = args['repo-root'] || path.join(home, 'development', 'nix-flakes');
  const workspaceRoot = args['workspace-root'] || path.join(home, '.openclaw', 'workspace');
  const outputsRoot = args['outputs-root'] || path.join(sessionRoot, 'review');
  const targetDate = args.date || formatDateInTimeZone(new Date(), timeZone);
  const [year, month, day] = targetDate.split('-');
  const parts = { year, month, day };

  const currentDay = {
    codex: await collectSessionsForDate(sessionRoot, 'codex', parts),
    claude: await collectSessionsForDate(sessionRoot, 'claude', parts),
  };

  const contextDir = path.join(outputsRoot, 'context');
  const summaryDir = path.join(outputsRoot, 'summaries', 'daily');
  const analysisDir = path.join(outputsRoot, 'analysis');
  const proposalsDir = path.join(outputsRoot, 'proposals');
  const reportsDir = path.join(outputsRoot, 'reports');

  await Promise.all([
    ensureDir(contextDir),
    ensureDir(summaryDir),
    ensureDir(analysisDir),
    ensureDir(proposalsDir),
    ensureDir(reportsDir),
  ]);

  const priorSummaryFiles = await collectPriorSummaryFiles(outputsRoot, targetDate);
  const context = {
    generatedAt: new Date().toISOString(),
    timeZone,
    date: targetDate,
    paths: {
      sessionRoot,
      repoRoot,
      workspaceRoot,
      outputsRoot,
    },
    currentDay,
    priorSummaryFiles,
    ruleTargets: {
      repoCodexRules: path.join(repoRoot, 'AGENTS.md'),
      repoClaudeRules: path.join(repoRoot, 'CLAUDE.md'),
      globalCodexRules: path.join(repoRoot, 'modules', 'codex', 'files', 'AGENTS.md'),
      globalClaudeRules: path.join(repoRoot, 'modules', 'claude', 'files', 'CLAUDE.md'),
      workspaceSkills: path.join(workspaceRoot, 'skills'),
    },
    outputTargets: {
      contextJson: path.join(contextDir, `${targetDate}.json`),
      contextMarkdown: path.join(contextDir, `${targetDate}.md`),
      summary: path.join(summaryDir, `${targetDate}.md`),
      analysis: path.join(analysisDir, `${targetDate}.md`),
      proposals: path.join(proposalsDir, `${targetDate}.md`),
      report: path.join(reportsDir, `${targetDate}.md`),
    },
  };

  await fs.writeFile(context.outputTargets.contextJson, JSON.stringify(context, null, 2) + '\n');
  await fs.writeFile(context.outputTargets.contextMarkdown, buildMarkdown(context));

  process.stdout.write(`${context.outputTargets.contextJson}\n`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack : String(error));
  process.exit(1);
});
