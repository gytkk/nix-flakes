# TODO 4: 환경별 설정 중앙화 액션 플랜

## 개요

현재 `flake.nix`에 하드코딩되어 있는 환경별 설정들을 별도 파일로 분리하여 관리 효율성을 개선하고, 새로운 환경 추가를 용이하게 합니다.

## 목표

- [x] 환경별 설정을 별도 파일로 분리
  - `environments/devsisters-macbook.nix`
  - `environments/devsisters-macstudio.nix`  
  - `environments/wsl-ubuntu.nix`
- [x] 하드코딩된 값들을 환경 설정으로 이동
  - 사용자명, 홈 디렉토리
  - Git 사용자 정보
  - 시스템별 경로

## 현재 상황 분석

### 기존 구조의 문제점
- `flake.nix:44-62`에서 환경 설정이 하드코딩됨
- 환경별 중복 정보 (사용자명, 시스템 정보)
- 새로운 환경 추가 시 `flake.nix` 직접 수정 필요
- Git 사용자 정보가 각 모듈에서 하드코딩됨

### 현재 환경 설정
```nix
environmentConfigs = {
  "devsisters-macbook" = {
    system = "aarch64-darwin";
    username = "gyutak";
    homeDirectory = "/Users/gyutak";
    extraModules = [ ./modules/devsisters ];
  };
  "devsisters-macstudio" = {
    system = "aarch64-darwin";
    username = "gyutak";
    homeDirectory = "/Users/gyutak";
    extraModules = [ ./modules/devsisters ];
  };
  "wsl-ubuntu" = {
    system = "x86_64-linux";
    username = "gytkk";
    homeDirectory = "/home/gytkk";
    extraModules = [];
  };
};
```

## 실행 계획

### Phase 1: 환경 디렉토리 구조 생성

#### 1.1 environments 디렉토리 생성
```bash
mkdir environments
```

#### 1.2 환경별 설정 파일 생성
각 환경마다 별도의 Nix 파일을 생성하여 설정을 중앙화합니다.

### Phase 2: 환경 설정 파일 구현

#### 2.1 environments/devsisters-macbook.nix
```nix
{
  # 시스템 정보
  system = "aarch64-darwin";
  platform = "darwin";
  
  # 사용자 정보
  username = "gyutak";
  homeDirectory = "/Users/gyutak";
  
  # Git 설정
  git = {
    userName = "gyutak";
    userEmail = "gytk.kim@gmail.com";
  };
  
  # 환경별 모듈
  extraModules = [ ../modules/devsisters ];
  
  # 환경별 특성
  enableDevsisters = true;
  enableDocker = true;
}
```

#### 2.2 environments/devsisters-macstudio.nix
```nix
{
  # 시스템 정보
  system = "aarch64-darwin";
  platform = "darwin";
  
  # 사용자 정보  
  username = "gyutak";
  homeDirectory = "/Users/gyutak";
  
  # Git 설정
  git = {
    userName = "gyutak";
    userEmail = "gytk.kim@gmail.com";
  };
  
  # 환경별 모듈
  extraModules = [ ../modules/devsisters ];
  
  # 환경별 특성
  enableDevsisters = true;
  enableDocker = true;
}
```

#### 2.3 environments/wsl-ubuntu.nix
```nix
{
  # 시스템 정보
  system = "x86_64-linux";
  platform = "linux";
  
  # 사용자 정보
  username = "gytkk";
  homeDirectory = "/home/gytkk";
  
  # Git 설정
  git = {
    userName = "gytkk";
    userEmail = "gytk.kim@gmail.com";
  };
  
  # 환경별 모듈
  extraModules = [];
  
  # 환경별 특성
  enableDevsisters = false;
  enableDocker = false;
}
```

### Phase 3: lib/environments.nix 업데이트

#### 3.1 환경 설정 로더 함수 추가
```nix
# 환경 설정 로더
loadEnvironmentConfig = name:
  let
    envFile = ../environments + "/${name}.nix";
  in
    if builtins.pathExists envFile
    then import envFile
    else throw "Environment config file not found: ${envFile}";

# 모든 환경 설정 자동 로드
allEnvironments = 
  let
    envNames = [ "devsisters-macbook" "devsisters-macstudio" "wsl-ubuntu" ];
  in
    builtins.listToAttrs (map (name: {
      inherit name;
      value = loadEnvironmentConfig name;
    }) envNames);
```

### Phase 4: flake.nix 리팩토링

#### 4.1 하드코딩된 environmentConfigs 제거
```nix
# 기존 하드코딩된 설정 제거
# environmentConfigs = { ... };

# 라이브러리에서 환경 설정 가져오기
environmentConfigs = myLib.environments.allEnvironments;
```

### Phase 5: 모듈 업데이트

#### 5.1 Git 모듈 업데이트
`modules/git/default.nix`에서 환경별 Git 설정 사용:
```nix
{
  config,
  lib,
  pkgs,
  environmentConfig ? null,
  ...
}:

{
  programs.git = {
    enable = true;
    userName = if environmentConfig != null 
               then environmentConfig.git.userName 
               else "default-user";
    userEmail = if environmentConfig != null 
                then environmentConfig.git.userEmail 
                else "default@example.com";
    # ... 나머지 설정
  };
}
```

### Phase 6: 검증 및 테스트

#### 6.1 구문 검사
```bash
nix flake check
```

#### 6.2 빌드 테스트
```bash
home-manager build --flake .#wsl-ubuntu
home-manager build --flake .#devsisters-macbook
home-manager build --flake .#devsisters-macstudio
```

## 구현 세부사항

### 디렉토리 구조
```
environments/
├── devsisters-macbook.nix
├── devsisters-macstudio.nix
└── wsl-ubuntu.nix

lib/
├── default.nix
├── builders.nix
└── environments.nix  # 업데이트
```

### 환경 설정 스키마
각 환경 파일은 다음 구조를 가집니다:
```nix
{
  # 필수 필드
  system = "시스템 아키텍처";
  platform = "플랫폼 타입";
  username = "사용자명";
  homeDirectory = "홈 디렉토리 경로";
  
  # Git 설정
  git = {
    userName = "Git 사용자명";
    userEmail = "Git 이메일";
  };
  
  # 모듈 설정
  extraModules = [ 모듈 목록 ];
  
  # 기능 플래그
  enableDevsisters = 불린값;
  enableDocker = 불린값;
}
```

## 예상 효과

### 즉시 효과
- 환경별 설정의 명확한 분리
- Git 사용자 정보의 중앙화
- `flake.nix`의 코드 간소화

### 장기적 효과
- 새로운 환경 추가 시 단일 파일만 생성
- 환경별 설정 변경의 영향 범위 명확화
- 설정 재사용성 향상

## 위험 요소 및 대응책

### 위험 요소
- 파일 경로 변경으로 인한 빌드 실패
- 환경 설정 불일치

### 대응책
- 단계별 마이그레이션
- 각 단계마다 빌드 검증
- 기존 동작과 완전히 동일하게 유지

## 성공 기준

- [x] 모든 환경 설정이 별도 파일로 분리
- [x] `nix flake check` 통과
- [x] 모든 환경에서 `home-manager build` 성공
- [x] Git 사용자 정보가 환경별로 올바르게 설정
- [x] 기존 기능과 100% 동일한 동작

## 후속 작업

이 작업 완료 후 다음 TODO들을 연계 진행:
- **TODO 5**: 모듈 구조 표준화 (environmentConfig 활용)
- **TODO 8**: 조건부 모듈 로딩 시스템 (환경별 기능 플래그 활용)