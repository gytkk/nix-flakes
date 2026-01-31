# OpenCode 모듈

이 모듈은 오픈소스 AI 코딩 에이전트인 OpenCode를 설치하고 설정합니다.

## 기능

- nixpkgs에서 `opencode` 설치
- OpenCode 설정 파일 구성 (`~/.config/opencode/opencode.json`)
- MCP 서버 설정 (라이브러리 문서화를 위한 `context7`)
- 전역 지침 설치 (`~/.config/opencode/AGENTS.md`)
- Custom agents 설치 (`~/.config/opencode/agents/`)
- Custom skills 설치 (`~/.config/opencode/skills/`)

## 설정 파일

### opencode.json

- **모델**: `anthropic/claude-opus-4-5` (기본값)
- **테마**: `opencode`
- **자동 업데이트**: 활성화
- **MCP**: 최신 라이브러리 문서를 위한 Context7
- **권한**: 모든 skill 및 task 허용

### AGENTS.md

모든 프로젝트에서 OpenCode 동작을 설정하는 전역 지침 파일입니다.

## Custom Agents

`agents/` 디렉토리에 정의된 특화된 에이전트:

- **review**: 코드 리뷰 에이전트 (읽기 전용, 코드 품질 및 보안 검토)
- **troubleshoot**: 트러블슈팅 에이전트 (에러 분석 및 디버깅)

사용법: `@review`, `@troubleshoot`으로 호출

## Skills

`skills/` 디렉토리에 정의된 재사용 가능한 워크플로우:

- **git-commit**: Conventional Commits 형식의 git 커밋 생성
- **git-pr**: GitHub PR 생성 가이드

사용법: `/git-commit`, `/git-pr`로 로드
