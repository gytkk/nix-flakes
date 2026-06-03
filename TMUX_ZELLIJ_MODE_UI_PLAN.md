# tmux Zellij식 모드 UI 구현 계획

> **목표:** tmux에서 Zellij처럼 모드 진입 상태와 해당 모드의 단축키 힌트를 항상 명확히 보여준다.

## 범위

- 수정 대상: `modules/tmux/default.nix`
- 문서 보강: `README.md`의 tmux config 섹션
- 구현 방식: tmux native 기능만 사용
- 플러그인 추가 없음
- TPM 추가 없음
- 복잡한 동적 스크립트 추가 없음

## 핵심 요구사항

1. `Ctrl-w`를 누르면 window 모드에 진입한다.
2. window 모드에 진입하면 status 하단에 `WINDOW` 모드임을 표시한다.
3. window 모드에서 사용 가능한 단축키를 status 하단에 표시한다.
4. prefix 입력 상태도 별도 모드처럼 표시한다.
5. copy-mode 진입 상태도 별도 모드처럼 표시한다.
6. 일반 상태에서는 최소한의 도움말만 표시한다.
7. 기존 `C-b h`, `C-b ?`, `C-b w` 동작은 유지한다.

## UI 구조

### status 위치

- `status-position top`은 유지한다.
- `status 2`를 사용해 status를 2줄로 만든다.
- 1번째 줄: session/window 목록
- 2번째 줄: 현재 모드와 단축키 힌트

### 2번째 줄 표시 규칙

우선순위는 아래 순서로 둔다.

1. copy-mode: `COPY  v:select  y:yank  /:search  n:next  Esc:exit`
2. window 모드: `WINDOW  c:new  r:rename  h/l:prev/next  w:tree  x:kill  Esc:exit`
3. prefix 입력 상태: `PREFIX  c:new  h:help  ?:keys  w:tree  v/s:split  r:reload`
4. 일반 상태: `C-w window  C-b h help  C-b ? keys  C-b w tree`

## 구현 상세

### Task 1: status 2줄 활성화

**파일:** `modules/tmux/default.nix`

`extraConfig`의 status 설정 근처에 추가한다.

```tmux
set -g status 2
```

검증:

```bash
nix eval --raw '.#homeConfigurations.pylv-sepia.config.programs.tmux.extraConfig'
```

예상:

- 출력에 `set -g status 2`가 포함된다.

### Task 2: mode hint 문자열을 Nix 변수로 분리

**파일:** `modules/tmux/default.nix`

`let` 블록에 아래 변수를 추가한다.

```nix
modeHintStatus = ''
  #[align=left]#{?pane_in_mode,#[fg=colour16,bg=colour42,bold] COPY #[default] v:select y:yank /:search n:next Esc:exit,#{?#{==:#{client_key_table},window-mode},#[fg=colour16,bg=colour39,bold] WINDOW #[default] c:new r:rename h/l:prev/next w:tree x:kill Esc:exit,#{?client_prefix,#[fg=colour16,bg=colour214,bold] PREFIX #[default] c:new h:help ?:keys w:tree v/s:split r:reload,#[fg=colour245] C-w window | C-b h help | C-b ? keys | C-b w tree}}}
'';
```

원칙:

- 한 줄 status string으로 유지한다.
- 외부 command를 호출하지 않는다.
- `pane_in_mode`, `client_key_table`, `client_prefix`만 사용한다.

### Task 3: status-format[1]에 mode hint 적용

**파일:** `modules/tmux/default.nix`

`extraConfig`에 아래 설정을 추가한다.

```tmux
set -g status-format[1] "${modeHintStatus}"
```

배치:

- `status-left`, `status-right`, `window-status-format` 설정 다음에 둔다.
- 1번째 줄의 window list 설정과 분리해 읽기 쉽게 둔다.

검증:

```bash
nix eval --raw '.#homeConfigurations.pylv-sepia.config.programs.tmux.extraConfig'
```

