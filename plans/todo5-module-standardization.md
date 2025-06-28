# TODO 5: 모듈 구조 표준화 액션 플랜

## 📋 현황 분석

### 현재 모듈별 매개변수 상태

- **modules/git/**: `environmentConfig` 의존성 제거됨 (완료)
- **modules/zsh/**: `environmentConfig` 사용하여 환경별 설정 접근
- **modules/claude/**: 기본 매개변수만 사용
- **modules/devsisters/**: `environmentConfig` 사용하여 조건부 로딩

### 문제점

1. **일관성 부족**: 일부 모듈은 `environmentConfig`를 사용하고, 일부는 사용하지 않음
2. **매개변수 접근 방식 혼재**: 직접 매개변수 vs environmentConfig를 통한 접근
3. **타입 안정성 부족**: 옵셔널 매개변수에 대한 명확한 검증 없음

## 🎯 목표

1. 모든 모듈에서 일관된 매개변수 패턴 사용
2. 환경별 설정과 모듈별 기본값의 명확한 분리
3. 타입 안정성과 검증 강화

## 📝 액션 아이템

### 1. 모듈 매개변수 표준 패턴 정의

**결정사항:**

- 모든 모듈은 기본적으로 독립적으로 동작해야 함
- 환경별 커스터마이징이 필요한 경우만 `environmentConfig` 사용
- 선택적 매개변수는 기본값 제공

**표준 모듈 시그니처:**

```nix
{
  config,
  lib,
  pkgs,
  # 필요한 경우에만 추가
  environmentConfig ? null,
  username ? "default",
  homeDirectory ? "/home/default",
  ...
}:
```

### 2. modules/zsh/ 리팩토링

**현재 상태:**

- `environmentConfig.system`을 사용하여 조건부 설정 적용

**개선 계획:**

- `system` 매개변수를 직접 받도록 변경
- 플랫폼별 설정을 명시적으로 처리
- 기본값으로 크로스 플랫폼 호환성 확보

**구체적 작업:**

```bash
# 1. modules/zsh/default.nix 매개변수 수정
# 2. 플랫폼별 조건부 로직을 lib.mkIf로 명확히 표현
# 3. environmentConfig 의존성 제거
```

### 3. modules/devsisters/ 리팩토링

**현재 상태:**

- `environmentConfig.includeDevsisters`로 조건부 로딩

**개선 계획:**

- `enableDevsisters` 플래그를 직접 매개변수로 받기
- 모듈 자체는 항상 로드되지만 내용을 조건부로 활성화
- 더 명확한 enable/disable 패턴 사용

**구체적 작업:**

```bash
# 1. enableDevsisters 매개변수 추가
# 2. lib.mkIf를 사용한 조건부 설정
# 3. environmentConfig 의존성 제거
```

### 4. 모듈 로딩 시스템 개선

**목표:**

- 환경별 설정에서 모듈별 매개변수 명시적 전달
- `extraSpecialArgs`를 통한 일관된 매개변수 전달

**구체적 작업:**

#### A. lib/builders.nix 수정

```nix
# extraSpecialArgs 확장
extraSpecialArgs = {
  inherit (config) username homeDirectory system;
  enableDevsisters = config.includeDevsisters or false;
  # 기타 필요한 매개변수들
};
```

#### B. 환경별 설정 파일 수정

```nix
# environments/*.nix에서 모듈별 설정 명시
{
  # ... 기존 설정
  moduleConfig = {
    zsh = {
      enablePlatformSpecific = true;
    };
    devsisters = {
      enable = true;
    };
  };
}
```

### 5. 모듈 검증 시스템 추가

**목표:**

- 각 모듈에서 필요한 매개변수 검증
- 의미있는 에러 메시지 제공

**구체적 작업:**

```nix
# 각 모듈에 검증 로직 추가
let
  requiredParams = [ "username" "homeDirectory" ];
  missingParams = builtins.filter (p: !(builtins.hasAttr p args)) requiredParams;
in
assert missingParams == [] || throw "Missing required parameters: ${toString missingParams}";
```

## 🚀 실행 계획

### Phase 1: 기반 작업 (1주)

1. **표준 모듈 시그니처 문서화**
2. **lib/builders.nix에서 매개변수 전달 개선**
3. **모듈 검증 헬퍼 함수 생성**

### Phase 2: 모듈별 리팩토링 (2주)

1. **modules/zsh/ 리팩토링**
   - system 매개변수 직접 사용
   - 플랫폼별 조건 명시화
2. **modules/devsisters/ 리팩토링**
   - enableDevsisters 플래그 도입
   - 조건부 로딩 개선

### Phase 3: 검증 및 테스트 (1주)

1. **모든 환경에서 빌드 테스트**
2. **매개변수 검증 로직 테스트**
3. **문서 업데이트**

## 📊 성공 지표

### 정량적 지표

- [ ] 모든 모듈이 독립적으로 로드 가능
- [ ] `environmentConfig` 의존성 95% 이상 제거
- [ ] 모든 환경에서 빌드 성공

### 정성적 지표

- [ ] 새로운 모듈 추가 시 표준 패턴 적용 용이
- [ ] 환경별 설정 변경 시 영향 범위 명확
- [ ] 에러 발생 시 의미있는 메시지 제공

## 🔄 리스크 및 대응

### 리스크 1: 기존 환경 설정 깨짐

**대응:** 각 단계마다 모든 환경에서 빌드 테스트

### 리스크 2: 복잡성 증가

**대응:** 단계적 접근으로 점진적 개선

### 리스크 3: 호환성 문제

**대응:** 기존 인터페이스 유지하면서 새로운 패턴 도입

## 🎯 다음 단계

이 계획 완료 후:

1. **TODO 6: 프로필 시스템 구현** 준비
2. **TODO 8: 조건부 모듈 로딩 시스템** 기반 마련
3. **모듈 문서화** 표준 확립
