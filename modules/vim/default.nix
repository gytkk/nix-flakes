{
  config,
  flakeDirectory,
  ...
}:

let
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/vim/${path}";
  mkThemeSymlink =
    path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/themes/exports/nvim/${path}";
in
{
  xdg.configFile."nvim/lua/config".source = mkSymlink "files/config";
  xdg.configFile."nvim/monokai-pro-classic.lua".source = mkThemeSymlink "monokai-pro-classic.lua";

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    initLua = "require('config')";
  };
}
