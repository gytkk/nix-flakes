{
  config,
  lib,
  pkgs,
  ...
}:

let
  eclair = pkgs.writeShellScriptBin "ecl" ''
    export PATH="/Users/gyutak/.gem/ruby/3.1.0/bin:${pkgs.ruby_3_1}/bin:${pkgs.tmux}/bin:$PATH"
    export GEM_PATH="${pkgs.ruby_3_1}/lib/ruby/gems/3.1.0:/Users/gyutak/.gem/ruby/3.1.0"
    export GEM_HOME="/Users/gyutak/.gem/ruby/3.1.0"

    # Install eclair gem if not present
    if ! ${pkgs.ruby_3_1}/bin/gem list ecl -i > /dev/null 2>&1; then
      echo "Installing eclair gem..."
      ${pkgs.ruby_3_1}/bin/gem install ecl --version 3.0.4 --user-install --no-document 2>/dev/null
    fi

    # Execute the actual ecl command
    exec "/Users/gyutak/.gem/ruby/3.1.0/bin/ecl" "$@"
  '';
in
{
  home.packages = with pkgs; [
    # Authentication
    saml2aws
    vault

    # Required dependencies for eclair
    eclair
    ruby_3_1
    tmux
    ncurses.dev
    gcc

    # Custom scripts
    (pkgs.writeShellScriptBin "sign" (builtins.readFile ./scripts/sign))
    (pkgs.writeShellScriptBin "login" (builtins.readFile ./scripts/login))
  ];

  programs.zsh.envExtra = ''
    export VAULT_ADDR=https://vault.devsisters.cloud
  '';
}
