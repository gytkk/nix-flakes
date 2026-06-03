# tmux 모달 UI 구현 계획서

## 목표

- tmux에서 zellij처럼 "현재 모드가 무엇인지" 항상 명확히 보이게 한다.
- 특정 모드에 진입했을 때 해당 모드에서 가능한 액션과 단축키를 하단 status bar에 보여준다.
- 기존 tmux 동작을 크게 깨지 않고, 현재 `modules/tmux/default.nix` 위에 점진적으로 얹는다.

## 범위

- 포함
  - 모드 진입 상태 표시
  - 모드별 단축키 힌트 표시
  - 주요 모드 전환용 키 바인딩
  - 모드 종료 및 복귀 규칙 통일
  - 현재 tmux status bar와 공존 가능한 최소 UI
- 제외
  - 플러그인 의존
  - 복잡한 팝업 메뉴 중심 UX
  - 동적 아이콘, 애니메이션, 마우스 전용 상호작용
  - 세션 간 영구 상태 저장

## 구현 파일

- 주 구현: `modules/tmux/default.nix`
- 필요 시 문서 보강: `README.md`

## 핵심 설계

### 1. 상태 저장 방식

- tmux user option을 사용한다.
- 예시
  - `@mode`
  - `@mode_label`
  - `@mode_hints`
- 기본값
  - `@mode = root`
  - `@mode_label = NORMAL`
  - `@mode_hints = C-b w windows | C-b p panes | C-b r resize`

### 2. 모드 전환 방식

- tmux `key table`을 사용한다.
- 각 모드는 별도 key table로 구성한다.
- root에서 특정 진입 키를 누르면
  - `@mode`, `@mode_label`, `@mode_hints` 갱신
  - `switch-client -T <mode-table>` 실행
- 모드에서 액션을 실행한 뒤에는 아래 둘 중 하나로 처리한다.
  - 1회성 액션 모드: 즉시 root 복귀
  - 연속 작업 모드: 명시적으로 `Enter` 또는 `Escape`로 root 복귀

### 3. 상태 표시 방식

- tmux status bar를 2줄로 사용한다.
- 1줄
  - session 이름
  - window 목록
  - 현재 시각
- 2줄
  - 현재 모드 라벨
  - 해당 모드에서 가능한 단축키 힌트
- 상태 표시는 `status-format` 또는 `status-left`/ `status-right` 조합으로 구현한다.
- 목표는 "팝업을 열지 않아도 지금 가능한 행동이 보인다"는 점이다.

### 4. 복귀 규칙

- 모든 커스텀 모드에서 공통으로 아래 키를 지원한다.
  - `Escape`: root 복귀
  - `Enter`: root 복귀
  - `q`: root 복귀
- root 복귀 시 항상 아래를 실행한다.
  - `set -gq @mode root`
  - `set -gq @mode_label NORMAL`
  - `set -gq @mode_hints <기본 힌트>`
  - `switch-client -T root`

## 1차 구현 대상 모드

### A. window 모드

- 진입 키
  - `prefix + w`
- 목적
  - 창 관련 작업을 한곳에 모은다.
- 표시 라벨
  - `WINDOW`
- 힌트
  - `c 새 창 | , 이름 변경 | n 다음 | p 이전 | & 닫기 | 숫자 창 이동 | Enter/Esc 종료`
- 액션
  - `c`: 새 창 생성
  - `,`: 현재 창 이름 변경
  - `n`: 다음 창
  - `p`: 이전 창
  - `w`: choose-tree 또는 window tree
  - `&`: 현재 창 닫기 확인
  - `0-9`: 해당 번호 창 이동

### B. pane 모드

- 진입 키
  - `prefix + p`
- 목적
  - pane 이동 및 조작을 모은다.
- 표시 라벨
  - `PANE`
- 힌트
  - `h/j/k/l 이동 | v 세로 분할 | s 가로 분할 | z 줌 | x 닫기 | o 다음 pane | Enter/Esc 종료`
- 액션
  - `h/j/k/l`: pane 이동
  - `v`: 오른쪽 분할
  - `s`: 아래 분할
  - `z`: zoom 토글
  - `x`: pane 닫기 확인
  - `o`: 다음 pane 이동
  - `q`: root 복귀

### C. resize 모드

- 진입 키
  - `prefix + r`
- 목적
  - pane 크기 조절을 연속 작업으로 수행한다.
- 표시 라벨
  - `RESIZE`
- 힌트
  - `h/l 너비 | j/k 높이 | H/J/K/L 크게 이동 | = 균등 정렬 | Enter/Esc 종료`
- 액션
  - `h`: 왼쪽 축소
  - `l`: 오른쪽 확장
  - `j`: 아래 확장
  - `k`: 위 축소
  - `H/J/K/L`: 더 큰 단위 resize
  - `=`: pane 균등 분배

## root 기본 힌트

- 기본 상태에서 하단 2줄째에 최소 힌트를 노출한다.
- 예시
  - `C-b w windows | C-b p panes | C-b r resize | C-b h help`
