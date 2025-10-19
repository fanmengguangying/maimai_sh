#!/usr/bin/env bash
HOST=example.com
PORT=443

# 1. Bash 裸 TCP 连 443 → fd 5
exec 5<>/dev/tcp/$HOST/$PORT

# 2. 让 openssl 在 fd 5 上做 TLS，明文端用管道暴露给脚本
mkfifo plain.in plain.out
openssl s_client -quiet -connect $HOST:$PORT -servername $HOST \
        <plain.in >plain.out 2>/dev/null &

# 3. 把管道绑到永久 fd，方便后续读写
exec 6>plain.in   # 写明文
exec 7<plain.out  # 读明文
rm -f plain.in plain.out   # 删文件不影响已打开的 fd

# 4. 发 HTTPS 请求
cat >&6 <<EOF
GET / HTTP/1.1
Host: $HOST
Connection: close

EOF

# 5. 读明文响应
cat <&7

# 6. 收尾
exec 6>&- 7<&- 5<&-
