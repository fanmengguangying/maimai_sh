#!/bin/bash

process_http_headers() {
    log.debug "process_http_headers: 开始解析HTTP头" >&2
    local -n _headers_ref=$1
    _headers_ref=()
    IFS=$'\r' read -r line
    IFS=' ' read -ra parts <<<"$line"
    case "${parts[0]}" in
    GET | POST | PUT | DELETE | HEAD | OPTIONS | PATCH | TRACE | CONNECT)
        _headers_ref[method]="${parts[0]}"
        _headers_ref[path]="${parts[1]}"
        _headers_ref[http_version]="${parts[2]}"
        log.debug "process_http_headers: 请求行 - 方法: ${parts[0]}, 路径: ${parts[1]}, 版本: ${parts[2]}" >&2
        ;;
    'HTTP/'*)
        _headers_ref[http_version]="${parts[0]}"
        _headers_ref[status_code]="${parts[1]}"
        _headers_ref[status_text]="${parts[*]:2}"
        log.debug "process_http_headers: 响应行 - 版本: ${parts[0]}, 状态码: ${parts[1]}, 状态文本: ${parts[*]:2}" >&2
        ;;
    esac
    while IFS=$'\r' read -r line; do
        [[ -z "$line" ]] && break
        local header_name="${line%%: *}"
        local header_value="${line#*: }"
        _headers_ref["${header_name,,}"]="$header_value"
        log.trace "process_http_headers: 头字段 - ${header_name}: ${header_value}" >&2
    done
    log.debug "process_http_headers: 完成解析，共 ${#_headers_ref[@]} 个头字段" >&2
    return 0
}

rebuild_http_headers() {
    log.debug "rebuild_http_headers: 开始重建HTTP头" >&2
    local -n _headers_ref=$1
    if [[ -n "${_headers_ref[method]}" ]]; then
        printf "%s %s %s\r\n" "${_headers_ref[method]}" "${_headers_ref[path]}" "${_headers_ref[http_version]}"
        log.debug "rebuild_http_headers: 重建请求行 - ${_headers_ref[method]} ${_headers_ref[path]} ${_headers_ref[http_version]}" >&2
    elif [[ -n "${_headers_ref[http_version]}" ]]; then
        printf "%s %s %s\r\n" "${_headers_ref[http_version]}" "${_headers_ref[status_code]}" "${_headers_ref[status_text]}"
        log.debug "rebuild_http_headers: 重建响应行 - ${_headers_ref[http_version]} ${_headers_ref[status_code]} ${_headers_ref[status_text]}" >&2
    fi
    for header_name in "${!_headers_ref[@]}"; do
        [[ "$header_name" =~ ^(method|path|http_version|status_code|status_text)$ ]] && continue
        local header_value="${_headers_ref[$header_name]}"
        local rebuild_function="${header_name}_rebuilt"
        if declare -f "$rebuild_function" >/dev/null; then
            log.debug "rebuild_http_headers: 调用重建函数: $rebuild_function" >&2
            header_value=$($rebuild_function)
        fi
        printf "%s: %s\r\n" "$header_name" "$header_value"
        log.debug "rebuild_http_headers: 重建头字段 - ${header_name}: ${header_value}" >&2
    done
    printf $'\r\n'
    log.debug "rebuild_http_headers: 完成重建HTTP头" >&2
    return 0
}

