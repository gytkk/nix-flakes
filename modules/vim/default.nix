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
      set encoding=utf-8
      set fileencoding=utf-8
      set termencoding=utf-8
      set mouse=a
      set ruler
      set nu
      set ru
    '';
  };
}
