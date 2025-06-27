# TODO 3: 라이브러리 디렉토리 구조 생성 액션 플랜

## 개요

현재 `flake.nix`에 구현된 헬퍼 함수들을 `lib/` 디렉토리로 분리하여 코드의 모듈화와 재사용성을 개선합니다.

## 목표

- [x] `lib/` 디렉토리 생성
- [x] `lib/default.nix` - 라이브러리 익스포트
- [x] `lib/builders.nix` - 빌더 헬퍼 함수들

## 현재 상황 분석

### 기존 코드 현황
- `flake.nix:38-44`: `mkPkgs` 함수 (패키지 생성)
- `flake.nix:81-94`: `mkHomeConfig` 함수 (홈 설정 생성)
- `flake.nix:52-71`: `environmentConfigs` (환경별 설정)

### 문제점
- 모든 헬퍼 함수가 `flake.nix`에 집중
- 새로운 환경 추가 시 `flake.nix` 직접 수정 필요
- 함수 재사용이 어려움

## 실행 계획

### Phase 1: 기본 구조 생성

#### 1.1 lib 디렉토리 생성
```bash
mkdir lib
```

#### 1.2 lib/default.nix 생성
```nix
{ inputs, nixpkgs }:
{
  builders = import ./builders.nix { inherit inputs nixpkgs; };
}
```

#### 1.3 lib/builders.nix 생성
기존 `flake.nix`의 헬퍼 함수들을 이전:
- `mkPkgs` 함수
- `mkHomeConfig` 함수

### Phase 2: flake.nix 리팩토링

#### 2.1 라이브러리 import 추가
```nix
let
  myLib = import ./lib { inherit inputs nixpkgs; };
in
```

#### 2.2 기존 함수 호출을 라이브러리 함수로 변경
- `mkPkgs` → `myLib.builders.mkPkgs`
- `mkHomeConfig` → `myLib.builders.mkHomeConfig`

### Phase 3: 검증 및 테스트

#### 3.1 구문 검사
```bash
nix flake check
```

#### 3.2 빌드 테스트
```bash
home-manager build --flake .#wsl-ubuntu
home-manager build --flake .#devsisters-macbook
home-manager build --flake .#devsisters-macstudio
```

## 구현 세부사항

### lib/default.nix
```nix
{ inputs, nixpkgs }:
{
  builders = import ./builders.nix { inherit inputs nixpkgs; };
}
```

### lib/builders.nix
```nix
{ inputs, nixpkgs }:
rec {
  # 패키지 생성 헬퍼 함수 (기존 mkPkgs)
  mkPkgs = system: import nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [
      inputs.nix-vscode-extensions.overlays.default
    ];
  };

  # 시스템별 패키지 생성
  mkSystemPkgs = systems:
    builtins.listToAttrs (map (system: {
      name = system;
      value = mkPkgs system;
    }) systems);

  # Home Configuration 헬퍼 함수 (기존 mkHomeConfig)
  mkHomeConfig = { environmentConfigs, commonSpecialArgs, baseModules }: name: config:
    let
      requiredFields = [ "system" "username" "homeDirectory" ];
      missingFields = builtins.filter (field: !(builtins.hasAttr field config)) requiredFields;
      pkgs = mkPkgs config.system;
    in
      if missingFields != []
      then throw "Missing required fields for ${name}: ${builtins.toString missingFields}"
      else inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = commonSpecialArgs // {
          inherit (config) system username homeDirectory;
        };
        modules = baseModules ++ (config.extraModules or []);
      };
}
```

### 수정된 flake.nix 구조
```nix
outputs = { self, nixpkgs, ... }@inputs:
  let
    # 라이브러리 import
    myLib = import ./lib { inherit inputs nixpkgs; };
    
    # 시스템별 패키지
    pkgs = myLib.builders.mkSystemPkgs [ "x86_64-linux" "aarch64-darwin" ];

    # 환경별 설정 (기존과 동일)
    environmentConfigs = { ... };

    # 공통 설정 (기존과 동일)
    commonSpecialArgs = { ... };
    baseModules = [ ./home.nix ];

    # 홈 설정 생성 함수
    mkHomeConfig = myLib.builders.mkHomeConfig {
      inherit environmentConfigs commonSpecialArgs baseModules;
    };
  in {
    homeConfigurations = builtins.mapAttrs mkHomeConfig environmentConfigs;
  };
```

## 예상 효과

### 즉시 효과
- 코드 구조화로 가독성 향상
- 함수 재사용 가능성 확보
- `flake.nix` 파일 크기 감소

### 장기적 효과
- 새로운 헬퍼 함수 추가 용이
- 라이브러리 확장 기반 마련
- 다른 프로젝트에서 재사용 가능

## 위험 요소 및 대응책

### 위험 요소
- 함수 이전 과정에서 실수 가능성
- 기존 환경 설정 호환성 문제

### 대응책
- 단계별 테스트 진행
- 기존 동작과 완전히 동일하게 구현
- 각 단계마다 빌드 검증

## 후속 작업

이 작업 완료 후 다음 TODO들을 연계 진행:
- **TODO 4**: 환경별 설정 중앙화 (lib 확장)
- **TODO 5**: 모듈 구조 표준화 (lib 활용)

## 성공 기준

- [x] `nix flake check` 통과
- [x] 모든 환경에서 `home-manager build` 성공
- [x] 기존 기능과 100% 동일한 동작
- [x] 코드 중복 제거 완료