#!/bin/bash

# 路径常量和全局变量

# ---------- 0. 路径常量 ----------
port="${port:-3699}"
LOCKFILE="/dev/shm/siliconflow_${port}/LOCK"
INDEXFILE="/dev/shm/siliconflow_${port}/INDEX"
USING_KEYS="/dev/shm/siliconflow_${port}/USING_KEYS"
PID=$$
START_MS="$(date '+%s%3N')"

REQUEST_TIMES=0
TIMES_429=0

# HTTP 解析与重建相关的数组声明
declare -A REQUEST
declare -A RESPONSE_HEAD