#!/bin/bash

# bash解析http库，使用标准输出，调试echo请>&2
:<<EOF
GET /api/v1/users?id=123 HTTP/1.1
Host: api.example.com
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)
Accept: application/json
Accept-Language: zh-CN,zh;q=0.9
Connection: keep-alive
Authorization: Bearer abcdef123456
Content-Type: application/json; charset=utf-8
Content-Length: 85

{"name": "张三", "email": "zhangsan@example.com"}

HTTP/1.1 200 OK
Date: Mon, 06 Jan 2026 08:00:00 GMT
Server: nginx/1.18.0
Content-Type: application/json; charset=utf-8
Content-Length: 102
Cache-Control: max-age=3600
Set-Cookie: sessionId=xyz789; Path=/; HttpOnly

{
  "status": "success",
  "data": {
    "id": 123,
    "name": "张三",
    "email": "zhangsan@example.com"
  }
}
EOF
# declare -A HTTP_heads
HTTP_do_method=""
# HTTP_phrase_http_heads - 从标准输入解析 HTTP 首行和头部到关联数组
#
# 用法:
#   HTTP_phrase_http_heads <assoc_name>
# 参数:
#   <assoc_name> - 目标关联数组的名字（函数内部使用 local -n 以引用传入名称）
#
# 功能:
#   - 从标准输入按 CRLF(\r\n) 读取 HTTP 首行（请求行或响应行），并判断是请求还是响应。
#   - 对于请求行（例如 "GET /path HTTP/1.1"）：
#       * 在关联数组中设置 keys: method, path, http_version
#       * 设置全局变量 HTTP_do_method="HTTP_do_<METHOD>"（用于调用相应方法处理器）
#   - 对于响应行（例如 "HTTP/1.1 200 OK"）：
#       * 在关联数组中设置 keys: http_version, http_code, http_text
#   - 随后读取头部行直到遇到空行（头部部分结束），将头部名小写化并以 header_name=header_value 存入关联数组。
#
# 存入的键示例:
#   method, path, http_version, http_code, http_text, 以及各个小写的头部字段名（如 host, content-type 等）
#
# 返回值:
#   0 - 成功解析
#   1 - 传入的关联数组名无效或无法关联
#
# 注意事项:
#   - 期望输入行以 CRLF (\r\n) 作为分隔符。
#   - 头部行按第一个 ": " 分割，冒号后第一个空格作为分隔点；头部值中若包含额外冒号不会被再次分割。
#   - header 名称会被全部转换为小写以便一致访问。
#
# 示例:
#   declare -A heads
#   printf $'GET /foo HTTP/1.1\r\nHost: example.com\r\n\r\n' | HTTP_phrase_http_heads heads
#   # 之后可以通过 ${heads[method]}, ${heads[path]}, ${heads[host]} 访问
HTTP_phrase_http_heads(){
    # 标准输入输出
    local -n HTTP_heads="$1" || {
        echo "关联数组heads不存在" >&2
        return 1
    }
	#print_assoc_array HTTP_heads >&2
    IFS=$'\r\n' read -r HTTP_first_line
    IFS=' ' read -r -a HTTP_http_first_line<<<"$HTTP_first_line"
    local HTTP_OR_METHOD="${HTTP_http_first_line[0]}"
    case "$HTTP_OR_METHOD" in
        GET | POST | PUT | DELETE | HEAD | OPTIONS | PATCH | TRACE | CONNECT)
            HTTP_heads["method"]="${HTTP_http_first_line[0]}"
            HTTP_heads["path"]="${HTTP_http_first_line[1]}"
            HTTP_heads["http_version"]="${HTTP_http_first_line[2]}"
            HTTP_do_method="HTTP_do_${HTTP_heads["method"]}"
        ;;
        'HTTP/'*)
            HTTP_heads["http_version"]="${HTTP_http_first_line[0]}"
            HTTP_heads["http_code"]="${HTTP_http_first_line[1]}"
            HTTP_heads["http_text"]="${HTTP_http_first_line[*]:2}"
        ;;
    esac
    while IFS=$'\r\n' read -r HTTP_line; do
        [[ -z "$HTTP_line" ]] && break
        local header_name="${HTTP_line%%: *}"
        local header_value="${HTTP_line#*: }"
        header_name="${header_name,,}"
        HTTP_heads["${header_name}"]="$header_value"
    done
}
HTTP_phrase_http_body(){
    # 标准输入读取HTTP消息体
    local -n HTTP_heads="$1" || {
        echo "关联数组heads不存在" >&2
        return 1
    }
	local -n HTTP_body="$2" || {
		echo "HTTP_body变量不存在" >&2
		return 1
	}
	local HTTP_version="${HTTP_heads["http_version"]}"
	#print_assoc_array HTTP_heads >&2
    local content_length="${HTTP_heads["content-length"]}"
    local transfer_encoding="${HTTP_heads["transfer-encoding"]}"
    
    # 1. 如果有Content-Length头
    if [[ -n "$content_length" ]] && [[ "$content_length" =~ ^[0-9]+$ ]]; then
        # 读取指定长度的消息体
        if [[ $content_length -gt 0 ]]; then
            HTTP_body="$(head -c "$content_length")"
        else
            HTTP_body=""
        fi
    
    # 2. 如果是分块传输编码
    elif [[ "${transfer_encoding,,}" == *"chunked"* ]]; then
        local chunk_body=""
        local chunk_size=1
        
        while [[ $chunk_size -gt 0 ]]; do
            # 读取块大小行（十六进制）
            read -r chunk_line
            chunk_size="$( (16#${chunk_line//[!0-9a-fA-F]/} 2>/dev/null) )"
            
            if [[ $chunk_size -gt 0 ]]; then
                # 读取指定大小的块数据
                chunk_data="$(head -c "$chunk_size")"
                chunk_body="$chunk_body$chunk_data"
                
                # 跳过块后的CRLF
                read -r
            fi
        done
        
        # 读取可选的尾部头
        while IFS= read -r line && [[ -n "$line" ]]; do
            continue
        done
        
        HTTP_body="$chunk_body"
    
    # 3. 如果是multipart/form-data边界传输
    elif [[ "${HTTP_heads["content-type"]}" == *"multipart/form-data"* ]]; then
        # 提取boundary
        local content_type="${HTTP_heads["content-type"]}"
        local boundary=""
        
        if [[ "$content_type" =~ boundary=([^[:space:];]+) ]]; then
            boundary="${BASH_REMATCH[1]}"
            boundary="${boundary#*=}"
            boundary="${boundary//\"/}"
        fi
        
        if [[ -n "$boundary" ]]; then
            # 读取直到结束边界
            local boundary_start="--$boundary"
            local boundary_end="--$boundary--"
            local in_body=false
            local multipart_body=""
            
            while IFS= read -r line; do
                if [[ "$line" == "$boundary_start" ]]; then
                    in_body=true
                    # 跳过头部
                    while IFS= read -r header_line && [[ -n "$header_line" ]]; do
                        continue
                    done
                elif [[ "$line" == "$boundary_end" ]]; then
                    break
                elif $in_body; then
                    multipart_body="$multipart_body$line"$'\n'
                fi
            done
            
            # 移除最后的换行符
            HTTP_body="${multipart_body%$'\n'}"
        fi  
    # 4. 否则，如果没有指定长度，读取到EOF（连接关闭）
    # 注意：这种方式不推荐，因为可能永远阻塞
    elif [[ "${HTTP_version}" == "HTTP/1.0" ]]; then
        # HTTP/1.0 可以依赖连接关闭
        if [[ -t 0 ]]; then
            # 如果是终端输入，有限读取
            HTTP_body="$(timeout 5 cat 2>/dev/null || true)"
        else
            # 从管道或文件读取
            HTTP_body="$(cat)" # 可能永久堵塞，直至连接关闭，但是一般不会到达这里
        fi
    
    # 6. 其他情况
    else
        HTTP_body=""
    fi
    
    # 解码URL编码的消息体（如果是application/x-www-form-urlencoded）
    if [[ "${HTTP_heads["content-type"]}" == *"application/x-www-form-urlencoded"* ]] && \
       [[ -n "$HTTP_body" ]]; then
        # URL解码函数
        _urldecode() {
            local url_encoded="${1//+/ }" # 替换文本
            printf '%b' "${url_encoded//%/\\x}" # 解码文本
        }
        
        HTTP_body="$(_urldecode "$HTTP_body")"
    fi
    if [[ -n $HTTP_do_method ]] && [[ -n "${HTTP_heads[method]}" ]];then
        $HTTP_do_method
    fi
}

