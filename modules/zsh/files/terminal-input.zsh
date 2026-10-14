# Late TUI key events and terminal replies must not become vi editing commands.
_discard-terminal-csi() {
  local byte
  local -i count=0
  while (( count++ < 64 )) && read -r -k 1 -t 0.05 byte; do
    [[ $byte == [@-~] ]] && return 0
  done
  return 0
}

_discard-terminal-osc() {
  local byte previous
  local -i count=0
  while (( count++ < 256 )) && read -r -k 1 -t 0.05 byte; do
    [[ $byte == $'\a' || $previous$byte == $'\e\\' ]] && return 0
    previous=$byte
  done
  return 0
}

zle -N _discard-terminal-csi
zle -N _discard-terminal-osc
() {
  local keymap digit
  for keymap in viins vicmd emacs; do
    # Longer bindings, including modified arrows and bracketed paste, win.
    for digit in {0..9}; do
      bindkey -M "$keymap" $'\e['"$digit" _discard-terminal-csi
    done
    bindkey -M "$keymap" $'\e]' _discard-terminal-osc
  done
}
