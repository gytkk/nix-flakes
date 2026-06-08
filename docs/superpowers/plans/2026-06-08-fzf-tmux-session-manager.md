# Fzf Tmux Session Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the number-prompt `tm` session manager with an `fzf`-backed selector where arrow-key selection can attach, rename, delete, or create tmux sessions.

**Architecture:** Keep the existing `tm` wrapper in `modules/tmux/default.nix`, but pass both the real tmux binary and the Nix-store `fzf` binary into `modules/tmux/files/tmux-session-manager.sh`. The shell script remains the only runtime implementation, uses tmux `session_id` values as stable action targets, and loops back to `fzf` after rename/delete while attach/create `exec` into tmux.

**Tech Stack:** Bash, tmux, fzf, Nix Home Manager, shell-based integration tests with fake tmux/fzf commands.

---

## File Structure

- Modify `modules/tmux/files/tmux-session-manager.sh`: replace the numbered menu with an `fzf --expect` action loop.
- Create `modules/tmux/files/tmux-session-manager-test.sh`: focused shell tests using fake `tmux` and fake `fzf` binaries.
- Modify `modules/tmux/default.nix`: pass `${pkgs.fzf}/bin/fzf` into the manager script from the generated `tm` wrapper.
- Modify `README.md`: document the interactive `fzf` key bindings for `tm`.
- Modify `TMUX_GHOSTTY_ITEMS.md`: remove the completed tmux session-manager item after the implementation lands.

---

### Task 1: Add Focused Shell Tests

**Files:**
- Create: `modules/tmux/files/tmux-session-manager-test.sh`

- [ ] **Step 1: Add the failing test harness**

Create `modules/tmux/files/tmux-session-manager-test.sh` with this content:

