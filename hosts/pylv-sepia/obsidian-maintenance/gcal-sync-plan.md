# Google Calendar Sync for obsidian-maintenance

## Context

pylv-sepia의 obsidian-maintenance 서비스는 매시간 실행되며, Obsidian vault의 events/active.md에서 이벤트를 자동완료하고 아카이브한다. 현재는 캘린더 연동이 없어 이벤트를 수동으로 Google Calendar에 등록해야 한다. `gws` (Google Workspace CLI, nixpkgs v0.6.3)를 사용하여 active.md의 미등록 이벤트를 자동으로 Google Calendar에 생성하는 기능을 추가한다.

## Design Decisions

- **One-way sync**: Obsidian -> Google Calendar (생성만, 업데이트/삭제 없음)
- **Tracking**: `[gcal:: eventId]` 인라인 태그로 동기화 여부 추적
- **Idempotent**: `[gcal::]` 태그가 없는 active 이벤트만 생성
- **Fault-tolerant**: 캘린더 동기화 실패 시 기존 maintenance 기능에 영향 없음
- **실행 순서**: Calendar sync -> process_events (자동완료 전에 동기화해야 함)

## Event Format

```markdown
- [ ] 이벤트명 [date:: YYYY-MM-DD]                                    # all-day
- [ ] 이벤트명 [date:: YYYY-MM-DD] [start:: HH:MM]                    # timed (default 1h)
- [ ] 이벤트명 [date:: YYYY-MM-DD] [start:: HH:MM] [end:: HH:MM]     # explicit duration
```

동기화 후: `- [ ] 이벤트명 [date:: 2026-03-22] [start:: 11:00] [gcal:: abc123]`

## Files to Modify

### 1. `secrets/secrets.nix` — gws credentials 추가

```nix
"gws-credentials.age".publicKeys = allUsers ++ allHosts;
```

### 2. `hosts/pylv-sepia/obsidian-maintenance/default.nix` — gws 연동

- `age.secrets.gws-credentials` 선언 (owner: username, mode: 0400)
- `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` 환경변수 설정
- gws binary path를 스크립트 두 번째 인수로 전달

### 3. `hosts/pylv-sepia/obsidian-maintenance/scripts/maintenance.py` — 동기화 로직

- `import json, subprocess` 추가
- 새 regex: `START_RE`, `END_RE`, `GCAL_RE`
- `sync_events_to_gcal()`: active 이벤트 파싱 -> gws subprocess 호출 -> gcal 태그 추가
- `main()` 수정: calendar sync를 process_events 이전에 실행, 실패 시 계속 진행

### 4. `secrets/gws-credentials.age` — 새 시크릿 파일 (사용자가 수동 생성)

## gws Command Syntax

gws v0.6.3의 정확한 명령어 구문은 구현 시 `gws calendar --help`로 확인 필요. 두 가지 접근:

- Helper: `gws calendar +insert --summary "..." --start "..." --end "..."`
- Raw API: `gws calendar events insert --calendarId primary --requestBody '{...}'`

`+insert` helper가 v0.6.3에서 사용 가능한지 확인 후, 불가하면 raw API 사용.

## Error Handling

| 실패 유형              | 처리                                  |
| ---------------------- | ------------------------------------- |
| gws 미제공             | 동기화 skip, 기존 기능 정상 동작      |
| 인증 실패/만료         | 이벤트별 skip, 다음 실행 시 재시도    |
| 개별 이벤트 생성 실패  | 해당 이벤트만 skip, 나머지 계속       |
| 전체 sync 예외         | traceback 출력 후 maintenance 계속    |

## User Manual Steps (구현 후)

1. **gws 인증** (브라우저 있는 머신에서): `nix run nixpkgs#gws -- auth login -s calendar`
2. **credentials 내보내기**: `gws auth export --unmasked > /tmp/gws-credentials.json`
3. **agenix 시크릿 생성**: `agenix -e secrets/gws-credentials.age` (내용 붙여넣기)
4. **배포**: `sudo nixos-rebuild switch --flake .#pylv-sepia`
5. **검증**: `sudo systemctl start obsidian-maintenance && journalctl -u obsidian-maintenance -n 30`

## Verification

1. `nix flake check --no-build` — Nix 구문 검증
2. 로컬에서 maintenance.py 단위 테스트 (gws mock으로 파싱 로직 검증)
3. pylv-sepia 배포 후 수동 서비스 실행으로 실제 캘린더 이벤트 생성 확인
