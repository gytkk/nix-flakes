# Pi coding agent setup plan

This document records the first-stage Pi configuration for making Pi a stronger
OpenAI Codex harness while keeping the initial extension surface bounded and
reviewable.

## Goals

- Adapt Pi's prompt and core file/shell tools to the dialect expected by Codex
  models.
- Add structured user questions and web research.
- Add focused subagents with conservative defaults and model routing.
- Keep plan mode, native Responses compaction, Code Mode, voice, image
  generation, memory, and autonomous scheduling out of the first stage.
- Keep package versions pinned and configuration managed from this repository.

## Packages

Pin the initial package set in Pi's global `settings.json`:

| Package | Version | Purpose |
| --- | --- | --- |
| `@howaboua/pi-codex-conversion` | `3.0.8` | Codex-oriented system prompt and structured shell/patch tools |
| `@juicesharp/rpiv-ask-user-question` | `2.4.0` | Structured `ask_user_question` interaction |
| `pi-web-access` | `0.18.0` | Web search, source verification, and content extraction |
| `pi-subagents` | `0.41.0` | Focused scout, planner, worker, reviewer, researcher, and oracle agents |

Expected package declarations:

```json
{
  "packages": [
    "npm:@howaboua/pi-codex-conversion@3.0.8",
    "npm:@juicesharp/rpiv-ask-user-question@2.4.0",
    "npm:pi-web-access@0.18.0",
    "npm:pi-subagents@0.41.0"
  ]
}
```

Pinned npm versions are intentionally skipped by `pi update --extensions`.
Upgrade each package through a reviewed repository change rather than accepting
unbounded runtime updates.

Pi packages execute with the full permissions of the Pi process. Review package
source and release changes before updating a pin.

## Codex adapter scope

Use the normal structured adapter, not Code Mode or extra-tools-only mode. The
normal adapter replaces Pi's `read`, `bash`, `edit`, and `write` surface with:

- `exec_command`
- `write_stdin`
- `apply_patch`

Enable the adapter's Codex-oriented system-prompt rewrite. Project context,
`AGENTS.md`, and configured skills must remain available after rewriting.

Disable all other optional adapter behavior for the first stage:

- `web_run`: disabled because `pi-web-access` owns web research
- `imagegen`: disabled
- text image descriptions: disabled
- `view_image`: accepted as a known package limitation for image-capable Codex
  models; normal structured mode currently adds it without a disable setting
- GPT-5.6 Code Mode: disabled
- Responses Lite: disabled
- native Responses compaction: disabled
- adapter fast mode: disabled because the repository already provides
  `codex-fast-mode.ts`
- forced cached WebSocket transport: disabled
- all-provider activation: disabled; activate only for Codex-like models
- additional provider activation: empty
- adapter status line and background-shell widget: disabled initially to avoid
  competing with the repository's custom footer

Manage `~/.pi/agent/pi-codex-conversion.json` from
`modules/pi/files/pi-codex-conversion.json` with the following effective values:

```json
{
  "voiceFeaturesOnly": false,
  "prompt": {
    "heavySystemPromptOverwrite": true
  },
  "scope": {
    "allProviders": "off",
    "additionalProviders": []
  },
  "tools": {
    "customRustBinariesDir": "",
    "webRun": false,
    "imageGeneration": false,
    "viewImageFallback": false,
    "applyPatchOnly": false,
    "viewImageOnly": false,
    "webRunOnly": false,
    "imageGenerationOnly": false
  },
  "ui": {
    "statusLine": false,
    "toolRenaming": true,
    "compactTools": false,
    "codeModeDetails": false,
    "backgroundShellWidget": false,
    "backgroundShellToggleShortcut": "alt+w",
    "backgroundShellPrevShortcut": "alt+q",
    "backgroundShellNextShortcut": "alt+e",
    "backgroundShellCloseShortcut": "alt+r"
  },
  "compaction": {
    "responsesCompaction": false
  },
  "beta": {
    "codeMode": false,
    "responsesLite": false,
    "v2UserMessageRetention": 64
  },
  "openai": {
    "fast": false,
    "verbosity": "low",
    "forceCachedWebSockets": false,
    "harnessIdentifierHeader": false,
    "webSearchModel": "gpt-5.6-luna"
  }
}
```

The extension fills omitted voice defaults internally. Do not enable voice
shortcuts or the LAN voice server as part of this stage.

