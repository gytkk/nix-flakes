{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  cfg = config.modules.openclaw;
  stateDir = toString cfg.stateDir;
in
{
  options.modules.openclaw = {
    enable = lib.mkEnableOption "runtime integration for a user-managed OpenClaw installation";

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "${homeDirectory}/.openclaw";
      description = "Mutable OpenClaw state and installation directory.";
    };

    disableHermesGateway = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Stop and disable the Hermes messaging gateway during the OpenClaw cutover.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" stateDir;
        message = "modules.openclaw.stateDir must be an absolute path.";
      }
      {
        assertion = !(lib.hasPrefix "/nix/store/" stateDir);
        message = "modules.openclaw.stateDir must point to mutable host storage, not the Nix store.";
      }
    ];

    home.sessionPath = [ "${stateDir}/bin" ];

    xdg.configFile."systemd/user/openclaw-gateway.service.d/20-nix-runtime.conf".text = ''
      [Service]
      Environment="PATH=${stateDir}/bin:${stateDir}/tools/node/bin:/run/current-system/sw/bin:${homeDirectory}/.nix-profile/bin:/etc/profiles/per-user/${username}/bin:${homeDirectory}/.local/bin:${homeDirectory}/bin:/usr/local/bin:/usr/bin:/bin"
      Environment="LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.libcap ]}"
    '';

    home.activation = lib.mkIf cfg.disableHermesGateway {
      disableHermesGateway = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
        if ${pkgs.systemd}/bin/systemctl --user cat hermes-gateway.service >/dev/null 2>&1; then
          run ${pkgs.systemd}/bin/systemctl --user disable --now hermes-gateway.service
        fi
      '';
    };
  };
}
