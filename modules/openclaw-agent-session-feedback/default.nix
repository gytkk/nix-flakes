{
  config,
  lib,
  pkgs,
  flakeDirectory,
  osConfig ? null,
  ...
}:

let
  cfg = config.modules.openclawAgentSessionFeedback;
  isPylvOnyx = osConfig != null && (osConfig.networking.hostName or null) == "pylv-onyx";
  mkSymlink =
    path:
    config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/openclaw-agent-session-feedback/${path}";
  automationRoot = "${config.home.homeDirectory}/.openclaw/workspace/automation/agent-session-feedback";
  openclawBin = if isPylvOnyx then "/run/current-system/sw/bin/openclaw" else "openclaw";
  promptTemplate = builtins.readFile ./files/automation/agent-session-feedback/CRON_PROMPT.txt;
  cronPromptText =
    lib.replaceStrings [ "__REPORT_CHANNEL_ID__" ] [ cfg.cron.channelId ]
      promptTemplate;
  syncCronScript = ''
    #!/usr/bin/env bash
    set -euo pipefail

    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.jq
      ]
    }:$PATH"

    OPENCLAW_BIN=${lib.escapeShellArg openclawBin}
    JOB_ID=${lib.escapeShellArg cfg.cron.id}
    JOB_NAME=${lib.escapeShellArg cfg.cron.name}
    JOB_DESCRIPTION=${lib.escapeShellArg cfg.cron.description}
    JOB_EXPR=${lib.escapeShellArg cfg.cron.expr}
    JOB_TZ=${lib.escapeShellArg cfg.cron.timezone}
    MESSAGE_FILE=${lib.escapeShellArg "${automationRoot}/CRON_PROMPT.txt"}

    if [ ! -x "$OPENCLAW_BIN" ]; then
      exit 0
    fi

    if [ ! -r "$MESSAGE_FILE" ]; then
      exit 0
    fi

    if ! "$OPENCLAW_BIN" cron status >/dev/null 2>&1; then
      exit 0
    fi

    message="$(${pkgs.coreutils}/bin/cat "$MESSAGE_FILE")"
    jobs_json="$($OPENCLAW_BIN cron list --json 2>/dev/null || true)"
    exists="$(${pkgs.jq}/bin/jq -r --arg id "$JOB_ID" '.jobs[]? | select(.id == $id) | .id' <<<"$jobs_json" | head -n 1)"

    if [ -n "$exists" ]; then
      "$OPENCLAW_BIN" cron edit "$JOB_ID" \
        --name "$JOB_NAME" \
        --description "$JOB_DESCRIPTION" \
        --cron "$JOB_EXPR" \
        --tz "$JOB_TZ" \
        --session isolated \
        --agent main \
        --message "$message" \
        --thinking medium \
        --timeout-seconds 1800 \
        --light-context \
        --no-deliver \
        --exact \
        >/dev/null
    else
      "$OPENCLAW_BIN" cron add \
        --name "$JOB_NAME" \
        --description "$JOB_DESCRIPTION" \
        --cron "$JOB_EXPR" \
        --tz "$JOB_TZ" \
        --session isolated \
        --agent main \
        --message "$message" \
        --thinking medium \
        --timeout-seconds 1800 \
        --light-context \
        --no-deliver \
        --exact \
        --json \
        >/dev/null

      fresh_jobs_json="$($OPENCLAW_BIN cron list --json 2>/dev/null || true)"
      created_id="$(${pkgs.jq}/bin/jq -r --arg name "$JOB_NAME" '.jobs[]? | select(.name == $name) | .id' <<<"$fresh_jobs_json" | head -n 1)"
      if [ -n "$created_id" ] && [ "$created_id" != "$JOB_ID" ]; then
        "$OPENCLAW_BIN" cron edit "$created_id" --name "$JOB_NAME" >/dev/null || true
      fi
    fi
  '';
in
{
  options.modules.openclawAgentSessionFeedback = {
    enable = lib.mkEnableOption "OpenClaw agent session feedback automation";
    cron = {
      id = lib.mkOption {
        type = lib.types.str;
        default = "agent-session-feedback-daily";
        description = "Stable OpenClaw cron job id for the daily agent session feedback loop";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "Agent Session Feedback Daily";
        description = "Display name for the OpenClaw cron job";
      };
      description = lib.mkOption {
        type = lib.types.str;
        default = "Claude/Codex session logs 기반 daily feedback loop로 summary, analysis, report, AGENTS/CLAUDE 개선안을 반영";
        description = "Description for the OpenClaw cron job";
      };
      expr = lib.mkOption {
        type = lib.types.str;
        default = "30 5 * * *";
        description = "Cron expression for the daily feedback loop";
      };
      timezone = lib.mkOption {
        type = lib.types.str;
        default = "Asia/Seoul";
        description = "Timezone for the OpenClaw cron job";
      };
      channelId = lib.mkOption {
        type = lib.types.str;
        default = "1496082783892803714";
        description = "Discord channel id that receives the daily feedback report";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = isPylvOnyx;
        message = "modules.openclawAgentSessionFeedback is intended for pylv-onyx only";
      }
    ];

    home.file.".openclaw/workspace/automation/agent-session-feedback/README.md".source =
      mkSymlink "files/automation/agent-session-feedback/README.md";

    home.file.".openclaw/workspace/automation/agent-session-feedback/RUNBOOK.md".source =
      mkSymlink "files/automation/agent-session-feedback/RUNBOOK.md";

    home.file.".openclaw/workspace/automation/agent-session-feedback/build_context.mjs".source =
      mkSymlink "files/automation/agent-session-feedback/build_context.mjs";

    home.file.".openclaw/workspace/automation/agent-session-feedback/CRON_PROMPT.txt".text =
      cronPromptText;

    home.file.".local/bin/openclaw-sync-agent-session-feedback-cron" = {
      text = syncCronScript;
      executable = true;
    };

    home.activation.openclawAgentSessionFeedbackCron = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      "$HOME/.local/bin/openclaw-sync-agent-session-feedback-cron" || true
    '';
  };
}
