#!/usr/bin/env bash

source ./lib/log.sh
source ./lib/http.sh
source ./lib/flock.sh
if [[ ! $inside_ncat == true ]]; then
	export inside_ncat=true

	# 检查是否提供了端口参数
	TOKEN_FILE="$1"
	PORT="${2:-3699}"
	if ! [[ -f "$TOKEN_FILE" ]]; then
		echo "用法: $0 <token_file> [port]" >&2
		exit 1
	fi
	mkdir -p "/dev/shm/siliconflow_$PORT"
	cp "$TOKEN_FILE" "/dev/shm/siliconflow_$PORT/siliconflow_tokens.txt"
	USING_TOKEN_FILE="/dev/shm/siliconflow_$PORT/using_tokens.txt"
	TOKEN_FILE="/dev/shm/siliconflow_$PORT/siliconflow_tokens.txt"
	INDEX_FILE="/dev/shm/siliconflow_$PORT/index"
	export TOKEN_FILE
	export INDEX_FILE
	export USING_TOKEN_FILE
	echo "启动WebSocket服务器在端口 $PORT"
	echo "按Ctrl+C停止服务器"

	# 使用ncat监听指定端口
	# -k 保持监听（接受多个连接）
	# -l 监听模式
	# --sh-exec 为每个连接执行此脚本
	ncat -v -k -l "$PORT" --sh-exec "$0"
	exit $?
fi
# 处理传入的连接
# HTTP_phrase_http_body(){
#     # 标准输入读取HTTP消息体
#     local -n HTTP_heads="$1" || {
#         echo "关联数组heads不存在" >&2
#         return 1
#     }
# ......
HTTP_do_POST() {
	# local -n HTTP_heads="$1"
	log.trace "当前PID $$ 处理POST请求" >&2
	#print_assoc_array HTTP_heads >&2
	#printf '%s\n' "$HTTP_body" >&2
	rebuild_http_heads
	# exec 3<>/dev/tcp/api.siliconflow.cn/80
	exec 3<>/dev/tcp/localhost/8080
	# 发送HTTP请求
	# HTTP_send(){
	# 标准输入输出
	# local -n HTTP_heads="$1" || {
	#     echo "关联数组heads不存在" >&2
	#     return 1
	# }
	# local -n HTTP_body="$2"
	HTTP_send siliconflow_heads siliconflow_body >&3 # 发送到服务器
	log.trace "已发送HTTP请求到 SiliconFlow 服务器" >&2
	# 读取HTTP响应
	{
		HTTP_phrase_http_heads siliconflow_response_heads
		HTTP_phrase_http_body siliconflow_response_heads siliconflow_response_body
		exec 3>&- # 关闭连接
	} <&3
	log.trace "已接收SiliconFlow服务器响应" >&2
	# 构建HTTP响应
	HTTP_send siliconflow_response_heads siliconflow_response_body # 发送回客户端
	log.trace "已发送HTTP响应回客户端" >&2
	if [[ "${siliconflow_response_heads[http_code]}" == "429" ]]; then
		log.warn "收到429响应，更新Token索引" >&2
		update_siliconflow_token_index
	fi
	return $?
}

rebuild_http_heads() {
	siliconflow_heads["host"]="api.siliconflow.cn"
	siliconflow_heads["connection"]="close"
	siliconflow_heads["authorization"]="Bearer $(get_siliconflow_token)"
}

get_siliconflow_token() {
	mapfile -t tokens <"$TOKEN_FILE"
	if [[ ${#tokens[@]} -eq 0 ]]; then
		log.error "没有可用的Token，请检查 $TOKEN_FILE 文件。" >&2
		echo ""
		return 1
	fi 
	local index=0
	if [[ -f "$INDEX_FILE" ]]; then
		index=$(<"$INDEX_FILE")
	fi
	local token="${tokens[$index]}"
	# 更新索引不在这里实现，避免并发问题
	echo "$token"
	return 0
}
# acquire_lock() {
#     local lock_file="${1:-/tmp/process.lock}"
#     local lock_content="${2:-$$}"
#     local timeout="${3:-300}"  # 默认超时300秒（5分钟）
#     local interval="${4:-1}" # 默认检查间隔1秒
update_siliconflow_token_index() {
	acquire_lock "${INDEX_FILE}.lock" $$ 10 1 || {
		log.error "无法获取索引锁，跳过更新Token索引" >&2
		return 1
	}
	local index=0
	if [[ -f "${INDEX_FILE}" ]]; then
		index=$(<"${INDEX_FILE}")
	fi
	local total_tokens
	mapfile -t tokens <"$TOKEN_FILE"
	total_tokens=${#tokens[@]}
	if [[ $total_tokens -eq 0 ]]; then
		log.error "没有可用的Token，无法更新索引" >&2
		release_lock "${INDEX_FILE}.lock" $$
		return 1
	fi
	index=$(( (index + 1) % total_tokens ))
	echo "$index" >"${INDEX_FILE}"
	release_lock "${INDEX_FILE}.lock" $$
	log.debug "更新Token索引到 $index" >&2
	return 0
}
# ncat提供的链接标准输入输出
declare -A siliconflow_heads
declare -A siliconflow_response_heads
siliconflow_body=""
siliconflow_response_body=""
HTTP_phrase_http_heads siliconflow_heads
HTTP_phrase_http_body siliconflow_heads siliconflow_body
log.info "连接关闭，等待下一个连接..." >&2
