#!/bin/bash

TODO() {
    # 获取调用位置的栈帧信息（调用文件、行号、函数名）
    local stackFrame=$(caller 0)
    # 提取行号字段（第二个字段）
    local lineNumber=$(awk '{print $1}' <<<"${stackFrame}")
    log.error "[TODO] \"${1}\"：未实现的功能在: 行号 ${lineNumber}"
    log.info "ԅ(¯﹃¯ԅ)没写完呢喵(*/ω＼*)"
}

# network_test 函数说明
# 功能：自动检测并设置 GitHub/Docker 代理服务器
#
# 参数：
#   $1 [必填] - 代理类型
#     - "Github"：GitHub 加速代理
#     - "Docker"：Docker 镜像代理
#
# 依赖变量：
#   $proxy_num [可选] - 手动指定代理编号
#     - 默认自动检测最快代理
#     - 0 表示不使用代理
#     - 1~N 指定代理数组索引
#
# 输出变量：
#   $target_proxy - 最终选择的代理地址
#
# 工作流程：
# 1. GitHub 代理检测：
#    - 测试 https://raw.githubusercontent.com 可达性
#    - 要求 HTTP 状态码 200
# 2. Docker 代理检测：
#    - 测试镜像站首页可达性
#    - 接受 HTTP 200 或 301 状态码
#
# 注意事项：
# 1. 代理列表内置在函数中（GitHub 5个/Docker 7个）
# 2. 自动检测时遍历所有代理直到找到可用节点
# 3. 所有代理均不可用时脚本将终止运行
# 4. 需要依赖外部 log() 函数记录日志
#
# 使用示例：
#   network_test "Github"  # 自动选择 GitHub 代理
#   proxy_num=3 network_test "Docker"  # 强制使用第3个Docker代理
network_test() {
    local parm1=${1}
    local found=0
    target_proxy=""
    proxy_num=${proxy_num:-9}

    if [ "${parm1}" == "Github" ]; then
        proxy_arr=("https://ghfast.top" "https://ghp.ci" "https://gh.wuliya.xin" "https://gh-proxy.com" "https://x.haod.me")
        # proxy_arr=("https://gitclone.com" "https://ghp.ci" "https://gh.wuliya.xin" "https://gh-proxy.com" "https://x.haod.me")
        check_url="https://raw.githubusercontent.com/NapNeko/NapCatQQ/main/package.json"
    elif [ "${parm1}" == "Docker" ]; then
        proxy_arr=("docker.rainbond.cc" "docker.1panel.dev" "dockerpull.com" "dockerproxy.cn" "docker.agsvpt.work" "hub.021212.xyz:8080" "docker.registry.cyou")
        check_url=""
    fi

    if [ -n "${proxy_num}" ] && [ "${proxy_num}" -ge 1 ] && [ "${proxy_num}" -le ${#proxy_arr[@]} ]; then
        log.info "手动指定代理: ${proxy_arr[${proxy_num} - 1]}"
        target_proxy="${proxy_arr[${proxy_num} - 1]}"
    else
        if [ "${proxy_num}" -ne 0 ]; then
            log.info "proxy 未指定或超出范围, 正在检查${parm1}代理可用性..."
            for proxy in "${proxy_arr[@]}"; do
                status=$(curl -o /dev/null -s -w "%{http_code}" "${proxy}/${check_url}")
                if [ "${parm1}" == "Github" ] && [ ${status} -eq 200 ]; then
                    found=1
                    target_proxy="${proxy}"
                    log.info "将使用${parm1}代理: ${proxy}"
                    break
                elif [ "${parm1}" == "Docker" ] && { [ ${status} -eq 200 ] || [ ${status} -eq 301 ]; }; then
                    found=1
                    target_proxy="${proxy}"
                    log.info "将使用${parm1}代理: ${proxy}"
                    break
                fi
            done
            if [ ${found} -eq 0 ]; then
                log.error "无法连接到${parm1}, 请检查网络。"
                exit 1
            fi
        else
            log.info "代理已关闭, 将直接连接${parm1}..."
        fi
    fi
}

New-NoneBotPlugin() {
    #现在好像没用了
    #以后做版本管理的时候要用
    local PluginName="$1"
    local WorkDir="${2:-$(pwd)}" # 默认当前目录

    local ProjectDir="${WorkDir}/${PluginName}"

    # 创建目录
    mkdir -p "${ProjectDir}/src/plugins" || {
        log.error "错误：无法创建目录"
        return 1
    }

    # 生成 pyproject.toml
    cat >"${ProjectDir}/pyproject.toml" <<EOF
[project]
name = "${PluginName}"
version = "0.1.0"
description = "${PluginName}"
readme = "README.md"
requires-python = ">=3.9, <4.0"

[tool.nonebot]
adapters = [
    { name = "OneBot V11", module_name = "nonebot.adapters.onebot.v11" }
]
plugins = []
plugin_dirs = ["src/plugins"]
builtin_plugins = []
EOF

    # 生成 .env 文件
    cat >"${ProjectDir}/.env" <<'EOF'
ENVIRONMENT=dev
DRIVER=~fastapi+~websockets
EOF

    cat >"${ProjectDir}/.env.dev" <<'EOF'
LOG_LEVEL=DEBUG
EOF

    touch "${ProjectDir}/.env.prod"
    log.info "[SUCCESS] 插件 '${PluginName}' 已创建于: ${ProjectDir}"
    log.info "[NOTE] 安装与src目录，使用fastapi+websockets"
}

# 返回 0 表示可以继续；返回 1 表示必须 root 却拿不到，直接退出
check_root() {
  # 0. 已经 root？直接过
  (( EUID == 0 )) && return 0

  # 1. 连 sudo 命令都没有 → 非 Linux 或极度裁剪环境（Termux、MT、recovery 等）
  if ! command -v sudo >/dev/null 2>&1; then
    # 这些环境本来就不需要 root，或者根本装不了 sudo
    case ${envType:-unknown} in
      termux|mt) return 0 ;;
      *) log.error "ERROR: sudo not found and not running as root."; exit 1 ;;
    esac
  fi

  # 2. sudo 存在，但能不能免密拿到 root？
  local sudo_test
  sudo_test=$(sudo -n true 2>&1)
  if (( $? == 0 )); then
    # 2-a. 可以免密 root → 若当前脚本还没被 sudo 重跑，就自动重跑一次
    if [[ ${IS_SOURCE:-} != "true" ]] && [[ ${envType:-unknown} == "unix" ]]; then
      exec sudo -E bash "$0" "$@"   # -E 保留当前环境变量
    fi
    return 0
  fi

  # 3. sudo 存在但拿不到 root
  case ${envType:-unknown} in
    unix)
      log.error "ERROR: sudo available but root privilege denied (check /etc/sudoers)."
      exit 1
      ;;
    termux|mt|unknown)
      log.warn "WARN: no root available in ${envType}. Continue without privilege."
      return 0
      ;;
  esac
}










