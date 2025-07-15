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

  # Generate terraform version aliases dynamically based on terraform module config
  terraformVersionAliases =
    lib.mkIf (config.modules.terraform.enable && config.modules.terraform.installAll)
      (
        builtins.listToAttrs (
          map (version: {
            name = "tf-${builtins.replaceStrings [ "." ] [ "" ] version}";
            value = "AWS_PROFILE=saml terraform-${version}";
          }) config.modules.terraform.versions
        )
      );
in
{
  home.packages = with pkgs; [
    # Authentication
    saml2aws
    vault

    # Required dependencies for eclair
    eclair
    ruby_3_1
    ncurses.dev

    # Databricks
    databricks-cli

    # Custom scripts
    (pkgs.writeShellScriptBin "sign" (builtins.readFile ./scripts/sign))
    (pkgs.writeShellScriptBin "login" (builtins.readFile ./scripts/login))
  ];

  programs.zsh = {
    envExtra = ''
      export VAULT_ADDR=https://vault.devsisters.cloud
    '';

    shellAliases = {
      tf = "AWS_PROFILE=saml terraform";
    } // terraformVersionAliases;
  };
}
