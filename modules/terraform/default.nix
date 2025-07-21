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
        "1.12.2"
        "latest"
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
    home.shellAliases = lib.mkIf (cfg.installAll || (builtins.length cfg.versions) > 1) (
      builtins.listToAttrs (
        map (version: {
          name = "terraform-${version}";
          value = "${terraformVersions.${version}}/bin/terraform";
        }) cfg.versions
      )
    );

    # Install terraform flake dotfile for direnv integration
    home.file.".config/nix-direnv/terraform-flake" = {
      source = ./terraform-flake;
      recursive = true;
    };
  };
}
