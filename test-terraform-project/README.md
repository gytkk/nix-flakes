# Terraform nix-direnv 테스트 프로젝트

이 디렉토리는 Terraform nix-direnv 통합 시스템을 테스트하기 위한 예제 프로젝트입니다.

## 테스트 방법

### 1. Home Manager 설정 적용

먼저 terraform 모듈이 활성화된 Home Manager 설정을 적용하세요:

```bash
home-manager switch --flake .#devsisters-macbook  # 또는 해당하는 환경
```

### 2. 프로젝트 디렉토리 진입

```bash
cd test-terraform-project
```

### 3. direnv 허용 (처음 한 번만)

```bash
direnv allow
```

### 4. Terraform 버전 확인

디렉토리에 진입하면 자동으로 Terraform 환경이 로드됩니다:

```bash
terraform version
```

예상 출력:
```
🚀 Terraform 1.10.5 environment loaded from environment variable
📁 Project: /Users/gyutak/development/nix-flakes/test-terraform-project
Terraform v1.10.5
```

### 5. Terraform 명령어 테스트

```bash
# 초기화
terraform init

# 계획 확인
terraform plan

# 적용 (테스트용 null_resource)
terraform apply

# 정리
terraform destroy
```

## 버전 변경 테스트

다른 Terraform 버전으로 변경해보세요:

```bash
terraform-switch-version 1.12.2 "="
```

디렉토리를 나갔다가 다시 들어오면 새 버전이 로드됩니다:

```bash
cd .. && cd test-terraform-project
terraform version
```

## 파일 구조

- `backend.tf`: Terraform 버전 요구사항이 정의된 파일
- `.envrc`: `layout_terraform` 함수를 호출하는 단일 라인 파일
- `main.tf`: 테스트용 Terraform 구성
- `README.md`: 이 파일

## 트러블슈팅

### direnv가 작동하지 않는 경우

1. direnv가 설치되어 있는지 확인:
   ```bash
   which direnv
   ```

2. 쉘에 direnv hook이 설정되어 있는지 확인:
   ```bash
   # bash인 경우
   echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

   # zsh인 경우  
   echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
   ```

3. 새 쉘 세션을 시작하거나 설정을 다시 로드:
   ```bash
   source ~/.bashrc  # 또는 ~/.zshrc
   ```

### Terraform 버전이 올바르지 않은 경우

1. TF_VERSION 환경변수 확인:
   ```bash
   echo $TF_VERSION
   ```

2. backend.tf의 required_version 확인:
   ```bash
   grep required_version backend.tf
   ```

3. direnv 재로드:
   ```bash
   direnv reload
   ```