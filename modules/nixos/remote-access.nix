{
  services.openssh = {
    enable = true;
    # Ghostty ssh-env가 전달하는 터미널 환경 변수 수락 (Claude Code TUI 렌더링에 필요)
    extraConfig = ''
      AcceptEnv COLORTERM TERM_PROGRAM TERM_PROGRAM_VERSION
    '';
  };

  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--ssh" ];
  };
}
