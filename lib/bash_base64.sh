#!/bin/bash
# shellcheck shell=bash
# -*- mode: bash -*-
# 纯 Bash Base64 编解码实现（修复中文问题）
# 无任何外部依赖，仅使用 Bash 内置功能
# shellcheck disable=SC2059
# Base64 编码函数（修复中文支持）
bash_base64_encode() {
    local input="$1"
    local input_len=${#input}
    local base64_chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local output=""
    local i=0
    local bytes=()

    # 将字符串转换为字节数组（支持多字节字符）
    while ((i < input_len)); do
        local char="${input:i:1}"
        # 获取字符的 Unicode 码点
        printf -v code 'U+%04X' "'$char"
        code="${code#U+}"
        code="$((16#$code))"
        # 将 Unicode 码点转换为 UTF-8 字节序列
        if ((code <= 0x7F)); then
            bytes+=("$code")
        elif ((code <= 0x7FF)); then
            bytes+=($((0xC0 | (code >> 6))))
            bytes+=($((0x80 | (code & 0x3F))))
        elif ((code <= 0xFFFF)); then
            bytes+=($((0xE0 | (code >> 12))))
            bytes+=($((0x80 | ((code >> 6) & 0x3F))))
            bytes+=($((0x80 | (code & 0x3F))))
        elif ((code <= 0x10FFFF)); then
            bytes+=($((0xF0 | (code >> 18))))
            bytes+=($((0x80 | ((code >> 12) & 0x3F))))
            bytes+=($((0x80 | ((code >> 6) & 0x3F))))
            bytes+=($((0x80 | (code & 0x3F))))
        fi
        ((i++))
    done

    # 处理字节数组进行 Base64 编码
    local byte_len=${#bytes[@]}
    i=0
    while ((i < byte_len)); do
        local octet_a=${bytes[i]}
        local octet_b=${bytes[i + 1]:-0}
        local octet_c=${bytes[i + 2]:-0}
        ((i += 3))
        local triple
        triple=$(((octet_a << 16) | (octet_b << 8) | octet_c))

        local a="$(((triple >> 18) & 0x3F))"

        local b=$(((triple >> 12) & 0x3F))

        local c=$(((triple >> 6) & 0x3F))

        local d=$((triple & 0x3F))

        output+="${base64_chars:a:1}${base64_chars:b:1}"

        if ((i - 1 > byte_len)); then
            output+="=="
        elif ((i > byte_len)); then
            output+="${base64_chars:c:1}="
        else
            output+="${base64_chars:c:1}${base64_chars:d:1}"
        fi
    done

    echo "$output"
}

# Base64 解码函数（修复中文支持）
bash_base64_decode() {
    local input="$1"
    local input_len="${#input}"
    local base64_chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local output=""
    local bytes=()
    local i=0

    # 移除填充字符
    while [[ "${input: -1}" == "=" ]]; do
        input="${input:0:-1}"
    done

    # 将 Base64 转换为字节数组
    while ((i < input_len)); do
        local char1="${input:i:1}"
        local char2="${input:i+1:1}"
        local char3="${input:i+2:1}"
        local char4="${input:i+3:1}"
        ((i += 4))

        # 查找字符在Base64表中的位置
        local index1=${base64_chars%%$char1*}
        local index2=${base64_chars%%$char2*}
        local index3=${base64_chars%%$char3*}
        local index4=${base64_chars%%$char4*}
        index1=${#index1}
        index2=${#index2}
        index3=${#index3}
        index4=${#index4}

        local triple=$(((index1 << 18) | (index2 << 12) | (index3 << 6) | index4))

        bytes+=($(((triple >> 16) & 0xFF)))
        bytes+=($(((triple >> 8) & 0xFF)))
        bytes+=($((triple & 0xFF)))
    done

    # 将字节数组转换为字符串（支持UTF-8）
    local byte_len=${#bytes[@]}
    i=0
    while ((i < byte_len)); do
        local byte1=${bytes[i]}

        # 解码UTF-8字节序列
        if (((byte1 & 0x80) == 0)); then
            # 1字节字符
            printf -v char "\\x$(printf '%02x' "$byte1")"
            output+="$char"
            ((i++))
        elif (((byte1 & 0xE0) == 0xC0)); then
            # 2字节字符
            local byte2=${bytes[i + 1]}
            printf -v char "\\x$(printf '%02x' "$byte1")\\x$(printf '%02x' "$byte2")"
            output+="$char"
            ((i += 2))
        elif (((byte1 & 0xF0) == 0xE0)); then
            # 3字节字符
            local byte2=${bytes[i + 1]}
            local byte3=${bytes[i + 2]}
            printf -v char "\\x$(printf '%02x' "$byte1")\\x$(printf '%02x' "$byte2")\\x$(printf '%02x' "$byte3")"
            output+="$char"
            ((i += 3))
        elif (((byte1 & 0xF8) == 0xF0)); then
            # 4字节字符
            local byte2=${bytes[i + 1]}
            local byte3=${bytes[i + 2]}
            local byte4=${bytes[i + 3]}
            printf -v char "\\x$(printf '%02x' "$byte1")\\x$(printf '%02x' "$byte2")\\x$(printf '%02x' "$byte3")\\x$(printf '%02x' "$byte4")"
            output+="$char"
            ((i += 4))
        else
            # 无效的UTF-8序列
            ((i++))
        fi
    done

    echo -e "$output"
}

# 测试函数
test_bash_base64() {
    # 测试ASCII
    local test_string="Hello, World!"
    echo "原始字符串: $test_string"

    local encoded=$(bash_base64_encode "$test_string")
    echo "编码后: $encoded"

    local decoded=$(bash_base64_decode "$encoded")
    echo "解码后: $decoded"

    if [[ "$test_string" == "$decoded" ]]; then
        echo "测试成功！编码解码结果匹配。"
    else
        echo "测试失败！结果不匹配。"
    fi

    # 测试中文
    test_string="你好，世界！"
    echo -e "\n测试中文: $test_string"

    encoded=$(bash_base64_encode "$test_string")
    echo "编码后: $encoded"

    decoded=$(bash_base64_decode "$encoded")
    echo "解码后: $decoded"

    if [[ "$test_string" == "$decoded" ]]; then
        echo "测试成功！中文编码解码结果匹配。"
    else
        echo "测试失败！中文结果不匹配。"
    fi

    # 测试混合内容
    test_string="Hello, 世界! 123 🚀"
    echo -e "\n测试混合内容: $test_string"

    encoded=$(bash_base64_encode "$test_string")
    echo "编码后: $encoded"

    decoded=$(bash_base64_decode "$encoded")
    echo "解码后: $decoded"

    if [[ "$test_string" == "$decoded" ]]; then
        echo "测试成功！混合内容编码解码结果匹配。"
    else
        echo "测试失败！混合内容结果不匹配。"
    fi
}

# 使用示例
if [[ "$1" == "--test" ]]; then
    test_bash_base64
elif [[ "$1" == "--encode" ]]; then
    bash_base64_encode "$2"
elif [[ "$1" == "--decode" ]]; then
    bash_base64_decode "$2"
else
    echo "用法:"
    echo "  $0 --test              # 运行测试"
    echo "  $0 --encode \"string\"   # 编码字符串"
    echo "  $0 --decode \"base64\"   # 解码Base64"
fi
