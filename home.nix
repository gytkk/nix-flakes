{ config, pkgs, ... }:

{
  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
  };

  # Disable news on update
  news.display = "silent";

  home = {
    username = "gyutak";
    homeDirectory = "/Users/gyutak";

    # Set language for shell sessions managed by home-manager
    language = {
      base = "en_US.UTF-8";
    };

    packages = with pkgs; [
      # Dev tools
      terraform
      awscli2
      yq

      # Kubernetes tools
      kubectl
      kubectx
      k9s

      # Zsh
      zsh-powerlevel10k

      # etc
      direnv
    ];

    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;

  # Zsh 및 Oh My Zsh 설정
  programs.zsh = {
    enable = true;
    
    # 이 옵션을 true로 설정하면 Home Manager가 .zshrc에 필요한 스크립트를 자동으로 추가합니다.
    autosuggestion.enable = true;

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
      theme = "powerlevel10k/powerlevel10k";

      # 사용하고 싶은 플러그인을 나열합니다.
      plugins = [
        "git"
        "zsh-syntax-highlighting"
        "fzf"
      ];
    };
  };
}
