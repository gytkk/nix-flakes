{
  pkgs,
  ...
}:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    extraPackages = with pkgs; [
      fd
      ripgrep
    ];

    extraConfig = ''
      " Leader key
      let mapleader = " "
      let maplocalleader = " "

      " Basic settings
      syntax enable
      syntax sync fromstart
      filetype plugin indent on

      " Editor settings
      set encoding=utf-8
      set fileencoding=utf-8
      set mouse=a
      set ruler
      set nu
      set ru

      " True color support
      set termguicolors
    '';

    initLua = builtins.readFile ./files/init.lua;
  };
}
