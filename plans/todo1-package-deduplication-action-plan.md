# TODO 1: Package 정의 함수화 액션 플랜

## 개요

현재 `flake.nix`에서 패키지 정의 부분(line 37-58)에서 중복된 설정이 발견됨. 두 개의 시스템별 패키지 정의에서 동일한 설정이 반복되고 있어 이를 함수화하여 개선이 필요함.

## 현재 문제점 분석

### 1. 코드 중복 현황
```nix
# 현재 코드 (flake.nix:37-58)
pkgs = {
  "x86_64-linux" = 
    import nixpkgs {
      config.allowUnfree = true;
      system = "x86_64-linux";
      overlays = [
        inputs.nix-vscode-extensions.overlays.default
      ];
    };
  "aarch64-darwin" = 
    import nixpkgs {
      config.allowUnfree = true;
      system = "aarch64-darwin";
      overlays = [
        inputs.nix-vscode-extensions.overlays.default
      ];
    };
};
```

**중복되는 요소들:**
- `config.allowUnfree = true`
- `overlays = [inputs.nix-vscode-extensions.overlays.default]`
- `import nixpkgs` 패턴

### 2. 확장성 문제
- 새로운 시스템 추가 시 동일한 설정을 반복 작성해야 함
- overlay나 config 변경 시 모든 시스템 정의를 수정해야 함
- 실수로 인한 시스템별 설정 불일치 가능성

## 액션 플랜

### Phase 1: `mkPkgs` 헬퍼 함수 생성

#### Step 1.1: 함수 설계
```nix
# 목표 함수 구조
mkPkgs = system: import nixpkgs {
  inherit system;
  config.allowUnfree = true;
  overlays = [
    inputs.nix-vscode-extensions.overlays.default
  ];
};
```

#### Step 1.2: 함수 적용
```nix
# 개선된 코드
pkgs = {
  "x86_64-linux" = mkPkgs "x86_64-linux";
  "aarch64-darwin" = mkPkgs "aarch64-darwin";
};
```

### Phase 2: 시스템별 overlay 설정 통합

#### Step 2.1: Overlay 중앙화
- 현재는 VS Code extension overlay만 사용
- 향후 추가될 overlay들을 고려한 확장 가능한 구조 설계

#### Step 2.2: 조건부 overlay 지원
```nix
# 목표 구조
mkPkgs = system: overlays: import nixpkgs {
  inherit system overlays;
  config.allowUnfree = true;
};
```

### Phase 3: 설정 매개변수화

#### Step 3.1: Config 설정 분리
```nix
# 목표: 설정을 매개변수로 받는 구조
defaultPkgsConfig = {
  allowUnfree = true;
  # 향후 추가될 설정들
};

mkPkgs = system: config: overlays: import nixpkgs {
  inherit system overlays;
  config = config;
};
```

## 구현 세부사항

### 1. 파일 수정 위치
- **파일**: `/Users/gyutak/development/nix-flakes/flake.nix`
- **수정 범위**: line 36-58 (`let` 블록 내부)

### 2. 변경 사항 요약
1. `mkPkgs` 함수 정의 추가
2. 기존 `pkgs` 객체를 `mkPkgs` 함수 호출로 대체
3. 중복된 설정 제거

### 3. 호환성 보장
- 기존 `pkgs.aarch64-darwin`, `pkgs.x86_64-linux` 접근 방식 유지
- `homeConfigurations`에서의 사용법 변경 없음

## 테스트 계획

### 1. 빌드 테스트
```bash
# 각 환경별 빌드 확인
home-manager build --flake .#devsisters-macbook
home-manager build --flake .#devsisters-macstudio  
home-manager build --flake .#wsl-ubuntu
```

### 2. 설정 검증
```bash
# flake 설정 검증
nix flake check
```

### 3. 실제 환경 테스트
```bash
# 안전한 환경에서 실제 전환 테스트
home-manager switch --flake .#devsisters-macbook
```

## 예상 효과

### 1. 코드 품질 개선
- **중복 제거**: 21줄 → 약 10줄로 단축
- **일관성 확보**: 모든 시스템에서 동일한 설정 보장
- **가독성 향상**: 함수명을 통한 의도 명확화

### 2. 유지보수성 향상
- **단일 진실 공급원**: 설정 변경 시 한 곳만 수정
- **확장성**: 새로운 시스템 추가 시 한 줄로 처리
- **오류 감소**: 설정 불일치로 인한 오류 방지

### 3. 향후 개선 기반 마련
- **모듈화**: 다른 TODO 항목들의 기반 구조 제공
- **표준화**: 헬퍼 함수 패턴의 표준 확립

## 위험 요소 및 대응

### 1. 호환성 문제
- **위험**: 기존 설정 파괴 가능성
- **대응**: 단계별 테스트 및 백업

### 2. 복잡성 증가
- **위험**: 간단한 설정이 함수화로 인해 복잡해질 수 있음
- **대응**: 명확한 함수명과 주석으로 가독성 확보

## 다음 단계

이 개선 완료 후 진행할 연관 작업:
1. **TODO 2**: Home Configuration 헬퍼 함수 생성
2. **TODO 3**: 라이브러리 디렉토리 구조 생성으로 `mkPkgs` 함수 이관

## 구현 타임라인

- **Phase 1**: 1시간 (함수 생성 및 적용)
- **Phase 2**: 30분 (overlay 통합)
- **Phase 3**: 30분 (매개변수화)
- **테스트**: 30분 (빌드 및 검증)

**총 예상 소요 시간**: 2.5시간
