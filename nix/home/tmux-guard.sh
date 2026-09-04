#!/usr/bin/env bash
# Guard in front of the real tmux; nix/home/tmux.nix installs it as the `tmux`
# on PATH. Usage: tmux-guard.sh <real-tmux> [tmux arguments...]
#
# Refuses the commands that take the user's server down with everything running
# in it: kill-server; kill-session and kill-window without a target, which kill
# the session or window the caller sits in; and either of those with -a, which
# kills every session or window except the target. A command that names its own
# socket (-L or -S, other than the default one) is talking to a throwaway server
# and passes. --dangerously-bypass-protection anywhere in the arguments passes
# too; it is stripped. Everything else is exec'd unchanged.
set -u

real=$1
shift

argv=()
bypass=false
for a in "$@"; do
  if [ "$a" = --dangerously-bypass-protection ]; then bypass=true; else argv+=("$a"); fi
done
if $bypass; then exec "$real" "${argv[@]}"; fi
n=${#argv[@]}

default_socket="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/default"
is_default_socket() {
  local p; p=$(readlink -m "$1")
  [ "$p" = "$(readlink -m "$default_socket")" ] ||
    { [ -n "${TMUX-}" ] && [ "$p" = "$(readlink -m "${TMUX%%,*}")" ]; }
}

# Global options end at the first command word.
own_socket=false
i=0
while [ $i -lt $n ]; do
  a=${argv[i]}
  case $a in
    -L)     [ "${argv[i+1]-}" != default ] && own_socket=true; i=$((i+2)); continue ;;
    -L?*)   [ "${a#-L}" != default ] && own_socket=true ;;
    -S)     is_default_socket "${argv[i+1]-}" || own_socket=true; i=$((i+2)); continue ;;
    -S?*)   is_default_socket "${a#-S}" || own_socket=true ;;
    -[cfT]) i=$((i+2)); continue ;;
    -?*)    ;;
    *)      break ;;
  esac
  i=$((i+1))
done
if $own_socket; then exec "$real" "${argv[@]}"; fi

# Command words: the first after the global options, then each one after a `;`.
blocked=""
at_cmd=true
j=$i
while [ $j -lt $n ]; do
  w=${argv[j]}
  if [ "$w" = ";" ]; then at_cmd=true; j=$((j+1)); continue; fi
  if $at_cmd; then
    at_cmd=false
    if [[ kill-server == "$w"* && ${#w} -ge 8 ]]; then
      blocked="$w kills the user's tmux server: every session, every pane, every process running in them (shells, editors, agents, dev servers)."
    elif [[ (kill-session == "$w"* && ${#w} -ge 8) || (kill-window == "$w"* && ${#w} -ge 6) || $w == killw ]]; then
      has_target=false
      has_all=false
      k=$((j+1))
      while [ $k -lt $n ] && [ "${argv[k]}" != ";" ]; do
        case ${argv[k]} in
          -t*) has_target=true ;;
          -*)  [[ ${argv[k]} =~ ^-[^t]*a ]] && has_all=true ;;
        esac
        k=$((k+1))
      done
      if $has_all; then
        blocked="$w -a kills every session or window except the target: the user's, with every process in them."
      elif ! $has_target; then
        blocked="$w without -t kills the session or window this command runs in: the user's, with every process in it."
      fi
    fi
  fi
  j=$((j+1))
done

if [ -n "$blocked" ]; then
  printf '%s\n' \
    "tmux guard: blocked. $blocked" \
    "Throwaway work gets its own server: tmux -L <label> ..., and tmux -L <label> kill-server when done. Your own sessions on this server: tmux kill-session -t <name>." \
    "If this server really is the target: stop and ask the user. Only with their explicit yes, re-run with --dangerously-bypass-protection." >&2
  exit 1
fi
exec "$real" "${argv[@]}"
