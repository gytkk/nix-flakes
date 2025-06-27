# TODO 2: Home Configuration 헬퍼 함수 생성 액션 플랜

## 개요

현재 `flake.nix`의 `homeConfigurations` 섹션(line 71-115)에서 각 환경별 설정이 중복되고 있음. 동일한 구조의 `homeManagerConfiguration` 호출이 반복되며, `extraSpecialArgs` 패턴과 모듈 설정이 중복됨.

## 현재 문제점 분석

### 1. 코드 중복 현황
```nix
# 현재 코드 (flake.nix:71-115)
homeConfigurations = {
  "devsisters-macbook" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = pkgs.aarch64-darwin;
    extraSpecialArgs = {
      system = "aarch64-darwin";
      username = "gyutak";
      homeDirectory = "/Users/gyutak";
      zsh-powerlevel10k = inputs.zsh-powerlevel10k;
    };
    modules = [
      ./home.nix
      ./modules/devsisters
    ];
  };

  "devsisters-macstudio" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = pkgs.aarch64-darwin;
    extraSpecialArgs = {
      system = "aarch64-darwin";
      username = "gyutak";
      homeDirectory = "/Users/gyutak";
      zsh-powerlevel10k = inputs.zsh-powerlevel10k;
    };
    modules = [
      ./home.nix
      ./modules/devsisters
    ];
  };

  "wsl-ubuntu" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = pkgs.x86_64-linux;
    extraSpecialArgs = {
      system = "x86_64-linux";
      username = "gytkk";
      homeDirectory = "/home/gytkk";
      zsh-powerlevel10k = inputs.zsh-powerlevel10k;
    };
    modules = [
      ./home.nix
    ];
  };
};
```

**중복되는 요소들:**
- `inputs.home-manager.lib.homeManagerConfiguration` 호출 패턴
- `extraSpecialArgs`의 `system`, `zsh-powerlevel10k` 설정
- `modules = [./home.nix]` 기본 모듈
- 유사한 `username`/`homeDirectory` 패턴

### 2. 환경별 차이점 분석
| 환경 | system | username | homeDirectory | 추가 모듈 |
|------|--------|----------|---------------|-----------|
| devsisters-macbook | aarch64-darwin | gyutak | /Users/gyutak | modules/devsisters |
| devsisters-macstudio | aarch64-darwin | gyutak | /Users/gyutak | modules/devsisters |
| wsl-ubuntu | x86_64-linux | gytkk | /home/gytkk | - |

### 3. 확장성 문제
- 새로운 환경 추가 시 전체 설정을 반복 작성해야 함
- 공통 설정 변경 시 모든 환경에서 수정 필요
- 환경별 설정 불일치 가능성
- 하드코딩된 값들로 인한 유연성 부족

## 액션 플랜

### Phase 1: 환경 설정 데이터 구조 설계

#### Step 1.1: 환경 설정 스키마 정의
```nix
# 목표 구조
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

#### Step 1.2: 공통 설정 분리
```nix
# 모든 환경에서 공통으로 사용되는 설정
commonSpecialArgs = {
  zsh-powerlevel10k = inputs.zsh-powerlevel10k;
};

baseModules = [ ./home.nix ];
```

### Phase 2: `mkHomeConfig` 헬퍼 함수 생성

#### Step 2.1: 기본 함수 구조
```nix
mkHomeConfig = name: config: inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = pkgs.${config.system};
  extraSpecialArgs = commonSpecialArgs // {
    inherit (config) system username homeDirectory;
  };
  modules = baseModules ++ config.extraModules;
};
```

#### Step 2.2: 향상된 함수 구조 (매개변수 검증 포함)
```nix
mkHomeConfig = name: config:
  let
    requiredFields = [ "system" "username" "homeDirectory" ];
    missingFields = builtins.filter (field: !(builtins.hasAttr field config)) requiredFields;
  in
    if missingFields != []
    then throw "Missing required fields for ${name}: ${builtins.toString missingFields}"
    else inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = pkgs.${config.system};
      extraSpecialArgs = commonSpecialArgs // {
        inherit (config) system username homeDirectory;
      };
      modules = baseModules ++ (config.extraModules or []);
    };
```

### Phase 3: 동적 설정 생성 시스템

#### Step 3.1: `builtins.mapAttrs`를 활용한 동적 생성
```nix
homeConfigurations = builtins.mapAttrs mkHomeConfig environmentConfigs;
```

#### Step 3.2: 조건부 모듈 로딩 지원
```nix
mkHomeConfig = name: config:
  let
    conditionalModules = 
      (if builtins.hasAttr "enableDevsisters" config && config.enableDevsisters
       then [ ./modules/devsisters ]
       else []);
  in inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = pkgs.${config.system};
    extraSpecialArgs = commonSpecialArgs // {
      inherit (config) system username homeDirectory;
    };
    modules = baseModules ++ (config.extraModules or []) ++ conditionalModules;
  };
