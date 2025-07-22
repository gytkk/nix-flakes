{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Create terraform packages mapping
  terraformVersions =
    lib.listToAttrs (
      map (version: {
        name = version;
        value = pkgs.terraform-versions.${version};
      }) cfg.versions
    )
    // {
      "latest" = pkgs.terraform;
    };

  # Configuration options
  cfg = config.modules.terraform;
in
{
  options.modules.terraform = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Terraform version management with nixpkgs-terraform";
    };

    versions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of terraform versions to install";
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
        TF_VAR_environment = "dev";
        AWS_REGION = "ap-northeast-2";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Install terraform packages
    home.packages = [ terraformVersions.${cfg.defaultVersion} ];

    # Configure nixpkgs to allow unfree for terraform
    nixpkgs.config.allowUnfree = true;

    # Add tf alias with environment variables if configured
    home.shellAliases = lib.optionalAttrs (cfg.runEnv != { }) {
      tf =
        let
          envPrefix = lib.concatStringsSep " " (
            lib.mapAttrsToList (name: value: "${name}=${value}") cfg.runEnv
          );
        in
        "${envPrefix} ${terraformVersions.${cfg.defaultVersion}}/bin/terraform";
    };

    home.file.".config/nix-direnv/terraform-flake" = {
      source = ./terraform-flake;
      recursive = true;
    };
  };
}