Normal structured mode currently activates `view_image` automatically when the
selected Codex model supports image input. The package does not expose a
`viewImage: false` setting: `viewImageFallback` controls only text descriptions,
and `viewImageOnly` controls extra-tools-only activation. Accept `view_image` as
the sole non-core adapter tool in this stage instead of maintaining a fork or a
fragile active-tool filtering hook. Revisit this decision if the package adds a
native disable option.

### Existing fast extension

Keep `modules/pi/files/extensions/codex-fast-mode.ts` as the sole owner of
`service_tier: "priority"` and `/fast`. The Codex adapter's own fast mode must
remain off. Verify after integration that only one footer is installed and that
`/fast status` still reports the effective state.

## Structured questions

Load `@juicesharp/rpiv-ask-user-question` without custom configuration at first.
It adds one `ask_user_question` tool, does not make its own model calls, and has
no native runtime dependency.

The global Pi instructions should continue to require the agent to investigate
safe, discoverable facts before asking. Use the question tool only for material,
non-discoverable decisions and present mutually exclusive choices with a
recommendation when genuine alternatives exist.

## Web access

Use `pi-web-access` as the only first-stage web extension. Its expected tools
are:

- `web_search`
- `source_check`
- `fetch_content`
- `get_search_content`

This tool set also satisfies the bundled `pi-subagents` researcher profile.
Keep the Codex adapter's `web_run` disabled to avoid overlapping web schemas.

Start with the zero-configuration provider path. Pi's Codex login may be reused
for OpenAI search, with Exa available as the package's keyless fallback. Do not
enable browser-cookie access, Gemini Web cookie extraction, remote curator
binding, paid explicit-only providers, or fresh Firecrawl scraping by default.

Secrets must not be committed to this repository. If provider credentials are
added later, reference environment variables or a secret-manager command from
`~/.pi/web-search.json`.

## Subagents

Install `pi-subagents`, but keep its initial behavior bounded:

- run foreground by default so results remain easy to observe
- store artifacts under the Pi session directory, not in the repository
- disable automatic missions and schedules
- cap parallel fan-out and total child launches
- do not enable watchdogs, persistent agent memory, worktree isolation, or
  nested delegation in the first stage
- never use git worktrees in this repository

Manage `~/.pi/agent/extensions/subagent/config.json` from
`modules/pi/files/subagent.json`:

```json
{
  "asyncByDefault": false,
  "artifactDir": "session",
  "maxSubagentSpawnsPerSession": 12,
  "parallel": {
    "maxTasks": 4,
    "concurrency": 2
  },
  "scheduledRuns": {
    "enabled": false
  },
  "missions": {
    "enabled": false
  }
}
```

Use Pi's main settings for role-specific model routing:

```json
{
  "subagents": {
    "agentOverrides": {
      "scout": {
        "model": "openai-codex/gpt-5.6-luna",
        "thinking": "low"
      },
      "researcher": {
        "model": "openai-codex/gpt-5.6-luna",
        "thinking": "low"
      },
      "worker": {
        "model": "openai-codex/gpt-5.6-terra",
        "thinking": "medium"
      },
      "reviewer": {
        "model": "openai-codex/gpt-5.6-terra",
        "thinking": "medium"
      },
      "planner": {
        "model": "openai-codex/gpt-5.6-sol",
        "thinking": "high"
      },
      "oracle": {
        "model": "openai-codex/gpt-5.6-sol",
        "thinking": "high"
      }
    }
  }
}
```

Use `scout` and `researcher` for bounded discovery, `worker` for implementation,
`reviewer` for an independent check, and `planner` or `oracle` only when the
problem warrants the stronger model. Do not make automatic subagent review a
global requirement until ordinary single-agent behavior is stable.

Run `/subagents-doctor` and `/subagents-models` after installation. Confirm that
the researcher receives the `pi-web-access` tools and that child sessions still
inherit applicable project `AGENTS.md` instructions.

The bundled agents declare Pi-native tool allowlists such as `read`, `bash`, and
`edit`, while the Codex adapter replaces those active names with
`exec_command`, `write_stdin`, and `apply_patch`. Their interaction is not
explicitly documented by either package, so child startup and tool preflight are
a required compatibility gate. If a child reports unavailable declared tools,
do not disable validation globally. Instead, keep the Codex adapter out of child
sessions or define small Codex-specific child profiles with matching tool names.

## Main Pi settings

Manage `~/.pi/agent/settings.json` from `modules/pi/files/settings.json`. The
reviewed starter configuration is:

