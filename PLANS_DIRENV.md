# Terraform nix-direnv 통합 시스템 구현 계획 (중앙집중식)

nix-direnv 기반 Terraform 버전 자동 매핑 시스템을 **중앙집중식 방식**으로 구현합니다.
각 프로젝트에 flake.nix를 생성하지 않고, 중앙 flake와 환경변수를 통한 버전 전달 방식을 사용합니다.

## 1. 스크립트 디렉토리 및 파일 생성

### `scripts/` 디렉토리 생성

- 프로젝트 루트에 scripts 디렉토리 생성

### `scripts/init-terraform-project.sh`

- **기능**: 새 Terraform 프로젝트 초기화
- **인수**: Terraform 버전 (선택사항, 기본값 1.12.2)
- **동작**:
  - backend.tf 파일 생성 (없는 경우)
  - 중앙 flake 기반 .envrc 파일 생성
  - `direnv allow` 실행

### `scripts/switch-terraform-version.sh`

- **기능**: 기존 프로젝트의 Terraform 버전 변경
- **인수**: 버전, 연산자 (기본값 ">=")
- **동작**:
  - backend.tf의 required_version 업데이트
  - `direnv reload` 실행

## 2. modules/terraform/default.nix 업데이트

### 스크립트 패키지 추가

- `writeShellScriptBin`으로 두 스크립트를 home.packages에 추가
- 스크립트명: `terraform-init-project`, `terraform-switch-version`

### 기존 기능 유지

- 중앙집중식 terraform-flake 복사 유지 (backward compatibility)

## 3. 테스트 프로젝트 생성

### `test-terraform-project/` 디렉토리

- 샘플 backend.tf (required_version = "1.10.5")
- README 파일로 테스트 방법 설명

## 4. 핵심 .envrc 템플릿 기능

### 환경변수 기반 버전 전달

- backend.tf → versions.tf → main.tf 순서로 required_version 파싱
- 파싱된 버전을 `TF_VERSION` 환경변수로 설정
- 중앙 terraform-flake에서 `TF_VERSION` 읽어서 해당 버전 제공

### 파일 감시

- watch_file로 Terraform 설정 파일 변경 감지
- 변경 시 자동 환경 재로드 및 버전 재파싱

## 예상 사용법

```bash
# 새 프로젝트 초기화
cd my-terraform-project
terraform-init-project 1.10.5

# 기존 프로젝트 버전 변경
terraform-switch-version 1.12.2 "="
```

## 구현 세부사항

### init-terraform-project.sh 스크립트 내용

- 인수 파싱 (버전, 기본값 설정)
- backend.tf 파일 존재 확인 및 생성
- .envrc 템플릿 적용
- direnv 활성화

### switch-terraform-version.sh 스크립트 내용

- 인수 파싱 (버전, 연산자)
- backend.tf 파일에서 required_version 라인 찾기 및 교체
- 환경 재로드

### .envrc 템플릿 (중앙집중식)

새로운 중앙집중식 .envrc 템플릿:

- watch_file 설정 (backend.tf, versions.tf, main.tf)
- Terraform 버전 파싱 함수 (bash)
- `TF_VERSION` 환경변수 설정
- `use flake ~/.config/nix-direnv/terraform-flake` 실행

### modules/terraform/default.nix 변경사항

- 새 스크립트들을 home.packages에 추가
- terraform-flake/flake.nix 개선: `TF_VERSION` 환경변수 지원
- 기존 terraform-flake 디렉토리 복사는 유지

### terraform-flake/flake.nix 개선사항

- `builtins.getEnv "TF_VERSION"`으로 환경변수에서 버전 읽기
- 환경변수가 없으면 PWD 기반 파일 파싱으로 fallback
- 더 안정적인 버전 감지 로직

## 기대 효과

이 시스템으로 Terraform 프로젝트에 진입하면 backend.tf의 required_version에 따라 자동으로 적절한 Terraform 버전이 로드됩니다.

- **자동화**: 수동 버전 관리 불필요
- **프로젝트별 격리**: 각 프로젝트가 독립적인 Terraform 환경
- **표준 호환**: 기존 Terraform 설정 파일 활용
- **캐시 최적화**: nix-direnv를 통한 빠른 로드
- **파일 최소화**: 프로젝트별 flake.nix 생성 불필요
- **중앙 관리**: 하나의 terraform-flake로 모든 프로젝트 지원

## 중앙집중식 방식의 장점

### 기존 로컬 flake 방식 대비

