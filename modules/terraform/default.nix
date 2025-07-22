{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Create terraform packages mapping
  terraformVersions =
    lib.listToAttrs (
      map (version: {
        name = version;
        value = pkgs.terraform-versions.${version};
      }) cfg.versions
    )
    // {
      "latest" = pkgs.terraform;
    };

  # Terraform project initialization script
  terraform-init-project = pkgs.writeShellScriptBin "terraform-init-project" ''
    #!/usr/bin/env bash
    
    set -euo pipefail
    
    # 기본 설정
    DEFAULT_VERSION="1.12.2"
    VERSION="''${1:-$DEFAULT_VERSION}"
    OPERATOR="''${2:->=}"
    
    # 색상 출력을 위한 함수들
    info() {
        echo -e "\033[1;34m[INFO]\033[0m $1"
    }
    
    success() {
        echo -e "\033[1;32m[SUCCESS]\033[0m $1"
    }
    
    error() {
        echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
    }
    
    # backend.tf 파일이 없으면 생성
    if [[ ! -f "backend.tf" ]]; then
        info "Creating backend.tf with Terraform version $VERSION..."
        cat > backend.tf << EOF
    terraform {
      required_version = "$OPERATOR $VERSION"
    
      required_providers {
        # Add your required providers here
      }
    
      # Uncomment and configure your backend
      # backend "s3" {
      #   bucket = "your-terraform-state-bucket"
      #   key    = "terraform.tfstate"
      #   region = "us-east-1"
      # }
    }
    EOF
        success "Created backend.tf"
    else
        info "backend.tf already exists, skipping creation"
    fi
    
    # .envrc 파일 생성 (한 줄로 간단히)
    if [[ ! -f ".envrc" ]]; then
        info "Creating .envrc file..."
        echo "layout_terraform" > .envrc
        success "Created .envrc"
    else
        info ".envrc already exists"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "layout_terraform" > .envrc
            success "Overwrote .envrc"
        else
            info "Keeping existing .envrc"
        fi
    fi
    
    # direnv 허용
    if command -v direnv >/dev/null 2>&1; then
        info "Allowing direnv..."
        direnv allow
        success "direnv allowed"
    else
        error "direnv not found in PATH"
        echo "Please install direnv and run 'direnv allow' manually"
        exit 1
    fi
    
    success "Terraform project initialization completed!"
    info "Terraform version: $VERSION"
    info "You can now 'cd' into this directory and Terraform $VERSION will be automatically loaded."
  '';

  # Terraform version switching script
  terraform-switch-version = pkgs.writeShellScriptBin "terraform-switch-version" ''
    #!/usr/bin/env bash
    
    set -euo pipefail
    
    # 기본 설정
    VERSION="''${1:-}"
    OPERATOR="''${2:->=}"
    
    # 색상 출력을 위한 함수들
    info() {
        echo -e "\033[1;34m[INFO]\033[0m $1"
    }
    
    success() {
        echo -e "\033[1;32m[SUCCESS]\033[0m $1"
    }
    
    error() {
        echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
    }
    
    # 버전 인수가 필요함
    if [[ -z "$VERSION" ]]; then
        error "Usage: terraform-switch-version <version> [operator]"
        echo "Example: terraform-switch-version 1.12.2 \"=\""
        exit 1
    fi
    
    # backend.tf 파일 존재 확인
    if [[ ! -f "backend.tf" ]]; then
        error "backend.tf not found in current directory"
        echo "Please run this command in a Terraform project directory"
        exit 1
    fi
    
    # backend.tf에서 required_version 업데이트
    info "Updating required_version in backend.tf..."
    
    if grep -q "required_version" backend.tf; then
        # 기존 required_version 라인을 새 버전으로 교체
        ${pkgs.gnused}/bin/sed -i "s/required_version.*=.*\"[^\"]*\"/required_version = \"$OPERATOR $VERSION\"/" backend.tf
        success "Updated required_version to \"$OPERATOR $VERSION\""
    else
        error "required_version not found in backend.tf"
        echo "Please add a terraform block with required_version manually"
        exit 1
    fi
    
    # direnv 재로드
    if command -v direnv >/dev/null 2>&1; then
        info "Reloading direnv..."
        direnv reload
        success "direnv reloaded"
    else
        error "direnv not found in PATH"
        echo "Please install direnv and run 'direnv reload' manually"
        exit 1
    fi
    
    success "Terraform version switched to $VERSION!"
    info "The new version will be loaded when you re-enter the directory"
  '';

  # Configuration options
  cfg = config.modules.terraform;
in
{
  options.modules.terraform = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Terraform version management with nixpkgs-terraform";
    };

    versions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of terraform versions to install";
      example = [
        "1.10.5"
        "1.12.2"
      ];
    };

    defaultVersion = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "Default terraform version to use";
    };

    runEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Environment variables to set when running terraform";
      example = {
        TF_VAR_environment = "dev";
        AWS_REGION = "ap-northeast-2";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Install terraform packages and scripts
    home.packages = [ 
      terraformVersions.${cfg.defaultVersion}
      terraform-init-project
      terraform-switch-version
    ];

    # Configure nixpkgs to allow unfree for terraform
    nixpkgs.config.allowUnfree = true;

    # Add tf alias with environment variables if configured
    home.shellAliases = lib.optionalAttrs (cfg.runEnv != { }) {
      tf =
        let
          envPrefix = lib.concatStringsSep " " (
            lib.mapAttrsToList (name: value: "${name}=${value}") cfg.runEnv
          );
        in
        "${envPrefix} ${terraformVersions.${cfg.defaultVersion}}/bin/terraform";
    };

    home.file.".config/nix-direnv/terraform-flake" = {
      source = ./terraform-flake;
      recursive = true;
    };

    # Install direnvrc with layout_terraform function
    home.file.".config/direnv/direnvrc" = {
      source = ./direnvrc;
    };
  };
}
