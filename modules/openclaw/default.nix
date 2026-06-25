{
  config,
  inputs,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}@args:
let
  cfg = config.modules.openclaw;
  gatewayPort = cfg.gatewayPort;
  lanProxyPort = cfg.lanProxyPort;
  publicProxyPort = cfg.publicProxyPort;
  lanInterface = cfg.lanInterface;
  openclawPackage = inputs.flake-stores.packages.${pkgs.system}.openclaw;
  qmdPackage = pkgs.callPackage ../../packages/qmd/package.nix { };
  stateDir = toString cfg.stateDir;
  gatewayTokenPath = "${stateDir}/gateway-auth-token";
  gatewayNginxAuthIncludePath = "/etc/openclaw/nginx-gateway-auth.conf";
  openclawBootstrapPath = "/etc/openclaw/bootstrap.sh";

  openclawRuntimeLibraryPath = lib.makeLibraryPath [ pkgs.libcap ];

  openclawServicePath = lib.concatStringsSep ":" [
    "/run/current-system/sw/bin"
    "${homeDirectory}/.nix-profile/bin"
    "/etc/profiles/per-user/${username}/bin"
    "${homeDirectory}/.local/bin"
    "${homeDirectory}/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];

  openclawCliPath = lib.concatStringsSep ":" [
    openclawServicePath
    "${homeDirectory}/.npm-global/bin"
    "${homeDirectory}/.volta/bin"
    "${homeDirectory}/.asdf/shims"
    "${homeDirectory}/.bun/bin"
    "${homeDirectory}/.nvm/current/bin"
    "${homeDirectory}/.fnm/current/bin"
    "${homeDirectory}/.local/share/pnpm"
  ];

  openclawSystemdDropInDir = "${homeDirectory}/.config/systemd/user/openclaw-gateway.service.d";
  openclawSystemdDropInPath = "${openclawSystemdDropInDir}/20-nix-path.conf";
  openclawSystemdDropInFile = pkgs.writeText "openclaw-gateway-20-nix-path.conf" ''
    [Service]
    # NixOS-specific PATH shim for the hybrid OpenClaw setup.
    Environment=PATH=${openclawServicePath}
    Environment=LD_LIBRARY_PATH=${openclawRuntimeLibraryPath}
  '';

  openclawHybridCli = pkgs.writeShellScriptBin "openclaw" ''
    export OPENCLAW_NIX_MODE=
    # NixOS-specific PATH shim for this hybrid setup.
    export PATH="${openclawCliPath}:$PATH"
    export LD_LIBRARY_PATH="${openclawRuntimeLibraryPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export OPENCLAW_PATH_BOOTSTRAPPED=1

    if [ -r ${pkgs.lib.escapeShellArg openclawBootstrapPath} ]; then
      . ${pkgs.lib.escapeShellArg openclawBootstrapPath}
    fi

    # Use the upstream-layout package from flake-stores so bundled skills resolve
    # correctly, while keeping the local bootstrap and PATH handling in this wrapper.
    exec ${openclawPackage}/bin/openclaw "$@"
  '';

  seedConfig = {
    gateway = {
      mode = "local";
      auth.mode = "token";
      port = gatewayPort;
      bind = "loopback";
      http = {
        endpoints.chatCompletions.enabled = true;
      };
      controlUi = {
        enabled = true;
      };
      tailscale.mode = "off";
    };
    browser = {
      enabled = true;
      defaultProfile = "openclaw";
      executablePath = "/run/current-system/sw/bin/chromium";
      headless = true;
      actionTimeoutMs = 60000;
      tabCleanup = {
        enabled = true;
        idleMinutes = 120;
        maxTabsPerSession = 8;
        sweepMinutes = 5;
      };
      profiles = {
        openclaw = {
          cdpPort = 18800;
          color = "#FF4500";
        };
        user = {
          driver = "existing-session";
          attachOnly = true;
          color = "#00AA00";
        };
      };
    };
    plugins.entries.browser.enabled = true;
    messages.groupChat.visibleReplies = "message_tool";
    agents.defaults.bootstrapMaxChars = 20000;
    channels.discord.threadBindings = {
      enabled = true;
      idleHours = 168;
      maxAgeHours = 0;
      spawnSessions = true;
      spawnSubagentSessions = true;
      # Keep Discord Codex/ACP workflows on explicit existing-thread binds.
      # This avoids the current ACP tool-path parity gap where thread spawns can
      # resolve as child placement instead of true "--bind here" semantics.
      spawnAcpSessions = false;
      defaultSpawnContext = "fork";
    };
    session.threadBindings = {
      enabled = true;
      idleHours = 168;
      maxAgeHours = 0;
      spawnSessions = true;
      defaultSpawnContext = "fork";
    };
  };

  seedConfigFile = pkgs.writeText "openclaw-seed.json" (builtins.toJSON seedConfig);

  bootstrapScriptFile = pkgs.writeText "openclaw-bootstrap.sh" ''
    # OpenClaw runtime bootstrap for the hybrid Nix + user-managed service setup.
    # Nix provides secret file locations; the wrapper loads only what exists.

    if [ -z "''${DISCORD_BOT_TOKEN-}" ] && [ -r /run/agenix/discord-bot-token ]; then
      export DISCORD_BOT_TOKEN="$(cat /run/agenix/discord-bot-token)"
    fi

    if [ -z "''${BRAVE_API_KEY-}" ] && [ -r /run/agenix/brave-search-api-key ]; then
      export BRAVE_API_KEY="$(cat /run/agenix/brave-search-api-key)"
    fi
  '';

  common = {
    inherit
      bootstrapScriptFile
      gatewayNginxAuthIncludePath
      gatewayPort
      gatewayTokenPath
      lanInterface
      lanProxyPort
      publicProxyPort
      openclawBootstrapPath
      openclawHybridCli
      openclawPackage
      openclawRuntimeLibraryPath
      openclawServicePath
      openclawSystemdDropInDir
      openclawSystemdDropInFile
      openclawSystemdDropInPath
      seedConfigFile
      stateDir
      ;
  };
in
{
  imports = [
    inputs.agenix.nixosModules.default
  ];

  options.modules.openclaw = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the OpenClaw hybrid gateway module";
    };
    gatewayPort = lib.mkOption {
      type = lib.types.port;
      default = 18789;
      description = "Loopback OpenClaw gateway port";
    };
    lanProxyPort = lib.mkOption {
      type = lib.types.port;
      default = 18790;
      description = "LAN nginx proxy port for OpenClaw";
    };
    publicProxyPort = lib.mkOption {
      type = lib.types.port;
      default = 18791;
      description = "Loopback public-origin nginx proxy port for OpenClaw";
    };
    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Network interface that receives LAN OpenClaw traffic";
    };
    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "${homeDirectory}/.openclaw";
      description = "OpenClaw state directory";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.lanInterface != "";
            message = "modules.openclaw.lanInterface must be set when modules.openclaw.enable is true.";
          }
          {
            assertion = lib.hasPrefix "/" stateDir;
            message = "modules.openclaw.stateDir must be an absolute path.";
          }
          {
            assertion = !(lib.hasPrefix "/nix/store/" stateDir);
            message = "modules.openclaw.stateDir must point to mutable host storage, not the Nix store.";
          }
        ];

        age.secrets.discord-bot-token = {
          file = ../../secrets/discord-bot-token.age;
          owner = username;
          group = "users";
          mode = "0400";
        };

        environment.systemPackages = with pkgs; [
          openclawHybridCli
          bun
          chromium
          libcap
          nodejs
          qmdPackage
        ];
      }
      (import ./state-sync.nix (args // { inherit common; }))
      (import ./nginx-proxy.nix (args // { inherit common; }))
    ]
  );
}
