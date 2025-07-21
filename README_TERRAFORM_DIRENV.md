# Terraform Direnv Integration

backend.tf 파일의 `required_version`을 자동으로 감지하여 해당 버전의 Terraform을 사용하는 direnv 통합 시스템입니다.

## 설치 완료 확인

```bash
# dotfile이 올바르게 설치되었는지 확인
ls -la ~/.config/nix-direnv/terraform-flake/
cat ~/.config/nix-direnv/terraform-flake/flake.nix
```

## 사용법

### 1. 새 프로젝트 초기화

```bash
cd /path/to/your/terraform/project
~/development/nix-flakes/scripts/init-terraform-project.sh 1.10.2
```

이 명령어는 다음을 수행합니다:
- `backend.tf` 파일 생성 (없는 경우)
- `.envrc` 파일 생성
- direnv 설정 활성화

### 2. 기존 프로젝트에 추가

기존 Terraform 프로젝트에 direnv를 추가하려면:

```bash
cd /path/to/existing/terraform/project

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
```

### 3. 버전 변경

```bash
~/development/nix-flakes/scripts/switch-terraform-version.sh 1.10.2 "="
```

## 지원되는 버전 형식

backend.tf에서 다음 형식들이 지원됩니다:

```hcl
terraform {
  # 정확한 버전
  required_version = "= 1.10.2"
  
  # 최소 버전
  required_version = ">= 1.10.2"
  
  # 범위 버전
  required_version = "~> 1.10.0"
  
  # 복합 조건 (첫 번째 조건만 파싱됨)
  required_version = ">= 1.10.0, < 2.0.0"
}
```

## 테스트

제공된 테스트 프로젝트에서 확인:

```bash
cd ~/development/nix-flakes/test-terraform-project

# backend.tf 내용 확인
cat backend.tf

# direnv 환경 진입 (자동으로 Terraform 버전 로드)
# direnv가 활성화되면 다음이 표시됩니다:
# 🚀 Terraform X.X.X environment loaded from terraform config
# 📁 Project: /path/to/project

# Terraform 버전 확인
terraform version
```

## 트러블슈팅

### direnv 에러가 발생하는 경우

1. terraform-flake가 올바르게 설치되었는지 확인:
```bash
ls -la ~/.config/nix-direnv/terraform-flake/flake.nix
```

2. flake가 유효한지 검증:
```bash
nix flake check ~/.config/nix-direnv/terraform-flake
```

3. direnv를 다시 허용:
```bash
direnv allow
direnv reload
```

### flake.nix가 존재하지 않는다는 에러가 발생하는 경우

수동으로 terraform-flake를 설치:
```bash
mkdir -p ~/.config/nix-direnv/terraform-flake
cp ~/development/nix-flakes/modules/terraform/terraform-flake/flake.nix ~/.config/nix-direnv/terraform-flake/
```

### Terraform 버전이 올바르게 감지되지 않는 경우

1. backend.tf 파일에 `required_version`이 올바르게 설정되어 있는지 확인
2. 파일 권한 확인: `ls -la backend.tf`
3. direnv 환경에서 파싱 확인을 위해 nix develop 직접 실행:
```bash
nix develop ~/.config/nix-direnv/terraform-flake --command terraform version
```

## 지원되는 Terraform 버전

nixpkgs-terraform에서 제공하는 모든 버전이 지원됩니다:
- 1.0.11, 1.1.9, 1.2.9, 1.3.10, 1.4.7, 1.5.7
- 1.6.6, 1.7.5, 1.8.5, 1.9.8, 1.10.2, 1.12.2

## 파일 구조

```
~/.config/nix-direnv/
└── terraform-flake/
    └── flake.nix              # 공통 Terraform flake

your-project/
├── backend.tf                # Terraform 버전 요구사항
├── main.tf                   # Terraform 설정
└── .envrc                    # direnv 설정
```