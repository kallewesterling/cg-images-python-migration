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
  # Checks for a non-empty body, not just a successful connection. Reusing a
  # host port right after `docker rm -f` on the previous container can hit a
  # window where the port accepts a connection but returns nothing while
  # Docker's proxy finishes rebinding -- curl -o /dev/null treats that as
  # success (no error, just an empty response), so a plain connectivity
  # check reports "up" before the app is actually reachable.
  local url="$1" tries=0 max_tries=300

  # Stay interruptible. demo-magic's run_cmd traps SIGINT with a no-op handler,
  # so without a trap of our own a Ctrl-C here is caught and discarded: it kills
  # at most the current `sleep` and the loop carries on polling for the full 30s.
  # On stage that reads as a dead demo you cannot escape. Take the signal, stop
  # waiting, and hand the presenter back control.
  local interrupted=false prev_int_trap
  prev_int_trap="$(trap -p INT)"
  trap 'interrupted=true' INT

  until [ -n "$(curl -s "$url" 2>/dev/null)" ] \
    || [ "$tries" -ge "$max_tries" ] \
    || [ "$interrupted" = true ]; do
    sleep 0.1
    tries=$((tries + 1))
  done

  # Put back whatever handler was in place (run_cmd's, normally) so the rest of
  # the demo keeps the interrupt behaviour it expects.
  if [ -n "$prev_int_trap" ]; then
    eval "$prev_int_trap"
  else
    trap - INT
  fi

  if [ "$interrupted" = true ]; then
    echo "^C -- stopped waiting for $url. Carrying on; the next command may show nothing." >&2
    return 130
  fi
  if [ "$tries" -ge "$max_tries" ]; then
    echo "!! $url never came up after $((max_tries / 10))s -- the next command will likely show nothing." >&2
  fi
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

# demo-magic parses our argv as it is sourced above: it defaults TYPE_SPEED to
# 20, and `-d` switches typing off by unsetting the variable entirely. So the
# speed override has to come after the source (or demo-magic's own default wins)
# AND has to be conditional (or it clobbers -d, leaving no way to stop typing --
# which matters when pv is missing, since demo-magic aborts without it).
if [ -n "${TYPE_SPEED+set}" ]; then
  TYPE_SPEED=60
fi
