# OpenClaw-specific rules

## Model routing

- Use the configured `astra` subagent for high-stakes or ambiguous end-to-end work, deep debugging, complex design, security-sensitive review, and costly failures.
- Use the configured `sol` subagent at `xhigh` for normal implementation, testing, research, and substantial deliverables. Incorporate delegated results before replying.
- Treat `astra` and `sol` as OpenClaw agent IDs, not CLI profile names. If the selected agent is unavailable, use the closest available agent for the task and report the fallback.
