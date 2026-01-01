#!/bin/bash

# we don't care about those undefined functions,we'll source to define them

# ---------- 1. 通用加锁 / 解锁 ----------
acquire_lock() {
    local lock_file="${1:-/tmp/process.lock}"
    local lock_content="${2:-$$}"
    local timeout="${3:-300}"  # 默认超时300秒（5分钟）
    local interval="${4:-1}" # 默认检查间隔1秒
    log.trace "acquire_lock: 开始获取锁，文件: $lock_file, 内容: $lock_content, 超时: $timeout秒" >&2
    local start_time=$(date +%s)
    local content
    local now
    local max_backoff=5
    local attempt=0
    
    while true;do
        if mkdir "${lock_file}.d" 2>/dev/null;then
            echo "$lock_content">"$lock_file" || log.error "acquire_lock: 无法写入$lock_file" >&2
            read -r content <$lock_file
            if [[ "$content" == "$lock_content" ]];then
                log.debug "acquire_lock: 成功获取锁，文件: $lock_file" >&2
                return 0
            else
                log.trace "acquire_lock: $lock_file繁忙..." >&2
                now=$(date +%s)
                (( now-start_time>$timeout)) && log.warn "acquire_lock: $lock_file超时$timeout秒" >&2 && return 124
                sleep "$interval"
            fi
        else
            now=$(date +%s)
            (( now-start_time>$timeout)) && log.warn "acquire_lock: $lock_file超时$timeout秒" >&2 && return 124
            local backoff=$(( (RANDOM % 100) * 2 ** attempt / 100 ))
            (( backoff > max_backoff )) && backoff=$max_backoff
            ((attempt++))
            sleep "$backoff"
        fi
    done
    
}

release_lock() {
    local lock_file="${1:-/tmp/process.lock}"
    local lock_content="${2:-$$}"
    log.trace "release_lock: 开始释放锁，文件: $lock_file, 内容: $lock_content" >&2
    # 可选：验证锁内容是否匹配，避免误删其他进程的锁
    if [[ -f "$lock_file" ]]; then
        local current_content
        read -r current_content<$lock_file
        if [[ "$current_content" == "$lock_content" ]]; then
            rm -f "${lock_file}" 2>/dev/null
            rm -r "${lock_file}.d" 2>/dev/null
            log.debug "release_lock: 成功释放锁，文件: $lock_file" >&2
        else
            log.warn "release_lock: 锁内容不匹配，不释放锁，文件: $lock_file" >&2
            return 1
        fi
    else
        log.debug "release_lock: 锁文件不存在，文件: $lock_file" >&2
    fi
}

if [[ "$0" == "${BASH_SOURCE}" ]]; then
    exit 1
fi