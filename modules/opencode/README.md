# OpenCode 모듈

이 모듈은 오픈소스 AI 코딩 에이전트인 OpenCode를 설치하고 설정합니다.

## 기능

- nixpkgs에서 `opencode` 설치
- OpenCode 설정 파일 구성 (`~/.config/opencode/opencode.json`)
- MCP 서버 설정 (라이브러리 문서화를 위한 `context7`)
- 전역 지침 설치 (`~/.config/opencode/AGENTS.md`)

## 설정 파일

### opencode.json

- **모델**: `anthropic/claude-opus-4-5` (기본값)
- **테마**: `opencode`
- **자동 업데이트**: 활성화
- **MCP**: 최신 라이브러리 문서를 위한 Context7

### AGENTS.md

모든 프로젝트에서 OpenCode 동작을 설정하는 전역 지침 파일입니다.
