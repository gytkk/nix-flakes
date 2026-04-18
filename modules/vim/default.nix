{
  config,
  flakeDirectory,
  ...
}:

let
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/vim/${path}";
  nvimThemeExports = config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/themes/exports/nvim";
in
{
  xdg.configFile."nvim/lua/config".source = mkSymlink "files/config";
  xdg.configFile."nvim/themes".source = nvimThemeExports;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    initLua = ''
      vim.g.nix_flakes_theme = ${builtins.toJSON config.modules.commonTheme}
      require('config')
    '';
  };
}
