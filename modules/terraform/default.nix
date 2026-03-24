{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.terraform;
  system = pkgs.stdenv.hostPlatform.system;
  terraformPkgs = inputs.nixpkgs-terraform.packages.${system};
in
{
  options.modules.terraform = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Terraform version management with nixpkgs-terraform";
    };

    versions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of available terraform versions (loaded lazily via direnv)";
      example = [
        "1.10.5"
        "1.12.2"
      ];
    };

    defaultVersion = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "Default terraform version to use";
    };

    runEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Environment variables to set when running terraform";
      example = {
        TF_VAR_ENVIRONMENT = "dev";
        AWS_REGION = "ap-northeast-1";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Only install default terraform version
    # Other versions are loaded lazily via direnv + nix-direnv
    home.packages = [
      (
        if cfg.defaultVersion == "latest" then
          pkgs.terraform
        else
          terraformPkgs.${"terraform-${cfg.defaultVersion}"}
      )
    ];

    # Configure nixpkgs to allow unfree for terraform
    nixpkgs.config.allowUnfree = true;

    # Add tf alias that uses the terraform binary from PATH (respects direnv)
    home.shellAliases = {
      tf =
        let
          envPrefix = lib.optionalString (cfg.runEnv != { }) (
            lib.concatStringsSep " " (lib.mapAttrsToList (name: value: "${name}=${value}") cfg.runEnv) + " "
          );
        in
        "${envPrefix}terraform";
    };

    # Add use_terraform function to direnv stdlib (preserves nix-direnv setup)
    programs.direnv.stdlib =
      builtins.replaceStrings
        [ "@DEFAULT_VERSION@" "@AVAILABLE_VERSIONS@" ]
        [ cfg.defaultVersion (lib.concatStringsSep " " cfg.versions) ]
        (builtins.readFile ./direnvrc);
  };
}
