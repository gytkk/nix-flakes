{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Terraform version configuration
  supportedVersions = [
    "1.10.2"
    "1.12.2"
  ];

  defaultVersion = "1.12.2";

  # Create terraform packages mapping
  terraformVersions =
    lib.listToAttrs (
      map (version: {
        name = version;
        value = pkgs.terraform-versions.${version};
      }) supportedVersions
    )
    // {
      "latest" = pkgs.terraform-versions.${defaultVersion};
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
      default = supportedVersions;
      description = "List of terraform versions to install";
      example = [
        "1.10.2"
        "1.11.1"
        "1.12.2"
      ];
    };

    defaultVersion = lib.mkOption {
      type = lib.types.str;
      default = defaultVersion;
      description = "Default terraform version to use";
    };

    installAll = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install all configured terraform versions";
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
    home.packages =
      if cfg.installAll then
        lib.attrValues terraformVersions
      else
        [ terraformVersions.${cfg.defaultVersion} ];

    # Configure nixpkgs to allow unfree for terraform
    nixpkgs.config.allowUnfree = true;

    # Create terraform version aliases if multiple versions are installed
    home.shellAliases = 
      let
        envPrefix = lib.concatStringsSep " " (lib.mapAttrsToList (name: value: "${name}=${value}") cfg.runEnv);
        terraformCmd = version: 
          if cfg.runEnv != {} then
            "${envPrefix} ${terraformVersions.${version}}/bin/terraform"
          else
            "${terraformVersions.${version}}/bin/terraform";
      in
      lib.mkIf (cfg.installAll || (builtins.length cfg.versions) > 1) (
        builtins.listToAttrs (
          map (version: {
            name = "terraform-${version}";
            value = terraformCmd version;
          }) cfg.versions
        )
      ) // 
      # Add main tf alias with environment variables
      (lib.optionalAttrs (cfg.runEnv != {}) {
        tf = 
          if cfg.installAll then
            terraformCmd cfg.defaultVersion
          else
            "${envPrefix} ${terraformVersions.${cfg.defaultVersion}}/bin/terraform";
      });

    home.file.".config/nix-direnv/terraform-flake" = {
      source = ./terraform-flake;
      recursive = true;
    };
  };
}
