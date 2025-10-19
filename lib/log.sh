#!/bin/bash

# ------ 1. 日志等级定义 ------
# 数值越小越重要；可通过 LOG_LEVEL 动态过滤
declare -A LOG_LEVELS=(
    [FATAL]=0
    [ERROR]=1
    [WARN]=2
    [INFO]=3
    [SUCCESS]=3
    [DEBUG]=4
    [TRACE]=5
)

# 默认输出等级：INFO（可外部 export LOG_LEVEL=DEBUG 覆盖）
LOG_LEVEL=${LOG_LEVEL:-INFO}

# ------ 2. 核心日志函数 ------
log() {
    local LOG_TYPE="${1:-INFO}"
    local LOG_MSG="${2:-}"
    local LOG_TIME=$(date +"%F %T")

    # 非法等级自动转成 INFO
    if [[ -z "${LOG_LEVELS[$LOG_TYPE]}" ]]; then
        LOG_MSG="$LOG_TYPE $LOG_MSG"
        LOG_TYPE="INFO"
    fi

    # 颜色映射
    case "$LOG_TYPE" in
        FATAL) LOG_COLOR=$RED   ;;
        ERROR) LOG_COLOR=$RED   ;;
         WARN) LOG_COLOR=$YELLOW;;
         INFO) LOG_COLOR=$WHITE ;;
      SUCCESS) LOG_COLOR=$GREEN ;;
        DEBUG) LOG_COLOR=$PURPLE;;
        TRACE) LOG_COLOR=$CYAN  ;;
            *) LOG_COLOR=$WHITE ;;
    esac

    # 等级过滤：当前类型等级 ≤ 设定等级时才输出
    (( ${LOG_LEVELS[$LOG_TYPE]} <= ${LOG_LEVELS[$LOG_LEVEL]} )) \
        && printf '%s' "${LOG_COLOR}[${LOG_TIME}] [${LOG_TYPE}] ${LOG_MSG}${NC}"$'\n' # 避免\r文本被解释破坏
}

# ------ 3. 快捷函数 ------
log.fatal()  { log FATAL "$@";  }
log.error()  { log ERROR "$@";  }
log.warn()   { log WARN  "$@";  }
log.info()   { log INFO  "$@";  }
log.success(){ log SUCCESS "$@";}
log.debug()  { log DEBUG "$@";  }
log.trace()  { log TRACE "$@";  }

if [[ "$0" == "${BASH_SOURCE}" ]]; then
    exit 1
fi