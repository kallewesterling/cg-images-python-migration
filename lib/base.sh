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
  local url="$1" tries=0
  until curl -s -o /dev/null "$url" 2>/dev/null || [ "$tries" -ge 100 ]; do
    sleep 0.1
    tries=$((tries + 1))
  done
}

# Print narration immediately -- no ENTER-wait, no typing effect. Use this
# for narration wedged between commands, where waiting for ENTER just to
# reveal plain text (not a command) is redundant. Always leads with a blank
# line so it reads as its own beat instead of running into the previous
# command's output.
#
# When a line both comments on the previous command's output ("We can see
# that ...") and leads into the next one ("Let's rebuild:"), put \n\n between
# the two clauses -- the blank line marks where the reflection ends and the
# lead-in to the next command begins, inside the same beat.
function say() {
  if [ "${SKIP_COMMENTS:-false}" = true ]; then
    return
  fi
  echo
  echo -e "${DEMO_COMMENT_COLOR}${1}${COLOR_RESET}"
}

. "${SCRIPT_DIR}/demo-magic.sh"
TYPE_SPEED=60
