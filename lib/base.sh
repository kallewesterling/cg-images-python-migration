#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOCKER_CLI_HINTS=false

function banner() {
  # Pause before every section transition -- gives the presenter room to wrap
  # up commentary on the previous section before the next banner appears.
  if [ "${NO_WAIT:-false}" = false ]; then
    wait
  fi

  # get the length of $1 string
  length=${#1}
  echo
  echo " ╔═$(printf '═%.0s' $(seq 1 $length))═╗"
  echo " ║ ${1} ║"
  echo " ╚═$(printf '═%.0s' $(seq 1 $length))═╝"
}

function wait_for_http() {
  local url="$1" tries=0 max_tries=300
  until curl -s -o /dev/null "$url" 2>/dev/null || [ "$tries" -ge "$max_tries" ]; do
    sleep 0.1
    tries=$((tries + 1))
  done
  if [ "$tries" -ge "$max_tries" ]; then
    echo "!! $url never came up after $((max_tries / 10))s -- the next command will likely show nothing." >&2
  fi
}

# Print narration immediately -- no ENTER-wait, no typing effect. Use this
# for the intro line(s) right after a banner, where banner() already
# consumed a wait; making the presenter wait again just to reveal plain
# text (not a command) is redundant.
function say() {
  if [ "${SKIP_COMMENTS:-false}" = true ]; then
    return
  fi
  echo -e "${DEMO_COMMENT_COLOR}${1}${COLOR_RESET}"
}

. "${SCRIPT_DIR}/demo-magic.sh"
TYPE_SPEED=60
