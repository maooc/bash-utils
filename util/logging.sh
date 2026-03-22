#!/usr/bin/env bash
#
# 加载说明:
#   - 此文件提供日志记录功能
#   - 依赖 base.sh 中的 REQUIRES_CMDS 等函数
#   - 如果 base.sh 尚未加载，logging.sh 会尝试自动加载它
#
# 预期加载顺序:
#   1. source util/base.sh
#   2. source util/logging.sh
#   3. logging.sh 会自动调用 __base_setup_traps 设置 trap

# 如果 base.sh 尚未加载，尝试自动加载
if [[ "$(type -t REQUIRES_CMDS)" != "function" ]]; then
    # 获取当前文件所在目录
    __LOGGING_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    if [[ -f "$__LOGGING_DIR/base.sh" ]]; then
        source "$__LOGGING_DIR/base.sh"
    fi
    unset __LOGGING_DIR
fi

REQUIRES_CMDS sed


### Global Variables

RESET='\033[0m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[2;37m'


### Logging Helpers

function log_start {
    local -n CONFIG_VAR="$1"
    local RUN_STR="${SCRIPTNAME} with config:"

    for KEY in "${!CONFIG_VAR[@]}"; do
        RUN_STR="${RUN_STR}\n$KEY=${CONFIG_VAR[$KEY]} "
    done

    debug "Running $RUN_STR"
}

function log_quit {
    local SIGNAL="$1" SOURCE="${2:-$SCRIPTNAME}"
    wait
    fatal --trace-depth="0" --status="$SIGNAL" "$SOURCE $SIGNAL"
}

function log {
    local LEVEL="$1"; shift
    local STRING="$*"

    set +o nounset
    local TIMESTAMPS="${CONFIG[TIMESTAMPS]:-1}"
    local LOGLEVELS="${CONFIG[LOGLEVELS]:-1}"
    local COLOR="${CONFIG[COLOR]:-1}"
    set -o nounset

    case "$LEVEL" in
        DEBUG)   ANSI="$GRAY";;
        INFO)    ANSI="$CYAN";;
        WARN)    ANSI="$YELLOW";;
        ERROR)   ANSI="$RED";;
        FATAL)   ANSI="$RED";;
        *)       ANSI="";;
    esac

    # replace newlines and repeated whitespace with a single space
    STRING="$(echo -e "$STRING" | sed -e "s/[[:space:]]\+/ /g")"
    if [[ "$TIMESTAMPS" == "1" ]]; then
        TS="[$(date +"%Y-%m-%d %H:%M")] "
    else
        TS=""
    fi
    if [[ "$LOGLEVELS" == "1" ]]; then
        LEVEL="$(printf '%-7s' "[${LEVEL}] ")"
    else
        LEVEL=""
    fi

    # if COLOR=0 or stderr is not a tty, turn off log coloring
    if [[ "$COLOR" == "1" && -t 2 ]]; then
        echo -e "${GRAY}${TS}${ANSI}${LEVEL}$RESET${STRING}" >&2
    else
        echo -e "${TS}${LEVEL}${STRING}" >&2
    fi
}

function debug {
    set +o nounset
    local VERBOSE="${CONFIG[VERBOSE]:-1}"
    set -o nounset

    [[ ! "$VERBOSE" == "1" ]] && return 0
    log DEBUG "$*"
    # set -o xtrace
}
function info {
    set +o nounset
    local QUIET="${CONFIG[QUIET]:-0}"
    set -o nounset

    [[ "$QUIET" == "1" ]] && return 0
    log INFO "$*"
}
function warn {
    log WARN "$*"
}
function error {
    log ERROR "$*"
}
function fatal {
    local STATUS=$? BACKTRACE_DEPTH=1 MSG=""

    while (( "$#" )); do
        case "$1" in
            --status|--status=*)
                if [[ "$1" == *'='* ]]; then
                    STATUS=${1#*=}
                else
                    shift
                    STATUS=$1
                fi
                shift
            ;;
            --trace-depth|--trace-depth=*)
                if [[ "$1" == *'='* ]]; then
                    BACKTRACE_DEPTH=${1#*=}
                else
                    shift
                    BACKTRACE_DEPTH=$1
                fi
                shift
            ;;
            *)
                MSG="$MSG$1 "
                shift
            ;;
        esac
    done

    log FATAL "$MSG\n$(backtrace $BACKTRACE_DEPTH)"

    # e.g. if STATUS is a named signal like SIGSEV instead of a number
    [ ! -z "${STATUS##*[!0-9]*}" ] || STATUS=3

    # kill all child processes in current subshell
    jobs -p | xargs 'kill -9 --' 2>/dev/null

    exit $STATUS
}

# logging.sh 加载完成后，自动设置 base.sh 中的 trap
# 这会确保 log_quit 函数已经可用
if [[ "${__BASE_TRAPS_NEED_SETUP:-}" == "true" ]]; then
    __base_setup_traps
fi

