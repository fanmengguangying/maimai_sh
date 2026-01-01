#!/bin/bash

# 代理转发相关函数

# 需要先source constants.sh来获取port变量
# 需要先source invalid_keys.sh来获取add_invalid_key函数

close_and_release(){
close_connection "$fd_server_in" "$fd_server_out" # 我们改为总是关闭连接
release_lock "$connection_lock" $$
}

# ---------- 7. 转发函数 ----------
turn2siliconflow() {
    log.debug "turn2siliconflow: 开始转发请求到SiliconFlow" >&2
    local fd
    local connection_lock
    local fd_server_in
    local fd_server_out
    local lock_acquired=false
    local response_body
    # 尝试获取可用连接
    mkdir -p "/dev/shm/siliconflow_${port}/connections/"
    for fd in {1..5}; do
        connection_lock="/dev/shm/siliconflow_${port}/connections/${APIKEY}_${fd}.LOCK"
        fd_server_in="/dev/shm/siliconflow_${port}/connections/${APIKEY}_${fd}_in"
        fd_server_out="/dev/shm/siliconflow_${port}/connections/${APIKEY}_${fd}_out"
        
        log.debug "turn2siliconflow: 尝试获取连接 $fd 的锁" >&2
        
        if acquire_lock "$connection_lock" $$ 0 0.01; then
            log.debug "turn2siliconflow: 成功获取连接 $fd 的锁" >&2
            lock_acquired=true
            break
        else
            # 检查锁持有进程是否存活
            local lock_pid
            read -r lock_pid <"$connection_lock"
            if [[ -n "$lock_pid" ]]; then
                if ! kill -0 "$lock_pid" 2>/dev/null; then
                    log.warn "连接 $fd 的锁进程 $lock_pid 不存在，清理并重新获取" >&2
                    rm -rf "$connection_lock" "$fd_server_in" "$fd_server_out" "${connection_lock}.d" 2>/dev/null
                    # 重新尝试获取锁
                    if acquire_lock "$connection_lock" $$ 0 0.01; then
                        log.success "turn2siliconflow: 成功获取清理后的连接 $fd 的锁" >&2
                        lock_acquired=true
                        break
                    fi
                fi
            else
                # 锁文件存在但为空，直接清理
                log.debug "连接 $fd 的锁文件为空，清理" >&2
                rm -rf "$connection_lock" "$fd_server_in" "$fd_server_out" "${connection_lock}.d" 2>/dev/null
            fi
        fi
    done
    
    # 检查是否成功获取锁
    if [[ $lock_acquired != true ]]; then
        log.error "turn2siliconflow: 无法获取任何连接锁" >&2
        return 1
    fi
    
    log.trace "turn2siliconflow: 使用连接 $fd，输入: $fd_server_in, 输出: $fd_server_out" >&2
    
    # 确保连接存在
    #set -x
    if [[ ! -p "$fd_server_in" || ! -p "$fd_server_out" ]]; then
        log.debug "turn2siliconflow: 连接管道不存在，创建连接" >&2
        if ! connect "$fd_server_in" "$fd_server_out"; then
            log.error "turn2siliconflow: 创建连接失败" >&2
            release_lock "$connection_lock" $$
            return 1
        fi
    fi
    
    REQUEST[host]="api.siliconflow.cn"
    
    # 发送请求
    if ! send_request "$fd_server_in" "REQUEST" "$body"; then
        log.error "turn2siliconflow: 发送请求失败" >&2
        close_and_release
        return 1
    fi
    
    {
    # 花括号代码块，为了同时使用一个命名管道，不中断，分次使用有问题
    if ! process_http_headers "RESPONSE_HEAD"; then
        log.error "turn2siliconflow: 处理响应头失败" >&2
        close_and_release
        return 1
    fi
    
    # 读取响应体
    log.debug "turn2siliconflow: 开始读取响应体" >&2
    # 检查连接状态
    # if [[ ${RESPONSE_HEAD["connection"]} == "close" ]]; then
        # #log.debug "turn2siliconflow: 连接被标记为关闭，清理连接 $fd" >&2
        # close_connection "$fd_server_in" "$fd_server_out"
    # fi
    
    local status="${RESPONSE_HEAD[status_code]}"
    log.trace "turn2siliconflow: 收到响应，状态码: $status" >&2
    
    # 处理各种状态码
    case $status in
    401|403)
        log.debug "turn2siliconflow: 处理认证错误，状态码: $status" >&2

        if [[ "$status" == "403" ]]; then
            # 判断模型是否以 Pro/ 开头
            if echo "$body" | jq -r '.model' | grep -q '^Pro/'; then
                log.debug "turn2siliconflow: 检测到模型降级错误，尝试降级模型" >&2
                downgraded="$(echo "$body" | jq -c '
                    .model |= (
                        if startswith("Pro/") then .[4:] else . end |
                        if startswith("/") then .[1:] else . end
                    )
                ')"
                body="$downgraded"
                log.debug "turn2siliconflow: 模型降级完成，结束turn2siliconflow函数" >&2
                close_and_release
                return 1
            else
                log.warn "turn2siliconflow: API密钥无效，添加到无效列表，索引: $index" >&2
                add_invalid_key "$index" "${KEYS[$index]}"
                rm "$USING_KEYS/$APIKEY" 2>/dev/null
                close_and_release
                using_keys=($(ls $USING_KEYS))
                while { ! get_key; } ;do :; done
                echo "$APIKEY">"$USING_KEYS/$APIKEY"
                return 1
            fi
        else # 401
            log.warn "turn2siliconflow: API密钥无效，添加到无效列表，索引: $index" >&2
            add_invalid_key "$index" "${KEYS[$index]}"
            rm "$USING_KEYS/$APIKEY" 2>/dev/null
            close_and_release
            using_keys=($(ls $USING_KEYS))
            while { ! get_key; } ;do :; done
            echo "$APIKEY">"$USING_KEYS/$APIKEY"
            return 1
        fi
        ;;
    429|400|413|500|502|503|504)
        log.debug "turn2siliconflow: 处理状态码 $status" >&2
        if [[ $status == 400 ]]; then
            if echo "$body" | jq -e 'has("enable_thinking")' >/dev/null 2>&1; then
                log.debug "turn2siliconflow: 检测到enable_thinking参数，尝试移除" >&2
                downgraded="$(echo "$body" | jq -c 'del(.enable_thinking)')"
                body="$downgraded"
                log.debug "turn2siliconflow: 参数移除完成，结束turn2siliconflow函数" >&2
                close_and_release
                return 1
            fi
        elif [[ $status == 429 ]];then
            # get_key # 应该是从USING_KEYS中获取，没有则get_key
            ((TIMES_429++))
            using_keys=($(ls $USING_KEYS))
            if [[ -z "${using_keys[TIMES_429]}" ]];then
                APIKEY_OLD=$APIKEY
                while { ! get_key; } ;do :; done
                echo "$APIKEY">"$USING_KEYS/$APIKEY"
                log.debug "turn2siliconflow: 429换key请求" >&2
                close_and_release
                return 1
            else
                APIKEY="${using_keys[TIMES_429]}"
                close_and_release
                return 1
            fi
        fi
        ;;
    esac
    rebuild_http_headers "RESPONSE_HEAD"
    read_response "${REQUEST[stream]:-false}" "RESPONSE_HEAD"
    log.debug "turn2siliconflow: 转发完成，响应体长度: ${#response_body}" >&2
    }<"$fd_server_out"
    close_and_release
    return 0
}