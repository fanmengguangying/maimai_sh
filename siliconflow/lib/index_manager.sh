#!/bin/bash

# 索引管理相关函数

# 需要先source constants.sh来获取INDEXFILE和KEY_COUNT变量

# ---------- 4. 原子取下一个有效下标 ----------
next_index() {
    log.trace "next_index: 开始获取下一个索引" >&2
    local idx
    [[ -f "$INDEXFILE" ]] && read -r idx <"$INDEXFILE" || idx=0
    ((idx >= KEY_COUNT)) && idx=0
    echo $((idx + 1)) >"$INDEXFILE"
    log.debug "next_index: 获取到索引: $idx, 下一个索引: $((idx + 1))" >&2
    echo "$((idx + 1))"
}