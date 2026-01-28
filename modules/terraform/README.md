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

### 다중 버전 설정

```nix
modules.terraform = {
  enable = true;
  versions = [ "1.10.5" "1.11.4" "1.12.2" ];  # direnv에서 인식할 버전 목록
  defaultVersion = "1.12.2";
};
```

## 설정 옵션

### `enable`

- **타입**: `bool`
- **기본값**: `true`
- **설명**: Terraform 모듈 활성화

### `versions`

- **타입**: `list of strings`
- **기본값**: `[]`
- **설명**: direnv에서 사용 가능한 Terraform 버전 목록 (lazy loading)

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

`backend.tf` 파일의 `required_version`을 자동으로 감지하여 해당 버전의 Terraform을 로드합니다.

### 작동 방식

1. 프로젝트 디렉토리에 `.envrc` 파일 생성
2. `use_terraform` 함수 호출
3. `backend.tf`, `versions.tf`, `main.tf`에서 `required_version` 파싱
4. 기본 버전과 다르면 **nix-direnv를 통해 lazy load**
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
  
  # 최소 버전
  required_version = ">= 1.10.5"
  
  # 범위 버전
  required_version = "~> 1.10.0"
  
  # 버전만 지정
  required_version = "1.10.5"
}
```

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
nix shell github:stackbuilders/nixpkgs-terraform#1.10.5 --command terraform version
```

### 빌드가 오래 걸리는 경우

첫 번째 로드 시에만 빌드가 필요합니다. 이후에는 `/nix/store` 캐시를 사용합니다.

binary cache에서 다운로드되지 않는 경우 로컬 빌드가 필요할 수 있습니다 (특히 aarch64-darwin).
