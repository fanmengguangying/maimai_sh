#!/bin/bash

# HTTP头部重建相关函数

# ---------- 5. 重建函数 ----------
authorization_rebuilt() { 
    log.debug "authorization_rebuilt: 重建Authorization头，APIKEY: ${APIKEY:0:8}******" >&2
    printf "Bearer %s" "$APIKEY"; 
}

host_rebuilt() { 
    log.debug "host_rebuilt: 重建Host头" >&2
    printf "api.siliconflow.cn"; 
}