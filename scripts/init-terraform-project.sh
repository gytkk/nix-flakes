#!/usr/bin/env bash

TF_VERSION=${1:-"1.12.2"}
PROJECT_DIR=${2:-"."}

cd "$PROJECT_DIR"

# backend.tf 파일 생성 (또는 기존 파일 확인)
if [[ ! -f "backend.tf" && ! -f "versions.tf" && ! -f "main.tf" ]]; then
  cat > backend.tf << EOF
terraform {
  required_version = ">= $TF_VERSION"

  # 필요한 경우 backend 설정 추가
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "terraform.tfstate"
  #   region = "us-west-2"
  # }
}
EOF
fi

# .envrc 파일 생성
cat > .envrc << 'EOF'
#!/usr/bin/env bash
# Terraform 설정 파일들 변경 감지
watch_file backend.tf
watch_file versions.tf
watch_file main.tf

# 공통 terraform flake 사용
use flake ~/.config/nix-direnv/terraform-flake
EOF

# direnv 허용
direnv allow

echo "✅ Terraform $TF_VERSION project initialized"
echo "📁 Using shared flake: ~/.config/nix-direnv/terraform-flake"
echo "🔧 Terraform version will be auto-detected from backend.tf"