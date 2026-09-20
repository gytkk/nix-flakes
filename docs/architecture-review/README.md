# nix-flakes 구조 리뷰와 개선 계획

이 문서는 사람과 agent가 설정과 앱을 추가하고 변경하기 쉬운지를 기준으로 저장소 구조를 검토한 결과와 이슈별 해결안을 기록한다.

| 항목 | 내용 |
| --- | --- |
| 검토일 | 2026-09-18 |
| 기준 커밋 | `a271655591fe9706822ff64bec1ad4e001095098` |
| 범위 | Flake와 builder, inventory와 profile, Home Manager와 NixOS 모듈, 패키지, agent-core, 테마, CI, 문서 |
| 검토 방식 | 설계, 유지보수성, 숨은 가정에 대한 정적 분석과 범위가 좁은 로컬 검증 |
| 판단 | `needs_work`. 기본 확장 경로는 있지만 변경 책임과 검증 범위가 불균일하다. |
| 신뢰도 | 정적 구조 판단 기준 8/10. 실제 활성화와 원격 환경은 미검증이다. |
| 해결 상태 | 이슈 4와 8은 적용 완료했다. 나머지 해결안은 제안 단계다. |

파일 링크와 줄 번호는 검토 당시 코드를 근거로 한다. 후속 변경으로 줄 번호가 달라지면 기준 커밋에서 확인한다.

## 핵심 판단

기존 앱 설정은 대응 모듈을 찾아 변경하기 쉽다. 반면 새 환경 추가, 공통 동작 변경, 생성물 삭제에서는 다른 파일과 실행 환경의 전제를 함께 알아야 한다. 우선 개선할 대상은 Sepia의 접근 제한, 변경 영역별 검증 경로, 공통 base에 섞인 개별 기능이다.

다음 구조는 유지할 가치가 있다.

- `inventory -> builder -> profile -> module`은 환경을 구성하는 진입점과 흐름을 제공한다.
- `modules.<name>.enable`과 명시적 import는 설치 가능한 기능과 환경별 선택을 구분한다. Import 목록과 활성화 기본값은 책임이 다르므로, 목록이 두 개라는 이유만으로 자동 탐색을 도입하지 않는다.
- `agent-core`의 canonical 원본과 결정적 renderer는 공통 지침을 한 곳에서 변경할 수 있게 한다.
- 테마의 `core/templates/overrides/exports` 구분은 공통 색상과 앱별 표현을 분리한다.
- Mutable 설정과 OpenClaw의 별도 materialization에는 앱의 소유권과 파일 형식 요구를 반영한 이유가 있다. 일괄적으로 immutable 설치로 바꾸기보다 앱별 계약을 명확히 한다.

## 이슈 목록

`major`는 우선 해결해야 할 운영 또는 유지보수 위험이고, `minor`는 변경 비용과 오류 가능성을 줄이는 개선 사항이다. 작업 순서는 심각도와 선행 작업을 함께 고려한다.

