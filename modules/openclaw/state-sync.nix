{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  common,
  ...
}:
{
  system.activationScripts.openclawSyncGatewayConfig = lib.stringAfter [ "etc" ] ''
    # Ensure /etc/openclaw is a real writable directory.
    # Previous configs used environment.etc which created it as a read-only
    # symlink to the Nix store, incompatible with the dynamic auth conf file.
    if [ -L /etc/openclaw ]; then
      ${pkgs.coreutils}/bin/rm /etc/openclaw
    fi
    ${pkgs.coreutils}/bin/mkdir -p /etc/openclaw

    # Install static Nix-generated config files.
    ${pkgs.coreutils}/bin/install -m 444 ${common.seedConfigFile} /etc/openclaw/openclaw.seed.json
    ${pkgs.coreutils}/bin/install -m 444 ${common.bootstrapScriptFile} /etc/openclaw/bootstrap.sh

    ${pkgs.coreutils}/bin/install -d -m 755 -o ${username} -g users ${pkgs.lib.escapeShellArg "${homeDirectory}/.config/systemd/user/openclaw-gateway.service.d"}
    ${pkgs.coreutils}/bin/install -m 644 -o ${username} -g users ${common.openclawSystemdDropInFile} ${pkgs.lib.escapeShellArg common.openclawSystemdDropInPath}

    CONFIG_FILE=${pkgs.lib.escapeShellArg "${common.stateDir}/openclaw.json"}
    TOKEN_FILE=${pkgs.lib.escapeShellArg common.gatewayTokenPath}
    NGINX_AUTH_FILE=${pkgs.lib.escapeShellArg common.gatewayNginxAuthIncludePath}

    gateway_token=
    if [ -f "$CONFIG_FILE" ]; then
      gateway_token="$(${pkgs.jq}/bin/jq -er '.gateway.auth.token // empty' "$CONFIG_FILE" 2>/dev/null || true)"
    fi

    if [ -z "$gateway_token" ] && [ -s "$TOKEN_FILE" ]; then
      gateway_token="$(${pkgs.coreutils}/bin/cat "$TOKEN_FILE")"
    fi

    if [ -z "$gateway_token" ]; then
      gateway_token="$(${pkgs.openssl}/bin/openssl rand -hex 24)"
    fi

    tmp_token="$(${pkgs.coreutils}/bin/mktemp)"
    printf '%s' "$gateway_token" > "$tmp_token"
    ${pkgs.coreutils}/bin/install -D -o ${username} -g users -m 600 "$tmp_token" "$TOKEN_FILE"
    ${pkgs.coreutils}/bin/rm -f "$tmp_token"

    tmp_auth="$(${pkgs.coreutils}/bin/mktemp)"
    cat > "$tmp_auth" <<EOF
    proxy_set_header Authorization "Bearer $gateway_token";
    EOF
    ${pkgs.coreutils}/bin/install -m 440 -o root -g ${config.services.nginx.group} "$tmp_auth" "$NGINX_AUTH_FILE"
    ${pkgs.coreutils}/bin/rm -f "$tmp_auth"

    if [ ! -f "$CONFIG_FILE" ]; then
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.jq}/bin/jq \
        --arg token "$gateway_token" \
        '
          .gateway.auth.token = $token
        ' \
        ${common.seedConfigFile} > "$tmp"
      ${pkgs.coreutils}/bin/install -D -o ${username} -g users -m 600 "$tmp" "$CONFIG_FILE"
      ${pkgs.coreutils}/bin/rm -f "$tmp"
    fi
  '';
}
