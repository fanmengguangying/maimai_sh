#!/bin/bash

# 仪表盘日志记录相关函数

# 需要先source constants.sh来获取相关变量

# ---------- 仪表盘函数 ----------
dashboard_log() {
    log.debug "dashboard_log: 开始记录仪表盘日志" >&2
    local status_code="${RESPONSE_HEAD[status_code]:-ERR}"
    local ts_ms=$(date '+%s%3N')
    local day_time=$(date -d @"${ts_ms:0:-3}" '+%F %T')
    local preview="${APIKEY:0:8}********"
    local inv=${#INVALID[@]}
    local left=$((KEY_COUNT - inv))
    local ratio=$((left * 100 / KEY_COUNT))
    local connection_status="${RESPONSE_HEAD[connection]:-keep-alive}"
    END_MS=$(date '+%s%3N')
    ELAPSED=$((END_MS - START_MS))
    
    # 状态码颜色
    local status_color=$GREEN
    [[ "$status_code" =~ ^[45] ]] && status_color=$RED
    
    # 剩余密钥颜色
    local key_color=$GREEN
    ((left <= 5)) && key_color=$RED
    ((left > 5 && left <= 10)) && key_color=$YELLOW
    
    # 耗时颜色
    local elapsed_color=$GREEN
    ((ELAPSED > 1000)) && elapsed_color=$YELLOW
    ((ELAPSED > 5000)) && elapsed_color=$RED
    
    # 连接状态颜色和图标
    local conn_color=$GREEN
    local conn_icon="✓"
    if [[ "${connection_status,,}" == "close" ]]; then
        conn_color=$RED
        conn_icon="✗"
    fi
    
    # 构建进度条
    local progress_bar="["
    local filled=$((left * 20 / KEY_COUNT))
    local empty=$((20 - filled))
    
    progress_bar+="${GREEN}"
    for ((i=0; i<filled; i++)); do progress_bar+="█"; done
    progress_bar+="${RED}"
    for ((i=0; i<empty; i++)); do progress_bar+="░"; done
    progress_bar+="${NC}]"
    
    # 格式化输出 - 全部使用 %s
    printf '%s[%s]%s | %sidx=%s%s | %skey=%s%s | %sinvalid=%s/%s%s | %s%s %s%%%s | %scode=%s%s | %sconn=%s%s%s | %stries=%s%s | %selapsed=%sms%s\n' \
        "$CYAN" "$day_time" "$NC" \
        "$BLUE" "${index:--}" "$NC" \
        "$MAGENTA" "$preview" "$NC" \
        "$YELLOW" "$inv" "$KEY_COUNT" "$NC" \
        "$key_color" "$progress_bar" "$ratio" "$NC" \
        "$status_color" "$status_code" "$NC" \
        "$conn_color" "$conn_icon" "$connection_status" "$NC" \
        "$CYAN" "$REQUEST_TIMES" "$NC" \
        "$elapsed_color" "$ELAPSED" "$NC" \
        >>/dev/shm/siliconflow_${port}/log
        
    log.debug "dashboard_log: 仪表盘日志记录完成，状态码: $status_code, 耗时: ${ELAPSED}ms, 剩余密钥: $left/$KEY_COUNT" >&2
}