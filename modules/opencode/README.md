# OpenCode 모듈

이 모듈은 오픈소스 AI 코딩 에이전트인 OpenCode를 설치하고 설정합니다.

## 초기 설정

OpenCode 사용 전에 먼저 인증이 필요합니다:

```bash
opencode auth login
```

## 기능

- nixpkgs에서 `opencode` 설치
- OpenCode 설정 파일 구성 (`~/.config/opencode/opencode.json`)
- oh-my-opencode 설정 파일 구성 (`~/.config/opencode/oh-my-opencode.json`)
- MCP 서버 설정 (라이브러리 문서화를 위한 `context7`)
- 전역 지침 설치 (`~/.config/opencode/AGENTS.md`)
- Custom agents 설치 (`~/.config/opencode/agents/`)
- 로컬 플러그인 설치 (`~/.config/opencode/plugins/`)

## 설정 파일

### opencode.json

- **기본 모델**: `opencode/claude-opus-4-6`
- **small model**: `opencode/minimax-m2.7-highspeed`
- **테마**: `opencode`
- **자동 업데이트**: 활성화
- **플러그인**: `@plannotator/opencode`, `opencode-anthropic-auth`, `oh-my-opencode`
- **MCP**: `context7`, `notion`
- **권한**: 모든 skill 및 task 허용

### oh-my-opencode.json

- oh-my-opencode 플러그인의 에이전트/카테고리 모델 오버라이드를 정의합니다.
- 현재 이 저장소는 OpenAI + OpenCode Zen 혼합 구성을 유지합니다.
- 메인 오케스트레이터(`sisyphus`)와 검색 유틸리티(`librarian`, `explore`)는 OpenCode Zen 모델을 사용하고, 깊은 추론/검토 역할은 GPT-5.4 계열을 유지합니다.
- 최신 upstream 역할명과의 호환을 위해 `hephaestus`, `multimodal-looker`, `unspecified-low`, `unspecified-high`를 함께 정의합니다.

### AGENTS.md

모든 프로젝트에서 OpenCode 동작을 설정하는 전역 지침 파일입니다.

## Agents

oh-my-opencode 플러그인이 제공하는 주요 에이전트/카테고리와, 이 저장소가 로컬로 추가하는 에이전트가 함께 동작합니다.

### Plugin-provided agents (configured via `oh-my-opencode.json`)

- **sisyphus**: 메인 오케스트레이터. 전략적 위임, TODO 관리, 코드베이스 평가
- **hephaestus**: 집중 구현 실행자
- **atlas**: 워크 플랜 마스터 오케스트레이터. TODO 리스트의 모든 작업 완료까지 실행
- **prometheus**: 전략적 플래닝 컨설턴트. 요구사항 인터뷰 및 상세 워크 플랜 생성
- **oracle**: 고난이도 추론 전문가 (아키텍처 설계, 디버깅). 읽기 전용 상담
- **librarian**: 원격 코드베이스 검색, 공식 문서 조회, 구현 예시 탐색
- **explore**: 코드베이스 문맥 검색 ("X는 어디에?", "Z를 하는 코드 찾기")
- **metis**: 사전 계획 분석 (숨겨진 의도, 모호성 식별)
- **momus**: 플랜 검토 전문가 (명확성, 검증 가능성, 완전성)
- **multimodal-looker**: 미디어 파일 분석 (PDF, 이미지, 다이어그램)
- **sisyphus-junior**: 집중 작업 실행자 (위임 불가)

### Local custom agents (installed from this repo)

- **troubleshoot**: 트러블슈팅 에이전트 (에러 분석 및 디버깅)

사용법: `@sisyphus`, `@hephaestus`, `@atlas`, `@prometheus`, `@oracle`, `@librarian`, `@explore`, `@metis`, `@momus`, `@multimodal-looker`, `@sisyphus-junior`, `@troubleshoot`

현재 Nix 모듈이 직접 설치하는 로컬 agent 파일은 `agents/troubleshoot.md` 하나입니다. 나머지 기본 에이전트는 oh-my-opencode 플러그인이 제공합니다.

## Categories

이 저장소의 `oh-my-opencode.json`은 다음 카테고리를 오버라이드합니다.

- **visual-engineering**: Gemini 기반 시각 작업
- **ultrabrain**: GPT-5.4 `xhigh`
- **artistry**: Gemini 기반 창의 작업
- **quick**: GPT-5.4 기반 경량 작업
- **unspecified-low**: GPT-5.4 기반 일반 저강도 작업
- **unspecified-high**: GPT-5.4 `xhigh` 기반 일반 고강도 작업
- **writing**: GPT-5.4 기반 문서 작업

## Skills

이 저장소에는 현재 `modules/opencode/files/skills/` 아래에 배포되는 로컬 skill 파일이 없습니다.

OpenCode/oh-my-opencode에서 제공하는 built-in skills는 런타임에서 사용할 수 있지만, 이 모듈이 별도 로컬 skill 파일을 설치하지는 않습니다.