```bash
#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="${SCRIPT_DIR}/tmux-session-manager.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/tmux-session-manager-test.XXXXXX")"
FAKE_TMUX="${TEST_ROOT}/tmux"
FAKE_FZF="${TEST_ROOT}/fzf"
TMUX_LOG="${TEST_ROOT}/tmux.log"
FZF_INPUT="${TEST_ROOT}/fzf-input"
FZF_USED="${TEST_ROOT}/fzf-used"
SESSIONS_FILE="${TEST_ROOT}/sessions"

trap 'rm -rf "${TEST_ROOT}"' EXIT

cat >"${FAKE_TMUX}" <<'FAKE_TMUX'
#!/usr/bin/env bash

set -euo pipefail

: "${TMUX_TEST_LOG:?}"
: "${TMUX_TEST_SESSIONS:?}"

printf 'args:%s\n' "$*" >>"${TMUX_TEST_LOG}"

case "${1:-} ${2:-}" in
  'list-sessions -F')
    if [ -s "${TMUX_TEST_SESSIONS}" ]; then
      cat "${TMUX_TEST_SESSIONS}"
    else
      exit 1
    fi
    ;;
  'attach-session -t')
    printf 'attached:%s\n' "${3:-}" >>"${TMUX_TEST_LOG}"
    ;;
  'new-session -s')
    printf 'new:%s\n' "${3:-}" >>"${TMUX_TEST_LOG}"
    ;;
  'rename-session -t')
    printf 'renamed:%s:%s\n' "${3:-}" "${4:-}" >>"${TMUX_TEST_LOG}"
    ;;
  'kill-session -t')
    printf 'killed:%s\n' "${3:-}" >>"${TMUX_TEST_LOG}"
    ;;
  *)
    printf 'unexpected tmux args: %s\n' "$*" >&2
    exit 2
    ;;
esac
FAKE_TMUX

cat >"${FAKE_FZF}" <<'FAKE_FZF'
#!/usr/bin/env bash

set -euo pipefail

: "${TMUX_TEST_FZF_INPUT:?}"
: "${TMUX_TEST_FZF_OUTPUT:?}"
: "${TMUX_TEST_FZF_USED:?}"

cat >"${TMUX_TEST_FZF_INPUT}"

if [ -e "${TMUX_TEST_FZF_USED}" ]; then
  exit 130
fi

: >"${TMUX_TEST_FZF_USED}"
printf '%b' "${TMUX_TEST_FZF_OUTPUT}"
FAKE_FZF

chmod +x "${FAKE_TMUX}" "${FAKE_FZF}"

reset_files() {
  : >"${TMUX_LOG}"
  : >"${FZF_INPUT}"
  : >"${SESSIONS_FILE}"
  rm -f "${FZF_USED}"
}

run_manager() {
  local stdin="${1:-}"
  local fzf_output="${2:-}"

  TMUX_TEST_LOG="${TMUX_LOG}" \
    TMUX_TEST_SESSIONS="${SESSIONS_FILE}" \
    TMUX_TEST_FZF_INPUT="${FZF_INPUT}" \
    TMUX_TEST_FZF_USED="${FZF_USED}" \
    TMUX_TEST_FZF_OUTPUT="${fzf_output}" \
    bash "${SUBJECT}" "${FAKE_TMUX}" "${FAKE_FZF}" <<<"${stdin}"
}

assert_log_has() {
  local expected="${1}"
  local line

  while IFS= read -r line; do
    if [ "${line}" = "${expected}" ]; then
      return 0
    fi
  done <"${TMUX_LOG}"

  printf 'Expected log line not found: %s\n' "${expected}" >&2
  printf 'Actual log:\n' >&2
  cat "${TMUX_LOG}" >&2
  return 1
}

assert_file_equals() {
  local file="${1}"
  local expected="${2}"
  local actual

  actual="$(cat "${file}")"
  if [ "${actual}" != "${expected}" ]; then
    printf 'Unexpected file content for %s\n' "${file}" >&2
    printf 'Expected:\n%s\n' "${expected}" >&2
    printf 'Actual:\n%s\n' "${actual}" >&2
    return 1
  fi
}

test_attach_selected_session() {
  reset_files
  printf '@1\twork\t2 windows\n@2\tops\t1 windows\n' >"${SESSIONS_FILE}"

  run_manager '' $'enter\n@2\tops\t1 windows\n'

  assert_log_has 'attached:@2'
  assert_file_equals "${FZF_INPUT}" $'@1\twork\t2 windows\n@2\tops\t1 windows'
}

test_rename_selected_session() {
  reset_files
  printf '@1\twork\t2 windows\n' >"${SESSIONS_FILE}"

  run_manager $'renamed\n' $'ctrl-r\n@1\twork\t2 windows\n'

  assert_log_has 'renamed:@1:renamed'
}

test_delete_selected_session() {
  reset_files
  printf '@1\twork\t2 windows\n' >"${SESSIONS_FILE}"

  run_manager $'y\n' $'ctrl-d\n@1\twork\t2 windows\n'

  assert_log_has 'killed:@1'
}

test_ctrl_n_creates_session() {
  reset_files
  printf '@1\twork\t2 windows\n' >"${SESSIONS_FILE}"

  run_manager $'fresh\n' $'ctrl-n\n'

  assert_log_has 'new:fresh'
}

test_no_sessions_prompts_for_new_session() {
  reset_files

  run_manager $'fresh\n' ''

  assert_log_has 'new:fresh'
  assert_file_equals "${FZF_INPUT}" ''
}

test_attach_selected_session
test_rename_selected_session
test_delete_selected_session
test_ctrl_n_creates_session
test_no_sessions_prompts_for_new_session

printf 'tmux-session-manager tests passed\n'
```

- [ ] **Step 2: Make the test executable**

Run:

```bash
chmod +x modules/tmux/files/tmux-session-manager-test.sh
```

- [ ] **Step 3: Run the test and verify it fails on the current numbered manager**

Run:

```bash
bash modules/tmux/files/tmux-session-manager-test.sh
```

Expected: FAIL because the current script treats the fake `fzf` path as unused, prompts for numbered choices, and does not emit `attached:@2` for the `fzf` selection.

---

### Task 2: Implement the Fzf Action Loop

**Files:**
- Modify: `modules/tmux/files/tmux-session-manager.sh`
- Test: `modules/tmux/files/tmux-session-manager-test.sh`

- [ ] **Step 1: Replace the manager script with the fzf-based implementation**

Replace `modules/tmux/files/tmux-session-manager.sh` with:

