{
  inputs,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  hermesPackage = inputs.hermes-agent.packages.${system}.default;
  qmdPackage = pkgs.callPackage ../../packages/qmd/package.nix { };
  stateDir = "${homeDirectory}/.hermes";
  bootstrapPath = "/etc/hermes-agent/bootstrap.sh";

  hermesRuntimeLibraryPath = lib.makeLibraryPath [ pkgs.libcap ];
  hermesPythonPath = pkgs.python312Packages.makePythonPath [
    pkgs.python312Packages.discordpy
  ];

  hermesServicePath = lib.concatStringsSep ":" [
    "/run/current-system/sw/bin"
    "${homeDirectory}/.nix-profile/bin"
    "/etc/profiles/per-user/${username}/bin"
    "${homeDirectory}/.local/bin"
    "${homeDirectory}/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];

  hermesCliPath = lib.concatStringsSep ":" [
    hermesServicePath
    "${stateDir}/lsp/bin"
    "${homeDirectory}/.npm-global/bin"
    "${homeDirectory}/.volta/bin"
    "${homeDirectory}/.asdf/shims"
    "${homeDirectory}/.bun/bin"
    "${homeDirectory}/.nvm/current/bin"
    "${homeDirectory}/.fnm/current/bin"
    "${homeDirectory}/.local/share/pnpm"
  ];

  hermesSystemdDropInPath = "${homeDirectory}/.config/systemd/user/hermes-gateway.service.d/20-nix-wrapper.conf";
  hermesSystemdDropInFile = pkgs.writeText "hermes-gateway-20-nix-wrapper.conf" ''
    [Service]
    # Route the CLI-installed gateway service through the Nix wrapper so bundled
    # plugins and agenix-backed runtime secrets are available under systemd.
    ExecStart=
    ExecStart=/run/current-system/sw/bin/hermes gateway run --replace
    Environment=HOME=${homeDirectory}
    Environment=HERMES_HOME=${stateDir}
    Environment=PATH=${hermesServicePath}
    Environment=LD_LIBRARY_PATH=${hermesRuntimeLibraryPath}
  '';

  hermesWrapper = pkgs.runCommand "hermes-agent-wrapped" { } ''
    mkdir -p "$out/bin"

    for bin in hermes hermes-agent hermes-acp; do
      cat > "$out/bin/$bin" <<EOF
    #!${pkgs.runtimeShell}
    export HERMES_HOME=${lib.escapeShellArg stateDir}
    export HERMES_PATH_BOOTSTRAPPED=1
    export PATH=${lib.escapeShellArg hermesCliPath}:\$PATH
    export LD_LIBRARY_PATH=${lib.escapeShellArg hermesRuntimeLibraryPath}\''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}
    export PYTHONPATH=${lib.escapeShellArg hermesPythonPath}\''${PYTHONPATH:+:\$PYTHONPATH}

    if [ -r ${lib.escapeShellArg bootstrapPath} ]; then
      . ${lib.escapeShellArg bootstrapPath}
    fi

    exec ${hermesPackage}/bin/$bin "\$@"
    EOF
      chmod +x "$out/bin/$bin"
    done
  '';

  bootstrapScriptFile = pkgs.writeText "hermes-agent-bootstrap.sh" ''
    # Hermes Agent runtime bootstrap for the Nix-managed CLI.
    # Nix provides secret file locations; the wrapper loads only what exists.

    if [ -z "''${DISCORD_BOT_TOKEN-}" ] && [ -r /run/agenix/discord-bot-token ]; then
      export DISCORD_BOT_TOKEN="$(cat /run/agenix/discord-bot-token)"
    fi

    if [ -r /run/agenix/brave-search-api-key ]; then
      if [ -z "''${BRAVE_SEARCH_API_KEY-}" ]; then
        export BRAVE_SEARCH_API_KEY="$(cat /run/agenix/brave-search-api-key)"
      fi
      if [ -z "''${BRAVE_API_KEY-}" ]; then
        export BRAVE_API_KEY="$(cat /run/agenix/brave-search-api-key)"
      fi
    fi

    if [ -z "''${OPENAI_API_KEY-}" ] && [ -r /run/agenix/openai-api-key ]; then
      export OPENAI_API_KEY="$(cat /run/agenix/openai-api-key)"
    fi
  '';
in
{
  age.secrets.discord-bot-token = {
    file = lib.mkDefault ../../secrets/discord-bot-token.age;
    owner = lib.mkDefault username;
    group = lib.mkDefault "users";
    mode = lib.mkDefault "0400";
  };

  environment.sessionVariables.HERMES_HOME = stateDir;

  environment.systemPackages = with pkgs; [
    hermesWrapper
    bun
    chromium
    libcap
    nodejs
    qmdPackage
  ];

  system.activationScripts.hermesAgentSyncConfig = lib.stringAfter [ "etc" ] ''
    if [ -L /etc/hermes-agent ]; then
      ${pkgs.coreutils}/bin/rm /etc/hermes-agent
    fi
    ${pkgs.coreutils}/bin/mkdir -p /etc/hermes-agent
    ${pkgs.coreutils}/bin/install -m 444 ${bootstrapScriptFile} /etc/hermes-agent/bootstrap.sh

    ${pkgs.coreutils}/bin/install -d -m 700 -o ${username} -g users ${lib.escapeShellArg stateDir}
    for subdir in logs sessions memories skills plugins lsp; do
      ${pkgs.coreutils}/bin/install -d -m 700 -o ${username} -g users ${lib.escapeShellArg stateDir}/"$subdir"
    done

    ${pkgs.coreutils}/bin/install -d -m 755 -o ${username} -g users ${lib.escapeShellArg "${homeDirectory}/.config/systemd/user/hermes-gateway.service.d"}
    ${pkgs.coreutils}/bin/install -m 644 -o ${username} -g users ${hermesSystemdDropInFile} ${lib.escapeShellArg hermesSystemdDropInPath}
  '';
}
