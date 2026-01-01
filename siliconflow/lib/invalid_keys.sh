#!/bin/bash

# 失效密钥管理相关函数

# 需要先source constants.sh来获取相关变量

# ---------- 3. 失效索引表 ----------
declare -A INVALID

# 初始化失效密钥表
init_invalid_keys() {
    while read -r line; do
        [[ "$line" =~ ^[0-9]+ ]] && INVALID["${line%% *}"]=1
    done <$turn2siliconflow_path/InvalidKeys 2>/dev/null
}

# 添加失效密钥
add_invalid_key() {
    local index="$1"
    local key="$2"
    echo "$index $key" >>$turn2siliconflow_path/InvalidKeys
    INVALID["$index"]=1
}