#!/bin/bash

# ---------- 0. 路径常量 ----------
port="${port:-3699}"
LOCKFILE="/dev/shm/siliconflow_${port}/LOCK"
INDEXFILE="/dev/shm/siliconflow_${port}/INDEX"
PID=$$
START_MS="$(date '+%s%3N')"
REQUEST_TIMES=0

# ---------- 1. 加锁 / 解锁 ----------
acquire_lock() {
    while ! ( set -o noclobber; echo "$PID" > "$LOCKFILE" ) 2>/dev/null; do
        sleep 0.01
    done
}

release_lock() { rm -f "$LOCKFILE"; }

# ---------- 2. 读共享内存 ----------
if [[ ! -f "/dev/shm/siliconflow_${port}/key_count" || ! -f "/dev/shm/siliconflow_${port}/ALLKEYS" ]]; then
    echo "Error: Shared memory files not found. Please run the setup script." >&2
    exit 1
fi
read -r KEY_COUNT </dev/shm/siliconflow_${port}/key_count
mapfile -t KEYS </dev/shm/siliconflow_${port}/ALLKEYS

# ---------- 3. 失效索引表 ----------
declare -A INVALID
while read -r line; do
    [[ "$line" =~ ^[0-9]+ ]] && INVALID["${line%% *}"]=1
done </dev/shm/siliconflow_${port}/InvalidKeys 2>/dev/null

# ---------- 4. 原子取下一个有效下标 ----------
next_index() {
    local idx
    [[ -f "$INDEXFILE" ]] && read -r idx <"$INDEXFILE" || idx=0
    ((idx >= KEY_COUNT)) && idx=0
    echo $((idx + 1)) >"$INDEXFILE"
    echo "$idx"
}

# ---------- 5. 重建函数 ----------
authorization_rebuilt() { printf "Bearer %s" "$APIKEY"; }
host_rebuilt() { printf "api.siliconflow.cn"; }

# ---------- 6. HTTP 解析与重建 ----------
declare -A REQUEST
declare -A RESPONSE_HEAD

process_http_headers() {
    local -n _headers_ref=$1
    _headers_ref=()
    IFS=$'\r' read -r line
    IFS=' ' read -ra parts <<<"$line"
    case "${parts[0]}" in
    GET | POST | PUT | DELETE | HEAD | OPTIONS | PATCH | TRACE | CONNECT)
        _headers_ref[method]="${parts[0]}"
        _headers_ref[path]="${parts[1]}"
        _headers_ref[http_version]="${parts[2]}"
        ;;
    'HTTP/'*)
        _headers_ref[http_version]="${parts[0]}"
        _headers_ref[status_code]="${parts[1]}"
        _headers_ref[status_text]="${parts[*]:2}"
        ;;
    esac
    while IFS=$'\r' read -r line; do
        [[ -z "$line" ]] && break
        local header_name="${line%%: *}"
        local header_value="${line#*: }"
        _headers_ref["${header_name,,}"]="$header_value"
    done
}

rebuild_http_headers() {
    local -n _headers_ref=$1
    if [[ -n "${_headers_ref[method]}" ]]; then
        printf "%s %s %s\r\n" "${_headers_ref[method]}" "${_headers_ref[path]}" "${_headers_ref[http_version]}"
    elif [[ -n "${_headers_ref[http_version]}" ]]; then
        printf "%s %s %s\r\n" "${_headers_ref[http_version]}" "${_headers_ref[status_code]}" "${_headers_ref[status_text]}"
    fi
    for header_name in "${!_headers_ref[@]}"; do
        [[ "$header_name" =~ ^(method|path|http_version|status_code|status_text)$ ]] && continue
        local header_value="${_headers_ref[$header_name]}"
        local rebuild_function="${header_name}_rebuilt"
        if declare -f "$rebuild_function" >/dev/null; then
            header_value=$($rebuild_function)
        fi
        printf "%s: %s\r\n" "$header_name" "$header_value"
    done
    printf "\r\n"
}

# ---------- 连接相关函数 ----------
connect(){
    local fdin="${1}"
    local fdout="${2}"
    local host="api.siliconflow.cn"
    local host=localhost
    rm -f "${fdin}" "${fdout}"
    mkfifo "${fdin}" "${fdout}" 2>/dev/null
    if command -v openssl >/dev/null 2>&1; then
        local port=443
        local port=3700
        openssl s_client -connect "${host}:${port}" -quiet <"${fdin}" >"${fdout}" 2>/dev/null &
    else
        local port=80
        if command -v ncat >/dev/null 2>&1; then
            ncat "${host}" "${port}" <"${fdin}" >"${fdout}" 2>/dev/null &
        elif command -v nc >/dev/null 2>&1; then
            nc "${host}" "${port}" <"${fdin}" >"${fdout}" 2>/dev/null &
        else
            echo "Error: openssl, ncat, or nc is required for network connection." >&2
            exit 1
        fi
    fi
    local net_pid=$!
    echo "$net_pid" > "/tmp/net_${fdin//\//_}_${fdout//\//_}.pid"
    sleep 0.2
}

close_connection(){
    local fdin="${1}"
    local fdout="${2}"
    local pid_file="/tmp/net_${fdin//\//_}_${fdout//\//_}.pid"
    if [[ -f "$pid_file" ]]; then
        local net_pid=$(cat "$pid_file")
        if ps -p "$net_pid" > /dev/null; then
           kill "$net_pid" 2>/dev/null
        fi
        rm -f "$pid_file"
    fi
    rm -f "${fdin}" "${fdout}" 2>/dev/null
}

