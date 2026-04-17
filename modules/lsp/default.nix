{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.modules.lsp;
in
{
  options.modules.lsp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable LSP server packages";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      # Nix
      nixd

      # Go
      gopls

      # TypeScript
      typescript-language-server

      # Terraform
      terraform-ls

      # Scala
      metals

      # Python
      ty

      # YAML
      yaml-language-server

      # Markdown
      marksman

      # Rust: rust-analyzer is provided by rustup
    ];
  };
}