# napcat的启动脚本生成。可恶啊！居然移除了控制脚本！
__NAPCAT__() {
    cat >"/usr/local/bin/napcat" <<'NAPCAT'
#!/bin/bash

MAGENTA='\033[0;1;35;95m'
RED='\033[0;1;31;91m'
YELLOW='\033[0;1;33;93m'
GREEN='\033[0;1;32;92m'
CYAN='\033[0;1;36;96m'
BLUE='\033[0;1;34;94m'
NC='\033[0m'

QQ=$2
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
CMD="sudo /usr/bin/xvfb-run -a qq --no-sandbox -q ${QQ}"
PID_FILE="/var/run/napcat_${QQ}.pid"
LOG_FILE="/var/log/napcat_${QQ}.log"

start() {
    if [ -z "${QQ}" ]; then
        echo -e "${RED}请传入QQ号,如${NC}${GREEN} $0 start 3116556127${NC}"
        exit 1
    fi
    if [ -f "${PID_FILE}" ] && sudo ps aux | grep -v "grep" | grep -q "qq --no-sandbox -q ${QQ}" > /dev/null 2>&1; then
        echo -e "${RED}服务已运行 (PID: $(cat "${PID_FILE}"))${NC}"
    else
        touch "${PID_FILE}"
        cp -f /opt/QQ/resources/app/app_launcher/napcat/config/napcat.json /opt/QQ/resources/app/app_launcher/napcat/config/napcat_${QQ}.json
        echo -e "${MAGENTA}启动 napcat 服务中 QQ: ${QQ}...${NC}"
        exec ${CMD} >> "${LOG_FILE}" 2>&1 &
        echo $! > "${PID_FILE}"
        echo -e "${GREEN}服务已启动 (PID: $(cat "${PID_FILE}"))${NC}"
    fi
}

stop() {
    if [ -z "${QQ}" ]; then
        pid_files=($(sudo find /var/run/ -name 'napcat_*.pid'))
        for pid_file in "${pid_files[@]}"; do
            echo -e "${MAGENTA}停止 napcat 服务 (PID: $(cat "${pid_file}"))...${NC}"
            QQ=$(basename "${pid_file}" .pid | sed 's/napcat_//')
            sudo pkill -f "qq --no-sandbox -q ${QQ}" && sudo rm -f "${pid_file}"
        done
        echo -e "${RED}所有服务已停止${NC}"
        return 0
    fi

    if [ ! -f "${PID_FILE}" ] || ! sudo ps aux | grep -v "grep" | grep -q "qq --no-sandbox -q ${QQ}" > /dev/null 2>&1; then
        echo -e "${GREEN}服务未运行${NC}"
        sudo rm -f "${PID_FILE}" && sudo rm -f "${LOG_FILE}"
    else
        echo -e "${MAGENTA}停止 napcat 服务中 QQ: ${QQ}...${NC}"
        sudo pkill -f "qq --no-sandbox -q ${QQ}" && sudo rm -f "${PID_FILE}" && sudo rm -f "${LOG_FILE}"
        echo -e "${RED}服务已停止${NC}"
    fi
}

restart() {
    if [ -z "${QQ}" ]; then
        echo -e "${RED}请传入QQ号,如${NC}${GREEN} $0 restart 3116556127${NC}"
        exit 1
    fi

    echo -e "${MAGENTA}重启 napcat 服务中 QQ: ${QQ}...${NC}"
    stop
    sleep 2
    start
}

status() {
    if [ -z "${QQ}" ]; then
        echo -e "${YELLOW}当前正在运行的服务有:${NC}"
        for pid_file in /var/run/napcat_*.pid; do
            if [ -f "${pid_file}" ]; then
                QQ=$(basename "${pid_file}" .pid | sed 's/napcat_//')
                if sudo ps aux | grep -v "grep" | grep -q "qq --no-sandbox -q ${QQ}" > /dev/null 2>&1; then
                    echo -e "${GREEN}${QQ} 运行中 (PID: $(cat "${pid_file}"))${NC}"
                else
                    echo -e "${RED}${QQ} 未运行${NC}"
                fi
            fi
        done
    else
        if [ -f "${PID_FILE}" ] && sudo ps aux | grep -v "grep" | grep -q "qq --no-sandbox -q ${QQ}" > /dev/null 2>&1; then
            echo -e "${GREEN}服务运行中 QQ: ${QQ} (PID: $(cat "${PID_FILE}"))${NC}"
        else
            echo -e "${RED}服务未运行 QQ: ${QQ}${NC}"
        fi
    fi
}

log() {
    if [ -z "${QQ}" ]; then
        echo -e "${RED}请传入QQ号,如${NC}${GREEN} $0 log 3116556127${NC}"
        exit 1
    fi

    if [ -f "${LOG_FILE}" ]; then
        tail -n 50 "${LOG_FILE}"
        tail -f "${LOG_FILE}"
    else
        echo -e "${RED}日志文件不存在: ${LOG_FILE}${NC}"
    fi
}

startup() {
    if [ -z "${QQ}" ]; then
        echo -e "${RED}请传入QQ号,如${NC}${GREEN} $0 startup 3116556127${NC}"
        exit 1
    fi

    if [ -f "/etc/init.d/nc_${QQ}" ]; then
        echo -e "${GREEN}已存在QQ${QQ}的开机自启动服务${NC}"
        exit 1
    fi

cat <<EOF > "/etc/init.d/nc_${QQ}"
#!/bin/bash
### BEGIN INIT INFO
# Provides:          nc_${QQ}
# Required-Start:    \${network} \${remote_fs} \${syslog}
# Required-Stop:     \${network} \${remote_fs} \${syslog}
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Manage nc_${QQ} service
# Description:       Start of nc_${QQ} service.
### END INIT INFO

PATH=/usr/local/sbin:/usr/local/bin:/sbin:bin:/usr/sbin:/usr/bin
CMD="sudo /usr/bin/xvfb-run -a qq --no-sandbox -q ${QQ}"
PID_FILE="/var/run/napcat_${QQ}.pid"
LOG_FILE="/var/log/napcat_${QQ}.log"

start() {
    touch "\${PID_FILE}"
    exec \${CMD} >> "\${LOG_FILE}" 2>&1 &
    echo \$! > "\${PID_FILE}"
    echo "nc sucess"
}

case "\$1" in
    start)
        start
        ;;
    *)
        exit 1
        ;;
