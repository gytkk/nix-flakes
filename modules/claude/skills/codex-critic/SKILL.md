---
name: codex-critic
description: Codex 기반 코드/계획 검증 및 피드백 제공. 현재 변경사항이 원래 요청을 올바르게 구현했는지 독립적으로 검증합니다.
allowed-tools:
  - Bash
  - Read
---

# Codex Critic

OpenAI Codex CLI의 비대화형 모드(`codex exec`)를 사용하여, 현재 코드 변경사항(diff)이 원래 사용자 요청에 부합하는지 독립적으로 검증하고 구조화된 피드백을 제공합니다.

## Invocation

```
/codex-critic <원래 사용자 요청 또는 검증 대상 설명>
```

## Execution Steps

### Step 1: Run the critic script

사용자가 제공한 인자를 그대로 스크립트에 전달합니다. 인자가 없으면 현재 대화 컨텍스트에서 가장 최근 사용자 요청을 추론하여 사용합니다.

```bash
bash modules/claude/files/codex_critic.sh "<인자 또는 추론된 사용자 요청>"
```

**중요**: 스크립트가 에러를 반환하면 에러 메시지를 그대로 사용자에게 전달하고 중단합니다. 환경 설정 문제(codex 미설치, API 키 미설정)는 스크립트가 안내 메시지를 출력합니다.

### Step 2: Read the result

스크립트가 성공하면 출력된 파일 경로(`.ai/critic-result.json`)를 읽습니다.

```
Read .ai/critic-result.json
```

### Step 3: Present the results

JSON 결과를 다음 형식으로 정리하여 사용자에게 보고합니다:

```
## Codex Critic 결과

**Verdict**: {verdict} | **Score**: {score}/10 | **Iterations**: {iteration}

### Summary
{summary}

### Issues ({이슈 수}건)
| Severity | Category | File | Description | Suggestion |
|----------|----------|------|-------------|------------|
| ... | ... | ... | ... | ... |

### Checklist
- [x/  ] {item}: {note}
```

### Step 4: Propose actions (if needed)

- `verdict`가 `fail`이면: 이슈별 수정 계획을 제안합니다.
- `verdict`가 `warn`이면: 주요 이슈에 대한 수정 여부를 사용자에게 제안합니다.
- `verdict`가 `pass`이면: 결과만 보고하고 완료합니다.

수정 작업은 사용자 승인 후에만 진행합니다.

## Notes

- 이 스킬은 자동 호출되지 않습니다 (`disable-model-invocation: true`).
- Codex는 read-only sandbox에서 실행되어 파일을 수정하지 않습니다.
- 결과는 `.ai/critic-result.json`에 저장되며, 반복(iteration) 결과는 `.ai/critic-iter-{N}.json`에 보존됩니다.
- 환경변수 `CRITIC_MAX_ITER` (기본 5), `CRITIC_MAX_DIFF_LINES` (기본 500)으로 동작을 조정할 수 있습니다.
