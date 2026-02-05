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
- MCP 서버 설정 (라이브러리 문서화를 위한 `context7`)
- 전역 지침 설치 (`~/.config/opencode/AGENTS.md`)
- Custom agents 설치 (`~/.config/opencode/agents/`)
- Custom skills 설치 (`~/.config/opencode/skills/`)

## 설정 파일

### opencode.json

- **모델**: `anthropic/claude-opus-4-6` (기본값)
- **테마**: `opencode`
- **자동 업데이트**: 활성화
- **MCP**: 최신 라이브러리 문서를 위한 Context7
- **권한**: 모든 skill 및 task 허용

### AGENTS.md

모든 프로젝트에서 OpenCode 동작을 설정하는 전역 지침 파일입니다.

## Custom Agents

`agents/` 디렉토리에 정의된 특화된 에이전트:

### Primary Orchestrators (Oh-My-OpenCode)

- **sisyphus**: 메인 오케스트레이터. 전략적 위임, TODO 관리, 코드베이스 평가
- **atlas**: 워크 플랜 마스터 오케스트레이터. TODO 리스트의 모든 작업 완료까지 실행
- **prometheus**: 전략적 플래닝 컨설턴트. 요구사항 인터뷰 및 상세 워크 플랜 생성

### Specialized Subagents (Oh-My-OpenCode)

- **oracle**: 고난이도 추론 전문가 (아키텍처 설계, 디버깅). 읽기 전용 상담
- **librarian**: 원격 코드베이스 검색, 공식 문서 조회, 구현 예시 탐색
- **explore**: 코드베이스 문맥 검색 ("X는 어디에?", "Z를 하는 코드 찾기")
- **metis**: 사전 계획 분석 (숨겨진 의도, 모호성 식별)
- **momus**: 플랜 검토 전문가 (명확성, 검증 가능성, 완전성)
- **multimodal-looker**: 미디어 파일 분석 (PDF, 이미지, 다이어그램)
- **sisyphus-junior**: 집중 작업 실행자 (위임 불가)

### Custom Agents

- **review**: 코드 리뷰 에이전트 (읽기 전용, 코드 품질 및 보안 검토)
- **troubleshoot**: 트러블슈팅 에이전트 (에러 분석 및 디버깅)

사용법: `@sisyphus`, `@atlas`, `@prometheus`, `@oracle`, `@librarian`, `@explore`, `@metis`, `@momus`, `@multimodal-looker`, `@sisyphus-junior`, `@review`, `@troubleshoot`

## Skills

`skills/` 디렉토리에 정의된 재사용 가능한 워크플로우:

- **git-commit**: Conventional Commits 형식의 git 커밋 생성
- **git-pr**: GitHub PR 생성 가이드

사용법: `/git-commit`, `/git-pr`로 로드
