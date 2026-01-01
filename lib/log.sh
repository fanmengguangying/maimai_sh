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
    local __status=$?
    local LOG_TYPE="${1:-INFO}"
    local LOG_MSG="${2:-}"
    
    # 转换为大写，实现大小写不敏感
    LOG_TYPE="${LOG_TYPE^^}"
    
    # 非法等级自动转成 INFO
    if [[ -z "${LOG_LEVELS[$LOG_TYPE]}" ]]; then
        LOG_MSG="$LOG_TYPE $LOG_MSG"
        LOG_TYPE="INFO"
    fi

    # 颜色定义 - 使用 ANSI 转义序列
    # \033[ 转义序列开始
    # 31m 红色，32m 绿色，33m 黄色，34m 蓝色，35m 紫色，36m 青色，37m 白色
    # local RED=$'\033[31m'
    # local GREEN=$'\033[32m'
    # local YELLOW=$'\033[33m'
    # local BLUE=$'\033[34m'
    # local PURPLE=$'\033[35m'
    # local CYAN=$'\033[36m'
    # local WHITE=$'\033[37m'
    # local NC=$'\033[0m' # No Color

    # 颜色映射
    case "$LOG_TYPE" in
        FATAL)  LOG_COLOR=$'\033[31m' ;;
        ERROR)  LOG_COLOR=$'\033[31m' ;;
        WARN)   LOG_COLOR=$'\033[33m' ;;
        INFO)   LOG_COLOR=$'\033[37m' ;;
        SUCCESS)LOG_COLOR=$'\033[32m' ;;
        DEBUG)  LOG_COLOR=$'\033[35m' ;;
        TRACE)  LOG_COLOR=$'\033[36m' ;;
        *)      LOG_COLOR=$'\033[37m' ;;
    esac


    # 等级过滤：当前类型等级 ≤ 设定等级时才输出
    # 使用内置 printf 和日期格式，避免外部命令调用
    if (( ${LOG_LEVELS[$LOG_TYPE]} <= ${LOG_LEVELS[${LOG_LEVEL^^}]:-3} )); then
        printf '%s\n' "$(date +"%F %T") ${LOG_COLOR}[${LOG_TYPE}]${NC} ${LOG_MSG}"
    fi
    
    return $__status
}

# ------ 3. 快捷函数 ------
log.fatal()  { log FATAL "$@";  }
log.error()  { log ERROR "$@";  }
log.warn()   { log WARN  "$@";  }
log.info()   { log INFO  "$@";  }
log.success(){ log SUCCESS "$@";}
log.debug()  { log DEBUG "$@";  }
log.trace()  { log TRACE "$@";  }

# 测试代码（可选）
if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    # 测试不同日志级别
    echo "=== 测试日志系统 ==="
    LOG_LEVEL=TRACE
    log.trace "这是一个跟踪信息"
    log.debug "这是一个调试信息" 
    log.info "这是一个普通信息"
    log.success "这是一个成功信息"
    log.warn "这是一个警告信息"
    log.error "这是一个错误信息"
    log.fatal "这是一个致命错误"
    
    # 测试大小写不敏感
    echo "=== 测试大小写不敏感 ==="
    log "info" "小写 info 测试"
    log "DEBUG" "大写 DEBUG 测试"
    log "Error" "混合大小写测试"
fi