HTTP_send(){
    # 标准输入输出 
    local -n HTTP_heads="$1" || {
        echo "关联数组heads不存在" >&2
        return 1
    }
	local -n HTTP_body="$2" || {
		echo "HTTP_body变量不存在" >&2
		return 1
	}
    local HTTP_head_key
    local HTTP_body_length
	#print_assoc_array HTTP_heads >&2
    
    # 确定是请求还是响应
    if [[ -n "${HTTP_heads[http_code]}" ]]; then
        # 响应：输出状态行
        printf "%s %s %s\r\n" "${HTTP_heads[http_version]}" "${HTTP_heads[http_code]}" "${HTTP_heads[http_text]}"
    elif [[ -n "${HTTP_heads[method]}" ]]; then
        # 请求：输出请求行
        printf "%s %s %s\r\n" "${HTTP_heads[method]}" "${HTTP_heads[path]}" "${HTTP_heads[http_version]}"
    else
        echo "HTTP_send: 无效的HTTP头部，缺少method或http_code" >&2
        return 1
    fi
    
    # 检查是否为分块传输编码
    local is_chunked=false
    if [[ "${HTTP_heads["Transfer-Encoding"],,}" == "chunked" ]]; then
        is_chunked=true
    fi
    
    # 如果不是分块传输，则设置Content-Length
    if ! $is_chunked; then
        if [[ -n "$HTTP_body" ]]; then
            HTTP_body_length="$(printf '%s' "$HTTP_body" | wc -c)"
            HTTP_heads["Content-Length"]="$HTTP_body_length"
        elif [[ -z "${HTTP_heads["Content-Length"]}" ]]; then
            # 没有消息体且没有Content-Length，显式设置为0
            HTTP_heads["Content-Length"]="0"
        fi
    fi
    
    # 输出所有HTTP头部（跳过内部使用的字段）
    for HTTP_head_key in "${!HTTP_heads[@]}"; do
        case "${HTTP_head_key}" in
            method|path|http_version|http_code|http_text)
                # 跳过起始行相关的内部字段
                continue
                ;;
            *)
                # 输出头部字段（保持原始大小写）
                # 注意：HTTP_heads数组的键名是小写的，但原始头部可能有不同大小写
                # 这里我们使用原样输出，用户传入时需确保键名正确
                local header_name="$HTTP_head_key"
                # 将首字母大写，后续字母保持原样（简单的格式化）
                if [[ "$header_name" =~ ^[a-z] ]]; then
                    header_name="${header_name^}"
                    # 处理连字符后的字母也大写（如content-type -> Content-Type）
                    if [[ "$header_name" =~ -([a-z]) ]]; then
                        local match="${BASH_REMATCH[1]}"
                        header_name="${header_name//-$match/-${match^}}"
                    fi
                fi
                printf "%s: %s\r\n" "$header_name" "${HTTP_heads[$HTTP_head_key]}"
                ;;
        esac
    done
    
    # 输出空行分隔头部和消息体
    printf "\r\n"
    
    # 输出消息体
    if $is_chunked; then
        # 分块传输编码
        if [[ -n "$HTTP_body" ]]; then
            # 将消息体分成块输出
            local chunk_size=4096  # 每块大小
            local offset=0
            local total_length="${#HTTP_body}"
            
            while [[ $offset -lt $total_length ]]; do
                # 计算本次读取的长度
                local read_length=$(( chunk_size < total_length - offset ? chunk_size : total_length - offset ))
                # 提取块数据
                local chunk_data="${HTTP_body:$offset:$read_length}"
                # 输出块大小（十六进制）
                printf "%x\r\n" "${#chunk_data}"
                # 输出块数据
                printf "%s" "$chunk_data"
                printf "\r\n"
                
                offset=$((offset + read_length))
            done
        fi
        # 输出结束块（0字节块）
        printf "0\r\n"
        printf "\r\n"
    elif [[ -n "$HTTP_body" ]]; then
        # 普通消息体输出
        printf "%s" "$HTTP_body"
    fi
    # 注意：当没有消息体且不是分块传输时，不输出任何内容
}



