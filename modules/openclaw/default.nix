{
  config,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  gatewayPort = 18789;
  stateDir = "${homeDirectory}/.openclaw";
  runtimeConfigPath = "${stateDir}/openclaw.json";
  seedConfigPath = "/etc/openclaw/openclaw.seed.json";

  seedConfig = { };
in
{
  services.openclaw-gateway = {
    enable = true;
    package = pkgs.openclaw-gateway;
    port = gatewayPort;
    user = username;
    group = "users";
    createUser = false;
    stateDir = stateDir;
    configPath = seedConfigPath;
    config = seedConfig;

    environment = {
      OPENCLAW_CONFIG_PATH = runtimeConfigPath;
      CLAWDBOT_CONFIG_PATH = runtimeConfigPath;
    };

    execStartPre = [
      "${pkgs.writeShellScript "openclaw-runtime-config" ''
        set -euo pipefail

        runtime_config=${pkgs.lib.escapeShellArg runtimeConfigPath}
        seed_config=${pkgs.lib.escapeShellArg seedConfigPath}
        state_dir=${pkgs.lib.escapeShellArg stateDir}

        mkdir -p "$state_dir"

        if [ -L "$runtime_config" ]; then
          migrated_file="$(${pkgs.coreutils}/bin/mktemp "$state_dir/openclaw.json.migrate.XXXXXX")"
          ${pkgs.coreutils}/bin/cp --dereference "$runtime_config" "$migrated_file"
          ${pkgs.coreutils}/bin/chmod 600 "$migrated_file"
          ${pkgs.coreutils}/bin/mv -f "$migrated_file" "$runtime_config"
        fi

        if [ ! -e "$runtime_config" ]; then
          seeded_file="$(${pkgs.coreutils}/bin/mktemp "$state_dir/openclaw.json.seed.XXXXXX")"
          ${pkgs.coreutils}/bin/cp "$seed_config" "$seeded_file"
          ${pkgs.coreutils}/bin/chmod 600 "$seeded_file"
          ${pkgs.coreutils}/bin/mv -f "$seeded_file" "$runtime_config"
        fi

        ${pkgs.jq}/bin/jq -e . "$runtime_config" >/dev/null
      ''}"
    ];

    servicePath = with pkgs; [
      bun
      nodejs
    ];
  };

  environment.systemPackages = [ pkgs.openclaw-gateway ];

}
