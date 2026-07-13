# Terraform 모듈

[stackbuilders/nixpkgs-terraform](https://github.com/stackbuilders/nixpkgs-terraform)를 사용한 Terraform 버전 관리 모듈입니다.

## Lazy Loading 방식

이 모듈은 **lazy loading** 방식을 사용합니다:

- **기본 버전**만 `home-manager switch` 시 설치
- **다른 버전**은 프로젝트 디렉토리 진입 시 **on-demand로 로드**
- 한 번 로드된 버전은 `/nix/store`에 캐시되어 **기기 전체에서 재사용**

### 장점

- `home-manager switch`가 빠름 (기본 버전만 빌드)
- 실제 사용하는 버전만 빌드됨
- Nix의 재현성 유지

## 설정 방법

### 기본 사용법

```nix
modules.terraform = {
  enable = true;
  defaultVersion = "1.12.2";
};
```

사용 가능한 버전 목록은 별도 설정 없이 `nixpkgs-terraform` flake input이 제공하는
전체 버전(1.0.0 이상)에서 자동으로 파생됩니다. 새 버전이 필요하면
`nix flake update nixpkgs-terraform` 후 `home-manager switch`를 실행하세요.

## 설정 옵션

### `enable`

- **타입**: `bool`
- **기본값**: `true`
- **설명**: Terraform 모듈 활성화

### `defaultVersion`

- **타입**: `string`
- **기본값**: `"latest"`
- **설명**: 기본으로 사용할 Terraform 버전 (즉시 설치됨)

### `runEnv`

- **타입**: `attrs of strings`
- **기본값**: `{}`
- **설명**: `tf` alias 실행 시 설정할 환경 변수

---

## Direnv 통합

디렉토리 내 `.tf` 파일의 `required_version`을 자동으로 감지하여 해당 버전의 Terraform을 로드합니다.

### 작동 방식

1. 프로젝트 디렉토리에 `.envrc` 파일 생성
2. `use_terraform` 함수 호출
3. 디렉토리의 모든 `*.tf` 파일에서 `required_version` 파싱 (첫 번째 발견된 스펙 사용)
4. 제약 조건을 만족하는 버전 선택:
   - 기본 버전이 조건을 만족하면 기본 버전 사용 (추가 로드 없음)
   - 아니면 조건을 만족하는 **가장 높은 버전**을 nix-direnv로 lazy load
   - 만족하는 버전이 없거나 스펙을 파싱할 수 없으면 경고 후 기본 버전 사용
5. `/nix/store`에 캐시되어 이후 즉시 로드

### 사용법

프로젝트 디렉토리에 `.envrc` 파일 생성:

```bash
# .envrc
use_terraform
```

그리고 direnv 허용:

```bash
direnv allow
```

### 지원되는 버전 형식

```hcl
terraform {
  # 정확한 버전
  required_version = "= 1.10.5"

  # 비교 연산자 (>=, <=, >, <)
  required_version = ">= 1.10.5"

  # Pessimistic 연산자 (Terraform 의미론 준수)
  required_version = "~> 1.10"    # >= 1.10.0, < 2.0.0
  required_version = "~> 1.10.2"  # >= 1.10.2, < 1.11.0

  # 버전만 지정
  required_version = "1.10.5"

  # 쉼표로 구분된 복합 조건 (AND)
  required_version = ">= 1.10.0, < 2.0.0"
}
```

`!=` 등 지원하지 않는 연산자가 포함된 스펙은 경고를 출력하고 기본 버전으로 동작합니다.

## 캐시 동작

| 상황 | 동작 |
|------|------|
| 첫 번째 프로젝트에서 1.10.5 사용 | 빌드 (1회) |
| 두 번째 프로젝트에서 1.10.5 사용 | 캐시에서 즉시 로드 |
| `nix flake update` 후 (nixpkgs-terraform 고정) | 캐시 유지 |
| `nix flake update` 후 (nixpkgs-terraform 변경) | 재빌드 |

## 트러블슈팅

### 버전이 로드되지 않는 경우

1. nix-direnv가 설치되어 있는지 확인:
```bash
# base/default.nix에서 direnv.nix-direnv.enable = true 확인
```

2. direnv 캐시 초기화:
```bash
rm -rf .direnv
direnv allow
```

3. 수동으로 버전 확인:
```bash
nix shell github:stackbuilders/nixpkgs-terraform#terraform-1.10.5 --command terraform version
```

### 빌드가 오래 걸리는 경우

첫 번째 로드 시에만 빌드가 필요합니다. 이후에는 `/nix/store` 캐시를 사용합니다.

binary cache에서 다운로드되지 않는 경우 로컬 빌드가 필요할 수 있습니다 (특히 aarch64-darwin).