| 번호 | 이슈 | 심각도 | 근거의 성격 | 권장 순서 |
| --- | --- | --- | --- | --- |
| [1](#issue-1) | Sepia 접근 제한 설명과 설정의 불일치 | major | 설정 불일치 확인, 실제 외부 노출 미검증 | 1 |
| [2](#issue-2) | 앱 패키지에 편중된 CI | major | 실행 조건과 검증 대상 확인 | 2 |
| [3](#issue-3) | 공통 base에 섞인 개별 기능 | major | 책임 혼재와 외부 저장소 의존 확인 | 3 |
| [4](#issue-4) | 두 갈래의 로컬 패키지 등록 경로 | minor | 적용 완료, 아래 검증 결과 참조 | 완료 |
| [5](#issue-5) | 거의 동일한 배포 구현의 복제 | minor | 파일 비교와 테스트 대상 확인 | 4 |
| [6](#issue-6) | 테마 삭제와 선택값 검증의 빈틈 | minor | 삭제 후 export 잔존 재현 | 4 |
| [7](#issue-7) | 공통 agent 리뷰 기준의 별도 사본 | minor | 중복 확인, 현재 동작 차이 근거 없음 | 5 |
| [8](#issue-8) | 현재 구조와 어긋난 안내 문서 | minor | 적용 완료, 아래 검증 결과 참조 | 완료 |

<a id="issue-1"></a>

## 1. Sepia 접근 제한 설명과 설정의 불일치

### 현재 상태와 영향

[hosts/pylv-sepia/configuration.nix:29](../../hosts/pylv-sepia/configuration.nix#L29)는 code-server를 `0.0.0.0:8080`, `auth = "none"`으로 설정하면서 Tailscale로 접근을 제한한다고 설명한다. 그러나 [같은 파일:134](../../hosts/pylv-sepia/configuration.nix#L134)는 해당 포트를 전역 방화벽 허용 목록에 넣는다. Copyparty도 모든 주소에서 수신하면서 익명 읽기와 쓰기를 허용한다.

저장소 설정 자체로는 Tailscale 전용 접근이 보장되지 않는다. 호스트까지 도달할 수 있는 다른 네트워크의 클라이언트가 접근할 가능성이 있다. 외부 방화벽, 실제 라우팅, 인터넷 노출 여부는 확인하지 않았다.

서비스 선언과 접근 제한이 떨어져 있으면 이후 앱을 추가할 때 설명만 복사하고 실제 제한을 빠뜨리기 쉽다.

### 해결 방법

1. Code-server와 Copyparty 각각의 의도된 접근 경로를 확인한다. Tailscale 직접 접근, 로컬 Cloudflare Tunnel 경유, 인증을 갖춘 외부 접근 중 실제 사용하는 경로를 기준으로 설정한다.
2. Tailscale 전용 서비스는 전역 허용 목록에서 포트를 제외하고 해당 인터페이스에만 허용한다. 로컬 프록시만 접근해야 하는 서비스는 loopback 수신으로 제한한다.
3. 서비스의 수신 주소, 인증, 방화벽 선언을 해당 서비스 설정 가까이에 모은다. 별도 호스트 파일로 분리하더라도 하나의 변경에서 함께 검토할 수 있게 한다.
4. 실제 접근 방식이 설명과 일치하도록 주석과 호스트 README를 수정한다.

### 완료 기준

- [ ] 의도한 접근 경로에서 정상 접속되고, 허용하지 않은 경로에서는 접속되지 않는다.
- [ ] 허용 포트가 전역과 인터페이스별 목록에 중복 선언되지 않는다.
- [ ] Tailscale 제한을 전제로 인증을 생략하는 서비스는 실제 설정도 그 제한을 보장한다.
- [ ] 평가 결과와 실제 연결 검증을 구분해서 기록한다. 연결 검증 전에는 외부 노출 해소를 완료로 표시하지 않는다.

<a id="issue-2"></a>

## 2. 앱 패키지에 편중된 CI

### 현재 상태와 영향

[.github/workflows/apps-ci.yml:5](../../.github/workflows/apps-ci.yml#L5)의 경로 조건에는 `base/`, `hosts/`, `modules/`, `themes/`, `agent-core/`가 없다. 루트 `flake.nix` 변경으로 실행돼도 [평가 대상:37](../../.github/workflows/apps-ci.yml#L37)은 중첩된 `packages/apps` flake다. [패키지 빌드:81](../../.github/workflows/apps-ci.yml#L81)는 `x86_64-linux`에 한정된다.

루트 [flake.nix:272](../../flake.nix#L272)에는 agent-core 관련 checks가 있지만, 현재 앱 CI가 이를 실행하지 않는다. 따라서 CI 성공만으로 일반 설정 변경이나 Darwin 패키지의 정상 동작을 판단하기 어렵다.

### 해결 방법

1. 기존 앱 패키지 CI는 유지하고, 설정과 로컬 테스트를 담당하는 검증 경로를 추가한다. 어떤 파일 변경이 어떤 검사를 실행하는지 workflow에서 확인할 수 있게 한다.
2. 우선 외부 계정 없이 실행 가능한 agent-core, 테마, 모듈별 기존 테스트를 변경 경로에 연결한다. 문서만 바뀌면 링크와 문서 형식 검증 정도로 제한한다.
3. 일반 모듈 변경에는 관련 옵션과 파일 구성을 확인하는 좁은 평가를 사용하고, 공통 builder나 base 변경에는 대표 Home Manager와 NixOS 구성으로 범위를 넓힌다. 구성 조합을 확인할 때도 전체 시스템 빌드와 평가를 구분한다.
4. 실제 사용하는 `x86_64-linux`와 `aarch64-darwin`의 변경 패키지를 검증한다. 중첩 flake가 선언하는 다른 시스템은 평가 범위와 빌드 지원 범위를 명시한다.
5. 루트 flake의 private inputs와 공개 CI의 접근 제약을 확인한다. 공개 테스트는 독립 실행 경로를 유지하고, private input이 필요한 통합 검증은 인증된 로컬 환경 등 실행 가능한 위치와 명령을 문서화한다.
6. 자동 업데이트 workflow에도 같은 플랫폼 검증 기준을 적용한다. 변경된 파일을 검증 job에 전달하고, 필수 검증이 모두 성공한 뒤에만 해당 변경을 커밋하고 push하도록 연결한다.

### 완료 기준

- [ ] 테마나 agent-core 테스트를 깨뜨린 변경이 해당 CI에서 실패한다.
- [ ] 일반 모듈의 잘못된 옵션을 검증할 경로가 있고, 실행 환경이 문서화돼 있다.
- [ ] Darwin 전용 변경도 검증 대상에 포함되며, hash와 바이너리 문제는 평가만으로 검증됐다고 표시하지 않는다.
- [ ] 문서 변경이 불필요한 Nix 빌드를 유발하지 않는다.
- [ ] CI에서 검증하지 못하는 범위를 성공 상태 뒤에 숨기지 않고 명시한다.
- [ ] 자동 updater가 Darwin hash를 잘못 기록하면 `main`에 반영되기 전에 검증이 실패한다.

<a id="issue-3"></a>

## 3. 공통 base에 섞인 개별 기능

### 현재 상태와 영향

[base/default.nix:64](../../base/default.nix#L64)는 공통 import와 활성화 기본값을 관리한다. 같은 파일에는 agenix 내부 옵션을 읽는 macOS 우회 처리, GitUI 키 설정, Home Manager의 패키지 설치 단계 대체도 들어 있다.

특히 [base/default.nix:136](../../base/default.nix#L136)은 모든 Darwin 환경에 다른 저장소의 `workspace/gytkk-space/automation/mine-sessions.sh`를 실행하는 작업을 활성화한다. 이 동작은 Claude 모듈 활성화 여부와 별개다. 새 macOS 환경을 추가하면 해당 저장소와 스크립트가 있다는 전제까지 따라온다.

### 해결 방법

1. `base`의 역할을 공통 import, 기본 활성화 정책, 공통 환경 값으로 정리한다.
2. Agenix의 Darwin 호환 처리와 Home Manager 설치 단계 우회는 목적이 드러나는 내부 모듈로 옮긴다. 최초 이동에서는 동작을 보존하고, 우회 제거 여부는 버전과 재현 근거를 확인하는 별도 변경으로 다룬다.
3. 세션 분석 작업은 실행 경로와 활성화 여부를 가진 모듈로 분리한다. 실제 사용하는 profile이나 호스트에서 선택하고, 필요한 스크립트가 없을 때 원인을 확인할 수 있는 오류를 남긴다.
4. GitUI처럼 특정 앱에 속하는 설정은 대응 모듈로 옮긴다. 작업용 도구 묶음과 최소 공통 환경을 나눌 필요가 있는지는 실제 새 환경의 요구를 기준으로 결정한다.
5. 새 환경을 등록할 때 함께 활성화되는 자동화와 외부 경로 의존을 README에서 안내한다.

### 완료 기준

- [ ] 새 Darwin 환경이 세션 분석 작업을 의도치 않게 활성화하지 않는다.
- [ ] 세션 분석 작업의 활성화와 실행 경로를 base 구현을 읽지 않고 설정할 수 있다.
- [ ] 단순 파일 이동 전후의 관련 옵션과 activation 내용이 동일하다.
- [ ] 동작을 바꾸는 단계는 파일 이동과 구분해 검증하고 커밋한다.

<a id="issue-4"></a>

## 4. 두 갈래의 로컬 패키지 등록 경로

### 리뷰 당시 상태와 영향

[packages/apps/default.nix:3](../../packages/apps/default.nix#L3)는 패키지 등록, export, 업데이트 자동화가 연결되는 진입점이다. 반면 `databricks-cli`, `notion-cli`, `pup`은 별도 디렉터리에 있고 [overlays/default.nix:35](../../overlays/default.nix#L35)에서 등록된다. 이들은 앱 CI의 경로 필터에도 포함되지 않는다.

새 CLI를 추가하는 사람이 어느 패턴을 따라야 하는지 판단하기 어렵고, 위치에 따라 검증 범위가 달라진다.

### 해결 방법

1. 세 패키지의 지원 플랫폼, 기존 attribute 이름, 별칭, 수동 업데이트 정책을 확인한다.
2. 일반 실행 파일 패키지는 기존 `packages/apps` catalog로 모으는 방향을 기본으로 한다. 별도 관리가 필요한 예외는 그 이유와 등록, 업데이트, 검증 경로를 명시한다.
3. 이동 시 `pkgs.databricks-cli`, `pkgs.notion-cli`, `pkgs.ntn`, `pkgs.pup`의 호출 경로와 기존 root flake export를 보존한다. `ntn` 같은 별칭은 catalog의 앱 항목과 구분해 중복 업데이트가 생기지 않게 한다. Catalog 등록으로 `databricks-cli` 등 새로운 flake output이 노출되는 효과도 함께 검토한다.
4. 패키지 이동과 버전 변경을 분리한다. 기존 수동 업데이트 패키지는 자동 업데이트를 별도로 결정하기 전까지 수동 정책을 유지한다.
5. 패키지 추가 가이드와 CI의 변경 감지 범위를 새 위치에 맞춘다.

### 완료 기준

- [x] 기존 모듈의 패키지 참조와 별칭이 그대로 동작한다.
- [x] 이동만으로 버전, source hash, 설치되는 실행 파일이 달라지지 않는다.
- [x] 세 패키지의 변경도 CI에서 감지한다.
- [x] 자동 업데이트 도입 여부를 디렉터리 이동과 별개로 검토한다.

### 적용 결과

`databricks-cli`, `notion-cli`, `pup`은 `packages/apps`에 있으며, 등록과 `ntn` 별칭은 `packages/apps/default.nix`에서 관리한다. 루트 flake와 구성 overlay의 중복 등록은 제거했다. 세 패키지는 `lib/mk-tarball-cli.nix`로 플랫폼 선택, 다운로드, CLI 설치를 공유하며, 버전과 소스 정보는 앱별 파일에 남긴다. 별도 updater는 추가하지 않아 수동 업데이트 정책을 유지한다. 앱 추가 방법과 helper의 입력은 [앱 패키지 README](../../packages/apps/README.md)에 기록한다.

루트 nixpkgs의 2개 플랫폼과 독립 앱 flake의 4개 플랫폼에서 세 패키지의 변경 전후 derivation 경로, 소스, 버전, 설치 명령, 지원 플랫폼, 실행 파일 이름을 비교했다. 총 18개 조합이 동일하다. 루트와 중첩 flake의 기존 패키지 이름 및 `ntn` 별칭도 평가했다. 공통 helper 변경 시 전체 앱을 검사하는 변경 감지 테스트 7개가 통과했다.

전체 앱 flake 검사는 로컬 Nix store에 Herdr의 source derivation이 없어 중단됐다. 같은 명령이 기준 커밋에서도 같은 경로 오류로 실패하는 것을 확인했다. 이 제한은 위의 변경 패키지 평가와 구분하며, 이번 작업에서 전체 앱 빌드나 활성화는 수행하지 않았다.

<a id="issue-5"></a>

## 5. 거의 동일한 배포 구현의 복제

### 현재 상태와 영향

[astro-blog-deploy.py](../../hosts/pylv-sepia/astro-blog-deploy.py)와 [menu-deploy.py](../../hosts/pylv-sepia/menu-deploy.py)는 설명과 오류 메시지 세 곳만 다르다. Archive 검증, release 전환, rollback 구현은 동일하다. [test_menu_deploy.py:15](../../hosts/pylv-sepia/test_menu_deploy.py#L15)는 Menu 사본만 대상으로 한다.

검증이나 오류 처리를 수정할 때 두 사본을 함께 변경해야 하고, 한쪽만 수정해도 현재 테스트로는 놓칠 수 있다.

### 해결 방법

1. 공통 배포 구현을 하나로 추출하고 기존 `--root` 설정 방식을 유지한다. 사이트별 경로, 사용자, SSH 명령 제한은 각 Nix 파일에서 계속 관리한다.
2. 사이트별 오류 식별이 필요하면 짧은 진입점에서 표시 이름만 전달한다. 사이트마다 배포 알고리즘을 복사하지 않는다.
3. Nix 패키징도 공통 구현을 포함하도록 바꾼다. 현재처럼 파일 하나만 `writeText`로 옮기는 방식에서 import 대상이 누락되지 않도록 store에 들어갈 전체 구성을 확인한다.
4. 기존 테스트를 공유 구현 대상으로 옮기고, 두 사이트의 진입점이 같은 구현을 호출하는지도 검증한다.

### 완료 기준

- [ ] Archive 검증과 release 전환 로직을 한 곳에서만 수정한다.
- [ ] 두 진입점의 성공, 거부, rollback 시나리오가 임시 디렉터리 테스트를 통과한다.
- [ ] SSH 명령 형식, 기존 데이터 경로, 사용자 권한이 유지된다.
- [ ] 저장소가 없는 실행 환경에서도 패키징된 구현의 import가 정상 동작한다.

<a id="issue-6"></a>

## 6. 테마 삭제와 선택값 검증의 빈틈

### 현재 상태와 영향

[generate.py:1515](../../themes/generate.py#L1515)는 export를 생성하거나 덮어쓰지만 원본에서 사라진 테마의 export는 정리하지 않는다. 임시 디렉터리에서 원본 하나를 삭제하고 재생성했을 때 이전 export 8개가 남는 것을 재현했다. 현재 저장소의 export 48개는 재생성 결과와 모두 일치한다.

[commonTheme 옵션:86](../../base/default.nix#L86)은 존재하는 테마인지 검증하지 않는 문자열이다. 잘못된 값의 처리도 소비 앱에 따라 달라진다. Zed는 [settings.json:11](../../modules/zed/files/settings.json#L11)에서 별도로 테마를 선택한다. 이 부분은 mutable 설정 정책과 맞을 수 있으므로 현재 결함으로 단정하지 않는다.

### 해결 방법

1. Canonical 테마 ID 목록을 기준으로 `commonTheme`을 검증하고, 필요한 앱 export의 존재 여부도 확인한다. 오류에는 잘못된 ID와 사용할 수 있는 값을 포함한다.
2. 생성기를 쓰기 없는 `--check` 모드로 실행할 수 있게 한다. 임시 생성 결과와 관리 대상 export의 파일 집합과 내용을 비교해 누락, 변경, 잔존 파일을 보고한다.
3. 정리 기능은 전체 생성과 부분 생성을 구분한다. 테마 하나만 생성했다고 나머지 테마의 export를 삭제하지 않으며, 생성기가 관리하는 파일만 정리한다.
4. `commonTheme`을 따르는 앱과 개별 mutable 선택을 유지하는 앱을 문서화한다. Zed 설정을 강제로 덮어쓰는 변경은 이 정책을 결정한 뒤 별도로 진행한다.
5. 새 대상 앱 추가가 반복되면 renderer, 확장자, checker, override validator를 연결하는 작은 등록 정보를 도입한다. 현재의 모든 앱별 로직을 범용 템플릿 언어로 바꾸는 작업은 필요하지 않다.

### 완료 기준

- [ ] 현재 export 48개가 재생성 결과와 일치한다.
- [ ] 테마 원본 삭제와 이름 변경을 `--check`가 감지한다.
- [ ] 부분 생성이 다른 테마를 삭제하지 않는다.
- [ ] 잘못된 `commonTheme`은 앱 실행 전 명확한 오류로 드러난다.
- [ ] Generator나 template 변경 시 export 검사도 CI에서 실행된다.

<a id="issue-7"></a>

## 7. 공통 agent 리뷰 기준의 별도 사본

### 현재 상태와 영향

[Canonical rubric](../../agent-core/skills/devils-advocate/references/rubrics.md)과 [Claude plugin rubric](../../modules/claude/marketplace/skills/devils-advocate/references/rubrics.md)이 별도로 유지되며 문구가 다르다. Schema도 사본이 있다. Claude의 실제 command 분기와 schema 제약을 대조했을 때 현재 판정이나 출력 계약의 차이는 입증되지 않았다.

이 항목은 현재 동작 결함이 아니라 공통 기준을 변경할 때 사본을 빠뜨릴 수 있는 유지보수 위험이다.

### 해결 방법

1. Claude 전용 command와 agent는 runtime plugin에 남기고, 여러 runtime이 공유하는 rubric과 schema의 원본은 `agent-core`로 정한다.
2. Plugin 패키징과 파일 접근 방식을 확인한 뒤 canonical 파일을 생성 과정에서 포함한다. 설치된 plugin에서 저장소 바깥 상대 경로에 의존하지 않도록 한다.
3. 패키징 제약으로 물리적 사본을 유지해야 하면 원본에서 생성하고 일치 여부를 검사한다. 수동으로 사본을 편집하는 경로는 없앤다.
4. 공통 기준을 바꿀 때 canonical 검사와 Claude plugin 검사에서 함께 검증한다.

### 완료 기준

- [ ] 공통 판정 기준을 한 곳에서만 수정한다.
- [ ] Claude의 command와 agent 진입점이 유지된다.
- [ ] Plugin에 포함된 rubric과 schema가 canonical 원본에서 나온다는 검증이 있다.
- [ ] Runtime별 의도적인 차이는 adapter나 command에 명시돼 있다.

<a id="issue-8"></a>

## 8. 현재 구조와 어긋난 안내 문서

### 리뷰 당시 상태와 영향

[루트 README의 Kitty 설명](../../README.md#kitty-config)은 현재 없는 `modules/kitty`를 안내한다. [Zellij 설명](../../README.md#zellij-config)은 플랫폼별 템플릿과 자동 진입을 설명하지만, 현재 모듈은 [단일 템플릿과 wrapper](../../modules/zellij/default.nix#L12)를 사용한다. [AGENTS.md](../../AGENTS.md)의 모듈 표에도 이전 경로가 남아 있다.

문서를 출발점으로 삼는 사람과 agent가 불필요한 경로를 검색하거나 이미 제거된 동작을 전제로 수정하게 된다.

### 해결 방법

1. 삭제된 모듈과 바뀐 실행 경로를 README와 AGENTS.md에서 정정한다.
2. 루트 문서에는 구조, 작업 진입점, 적용 명령을 남기고 앱별 세부 동작은 해당 모듈의 README에서 관리한다.
3. 중복된 설명은 상세 문서 링크로 연결한다. 이 리뷰 문서는 기준 커밋의 기록으로 유지하고 현재 동작 안내를 대신하지 않는다.
4. 로컬 파일 링크와 코드 블록에 안내하는 경로를 확인하는 가벼운 검사를 마련한다. 계획 단계의 기능은 현재 기능과 구분해 표시한다.

### 완료 기준

- [x] 현행 안내 문서가 존재하지 않는 모듈을 관리 중인 앱으로 설명하지 않는다.
- [x] 설정 원본과 적용 방식이 실제 코드와 일치한다.
- [x] 같은 앱 동작을 여러 문서에서 독립적으로 수정할 필요가 줄어든다.
- [x] 관련 동작을 바꾸는 변경에 해당 문서 수정도 포함된다.

### 적용 결과

루트 README와 agent 안내에서 삭제된 Kitty 모듈 설명을 제거했다. Zellij의 단일 템플릿, 생성 설정, 테마 symlink, 인자 없는 실행의 `welcome` layout을 [모듈 README](../../modules/zellij/README.md)에 기록하고 루트 문서에서 연결한다. AGENTS.md의 모듈 표는 저장소 기준 경로와 실제 설치 방식을 안내하며, Neovim LSP 설정 위치와 Claude 로컬 marketplace 위치도 정정했다. CLAUDE.md는 모듈 표와 편집기 안내를 중복 관리하지 않고 AGENTS.md의 해당 절을 참조한다.

`uv run --no-project docs/check-paths.py`로 루트 README, AGENTS.md, CLAUDE.md, Zellij README의 로컬 링크 대상과 코드에 적힌 구체적인 저장소 경로를 확인했고 모두 통과했다. 임시 문서로 정상 경로, 누락 경로, 검사 제외 패턴, 없는 문서를 확인하는 7개 검사와 Ruff 검사도 통과했다. Placeholder, glob, 설치 경로, 외부 URL, anchor는 검사하지 않으며, 이 리뷰의 과거 경로는 기본 검사에서 제외한다. 설정 동작에 관한 설명은 대응 Nix 모듈과 직접 대조했다. Nix 평가나 activation은 수행하지 않았다.

## 작업별 변경 경로

| 작업 | 현재 진입점 | 유지보수 시 주의점 |
| --- | --- | --- |
| 기존 앱 설정 변경 | `modules/<app>/` | 직접 symlink, 생성 파일, Windows 복사 등 적용 방식이 다르다. |
| 일반 Home Manager 앱 추가 | 대응 모듈, base의 import와 기본값 | 모듈 구현과 환경별 활성화 정책을 구분한다. |
| 로컬 패키지 추가 | `packages/apps/` | Catalog 등록과 별칭, 업데이트 정책은 앱 패키지 README를 따른다. |
| 새 환경 추가 | `inventory.nix`, profile, 필요한 host 설정 | 공통 base의 자동화와 외부 경로 의존을 확인한다. |
| 공통 agent 지침 변경 | `agent-core/rules`, adapters, skills, manifest | 생성 결과와 golden 검증을 함께 확인한다. |
| 새 테마 대상 앱 추가 | `themes/`의 generator, template, checker, override 처리 | 등록 지점 누락과 export의 생성 및 삭제를 함께 검증한다. |

## 권장 진행 순서

1. 이슈 1에서 의도한 네트워크 접근 범위를 확인하고 설정 불일치를 해결한다.
2. 이슈 2에서 기존 로컬 검사를 CI에 연결하고, 나머지 구조 변경을 검증할 경로를 확보한다.
3. 이슈 3의 책임 분리는 동작 보존 이동과 정책 변경을 나눠 진행한다.
4. 이슈 5와 6은 서로 다른 파일 범위에서 작은 변경 단위로 진행한다. 이슈 4는 완료했다. 관련 검증을 먼저 연결하거나 같은 변경에 포함한다.
5. 이슈 7의 공통 사본을 정리한다. 이슈 8에서 정정한 현행 문서는 이후 관련 동작 변경과 함께 갱신한다.

## 수행한 검증과 한계

아래 결과는 앞선 읽기 전용 리뷰에서 수행한 검증이다. 해결안이 구현되거나 검증됐다는 의미는 아니다.

| 명령 또는 검사 | 결과 |
| --- | --- |
| `uv run --project agent-core -m pytest agent-core/tests -q` | 14개 통과 |
| `uv run --project agent-core agent-core check` | 통과 |
| `uv run themes/validate.py` | Core 테마 6개 검증 통과 |
| `uv run themes/validate_overrides.py` | Override 파일 11개 검증 통과 |
| `uv run themes/check_templates.py` | Template과 override 파일 24개 검증 통과 |
| `uv run -m unittest discover -s themes -p 'test_*.py'` | 5개 통과 |
| 임시 디렉터리에서 전체 테마 재생성 후 비교 | Export 48개 일치, 누락과 추가 파일 없음 |
| 임시 디렉터리에서 테마 원본 삭제 후 재생성 | 삭제한 테마의 export 8개 잔존 재현 |
| 앱 updater와 helper 스크립트의 `bash -n` 검사 | 구문 검사 통과 |
| 두 배포 스크립트의 `diff -u` 비교 | 설명과 오류 메시지 세 곳만 다름 |
| Claude와 canonical rubric 및 schema 비교 | 중복과 문구 차이 확인, 현재 판정 및 출력 계약 차이 근거 없음 |

전체 Nix 평가와 빌드, Home Manager activation, 앱 실행, 원격 네트워크 접근은 검증하지 않았다. Session recording과 shared memory는 agent 통합 경계 위주로 검토했으며 내부 동작 전체를 감사하지 않았다. 실제 노출 범위와 runtime 동작은 후속 구현 시 해당 환경에서 별도로 확인해야 한다.
