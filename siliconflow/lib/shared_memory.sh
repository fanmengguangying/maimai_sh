#!/bin/bash

# 共享内存操作相关函数

# 需要先source constants.sh来获取port变量

# ---------- 2. 读共享内存 ----------
read_shared_memory() {
    if [[ ! -f "/dev/shm/siliconflow_${port}/key_count" || ! -f "/dev/shm/siliconflow_${port}/ALLKEYS" ]]; then
        echo "Error: Shared memory files not found. Please run the setup script." >&2
        exit 1
    fi
    read -r KEY_COUNT </dev/shm/siliconflow_${port}/key_count
    mapfile -t KEYS </dev/shm/siliconflow_${port}/ALLKEYS
}