HTTP_do_GET() {
    # 处理GET请求
    # GET方法用于请求指定资源，只用于数据获取
    # 请求参数通常附加在URL后面
    # 对同一URL的多次GET请求应返回相同结果
    :
}

HTTP_do_POST() {
    # 处理POST请求
    # POST方法用于向指定资源提交数据
    # 数据包含在请求体中
    # 通常用于创建新资源或提交表单
    # 多次POST请求可能产生不同结果（如重复提交）
    :
}

HTTP_do_PUT() {
    # 处理PUT请求
    # PUT方法用于创建或替换目标资源
    # 如果资源不存在则创建，存在则完全替换
    # 需要提供完整的资源表示
    :
}

HTTP_do_DELETE() {
    # 处理DELETE请求
    # DELETE方法用于删除指定资源
    # 成功响应通常返回204 No Content
    :
}

HTTP_do_HEAD() {
    # 处理HEAD请求
    # HEAD方法与GET相同，但不返回消息体
    # 只返回响应头，用于获取资源的元信息
    :
}

HTTP_do_OPTIONS() {
    # 处理OPTIONS请求
    # OPTIONS方法用于获取目标资源支持的通信选项
    # 响应中包含Allow头，列出支持的HTTP方法
    # 也可用于CORS预检请求
    :
}