esac

exit 0
EOF

    sudo chmod +x /etc/init.d/nc_${QQ}
    sudo update-rc.d nc_${QQ} defaults
    echo -e "${MAGENTA}已添加QQ ${QQ}的开机自启动服务${NC}"
}

startdown() {
    if [ -z "${QQ}" ]; then
        echo -e "${RED}请传入QQ号,如${NC}${GREEN} $0 startdown 3116556127${NC}"
        exit 1
    fi

    if [ ! -f "/etc/init.d/nc_${QQ}" ]; then
        echo -e "${RED}不存在QQ ${QQ}的开机自启动服务${NC}"
        exit 1
    fi

    sudo update-rc.d nc_${QQ} remove
    sudo rm -f /etc/init.d/nc_${QQ}
    echo -e "${MAGENTA}已取消QQ ${QQ}的开机自启动服务${NC}"
}

update() {
    stop
    curl -sSL https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.sh | sudo bash -s -- --docker n --cli y
}

rebuild() {
    stop
    curl -sSL https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.sh | sudo bash -s -- --docker n --cli y --force
}

remove() {
    stop
    if command -v apt &> /dev/null; then
        sudo apt remove linuxqq -y
    elif command -v yum &> /dev/null; then
        sudo yum remove linuxqq -y
    fi

    if command -v dpkg &> /dev/null; then
        sudo dpkg -P linuxqq
    elif command -v rpm &> /dev/null; then
        sudo rpm -e --nodeps linuxqq
    fi

    sudo rm -rf /opt/QQ
    sudo rm -rf /root/.config/QQ
    sudo rm -f /usr/local/bin/napcat
    echo "卸载完成"
    echo -e "${MAGENTA}江${RED}湖${GREEN}不${CYAN}散，${MAGENTA}有${RED}缘${GREEN}再${CYAN}见。${NC}"
}

