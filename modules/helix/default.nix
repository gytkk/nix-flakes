{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.helix;
in
{
  options.modules.helix = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Helix editor module";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.helix = {
      enable = true;

      settings = {
        theme = "onelight";

        editor = {
          line-number = "relative";
          true-color = true;
          cursorline = true;
          bufferline = "multiple";
          color-modes = true;
          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };
          indent-guides = {
            render = true;
            character = "│";
          };
          statusline = {
            left = [
              "mode"
              "spinner"
              "file-name"
              "read-only-indicator"
              "file-modification-indicator"
            ];
            right = [
              "diagnostics"
              "selections"
              "register"
              "position"
              "file-encoding"
              "file-line-ending"
              "file-type"
            ];
          };
          lsp = {
            display-messages = true;
            display-inlay-hints = true;
          };
          file-picker = {
            hidden = false;
          };
        };

        keys = {
          normal = {
            space.w = ":write";
            space.q = ":quit";
          };
        };
      };
    };
  };
}