1. **파일 관리 간소화**: 각 프로젝트에 flake.nix/flake.lock 파일 불필요
2. **중앙 집중 관리**: terraform-flake 하나로 모든 버전 관리
3. **환경변수 기반**: 더 명확하고 디버깅하기 쉬운 버전 전달
4. **backward compatibility**: 기존 방식과 병행 사용 가능

### .envrc 템플릿 예시

```bash
#!/usr/bin/env bash

# Terraform 설정 파일들 변경 감지
watch_file backend.tf
watch_file versions.tf
watch_file main.tf

# Terraform 버전 파싱 함수
parse_terraform_version() {
  for file in backend.tf versions.tf main.tf; do
    if [[ -f "$file" ]]; then
      version=$(grep -o 'required_version.*=.*"[^"]*"' "$file" | \
               sed -n 's/.*"\([^"]*\)".*/\1/p' | head -1)
      if [[ -n "$version" ]]; then
        # 연산자 제거하고 버전만 추출
        echo "$version" | sed -E 's/^[><=~]+ *([0-9.]+).*/\1/'
        return
      fi
    fi
  done
  echo "1.12.2"  # 기본값
}

# TF_VERSION 환경변수 설정
export TF_VERSION=$(parse_terraform_version)

# 중앙 terraform-flake 사용
use flake ~/.config/nix-direnv/terraform-flake
```

## 5. 최적화된 사용자 경험

### `layout_terraform` 함수 구현

**목표**: `.envrc` 파일을 한 줄로 간소화

```bash
# .envrc 파일의 전체 내용
layout_terraform
```

### 구현 방안

1. **direnv stdlib 확장**: `~/.config/direnv/direnvrc` 파일에 `layout_terraform` 함수 정의
2. **modules/terraform에서 자동 설치**: home.file로 direnvrc 파일 배포
3. **함수 내부 로직**: 위의 복잡한 파싱 로직을 함수 내부로 캡슐화

### direnvrc 템플릿

```bash
#!/usr/bin/env bash

# Terraform layout 함수
layout_terraform() {
  # Terraform 설정 파일들 변경 감지
  watch_file backend.tf
  watch_file versions.tf
  watch_file main.tf
  
  # Terraform 버전 파싱 함수 (내부)
  local tf_version
  for file in backend.tf versions.tf main.tf; do
    if [[ -f "$file" ]]; then
      tf_version=$(grep -o 'required_version.*=.*"[^"]*"' "$file" | \
                   sed -n 's/.*"\([^"]*\)".*/\1/p' | head -1)
      if [[ -n "$tf_version" ]]; then
        # 연산자 제거하고 버전만 추출
        tf_version=$(echo "$tf_version" | sed -E 's/^[><=~]+ *([0-9.]+).*/\1/')
        break
      fi
    fi
  done
  
  # 기본값 설정
  tf_version=${tf_version:-"1.12.2"}
  
  # TF_VERSION 환경변수 설정
  export TF_VERSION="$tf_version"
  
  # 중앙 terraform-flake 사용
  use flake ~/.config/nix-direnv/terraform-flake
  
  log_status "🚀 Terraform $tf_version environment loaded"
}

### 사용자 경험 개선

**이전**: 복잡한 .envrc 파일
```bash
#!/usr/bin/env bash
watch_file backend.tf
watch_file versions.tf
# ... 30+ lines of bash code
```

**이후**: 단일 함수 호출
```bash
layout_terraform
```

### 추가 구현 사항

1. **modules/terraform/default.nix에 direnvrc 추가**:
   ```nix
   home.file.".config/direnv/direnvrc" = {
     source = ./direnvrc;
   };
   ```

2. **init-terraform-project.sh 간소화**:
   ```bash
   # .envrc 생성 시 한 줄만 작성
   echo "layout_terraform" > .envrc
   ```

3. **향후 확장성**: layout_node, layout_python 등 다른 언어/도구 지원 가능

## TODO

- [ ] scripts 디렉토리 생성
- [ ] direnvrc 파일 생성 (layout_terraform 함수 포함)
- [ ] init-terraform-project.sh 스크립트 작성 (한 줄 .envrc 생성)
- [ ] switch-terraform-version.sh 스크립트 작성
- [ ] terraform-flake/flake.nix 개선 (TF_VERSION 환경변수 지원)
- [ ] modules/terraform/default.nix 업데이트 (direnvrc 배포 추가)
- [ ] test-terraform-project 디렉토리 생성
- [ ] 테스트 및 검증