```json
{
  "theme": "dark",
  "defaultProvider": "openai-codex",
  "defaultModel": "gpt-5.6-sol",
  "defaultThinkingLevel": "high",
  "enabledModels": [
    "openai-codex/gpt-5.6-luna",
    "openai-codex/gpt-5.6-terra",
    "openai-codex/gpt-5.6-sol"
  ],
  "defaultProjectTrust": "ask",
  "externalEditor": "nvim",
  "doubleEscapeAction": "tree",
  "treeFilterMode": "no-tools",
  "packages": [
    "npm:@howaboua/pi-codex-conversion@3.0.8",
    "npm:@juicesharp/rpiv-ask-user-question@2.4.0",
    "npm:pi-web-access@0.18.0",
    "npm:pi-subagents@0.41.0"
  ],
  "subagents": {
    "agentOverrides": {
      "scout": {
        "model": "openai-codex/gpt-5.6-luna",
        "thinking": "low"
      },
      "researcher": {
        "model": "openai-codex/gpt-5.6-luna",
        "thinking": "low"
      },
      "worker": {
        "model": "openai-codex/gpt-5.6-terra",
        "thinking": "medium"
      },
      "reviewer": {
        "model": "openai-codex/gpt-5.6-terra",
        "thinking": "medium"
      },
      "planner": {
        "model": "openai-codex/gpt-5.6-sol",
        "thinking": "high"
      },
      "oracle": {
        "model": "openai-codex/gpt-5.6-sol",
        "thinking": "high"
      }
    }
  }
}
```

Review notes:

- Keep Sol/high as the quality-oriented parent default.
- Scope model cycling to Luna, Terra, and Sol rather than every authenticated
  model.
- Keep project trust at `ask`; it is not a sandbox, but prevents silent loading
  of project-local extensions and settings.
- Use the existing `/tree` flow on double Escape and hide tool entries by
  default in the tree for easier navigation.
- Set `nvim` explicitly so `Ctrl+G` does not depend on shell environment.
- Leave compaction, retry, transport, steering, and follow-up settings at Pi's
  maintained defaults until measurements show a reason to override them.
- Do not enable `showCacheMissNotices` globally; it is useful only during
  focused cache diagnostics and adds transcript noise.

Set prompt-cache retention through Home Manager:

```nix
home.sessionVariables.PI_CACHE_RETENTION = "long";
```

This requests the provider's extended cache retention for repeated work in the
same project. Remove it if longer provider-side prompt retention is not desired.

## Deferred features

Do not include these in the first implementation:

- `@narumitw/pi-plan-mode` or Plannotator plan mode
- GPT-5.6 Code Mode
- native Responses compaction
- adapter-provided `web_run`, image generation, image descriptions, or voice;
  `view_image` remains the documented structured-mode exception
- subagent watchdogs, persistent memory, schedules, automatic missions, or
  worktree isolation
- additional status-line/footer packages

## Implementation outline

1. Add the pinned package list and reviewed starter settings.
2. Add the minimal Codex adapter configuration.
3. Add the conservative subagent runtime configuration.
4. Wire all three JSON files through `modules/pi/default.nix` using the module's
   existing out-of-store symlink pattern.
5. Add `PI_CACHE_RETENTION=long` to the Pi module's Home Manager configuration.
6. Reconcile the adapter with the existing fast-mode extension without
   overwriting unrelated local changes.
7. Format changed Nix files with `nixfmt`.

## Verification

After implementation:

1. Run `pi list` and confirm all four pinned packages are present.
2. Start Pi and confirm the model sees `exec_command`, `write_stdin`, and
   `apply_patch`, but not Pi's original `read`, `bash`, `edit`, and `write`.
3. Confirm `web_run`, `imagegen`, Code Mode `exec`/`wait`, and native compaction
   are absent or disabled; `view_image` is the only accepted extra adapter tool.
4. Confirm the Codex-oriented prompt still contains global and project
   `AGENTS.md` context and available skills.
5. Run `/fast status` and verify only the repository fast extension controls
   priority mode and the footer remains correct.
6. Ask a task with a material ambiguity and verify `ask_user_question` opens
   the structured TUI.
7. Exercise `web_search`, `fetch_content`, and `source_check` without enabling
   browser-cookie access or paid providers.
8. Run `/subagents-doctor` and `/subagents-models`.
9. Run one foreground `scout`, one `researcher`, and one `reviewer`; verify the
   configured model tiers, inherited project rules, web tools, and session-local
   artifacts.
10. Confirm no `.pi-subagents` artifacts or git worktrees were created in this
    repository.
11. Run `nixfmt` on changed Nix files and `nix flake check --no-build` for the
    final module wiring validation.

Apply the Home Manager configuration only after reviewing the resulting diff;
the user runs `home-manager switch --flake .#<environment>`.
