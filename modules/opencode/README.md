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
- 로컬 플러그인 설치 (`~/.config/opencode/plugins/native-notify.ts`)

## 설정 파일

### opencode.json

- **기본 모델**: `opencode-go/glm-5`
- **small model**: `opencode-go/minimax-m2.7`
- **자동 업데이트**: 활성화
- **기본 primary agent**: OpenCode 내장 `build`, `plan`
- **플러그인**: `@plannotator/opencode@latest`, `@mohak34/opencode-notifier@latest`, `@tarquinen/opencode-dcp@latest`, `opencode-mem`, 로컬 `native-notify`
- **MCP**: `context7`
- **LSP**: `nixd`, `gopls`, `typescript-language-server`, `terraform-ls`, `metals`, `ty`, `yaml-language-server`, `marksman`, `rust-analyzer`
- **권한**: 모든 skill 및 task 허용

이 모듈은 별도의 외부 에이전트 하네스를 설치하지 않으며, OpenCode 기본 에이전트를 그대로 사용합니다.

### 기본 에이전트

- **build**: 기본 작업 에이전트. 일반적인 코드 수정과 도구 실행을 담당합니다.
- **plan**: 계획 전용 에이전트. 편집 도구 없이 조사와 계획 수립에 사용합니다.
- **general**: 범용 서브에이전트. 병렬 작업이나 복합 조사에 사용됩니다.
- **explore**: 빠른 코드베이스 탐색용 서브에이전트입니다.

### AGENTS.md

모든 프로젝트에서 OpenCode 동작을 설정하는 전역 지침 파일입니다.

## Skills

이 저장소에는 현재 `modules/opencode/files/skills/` 아래에 배포되는 로컬 skill 파일이 없습니다.

OpenCode가 제공하는 built-in skills는 런타임에서 사용할 수 있지만, 이 모듈이 별도 로컬 skill 파일을 설치하지는 않습니다.
