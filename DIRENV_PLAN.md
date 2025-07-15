# Direnv + nixpkgs-terraform 통합 계획

## 목표

direnv와 nixpkgs-terraform을 기반으로 각 디렉토리의 `.tool-versions` 파일 또는 `.envrc` 파일에 기록된 Terraform 버전을 자동으로 읽어서 적절한 Terraform 패키지를 선택하는 시스템 구현

## 구현 전략

### 핵심 아이디어
- `.tool-versions` 파일에서 terraform 버전을 읽어서 환경 변수로 설정
- `flake.nix`에서 환경 변수를 읽어서 적절한 nixpkgs-terraform 패키지 선택
- direnv를 통해 자동으로 환경 적용

### 구성 요소

1. **flake.nix** - 환경 변수 기반 terraform 버전 선택
2. **'.envrc'** - .tool-versions 파싱 및 환경 변수 설정
3. **'.tool-versions'** - terraform 버전 명시 (asdf 형식)

## 구현 단계

### 1단계: nix-direnv 설정

#### 필요한 패키지 설치
```bash
# nix-direnv 설치
nix profile install nixpkgs#nix-direnv
```

#### direnv 설정
```bash
# ~/.config/direnv/direnvrc에 추가
source_url "https://raw.githubusercontent.com/nix-community/nix-direnv/main/direnvrc" "sha256-0000000000000000000000000000000000000000000="
```

### 2단계: flake.nix 템플릿 생성

#### 기본 구조
```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";
  
  outputs = { self, nixpkgs, nixpkgs-terraform }:
    let
      system = "x86_64-linux";  # 또는 "aarch64-darwin"
      pkgs = nixpkgs.legacyPackages.${system};
      
      # 환경 변수에서 버전 읽기, 기본값 설정
      terraformVersion = builtins.getEnv "TERRAFORM_VERSION";
      defaultVersion = "1.5.7";
      version = if terraformVersion == "" then defaultVersion else terraformVersion;
      
      terraform = nixpkgs-terraform.packages.${system}.${version};
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [ terraform ];
        shellHook = ''
          echo "Using Terraform ${version}"
        '';
      };
    };
}
```

#### 향상된 기능
- 버전 유효성 검사
- 에러 처리
- 다중 시스템 지원

### 3단계: .envrc 템플릿 생성

#### 기본 구조
```bash
# .tool-versions에서 terraform 버전 읽기
if [[ -f .tool-versions ]]; then
  TF_VERSION=$(grep "^terraform " .tool-versions | cut -d' ' -f2)
  if [[ -n "$TF_VERSION" ]]; then
    export TERRAFORM_VERSION="$TF_VERSION"
  fi
fi

# nix-direnv 사용
use flake
```

#### 향상된 기능
- 버전 파싱 에러 처리
- 다중 도구 지원
- 로깅 및 디버깅

### 4단계: 테스트 및 검증

#### 테스트 케이스
1. **기본 동작 테스트**
   - `.tool-versions`에 terraform 버전 명시
   - 디렉토리 진입시 자동 환경 설정 확인

2. **버전 변경 테스트**
   - 다른 terraform 버전으로 변경
   - 환경 재로드 확인

3. **에러 처리 테스트**
   - 존재하지 않는 버전 지정
   - 파일 없음 상황 처리

#### 검증 방법
```bash
# terraform 버전 확인
terraform version

# 환경 변수 확인
echo $TERRAFORM_VERSION

# 활성화된 패키지 확인
which terraform
```

## 추가 고려사항

### 1. 시스템 호환성
- macOS (aarch64-darwin, x86_64-darwin)
- Linux (x86_64-linux)
- WSL 환경

### 2. 버전 관리
- nixpkgs-terraform에서 지원하는 버전 확인
- 버전 범위 지정 (예: 1.5.x)
- 최신 버전 자동 선택

### 3. 성능 최적화
- nix-direnv 캐싱 활용
- 불필요한 다운로드 방지
- 빠른 환경 전환

### 4. 확장성
- 다른 도구 지원 (terragrunt, tflint 등)
- 커스텀 훅 지원
- 팀 단위 설정 공유

## 배포 전략

### 1. 프로토타입 구현
- 기본 기능 구현
- 단일 시스템에서 테스트

### 2. 기능 확장
- 에러 처리 강화
- 다중 시스템 지원
- 성능 최적화

### 3. 문서화
- 사용법 가이드
- 트러블슈팅 가이드
- 설정 예시

### 4. 커뮤니티 공유
- GitHub 저장소 공개
- 사용 사례 공유
- 피드백 수집

## 예상 결과

이 시스템을 통해:
- 프로젝트별 terraform 버전 자동 관리
- 개발 환경 일관성 보장
- 기존 도구와의 호환성 유지
- 팀 협업 효율성 향상

## 유지보수 계획

- nixpkgs-terraform 업데이트 모니터링
- 새로운 terraform 버전 지원
- 버그 수정 및 성능 개선
- 사용자 피드백 반영