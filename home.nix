{ config, pkgs, ... };

{
  home = {
    username = "gytkk";
    homeDirectory = "/Users/gytkk";

    # Set language for shell sessions managed by home-manager
    language = {
      base = "en_US.UTF-8";
    };

    packages = with pkgs; [
      # ZSH
      zsh-powerlevel10k
    ];
  }

  programs.home-manager.enable = true;

  # Zsh 및 Oh My Zsh 설정
  programs.zsh = {
    enable = true;
    # 이 옵션을 true로 설정하면 Home Manager가 .zshrc에 필요한 스크립트를 자동으로 추가합니다.
    enableAutosuggestions = true;
    enableCompletion = true;
    
    # 기본 셸로 zsh을 사용하도록 설정
    shellAliases = {
      ll = "exa -l --icons";
      la = "exa -la --icons";
      l = "exa --icons";
    };

    # Oh My Zsh 설정
    oh-my-zsh = {
      enable = true;
      # 사용하고 싶은 테마를 설정합니다. (예: "robbyrussell", "agnoster")
      theme = "robbyrussell";

      # 사용하고 싶은 플러그인을 나열합니다.
      plugins = [
        "git"
        "zsh-syntax-highlighting"
        "fzf"
      ];
    };
  };
}
