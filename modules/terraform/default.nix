{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Create terraform packages with version-named binaries
  # Each version gets a wrapper like terraform-1.12.2
  terraformPackages = map (
    version:
    pkgs.writeShellScriptBin "terraform-${version}" ''
      exec ${pkgs.terraform-versions.${version}}/bin/terraform "$@"
    ''
  ) cfg.versions;

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
        "latest"
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
    # Install all terraform versions with version-named binaries
    home.packages = [
      # Default terraform version
      (
        if cfg.defaultVersion == "latest" then
          pkgs.terraform
        else
          pkgs.terraform-versions.${cfg.defaultVersion}
      )

      # All versioned terraform binaries (terraform-1.12.2, etc.)
    ]
    ++ terraformPackages;

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

    # Install direnvrc with use_terraform function
    home.file.".config/direnv/direnvrc" = {
      text =
        builtins.replaceStrings
          [ "@DEFAULT_VERSION@" "@AVAILABLE_VERSIONS@" ]
          [ cfg.defaultVersion (lib.concatStringsSep " " cfg.versions) ]
          (builtins.readFile ./direnvrc);
    };
  };
}