```bash
#!/usr/bin/env bash

set -u

tmux_bin="${1:-}"
fzf_bin="${2:-}"

if [ -z "${tmux_bin}" ] || [ ! -x "${tmux_bin}" ]; then
  printf 'tmux session manager: real tmux binary is missing or not executable\n' >&2
  exit 1
fi

if [ -z "${fzf_bin}" ] || [ ! -x "${fzf_bin}" ]; then
  printf 'tmux session manager: fzf binary is missing or not executable\n' >&2
  exit 1
fi

selected_action=''
selected_session_id=''
selected_session_name=''
session_name=''

list_session_rows() {
  local format

  format=$'#{session_id}\t#{session_name}\t#{session_windows} windows'
  "${tmux_bin}" list-sessions -F "${format}" 2>/dev/null || return 0
}

prompt_session_name() {
  local prompt="${1}"
  local name

  while true; do
    if ! read -r -p "${prompt}" name; then
      return 1
    fi

    if [ -z "${name}" ]; then
      printf 'Name cannot be empty.\n' >&2
      continue
    fi

    if [[ "${name}" == *:* ]]; then
      printf 'Name cannot contain ":".\n' >&2
      continue
    fi

    session_name="${name}"
    return 0
  done
}

parse_selected_row() {
  local row="${1}"
  local rest

  selected_session_id="${row%%$'\t'*}"
  rest="${row#*$'\t'}"
  selected_session_name="${rest%%$'\t'*}"
}

choose_action() {
  local rows output key row
  local lines=()

  selected_action=''
  selected_session_id=''
  selected_session_name=''

  rows="$(list_session_rows)"
  if [ -z "${rows}" ]; then
    selected_action='new'
    return 0
  fi

  if ! output="$(
    printf '%s\n' "${rows}" | "${fzf_bin}" \
      --height=80% \
      --layout=reverse \
      --border \
      --prompt='tmux> ' \
      --delimiter=$'\t' \
      --with-nth=2,3 \
      --header='enter attach | ctrl-n new | ctrl-r rename | ctrl-d delete | esc quit' \
      --expect=enter,ctrl-n,ctrl-r,ctrl-d
  )"; then
    return 1
  fi

  mapfile -t lines <<<"${output}"
  key="${lines[0]:-}"
  row="${lines[1]:-}"

  case "${key}" in
    enter | '')
      selected_action='attach'
      ;;
    ctrl-n)
      selected_action='new'
      return 0
      ;;
    ctrl-r)
      selected_action='rename'
      ;;
    ctrl-d)
      selected_action='delete'
      ;;
    *)
      return 1
      ;;
  esac

  if [ -z "${row}" ]; then
    return 1
  fi

  parse_selected_row "${row}"
}

create_session() {
  if ! prompt_session_name 'New session name: '; then
    return 1
  fi

  exec "${tmux_bin}" new-session -s "${session_name}"
}

rename_session() {
  local target="${1}"
  local old_name="${2}"
  local new_name

  if ! prompt_session_name "Rename \"${old_name}\" to: "; then
    return 0
  fi
  new_name="${session_name}"

  if "${tmux_bin}" rename-session -t "${target}" "${new_name}"; then
    printf 'Renamed "%s" to "%s".\n' "${old_name}" "${new_name}"
  else
    printf 'Could not rename "%s".\n' "${old_name}" >&2
  fi
}

delete_session() {
  local target="${1}"
  local name="${2}"
  local confirm

  if ! read -r -p "Delete \"${name}\"? [y/N] " confirm; then
    return 0
  fi

  case "${confirm}" in
    y | Y | yes | YES)
      if "${tmux_bin}" kill-session -t "${target}"; then
        printf 'Deleted "%s".\n' "${name}"
      else
        printf 'Could not delete "%s".\n' "${name}" >&2
      fi
      ;;
    *)
      printf 'Delete cancelled.\n'
      ;;
  esac
}

attach_session() {
  local target="${1}"

  exec "${tmux_bin}" attach-session -t "${target}"
}

while true; do
  if ! choose_action; then
    exit 0
  fi

  case "${selected_action}" in
    attach)
      attach_session "${selected_session_id}"
      ;;
    new)
      create_session || exit 0
      ;;
    rename)
      rename_session "${selected_session_id}" "${selected_session_name}"
      ;;
    delete)
      delete_session "${selected_session_id}" "${selected_session_name}"
      ;;
  esac
done
```

- [ ] **Step 2: Run the focused tests**

Run:

```bash
bash modules/tmux/files/tmux-session-manager-test.sh
```

Expected: PASS and print `tmux-session-manager tests passed`.

- [ ] **Step 3: Run Bash syntax checks**

Run:

```bash
bash -n modules/tmux/files/tmux-session-manager.sh
bash -n modules/tmux/files/tmux-session-manager-test.sh
```

Expected: both commands exit with status `0`.

---

### Task 3: Wire Fzf Through the Nix Wrapper

**Files:**
- Modify: `modules/tmux/default.nix`

- [ ] **Step 1: Pass the Nix-store fzf binary to the manager**

Change the manager invocation in `modules/tmux/default.nix` from:

```nix
exec ${pkgs.bash}/bin/bash ${flakeDirectory}/modules/tmux/files/tmux-session-manager.sh ${pkgs.tmux}/bin/tmux
```

