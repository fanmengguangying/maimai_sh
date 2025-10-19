#!/bin/bash

# 认证相关函数

_auth() {
    if [[ "${REQUEST[authorization]}" =~ ^Bearer[[:space:]]+sk- ]]; then
        :
    else
        printf "HTTP/1.1 401 Unauthorized\r\nContent-Type: text/plain\r\nContent-Length: 22\r\n\r\nAuthorization required."
        exit 0
    fi
}