help() {
    clear
    echo -e " ${MAGENTA}┌${RED}──${YELLOW}──${GREEN}──${CYAN}──${BLUE}──${MAGENTA}──${RED}──${YELLOW}──${GREEN}──${CYAN}──${BLUE}──${MAGENTA}──${RED}──${YELLOW}──${GREEN}──${CYAN}──${BLUE}──${MAGENTA}──${RED}──${YELLOW}──${GREEN}──${CYAN}──${BLUE}──${MAGENTA}──${RED}──${YELLOW}──${GREEN}──${CYAN}──${BLUE}──${MAGENTA}──${RED}──${YELLOW}──${GREEN}──${CYAN}──${BLUE}──${MAGENTA}${RED}─┐${NC}"
    echo -e " ${MAGENTA}│${RED}  ${YELLOW}  ${GREEN}  ${CYAN}  ${BLUE}  ${MAGENTA}  ${RED}  ${YELLOW}  ${GREEN}  ${CYAN}  ${BLUE}  ${MAGENTA}  ${RED}  ${YELLOW}  ${GREEN}  ${CYAN}  ${BLUE}  ${MAGENTA}  ${RED}  ${YELLOW}  ${GREEN}  ${CYAN}  ${BLUE}  ${MAGENTA}  ${RED}  ${YELLOW}  ${GREEN}  ${CYAN}  ${BLUE}  ${MAGENTA}  ${RED}  ${YELLOW}  ${GREEN}  ${CYAN}  ${BLUE}  ${MAGENTA} ${RED}│${NC}"
    echo -e " ${RED}│${YELLOW}██${GREEN}█╗${CYAN}  ${BLUE} █${MAGENTA}█╗${RED}  ${YELLOW}  ${GREEN} █${CYAN}██${BLUE}██${MAGENTA}╗ ${RED}  ${YELLOW}  ${GREEN}██${CYAN}██${BLUE}██${MAGENTA}╗ ${RED}  ${YELLOW}  ${GREEN} █${CYAN}██${BLUE}██${MAGENTA}█╗${RED}  ${YELLOW}  ${GREEN} █${CYAN}██${BLUE}██${MAGENTA}╗ ${RED}  ${YELLOW}  ${GREEN}██${CYAN}██${BLUE}██${MAGENTA}██${RED}╗${YELLOW}│${NC}"
    echo -e " ${YELLOW}│${GREEN}██${CYAN}██${BLUE}╗ ${MAGENTA} █${RED}█║${YELLOW}  ${GREEN}  ${CYAN}██${BLUE}╔═${MAGENTA}═█${RED}█╗${YELLOW}  ${GREEN}  ${CYAN}██${BLUE}╔═${MAGENTA}═█${RED}█╗${YELLOW}  ${GREEN}  ${CYAN}██${BLUE}╔═${MAGENTA}══${RED}═╝${YELLOW}  ${GREEN}  ${CYAN}██${BLUE}╔═${MAGENTA}═█${RED}█╗${YELLOW}  ${GREEN}  ${CYAN}╚═${BLUE}═█${MAGENTA}█╔${RED}══${YELLOW}╝${YELLOW}│${NC}"
    echo -e " ${GREEN}│${CYAN}██${BLUE}╔█${MAGENTA}█╗${RED} █${YELLOW}█║${GREEN}  ${CYAN}  ${BLUE}██${MAGENTA}██${RED}██${YELLOW}█║${GREEN}  ${CYAN}  ${BLUE}██${MAGENTA}██${RED}██${YELLOW}╔╝${GREEN}  ${CYAN}  ${BLUE}██${MAGENTA}║ ${RED}  ${YELLOW}  ${GREEN}  ${CYAN}  ${BLUE}██${MAGENTA}██${RED}██${YELLOW}█║${GREEN}  ${CYAN}  ${BLUE}  ${MAGENTA} █${RED}█║${YELLOW}  ${GREEN} ${GREEN}│${NC}"
    echo -e " ${CYAN}│${BLUE}██${MAGENTA}║╚${RED}██${YELLOW}╗█${GREEN}█║${CYAN}  ${BLUE}  ${MAGENTA}██${RED}╔═${YELLOW}═█${GREEN}█║${CYAN}  ${BLUE}  ${MAGENTA}██${RED}╔═${YELLOW}══${GREEN}╝ ${CYAN}  ${BLUE}  ${MAGENTA}██${RED}║ ${YELLOW}  ${GREEN}  ${CYAN}  ${BLUE}  ${MAGENTA}██${RED}╔═${YELLOW}═█${GREEN}█║${CYAN}  ${BLUE}  ${MAGENTA}  ${RED} █${YELLOW}█║${GREEN}  ${CYAN} ${CYAN}│${NC}"
    echo -e " ${BLUE}│${MAGENTA}██${RED}║ ${YELLOW}╚█${GREEN}██${CYAN}█║${BLUE}  ${MAGENTA}  ${RED}██${YELLOW}║ ${GREEN} █${CYAN}█║${BLUE}  ${MAGENTA}  ${RED}██${YELLOW}║ ${GREEN}  ${CYAN}  ${BLUE}  ${MAGENTA}  ${RED}╚█${YELLOW}██${GREEN}██${CYAN}█╗${BLUE}  ${MAGENTA}  ${RED}██${YELLOW}║ ${GREEN} █${CYAN}█║${BLUE}  ${MAGENTA}  ${RED}  ${YELLOW} █${GREEN}█║${CYAN}  ${BLUE} ${BLUE}│${NC}"
    echo -e " ${MAGENTA}│${RED}╚═${YELLOW}╝ ${GREEN} ╚${CYAN}══${BLUE}═╝${MAGENTA}  ${RED}  ${YELLOW}╚═${GREEN}╝ ${CYAN} ╚${BLUE}═╝${MAGENTA}  ${RED}  ${YELLOW}╚═${GREEN}╝ ${CYAN}  ${BLUE}  ${MAGENTA}  ${RED}  ${YELLOW} ╚${GREEN}══${CYAN}══${BLUE}═╝${MAGENTA}  ${RED}  ${YELLOW}╚═${GREEN}╝ ${CYAN} ╚${BLUE}═╝${MAGENTA}  ${RED}  ${YELLOW}  ${GREEN} ╚${CYAN}═╝${BLUE}  ${MAGENTA} ${MAGENTA}│${NC}"
    echo -e " ${RED}└${YELLOW}──${GREEN}──${CYAN}──${BLUE}──${MAGENTA}──${RED}──${YELLOW}──${GREEN}──${CYAN}──${BLUE}──${MAGENTA}──${RED}──${YELLOW}──${GREEN}──${CYAN}──${BLUE}──${MAGENTA}──${RED}──${YELLOW}──${GREEN}──${CYAN}──${BLUE}──${MAGENTA}──${RED}──${YELLOW}──${GREEN}──${CYAN}──${BLUE}──${MAGENTA}──${RED}──${YELLOW}──${GREEN}──${CYAN}──${BLUE}──${MAGENTA}──${RED}${YELLOW}─┘${NC}"
    echo
    echo -e "${MAGENTA}napcat 控制脚本${NC}"
    echo
    echo -e "${MAGENTA}使用方法: ${NC}"
    echo -e "${CYAN}  napcat {start|stop|restart|status|log|startup|startdown} QQ${NC}"
    echo -e "${CYAN}  napcat {status|update|rebuild|remove|help|oldhelp}${NC}"
    echo
    echo -e " ${GREEN}   napcat start {QQ}                     ${MAGENTA}启动对应QQ号的NAPCAT${NC}"
    echo -e " ${GREEN}   napcat stop {QQ}[可选]                ${MAGENTA}停止所有[对应QQ号]的NAPCAT及DLC${NC}"
    echo -e " ${GREEN}   napcat restart {QQ}                   ${MAGENTA}重启对应QQ号的NAPCAT${NC}"
    echo -e " ${GREEN}   napcat status {QQ}[可选]              ${MAGENTA}查看所有[对应QQ号]的NAPCAT${NC}"
    echo -e " ${GREEN}   napcat log {QQ}                       ${MAGENTA}查看对应QQ号的NAPCAT日志${NC}"
    echo -e " ${GREEN}   napcat startup {QQ}                   ${MAGENTA}添加开机自启动对应QQ号的NAPCAT及DLC${NC}"
    echo -e " ${GREEN}   napcat startdown {QQ}                 ${MAGENTA}取消开机自启动对应QQ号的NAPCAT及DLC${NC}"
    echo -e " ${GREEN}   napcat update                         ${MAGENTA}更新 NAPCAT及QQ${NC}"
    echo -e " ${GREEN}   napcat rebuild                        ${MAGENTA}重建 NAPCAT及QQ${NC}"
    echo -e " ${GREEN}   napcat remove                         ${MAGENTA}卸载 NAPCAT及QQ${NC}"
    echo -e " ${GREEN}   napcat help                           ${MAGENTA}查看此帮助${NC}"
    echo -e " ${GREEN}   napcat oldhelp                        ${MAGENTA}查看旧方法(若此脚本不生效)${NC}"
}