read_response(){
    local stream_mode="${1:-false}"
    local headers_ref_name="${2:-RESPONSE_HEAD}"
    local -n _headers_ref=$headers_ref_name
    if [[ "$stream_mode" == "stream" ]]; then
        if [[ "${_headers_ref[transfer-encoding]}" == "chunked" ]]; then
            while IFS=$'\r' read -r chunk_size_hex; do
                chunk_size=$((16#${chunk_size_hex}))
                [[ $chunk_size -eq 0 ]] && break
                dd bs=1 count="$chunk_size" 2>/dev/null
                read -r _
            done
        else
            cat
        fi
    else
        if [[ -n "${_headers_ref[content-length]}" ]]; then
            dd bs=1 count="${_headers_ref[content-length]}" 2>/dev/null
        elif [[ "${_headers_ref[transfer-encoding]}" == "chunked" ]]; then
            local response_body=""
            while IFS=$'\r' read -r chunk_size_hex; do
                chunk_size=$((16#${chunk_size_hex}))
                [[ $chunk_size -eq 0 ]] && break
                IFS= read -r -N "$chunk_size" chunk_data
                response_body+="$chunk_data"
                read -r _
            done
            printf "%s" "$response_body"
        else
            cat
        fi
    fi
}

send_request() {
    local fdin="$1"
    local headers_array_name="$2"
    local body_data="${3:-}"
    rebuild_http_headers "$headers_array_name" > "${fdin}"
    if [[ -n "$body_data" ]]; then
        printf "%s" "$body_data" > "${fdin}"
    fi
}

# ---------- 7. 转发函数 ----------
turn2siliconflow() {
    local fdin="/tmp/http_in_$$"
    local fdout="/tmp/http_out_$$"
    connect "$fdin" "$fdout"
    REQUEST[host]="api.siliconflow.cn"
    send_request "$fdin" "REQUEST" "$body"
    local response_body
    process_http_headers "RESPONSE_HEAD" <"$fdout"
    response_body=$(read_response "false" "RESPONSE_HEAD" <"$fdout")
    close_connection "$fdin" "$fdout"
    local status="${RESPONSE_HEAD[status_code]}"
    case $status in
    401|403)
        if echo "$response_body" | jq -e '.code == 30011' >/dev/null 2>&1; then
            downgraded="$(echo "$body" | jq -c '
            .model |= (
                if startswith("Pro/") then .[4:] else . end |
                if startswith("/") then .[1:] else . end
            )
            ')"
            body="$downgraded"
            main
            return $?
        else
            echo "$index ${KEYS[$index]}" >>/dev/shm/siliconflow_${port}/InvalidKeys
        fi
        ;;
    429|400|413|500|502|503|504)
        if [[ $status == 400 ]]; then
            if echo "$body" | jq -e 'has("enable_thinking")' >/dev/null 2>&1; then
                downgraded="$(echo "$body" | jq -c 'del(.enable_thinking)')"
                body="$downgraded"
                main
                return $?
            fi
        fi
        ;;
    esac
    rebuild_http_headers "RESPONSE_HEAD"
    printf "%s" "$response_body"
}

# ---------- 仪表盘函数 ----------
dashboard_log() {
    local status_code="${RESPONSE_HEAD[status_code]:-ERR}"
    local ts_ms=$(date '+%s%3N')
    local day_time=$(date -d @"${ts_ms:0:-3}" '+%F %T')
    local preview="${APIKEY:0:8}********"
    local inv=${#INVALID[@]}
    local left=$((KEY_COUNT - inv))
    END_MS=$(date '+%s%3N')
    ELAPSED=$((END_MS - START_MS))
    local color=$'\033[32m'
    [[ "$status_code" =~ ^[45] ]] && color=$'\033[31m'
    ((left <= 5)) && color=$'\033[31m'
    ((left > 5 && left <= 10)) && color=$'\033[33m'
    printf '%s[%s]| idx=%03d | key=%s | invalid=%03d | left=%03d | code=%s | tries=%s | elapsed=%sms '$'\033[0m''\n' \
        "$color" "$day_time" "${index:--}" "$preview" "$inv" "$left" "$status_code" "$REQUEST_TIMES" "$ELAPSED" \
        >>/dev/shm/siliconflow_${port}/log
}

_auth() {
    if [[ "${REQUEST[authorization]}" =~ ^Bearer[[:space:]]+sk- ]]; then
        :
    else
        printf "HTTP/1.1 401 Unauthorized\r\nContent-Type: text/plain\r\nContent-Length: 22\r\n\r\nAuthorization required."
        exit 0
    fi
}

# ---------- 8. 主程序 ----------
main() {
    ((REQUEST_TIMES++))
    acquire_lock
    while true; do
        index=$(next_index)
        if (( ${#INVALID[@]} >= KEY_COUNT )); then
            printf "HTTP/1.1 503 Service Unavailable\r\nContent-Type: text/plain\r\nContent-Length: 23\r\n\r\nAll API keys invalid."
            release_lock
            exit 1
        fi
        [[ -z "${INVALID[$index]}" ]] && break
    done
    APIKEY="${KEYS[$index]}"
    release_lock
    if (( REQUEST_TIMES == 1 )); then
        process_http_headers "REQUEST"
        _auth
        if [[ -n "${REQUEST[content-length]}" ]]; then
            body="$(dd bs=1 count="${REQUEST[content-length]}" 2>/dev/null | jq -c . 2>/dev/null || cat)"
            REQUEST['content-length']="$(printf '%s' "$body" | wc -c)"
        else
            body=""
        fi
    fi
    turn2siliconflow
}

trap dashboard_log EXIT
main
