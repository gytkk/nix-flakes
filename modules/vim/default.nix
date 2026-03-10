{
  pkgs,
  ...
}:

{
  xdg.configFile."nvim/zed_onelight.lua".source = ./files/zed_onelight.lua;

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

      " Smooth scrolling: 1 line per mouse wheel tick
      set mousescroll=ver:1,hor:1
    '';

    initLua = builtins.readFile ./files/init.lua;
  };
}
