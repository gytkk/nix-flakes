{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    extraConfig = ''
      " Basic settings
      syntax enable
      syntax sync fromstart
      filetype plugin indent on

      " Editor settings
      set mouse=a
      set ruler
      set nu
      set ru
    '';
  };
}