HTTP_do_PATCH() {
    # 处理PATCH请求
    # PATCH方法用于对资源进行部分修改
    # 与PUT不同，PATCH只发送要修改的部分
    # 用于资源的部分更新
    :
}

HTTP_do_TRACE() {
    # 处理TRACE请求
    # TRACE方法用于诊断，回显服务器收到的请求
    # 用于测试或诊断，通常不用于生产环境
    :
}

HTTP_do_CONNECT() {
    # 处理CONNECT请求
    # CONNECT方法用于建立到目标资源的隧道
    # 通常用于SSL/TLS隧道的建立
    # 用于通过代理服务器建立安全连接
    :
}
print_assoc_array() {
    if [[ $# -ne 1 ]]; then
        echo "用法: print_assoc_array 关联数组名" >&2
        return 1
    fi
    
    # 使用local -n创建数组引用
    local -n array_ref="$1"
    
    if [[ ${#array_ref[@]} -eq 0 ]]; then
        echo "关联数组 '$1' 为空" >&2
        return 0
    fi
    
    echo "=== 关联数组: $1 ===" >&2
    echo "数组大小: ${#array_ref[@]}" >&2
    echo "所有键值对:" >&2
    
    local key
    for key in "${!array_ref[@]}"; do
        # 处理空值情况
        if [[ -z "${array_ref[$key]}" ]]; then
            echo "  '$key': (空值或空字符串)" >&2
        else
            echo "  '$key': '${array_ref[$key]}'" >&2
        fi
    done
    echo "=== 结束 ===" >&2
}