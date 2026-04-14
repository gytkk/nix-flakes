{
  inputs,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}@args:
let
  gatewayPort = 18789;
  lanProxyPort = 18790;
  lanInterface = "wlo1";
  openclawPackage = inputs.flake-stores.packages.${pkgs.system}.openclaw;
  stateDir = "${homeDirectory}/.openclaw";
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

  openclawSystemdDropInPath = "${homeDirectory}/.config/systemd/user/openclaw-gateway.service.d/20-nix-path.conf";
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
      tailscale.mode = "off";
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
      openclawBootstrapPath
      openclawHybridCli
      openclawPackage
      openclawRuntimeLibraryPath
      openclawServicePath
      openclawSystemdDropInFile
      openclawSystemdDropInPath
      seedConfigFile
      stateDir;
  };
in
lib.mkMerge [
  {
    age.secrets.discord-bot-token = {
      file = ../../secrets/discord-bot-token.age;
      owner = username;
      group = "users";
      mode = "0400";
    };

    environment.systemPackages = with pkgs; [
      openclawHybridCli
      bun
      libcap
      nodejs
    ];
  }
  (import ./state-sync.nix (args // { inherit common; }))
  (import ./nginx-proxy.nix (args // { inherit common; }))
]