# ---------- 连接相关函数 ----------
connect(){
    # set -x
    log.debug "connect: 开始建立连接，fdin: $1, fdout: $2" >&2
    local fdin="${1}"
    local fdout="${2}"
    local host="api.siliconflow.cn"
    [[ $__DEBUG == true ]]&&host="$__DEBUG_HOST"&&log.debug "debug: 连接localhost" >&2
    rm -f "${fdin}" "${fdout}"
    mkfifo "${fdin}" "${fdout}" 2>/dev/null
    if command -v openssl >/dev/null 2>&1 && [[ ! $__DEBUG_TLS == false ]]; then
        local port=443
        [[ $__DEBUG == true ]]&&port=$__DEBUG_PORT
        log.debug "connect: 使用openssl建立SSL连接，主机: $host, 端口: $port" >&2
        openssl s_client -ign_eof -connect "${host}:${port}" -quiet <"${fdin}" >"${fdout}" 2>/dev/null &
    else
        local port=80
        [[ $__DEBUG == true ]]&&port=$__DEBUG_PORT
        if command -v ncat >/dev/null 2>&1; then
            log.debug "connect: 使用ncat建立连接，主机: $host, 端口: $port" >&2
            ncat "${host}" "${port}" <"${fdin}" >"${fdout}" 2>/dev/null &
        elif command -v nc >/dev/null 2>&1; then
            log.debug "connect: 使用nc建立连接，主机: $host, 端口: $port" >&2
            nc "${host}" "${port}" <"${fdin}" >"${fdout}" 2>/dev/null &
        else
            log.error "connect: 错误 - 未找到openssl、ncat或nc命令" >&2
            exit 1
        fi
    fi
    local net_pid=$!
    echo "$net_pid" > "/tmp/net_${fdin//\//_}_${fdout//\//_}.pid"
    sleep 0.2
    log.debug "connect: 连接建立完成，PID: $net_pid, 管道文件: $fdin, $fdout" >&2
    return 0
}

close_connection(){
    log.debug "close_connection: 开始关闭连接，fdin: $1, fdout: $2" >&2
    local fdin="${1}"
    local fdout="${2}"
    local pid_file="/tmp/net_${fdin//\//_}_${fdout//\//_}.pid"
    if [[ -f "$pid_file" ]]; then
        local net_pid=$(cat "$pid_file")
        if ps -p "$net_pid" > /dev/null; then
           log.debug "close_connection: 终止进程 $net_pid" >&2
           kill "$net_pid" 2>/dev/null
        fi
        rm -f "$pid_file"
    fi
    rm -f "${fdin}" "${fdout}" 2>/dev/null
    log.debug "close_connection: 连接关闭完成" >&2
}

read_response(){
    log.debug "read_response: 开始读取响应，流模式: $1" >&2
    local stream_mode="${1:-false}"
    local headers_ref_name="${2:-RESPONSE_HEAD}"
    local read_response_ref_name="${3:-read_response}"
    local -n _headers_ref=$headers_ref_name
    declare -n _read_response_ref=$read_response_ref_name
    if [[ "$stream_mode" == "true" ]]; then
        if [[ "${_headers_ref[transfer-encoding]}" == "chunked" ]]; then
            log.debug "read_response: 使用分块传输编码读取流式响应" >&2
            while IFS=$'\r' read -r chunk_size_hex; do
                chunk_size=$((16#${chunk_size_hex}))
                [[ $chunk_size -eq 0 ]] && break
                dd bs=1 count="$chunk_size" 2>/dev/null
                IFS=$'\r' read -r _
            done
        else
            cat
        fi
    else
        if [[ -n "${_headers_ref[content-length]}" ]]; then
            log.debug "read_response: 使用Content-Length读取响应，长度: ${_headers_ref[content-length]}" >&2
            dd bs=1 count="${_headers_ref[content-length]}" 2>/dev/null
        elif [[ "${_headers_ref[transfer-encoding]}" == "chunked" ]]; then
            log.debug "read_response: 使用分块传输编码读取响应" >&2
            read_response_ref=""
            while IFS=$'\r' read -r chunk_size_hex; do
                chunk_size=$((16#${chunk_size_hex}))
                [[ $chunk_size -eq 0 ]] && break
                IFS= read -r -N "$chunk_size" chunk_data
                read_response_ref+="$chunk_data"
                IFS=$'\r' read -r _
            done
            printf "%s" "$read_response_ref"
        else
            log.debug "read_response: 使用默认方式读取响应" >&2
            cat
        fi
    fi
    log.debug "read_response: 响应读取完成" >&2
}

send_request() {
    log.debug "send_request: 开始发送请求，fdin: $1, 头数组: $2, 数据长度: $(wc -c<<<$3)" >&2
    local fdin="$1"
    local headers_array_name="$2"
    local body_data="${3:-}"
    rebuild_http_headers "$headers_array_name" > "${fdin}"
    if [[ -n "$body_data" ]]; then
        printf "%s" "$body_data" > "${fdin}"
        log.debug "send_request: 请求发送完成" >&2
    fi
}

if [[ "$0" == "${BASH_SOURCE}" ]]; then
    exit 1
fi