예상:

- 출력에 `status-format[1]`가 포함된다.
- 출력에 `COPY`, `WINDOW`, `PREFIX`가 포함된다.

### Task 4: Ctrl-w window 모드 추가

**파일:** `modules/tmux/default.nix`

`extraConfig`의 bind-key 섹션에 추가한다.

```tmux
bind-key -n C-w switch-client -T window-mode
bind-key -T window-mode c new-window -c "#{pane_current_path}"
bind-key -T window-mode r command-prompt -I "#W" "rename-window -- %%"
bind-key -T window-mode h previous-window
bind-key -T window-mode l next-window
bind-key -T window-mode w choose-tree -Zw
bind-key -T window-mode x confirm-before -p "kill-window #W? (y/n)" kill-window
bind-key -T window-mode Escape display-message "normal mode"
```

주의:

- `C-w`는 shell의 word-delete를 대체한다.
- 이 단축키가 불편하면 이후 `C-b W` 또는 `C-Space`로 변경한다.

검증:

```bash
tmux list-keys -T window-mode
```

예상:

- `window-mode` key table에 `c`, `r`, `h`, `l`, `w`, `x`, `Escape`가 보인다.

### Task 5: copy-mode 힌트와 실제 copy-mode 키 정렬

**파일:** `modules/tmux/default.nix`

기존 copy-mode binding은 유지하고 검색 키만 필요하면 추가한다.

```tmux
bind-key -T copy-mode-vi / command-prompt -p "search forward" "send-keys -X search-forward '%%'"
bind-key -T copy-mode-vi n send-keys -X search-again
```

검증:

```bash
tmux list-keys -T copy-mode-vi
```

예상:

- `v`, `y`, `Escape`, `/`, `n`이 힌트와 일치한다.

### Task 6: tmux 설정 parse 검증

**명령:**

```bash
conf=$(nix eval --raw '.#homeConfigurations.pylv-sepia.config.xdg.configFile."tmux/tmux.conf".source')
tmux -f "$conf" start-server
```

예상:

- stderr가 비어 있다.
- exit code가 0이다.

### Task 7: README 업데이트

**파일:** `README.md`

`## tmux config` 섹션에 아래 내용을 반영한다.

```markdown
- The status area uses two lines: the first line shows session/window context,
  and the second line shows the active tmux mode plus available keys.
- Press `Ctrl-w` to enter window mode. The hint line shows actions such as
  `c` for new window, `r` for rename, `h/l` for previous/next, and `w` for tree.
```

검증:

```bash
git diff -- README.md modules/tmux/default.nix
```

예상:

- 변경 범위가 tmux UI 관련 내용만 포함한다.

## 수동 확인 체크리스트

- [ ] 새 tmux session에서 status가 2줄로 보인다.
- [ ] 일반 상태에서 기본 힌트가 보인다.
- [ ] `C-b`를 누르면 `PREFIX` 힌트가 보인다.
- [ ] `Ctrl-w`를 누르면 `WINDOW` 힌트가 보인다.
- [ ] window 모드에서 `c`가 새 window를 만든다.
- [ ] window 모드에서 `r`이 window 이름 변경 prompt를 연다.
- [ ] window 모드에서 `h/l`이 window를 이동한다.
- [ ] window 모드에서 `w`가 tree를 연다.
- [ ] copy-mode에서 `COPY` 힌트가 보인다.
- [ ] `C-b h`, `C-b ?`, `C-b w`는 기존처럼 동작한다.

## 커밋 단위

```bash
git add modules/tmux/default.nix README.md TMUX_ZELLIJ_MODE_UI_PLAN.md
git commit -m "feat(tmux): add zellij-style mode hints"
```

## 제외할 것

- tmux plugin 도입
- TPM 도입
- byobu 도입
- fzf 기반 command palette
- pane 모드 추가
- session 모드 추가
- 색상 테마 대규모 리팩터링
- Home Manager module option 추가
