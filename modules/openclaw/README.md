# OpenClaw

OpenClaw is installed with the official rootless installer under `~/.openclaw`.
The application owns its executable, plugins, mutable configuration, state,
updates, and systemd user service.

This directory contains only declarative host integration:

- `default.nix` provides NixOS dependencies, the agenix Discord token, runtime
  environment variables, and proxy authentication.
- `nginx-proxy.nix` provides the LAN and public-origin reverse proxies and the
  LAN firewall rule.
- `home.nix` adds the user-owned executable to `PATH` and supplies the NixOS
  runtime paths required by the OpenClaw-managed user service. It can also link
  the repository-managed `agent-session-record` plugin into the global OpenClaw
  extension directory.

The modules do not install an OpenClaw package, generate `openclaw.json`, set
`OPENCLAW_NIX_MODE`, or own `openclaw-gateway.service`.

The session recorder subscribes to OpenClaw's `session_end` plugin event and
passes the native transcript path to `agent-session-record`. It does not receive
or upload the raw session key. If mutable OpenClaw configuration defines
`plugins.allow`, include `agent-session-record` in that list.