to:

```nix
exec ${pkgs.bash}/bin/bash ${flakeDirectory}/modules/tmux/files/tmux-session-manager.sh ${pkgs.tmux}/bin/tmux ${pkgs.fzf}/bin/fzf
```

- [ ] **Step 2: Format the Nix file**

Run:

```bash
nixfmt modules/tmux/default.nix
```

Expected: command exits with status `0`.

- [ ] **Step 3: Validate Home Manager can evaluate the package list**

Run:

```bash
nix eval .#homeConfigurations.pylv-denim.config.home.packages --apply 'x: map (p: p.name) x'
```

Expected: command exits with status `0` and includes tmux-related packages in the evaluated list.

---

### Task 4: Update Documentation and Completed Item Tracking

**Files:**
- Modify: `README.md`
- Modify: `TMUX_GHOSTTY_ITEMS.md`

- [ ] **Step 1: Update the README tmux manager bullet**

Replace the current bare `tm` bullet in `README.md`:

```markdown
- Running bare interactive `tm` outside tmux opens the session manager; `tmux`
  remains the original tmux binary.
```

with:

```markdown
- Running bare interactive `tm` outside tmux opens the fzf-backed session
  manager; `tmux` remains the original tmux binary. Use arrow keys to select a
  session, `Enter` to attach, `Ctrl+n` to create, `Ctrl+r` to rename, and
  `Ctrl+d` to delete.
```

- [ ] **Step 2: Remove the completed tmux session-manager item from `TMUX_GHOSTTY_ITEMS.md`**

Delete this section from `TMUX_GHOSTTY_ITEMS.md` after the implementation passes:

```markdown
## tmux session manager
- 터미널에서 `tmux` 명령어로 tmux를 열었을 때, 현재 존재하는 세션 목록을 보여주고 사용자는 그 중에서 세션을 선택해서 attach하거나 rename/delete 등이 가능해야 한다
- 현재 존재하는 세션이 없더라도, `tmux` 명령어로 들어간 session manager에서 새로운 세션 이름을 지정해서 열 수 있어야 한다
```

- [ ] **Step 3: Check the documentation diff**

Run:

```bash
git diff -- README.md TMUX_GHOSTTY_ITEMS.md
```

Expected: the diff only documents the new `fzf` key bindings and removes the completed item.

---

### Task 5: Final Verification and Commit

**Files:**
- Verify all files touched in Tasks 1-4.

- [ ] **Step 1: Run the focused test suite**

Run:

```bash
bash modules/tmux/files/tmux-session-manager-test.sh
```

Expected: PASS and print `tmux-session-manager tests passed`.

- [ ] **Step 2: Run syntax and formatting checks**

Run:

```bash
bash -n modules/tmux/files/tmux-session-manager.sh
bash -n modules/tmux/files/tmux-session-manager-test.sh
nixfmt modules/tmux/default.nix
git diff --check
```

Expected: every command exits with status `0`.

- [ ] **Step 3: Run lightweight Nix evaluation**

Run:

```bash
nix eval .#homeConfigurations.pylv-denim.config.home.packages --apply 'x: map (p: p.name) x'
```

Expected: command exits with status `0`.

- [ ] **Step 4: Review the full diff**

Run:

```bash
git diff -- modules/tmux/files/tmux-session-manager.sh modules/tmux/files/tmux-session-manager-test.sh modules/tmux/default.nix README.md TMUX_GHOSTTY_ITEMS.md
```

Expected: the diff contains only the fzf session-manager implementation, its focused tests, the Nix wrapper wiring, and related documentation updates.

- [ ] **Step 5: Commit the implementation**

Run:

```bash
git add modules/tmux/files/tmux-session-manager.sh modules/tmux/files/tmux-session-manager-test.sh modules/tmux/default.nix README.md TMUX_GHOSTTY_ITEMS.md
git commit -m "feat: add fzf tmux session manager"
```

Expected: commit succeeds and records one focused implementation commit.

---

## Self-Review

- Spec coverage: the plan covers arrow-key selection via `fzf`, attach/open via `Enter`, rename via `Ctrl+r`, delete via `Ctrl+d`, create via `Ctrl+n`, and no-session creation without entering a dead-end state.
- Stability: actions target tmux `session_id` values rather than mutable session names.
- Verification: shell behavior is covered with fake tmux/fzf integration tests, Bash syntax checks, Nix formatting, lightweight Nix evaluation, diff review, and a focused commit.
- Scope: the plan stays within the existing tmux module and avoids unrelated terminal, theme, or keybinding changes.
