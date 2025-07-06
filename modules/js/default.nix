{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Helper function to create a derivation for a global npm package
  buildGlobalNpmPackage = { pname, version, src, npmDepsHash, ... }@args:
    pkgs.buildNpmPackage (args // {
      inherit pname version src npmDepsHash;
      dontNpmBuild = true;
      npmInstallFlags = [ "--global" ];
      
      # Create a wrapper script that adds the package to PATH
      postInstall = ''
        mkdir -p $out/bin
        # Link all executables from the npm global install
        if [ -d "$out/lib/node_modules/${pname}/bin" ]; then
          ln -s $out/lib/node_modules/${pname}/bin/* $out/bin/
        fi
        if [ -d "$out/lib/node_modules/${pname}/cli" ]; then
          ln -s $out/lib/node_modules/${pname}/cli/* $out/bin/
        fi
      '';
    });

  # NestJS CLI package
  nestjs-cli = buildGlobalNpmPackage {
    pname = "@nestjs/cli";
    version = "10.2.1";
    
    src = pkgs.fetchFromGitHub {
      owner = "nestjs";
      repo = "nest-cli";
      rev = "10.2.1";
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Replace with actual hash
    };
    
    npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Replace with actual hash
    
    meta = with lib; {
      description = "A command-line interface tool that helps you to initialize, develop, and maintain your Nest applications";
      homepage = "https://nestjs.com/";
      license = licenses.mit;
      maintainers = with maintainers; [ ];
    };
  };

in
{
  # Install global JavaScript packages
  home.packages = with pkgs; [
    # pnpm is already available in the base configuration
    
    # NestJS CLI example
    nestjs-cli
  ];

  # Alternative approach: Use pnpm directly with a custom derivation
  # This creates a more flexible solution for global package installation
  home.file.".pnpm-global" = {
    text = ''
      # Global pnpm packages configuration
      # This file can be used to track globally installed packages
      @nestjs/cli
    '';
    target = ".config/pnpm/global-packages.txt";
  };

  # Create a helper script for installing global packages with pnpm
  home.packages = with pkgs; [
    (pkgs.writeShellScriptBin "pnpm-global-install" ''
      #!/bin/bash
      # Helper script to install global packages with pnpm
      # Usage: pnpm-global-install @nestjs/cli
      
      if [ -z "$1" ]; then
        echo "Usage: pnpm-global-install <package-name>"
        exit 1
      fi
      
      echo "Installing $1 globally with pnpm..."
      ${pkgs.pnpm}/bin/pnpm install -g "$1"
      
      # Update the global packages list
      echo "$1" >> ~/.config/pnpm/global-packages.txt
      sort -u ~/.config/pnpm/global-packages.txt -o ~/.config/pnpm/global-packages.txt
    '')
  ];
}