- 목표
  - 새로 익히는 키만 보여주고, 모든 키를 나열하지 않는다.

## UI 규칙

- 현재 선택된 모드는 색으로도 구분한다.
- 권장 색 규칙
  - `NORMAL`: 중립 회색/기본색
  - `WINDOW`: 파랑 계열
  - `PANE`: 초록 계열
  - `RESIZE`: 노랑 계열
- 모드 라벨은 짧고 고정폭처럼 보이게 유지한다.
- 힌트는 한 줄 안에 들어오도록 짧은 문구를 사용한다.
- 상태바가 너무 길어지면 우선순위가 낮은 힌트부터 줄인다.

## 키 설계 원칙

- 진입 키는 prefix 뒤 한 글자로 통일한다.
- 모드 안에서는 가능한 한 vim식 `h/j/k/l`을 우선 사용한다.
- 현재 이미 있는 바인딩과 충돌하면 아래 우선순위를 따른다.
  - 1. 기존 핵심 tmux 동작 유지
  - 2. 현재 repo에서 이미 노출한 help/reload/tree 동작 유지
  - 3. 새 모달 UX 추가

## 단계별 작업 순서

### 1단계. 상태바 기반 준비

- `status`를 2줄로 확장
- `@mode`, `@mode_label`, `@mode_hints` 기본값 설정
- root 기본 힌트 노출
- 현재 상단 상태바와 레이아웃 충돌 없는지 확인

완료 조건

- tmux 시작 직후 `NORMAL` 상태와 기본 힌트가 보인다.

### 2단계. 공통 모드 유틸리티 정리

- 모드 진입용 공통 명령 패턴 정리
- root 복귀용 공통 명령 패턴 정리
- `Escape`, `Enter`, `q` 복귀 규칙 추가

완료 조건

- 아무 모드에서든 동일한 방식으로 빠져나올 수 있다.

### 3단계. window 모드 구현

- `prefix + w`로 진입
- window 관련 액션 연결
- 실행 후 root 복귀 또는 유지 정책 점검

완료 조건

- 진입 시 `WINDOW` 라벨과 힌트가 보인다.
- 창 생성, 이름 변경, 이동, 닫기가 정상 동작한다.

### 4단계. pane 모드 구현

- `prefix + p`로 진입
- pane 이동/분할/줌/닫기 연결

완료 조건

- 진입 시 `PANE` 라벨과 힌트가 보인다.
- pane 관련 핵심 조작이 마우스 없이 가능하다.

### 5단계. resize 모드 구현

- `prefix + r`로 진입
- 연속 resize 작업 연결

완료 조건

- 진입 시 `RESIZE` 라벨과 힌트가 보인다.
- resize 중 모드를 유지하다가 명시적으로 종료할 수 있다.

### 6단계. polish

- 힌트 문구 길이 조정
- 색/강조 조정
- 기존 help popup과 역할 중복 최소화

완료 조건

- 상태바가 과하게 복잡하지 않고, 초보자도 모드를 읽을 수 있다.

## 검증 체크리스트

- tmux 시작 시 에러 없이 로드된다.
- `prefix + w` 진입 시 `WINDOW` 표시가 즉시 갱신된다.
- `prefix + p` 진입 시 `PANE` 표시가 즉시 갱신된다.
- `prefix + r` 진입 시 `RESIZE` 표시가 즉시 갱신된다.
- 각 모드에서 `Escape`, `Enter`, `q`가 root 복귀로 동작한다.
- root 복귀 시 힌트가 기본 힌트로 돌아온다.
- status bar 2줄이 narrow 터미널에서도 치명적으로 깨지지 않는다.
- 기존 `prefix + h`, `prefix + ?`, `prefix + w` 동작 재배치 충돌을 확인한다.

## 기존 바인딩과의 정리 필요 항목

- 현재 `prefix + w`는 `choose-tree -Zw`에 사용 중이다.
- 모달 UI를 도입하면 아래 중 하나를 선택해야 한다.
  - `prefix + w`를 window 모드 진입으로 변경하고 tree는 모드 내부로 이동
  - window 모드 진입 키를 다른 키로 변경
- 계획서 기준 권장안
  - `prefix + w`를 window 모드 진입으로 사용
  - tree는 window 모드 안의 `w`에 배치

## 구현 후 문서 반영

- `README.md`의 tmux 섹션에 아래만 추가한다.
  - 모드 진입 키
  - 각 모드의 목적
  - 종료 키

## 비목표

- zellij와 완전히 동일한 UI 재현
- 모든 tmux 기능의 모드화
- 사용자가 커스텀한 모든 키를 자동 힌트로 생성
- 복잡한 스크립트 기반 렌더러 도입

## 최종 산출물

- `modules/tmux/default.nix`에 모달 UI 지원 추가
- 2줄 status bar 기반 모드 표시
- `window`, `pane`, `resize` 3개 모드
- 최소 README 사용법 업데이트