```

## 구현 세부사항

### 1. 파일 수정 위치
- **파일**: `/Users/gyutak/development/nix-flakes/flake.nix`
- **수정 범위**: line 50-115 (`homeConfigurations` 섹션 전체)

### 2. 단계별 변경사항

#### 2.1 Phase 1 구현
1. `environmentConfigs` 객체 정의
2. `commonSpecialArgs`, `baseModules` 정의
3. 기존 설정과의 호환성 확인

#### 2.2 Phase 2 구현
1. `mkHomeConfig` 함수 정의
2. 기존 하드코딩된 설정을 함수 호출로 대체
3. 매개변수 검증 로직 추가

#### 2.3 Phase 3 구현
1. `builtins.mapAttrs`를 활용한 동적 생성
2. 조건부 모듈 로딩 시스템 추가
3. 확장성을 위한 추가 옵션 지원

### 3. 호환성 보장
- 기존 환경명 (`devsisters-macbook`, `devsisters-macstudio`, `wsl-ubuntu`) 유지
- 기존 `extraSpecialArgs` 구조 유지
- 모듈 로딩 순서 유지

## 테스트 계획

### 1. 구조 검증
```bash
# 환경별 설정 확인
nix eval .#homeConfigurations.devsisters-macbook.config.home.username
nix eval .#homeConfigurations.devsisters-macbook.config.home.homeDirectory
```

### 2. 빌드 테스트
```bash
# 각 환경별 빌드 확인
home-manager build --flake .#devsisters-macbook
home-manager build --flake .#devsisters-macstudio  
home-manager build --flake .#wsl-ubuntu
```

### 3. 설정 검증
```bash
# flake 설정 검증
nix flake check

# 특정 환경의 extraSpecialArgs 확인
nix eval .#homeConfigurations.devsisters-macbook.extraSpecialArgs.system
```

## 예상 효과

### 1. 코드 품질 개선
- **중복 제거**: 45줄 → 약 25줄로 단축 (44% 감소)
- **일관성 확보**: 모든 환경에서 동일한 설정 패턴 보장
- **가독성 향상**: 환경별 차이점이 명확하게 구분됨

### 2. 유지보수성 향상
- **단일 진실 공급원**: 공통 설정 변경 시 한 곳만 수정
- **환경 추가 간소화**: 새 환경 추가 시 설정 객체만 추가
- **오류 감소**: 매개변수 검증으로 설정 오류 방지

### 3. 확장성 개선
- **동적 환경 생성**: 설정 기반 자동 환경 생성
- **조건부 기능**: 환경별 선택적 기능 활성화
- **프로파일 시스템**: 향후 프로파일 기반 설정 지원 기반 마련

## 위험 요소 및 대응

### 1. 복잡성 증가
- **위험**: 함수화로 인한 코드 이해 난이도 상승
- **대응**: 명확한 주석과 예제, 단계적 구현

### 2. 디버깅 어려움
- **위험**: 동적 생성으로 인한 오류 추적 복잡화
- **대응**: 매개변수 검증 및 명확한 오류 메시지

### 3. 기존 설정 파괴
- **위험**: 리팩토링 과정에서 기존 동작 변경
- **대응**: 단계별 테스트 및 백업, 점진적 적용

## 다음 단계

이 개선 완료 후 진행할 연관 작업:
1. **TODO 4**: 환경별 설정 중앙화 (환경 설정을 별도 파일로 분리)
2. **TODO 5**: 모듈 구조 표준화 (매개변수 일관성 확보)
3. **TODO 6**: 프로필 시스템 구현 (패키지 프로필 조합)

## 마이그레이션 전략

### Phase 1: 기본 구조 (1시간)
1. `environmentConfigs` 정의
2. `commonSpecialArgs`, `baseModules` 분리
3. 기본 `mkHomeConfig` 함수 생성

### Phase 2: 함수 적용 (30분)
1. 기존 설정을 함수 호출로 대체
2. 빌드 테스트 및 검증

### Phase 3: 고급 기능 (1시간)
1. 매개변수 검증 추가
2. 조건부 모듈 로딩
3. 동적 환경 생성

**총 예상 소요 시간**: 2.5시간

## 성공 지표

- [ ] 코드 라인 수 44% 감소 달성
- [ ] 모든 기존 환경 빌드 성공
- [ ] 새 환경 추가 시간 5분 이내 달성
- [ ] `nix flake check` 통과
- [ ] 기존 동작 100% 호환성 유지