oldhelp() {
    echo -e "输入${GREEN} xvfb-run -a qq --no-sandbox ${NC}命令启动。"
    echo -e "保持后台运行 请输入${GREEN} screen -dmS napcat bash -c \"xvfb-run -a qq --no-sandbox\" ${NC}"
    echo -e "后台快速登录 请输入${GREEN} screen -dmS napcat bash -c \"xvfb-run -a qq --no-sandbox -q QQ号码\" ${NC}"
    echo -e "注意, 您可以随时使用${GREEN} screen -r napcat ${NC}来进入后台进程并使用${GREEN} ctrl + a + d ${NC}离开(离开不会关闭后台进程)。"
    echo -e "停止后台运行 请输入${GREEN} screen -S napcat -X quit${NC}"
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    log)
        log
        ;;
    startup)
        startup
        ;;
    startdown)
        startdown
        ;;
    update)
        update
        ;;
    rebuild)
        rebuild
        ;;
    remove)
        remove
        ;;
    help)
        help
        exit 0
        ;;
    oldhelp)
        oldhelp
        exit 0
        ;;
    *)
        help
        exit 1
        ;;
esac

exit 0
NAPCAT
    chmod +x "/usr/local/bin/napcat"
    log.success "napcat控制脚本不存在，已生成"
}


if [[ "$0" == "${BASH_SOURCE}" ]]; then
    exit 1
fi