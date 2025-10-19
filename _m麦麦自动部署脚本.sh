#!/bin/bash
# <#
# .SYNOPSIS
#     小白友好的一键脚本带简易 UI
# #>
# shellcheck disable=SC1111
# shellcheck disable=SC2086
# shellcheck disable=SC2046
# shellcheck disable=SC2155
# shellcheck disable=SC2015
# shellcheck disable=SC1091
# shellcheck disable=SC1087
# shellcheck disable=SC2128
# shellcheck disable=SC2162
# shellcheck disable=SC2004

# shellcheck source="${ConfigLoaded}"
# shellcheck source="display.sh"
###

for dep_sh in $(ls lib);do
    source $dep_sh || {
        echo "${dep_sh}加载失败！"
        exit 1
    }
done

Initialize-ScriptEnvironment() {
    TARGET_FOLDER="/opt/QQ/resources/app/app_launcher"        # napcat安装目录
    TARGETCONFIG="${MaiM_HOME}/MaiBot/config/bot_config.toml" # 麦麦配置文件
    WORKPATH="./tmp"                                          #
    # 是否自动推荐
    AUTO_RECOMMANDED=${AUTO_RECOMMANDED:-}
    # 是否换源
    AUTO_SOURCES=${AUTO_SOURCES:-}
    # 是否自动处理错误
    AUTO_FIX=${AUTO_FIX:-}
    # 是否在python版本不满足时编译合适版本的python
    AUTO_COMPILE_PYTHON=${AUTO_COMPILE_PYTHON:-}
    # 是否自动安装依赖
    AUTO_INSTALL_DEPENDENCIES=${AUTO_INSTALL_DEPENDENCIES:-}
    # 是否自动安装mongodb
    AUTO_INSTALL_MONGODB=${AUTO_INSTALL_MONGODB:-}
    # 是否自动安装napcat
    AUTO_INSTALL_NAPCAT=${AUTO_INSTALL_NAPCAT:-}
    # 是否自动配置麦麦
    AUTO_CONFIG_MAIMAI=${AUTO_CONFIG_MAIMAI:-}
    # 是否自动安装proot
    AUTO_INSTALL_PROOT=${AUTO_INSTALL_PROOT:-}
    # 是否隔离数据库
    ISOLATE_DATABASE=${ISOLATE_DATABASE:-}
    # 是否交互
    INTERACTIVE=${INTERACTIVE:-}
    # 是否安装在系统中安装uv
    INSTALL_UV=${INSTALL_UV:-}
    # 是否更换pip源
    AUTO_PIP_SOURCE=${AUTO_PIP_SOURCE:-}
    # 是否自动GitHub代理
    AUTO_PROXY=${AUTO_PROXY:-}
    # 是否使用默认推荐的麦麦版本
    AUTO_MAIMAI_VERSION=${AUTO_MAIMAI_VERSION:-}
    self="$(basename ${BASH_SOURCE[-1]})" # 脚本自己的名字
    if [[ "${self}" == "bashdb" ]]; then
        BASHDB="true"
        self="$(basename ${BASH_SOURCE[-2]})" #脚本自己的名字
    elif [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
        PWD0="$(dirname $(realpath $0))" #脚本最初始的位置
    else
        IS_SOURCE="true"
        PWD0="$(dirname $(realpath ${BASH_SOURCE[0]}))" #脚本最初始的位置
    fi
    return 0
}


# bash_whiptail 函数说明
# 功能：封装 whiptail/msgbox 命令的终端对话框工具
#
# 参数说明（支持所有 whiptail 参数）：
#   --title <标题>       对话框标题
#   --backtitle <背景标题> 屏幕顶部背景标题
#   --yesno <文本> <高度> <宽度>  是/否对话框
#   --msgbox <文本> <高度> <宽度> 消息框
#   --infobox <文本> <高度> <宽度> 信息框（无交互）
#   --inputbox <文本> <高度> <宽度> [初始内容] 输入框
#   --passwordbox <文本> <高度> <宽度> 密码输入框
#   --textbox <文件> <高度> <宽度> 文本浏览框
#   --menu <标题> <高度> <宽度> <列表高度> [标签 项目]... 菜单选择
#   --checklist <标题> <高度> <宽度> <列表高度> [标签 项目 状态]... 多选框
#   --radiolist <标题> <高度> <宽度> <列表高度> [标签 项目 状态]... 单选列表
#   --gauge <文本> <高度> <宽度> [百分比] 进度条
#   --default-item <项目> 设置默认选中项
#   --ok-button <文本>   确定按钮文本
#   --cancel-button <文本> 取消按钮文本
#   --clear            退出时清屏
#   --defaultno        默认选中"No"
#   --fb, --fullbuttons 使用完整按钮
#   --nocancel         隐藏取消按钮
#   --yes-button <文本> 是按钮文本
#   --no-button <文本>  否按钮文本
#
# 返回值：
#   0  : 成功执行
#   40  : 未找到 whiptail 或 msgbox
#   其他: 返回 whiptail/msgbox 的退出码
#
# 工作流程：
# 1. 优先尝试调用 whiptail
# 2. 若失败则尝试 msgbox
# 3. 两者均未找到时报错
#
# 注意事项：
# 1. 需要预先安装 whiptail 或 msgbox 工具
# 2. 避免重定向输出（会破坏对话框显示）
# 3. 高度/宽度参数建议使用终端实际尺寸的80%
# 4. 复杂对话框需正确转义特殊字符
#
# 使用示例：
#   bash_whiptail --title "示例" --msgbox "Hello World" 10 40
#   choice=$(bash_whiptail --menu "选项" 15 40 4 1 "苹果" 2 "香蕉" 3 "橙子")
bash_whiptail() {
    if [[ -x "$(command -v whiptail 2>&1)" ]]; then
        whiptail "$@"
    elif command -v msgbox >/dev/null; then
        msgbox "$@" # 不能重定向输出，否则会导致whiptail无法正常显示
    else
        echo "whiptail或msgbox命令未找到，请安装whiptail或msgbox工具"
        return 40
    fi
    return $?
}
# 主菜单函数
Main() {
    mkdir -p "${WORKPATH}"
    cd "${WORKPATH}" || exit
    cp "${PWD0}/${self}" "${WORKPATH}/${self}" >/dev/null
    Get-Environment
    case "${envType}" in
    mt | termux | unknown)
        AndoridMenu "$@"
        ;;
    unix)
        UnixMenu "$@"
        ;;
    esac
}
Install-ProotEnvironment() {
    Get-Environment #envType="mt"、"termux"、"unix"
    log "尝试安装完整Linux环境（proot）"
    case "${envType}" in
    mt)
        Install-MTManagerProot
        ;;
    termux)
        Install-TermuxProot "$@"
        ;;
    unix)
        log "跳过，正常部署...."
        return 0
        ;;
    unknow)
        if bash_whiptail --backtitle "mt管理器终端安装目前仅支持arm" --yesno "既不是发行版，也不是termux，甚至不是mt管理器，非预期的环境，还要运行吗？" 8 60; then
            Install-MTManagerProot
        fi
        ;;
    esac
    #↓启动proot
    case "${tmoe}" in
    true)
        debianHOME="${HOME}/.local/share/tmoe-linux/containers/proot/debian-bookworm_arm64/root"
        bashrc="${debianHOME}/.bashrc"
        bashrc_old="${debianHOME}/.bashrc.old"
        [ -f "${debianHOME}/.zshrc" ] && bashrc="${debianHOME}/.zshrc" && bashrc_old="${debianHOME}/.zshrc.old"
        touch "${bashrc}"
        cp "${bashrc_old}" "${bashrc}"
        cp "${bashrc}" "${bashrc_old}"
        echo "" >>"${bashrc}"
        echo "exec bash -i ./${self}" >"${bashrc}"
        echo "exit" >>"${bashrc}"
        echo "复制本体到proot"
        cp "${WORKPATH}/${self}" "${debianHOME}/${self}"
        {
            sleep 10
            mv "${bashrc_old}" "${bashrc}" 1>/dev/null 2>&1
        } &
        bash "${PREFIX}/bin/tmoe" pr debian-bookworm
        ;;
    false)
        echo "复制本体到proot"
        cp "${WORKPATH}/${self}" "${MaiM_HOME}/debian12/rootfs/root/${self}"
        echo "启动proot，如果没有启动的话还请在容器启动本脚本"
        bash "${MaiM_HOME}/debian12/start" "${self}"
        ;;
    esac
}

# Update-PackageSources 函数说明
# 功能：自动更换系统软件源（支持Termux/Ubuntu/Debian）
#
# 依赖变量：
#   - $envType    [必填] 环境类型
#     - "termux"  : Termux环境
#     - "unix"    : Linux系统环境
#   - $os_id      [unix必填] 系统类型
#     - "ubuntu"  : Ubuntu系统
#     - "debian"  : Debian系统
#   - $os_version [unix必填] 系统版本号
#     - Ubuntu支持: 20.04/22.04/24.04
#     - Debian支持: 11/12/13
#   - $answer     [可选] 用户确认(y/n)
#
# 使用特点：
# 1. Termux环境：
#    - 自动替换为清华源
#    - 执行强制升级(--force-confnew)
# 2. Linux环境：
#    - 自动备份原文件(/etc/apt/sources.list.bak)
#    - 支持Ubuntu/Debian多版本
#    - 24.04特殊处理GPG密钥
#    - 需要root权限执行
#
# 注意事项：
# 1. 必须预先定义log()函数用于日志输出
# 2. Ubuntu 24.04需要联网获取GPG密钥
# 3. 涉及系统文件修改，建议提前备份
# 4. Termux会执行强制升级操作
#
# 典型调用方式：
#   envType="termux" Update-PackageSources       # Termux换源
#   envType="unix" os_id="ubuntu" os_version="22.04" Update-PackageSources  # Ubuntu换源
Update-PackageSources() {
    case "${envType}" in
    "termux")
        log "开始为termux换源！"
        sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/termux-packages-24 stable main@' "${PREFIX}"/etc/apt/sources.list && apt update && apt -o Dpkg::Options::="--force-confnew" upgrade -y && DEBIAN_FRONTEND=noninteractive apt upgrade -y --allow-downgrades --allow-remove-essential --allow-change-held-packages
        # sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/termux-packages-24 stable main@' ${PREFIX}/etc/apt/sources.list && apt update && apt upgrade
        ;;
    "unix")
        [[ "${answer}" =~ ^[Nn] ]] && return 0
        log "正在为系统更换为阿里源..."
        if [ -f /etc/apt/sources.list ]; then
            cp /etc/apt/sources.list /etc/apt/sources.list.bak
            log "已备份原有源文件到 /etc/apt/sources.list.bak"
        fi
        case "${os_id}" in
        "ubuntu")
            # 分割
            case "${os_version}" in
            "20.04")
                cat >/etc/apt/sources.list <<'UBUNTU_2004'
# 阿里云 Ubuntu 20.04 镜像源
deb [trusted=yes] http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src [trusted=yes] http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb [trusted=yes] http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src [trusted=yes] http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb [trusted=yes] http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src [trusted=yes] http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb [trusted=yes] http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src [trusted=yes] http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
UBUNTU_2004
                apt -q update
                ;;
            "22.04")
                cat >/etc/apt/sources.list <<'UBUNTU_2204'
# 阿里云 Ubuntu 22.04 镜像源
deb [trusted=yes] http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb-src [trusted=yes] http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb [trusted=yes] http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb-src [trusted=yes] http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb [trusted=yes] http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb-src [trusted=yes] http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb [trusted=yes] http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
deb-src [trusted=yes] http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
UBUNTU_2204
                apt -q update
                ;;
            "24.04")
                cat >/etc/apt/sources.list <<'UBUNTU_2404'
# 阿里云 Ubuntu 24.04 镜像源
deb [trusted=yes] https://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse
deb-src [trusted=yes] https://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse
deb [trusted=yes] https://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse
deb-src [trusted=yes] https://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse
deb [trusted=yes] https://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse
deb-src [trusted=yes] https://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse
deb [trusted=yes] https://mirrors.aliyun.com/ubuntu/ noble-proposed main restricted universe multiverse
deb-src [trusted=yes] https://mirrors.aliyun.com/ubuntu/ noble-proposed main restricted universe multiverse
deb [trusted=yes] https://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse
deb-src [trusted=yes] https://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse
UBUNTU_2404
                apt -q update || {
                    sudo gpg --keyserver keyserver.ubuntu.com --recv-keys 871920D1991BC93C
                    sudo gpg --export --armor 871920D1991BC93C | sudo tee /etc/apt/trusted.gpg.d/aliyun-ubuntu-archive.asc
                } || apt update || {
                    sudo gpg --keyserver keyserver.ubuntu.com --recv-keys 871920D1991BC93C
                    sudo gpg --export --armor 871920D1991BC93C | sudo tee /etc/apt/trusted.gpg.d/aliyun-ubuntu-archive.asc
                }
                ;;
            esac
            # 分割
            ;;
        "debian")
            case "${os_version}" in
            "11")
                cat >/etc/apt/sources.list <<'DEBIAN_11'
# 阿里云 Debian 11 (bullseye)镜像源
deb [trusted=yes] http://mirrors.aliyun.com/debian/ bullseye main non-free non-free-firmware contrib
deb-src [trusted=yes] http://mirrors.aliyun.com/debian/ bullseye main non-free non-free-firmware contrib
deb [trusted=yes] http://mirrors.aliyun.com/debian-security/ bullseye-security main
deb-src [trusted=yes] http://mirrors.aliyun.com/debian-security/ bullseye-security main
deb [trusted=yes] http://mirrors.aliyun.com/debian/ bullseye-updates main non-free non-free-firmware contrib
deb-src [trusted=yes] http://mirrors.aliyun.com/debian/ bullseye-updates main non-free non-free-firmware contrib
deb [trusted=yes] http://mirrors.aliyun.com/debian/ bullseye-backports main non-free non-free-firmware contrib
deb-src [trusted=yes] http://mirrors.aliyun.com/debian/ bullseye-backports main non-free non-free-firmware contrib
DEBIAN_11
                apt -q update
                ;;
            "12")
                cat >/etc/apt/sources.list <<'DEBIAN_12'
# 阿里云 Debian 12 (bookworm)镜像源
deb [trusted=yes] http://mirrors.aliyun.com/debian/ bookworm main non-free non-free-firmware contrib
deb-src [trusted=yes] http://mirrors.aliyun.com/debian/ bookworm main non-free non-free-firmware contrib
deb [trusted=yes] http://mirrors.aliyun.com/debian-security/ bookworm-security main
deb-src [trusted=yes] http://mirrors.aliyun.com/debian-security/ bookworm-security main
deb [trusted=yes] http://mirrors.aliyun.com/debian/ bookworm-updates main non-free non-free-firmware contrib
deb-src [trusted=yes] http://mirrors.aliyun.com/debian/ bookworm-updates main non-free non-free-firmware contrib
deb [trusted=yes] http://mirrors.aliyun.com/debian/ bookworm-backports main non-free non-free-firmware contrib
deb-src [trusted=yes] http://mirrors.aliyun.com/debian/ bookworm-backports main non-free non-free-firmware contrib
DEBIAN_12
                apt -q update
                ;;
            "13")
                cat >/etc/apt/sources.list <<'DEBIAN_13'
# 阿里云 Debian 13 (trixie) 镜像源
deb [trusted=yes] http://mirrors.aliyun.com/debian/ trixie main non-free non-free-firmware contrib
deb-src [trusted=yes] http://mirrors.aliyun.com/debian/ trixie main non-free non-free-firmware contrib
deb [trusted=yes] http://mirrors.aliyun.com/debian-security/ trixie-security main
deb-src [trusted=yes] http://mirrors.aliyun.com/debian-security/ trixie-security main
deb [trusted=yes] http://mirrors.aliyun.com/debian/ trixie-updates main non-free non-free-firmware contrib
deb-src [trusted=yes] http://mirrors.aliyun.com/debian/ trixie-updates main non-free non-free-firmware contrib
deb [trusted=yes] http://mirrors.aliyun.com/debian/ trixie-backports main non-free non-free-firmware contrib
deb-src [trusted=yes] http://mirrors.aliyun.com/debian/ trixie-backports main non-free non-free-firmware contrib
DEBIAN_13
                apt -q update
                ;;
            esac
            # 分割
            ;;
        *)
            log "不支持的系统！"
            return 1
            ;;
        esac
        log "阿里源配置完成！"
        ;;
    esac
}




DeployAskForVersion() {
    # 代理服务器配置
    proxy_arr=("https://ghfast.top" "https://ghp.ci" "https://gh.wuliya.xin" "https://gh-proxy.com" "https://x.haod.me")

    # 代理选择逻辑
    if [[ -z "$AUTO_PROXY" || "$AUTO_PROXY" == "false" ]]; then
        proxy_num=$(bash_whiptail \
            --title "是否使用GitHub加速？" \
            --menu "请选择一个代理服务器" 8 60 0 \
            '0' "不使用代理加速" \
            '1' "${proxy_arr[0]}" \
            '2' "${proxy_arr[1]}" \
            '3' "${proxy_arr[2]}" \
            '4' "${proxy_arr[3]}" \
            '5' "${proxy_arr[4]}" \
            '9' "自动检测" \
            3>&1 1>&2 2>&3) || proxy_num=9
    fi

    # 网络测试
    network_test "Github" >&2

    # 版本选择函数
    select_component_version() {
        local -n default_version=$1
        local -n tags_array=$2
        local repo_url=$3
        local component_name=$4
        local auto_env=$5

        [[ -n "$auto_env" && "$auto_env" != "false" ]] && return

        if ! bash_whiptail --title "${component_name}版本选择" \
            --yesno "是否需要部署特定版本？\n如果不确定，请选择否。" 8 60; then
            log "选择不指定版本，使用默认版本。" >&2
            return
        fi

        while true; do
            local selection=$(bash_whiptail \
                --ok-button "确定" \
                --backtitle "版本选择，按ESC取消选择${component_name:+\nps:EasyInstall-windows是无效的}" \
                --title "选择版本(硬编码缓存)" \
                --menu "以后会尝试预览" 0 60 6 \
                --cancel-button "获取最新tags" \
                $(for i in "${!tags_array[@]}"; do echo "$i ${tags_array[$i]}"; done) \
                3>&1 1>&2 2>&3)
            local status=$?

            if [[ -n "$selection" ]]; then
                log "选择了版本: ${tags_array[$selection]}" >&2
                default_version="${tags_array[$selection]}"
                break
            elif [[ "$status" -eq 255 ]]; then
                log "未选择版本，使用默认版本。" >&2
                break
            fi

            # 刷新标签
            if mapfile new_tags < <(Get-AllRepositorysTags "$repo_url"); then
                tags_array=("${new_tags[@]}")
            else
                log "刷新tag失败了" >&2
            fi
        done
    }

    # 设置默认版本
    MaiBot_Version="0.8.1-alpha"
    MaiBot_Napcat_Adapter_Version="0.4.2"

    # 为各组件选择版本
    select_component_version \
        MaiBot_Version \
        MaiBot_tags \
        "${maibo_repo_urls[main]}" \
        "MaiBot" \
        "$AUTO_MAIMAI_VERSION"

    select_component_version \
        MaiBot_Napcat_Adapter_Version \
        MaiBot_Napcat_Adapter_tags \
        "${maibo_adapter_repo_urls[main]}" \
        "MaiBot-Napcat-Adapter" \
        "$AUTO_MAIMAI_VERSION"
}
CheckPythonVersion() {
    local _python="${1:-python3}"
    IFS=' ' read -r _ Python_Version <<<"$($_python --version)" || {
        log "${RED}未检测到Python3，请手动安装Python3${NC}" >&2
        return 1
    }
    IFS='.' read -r a b _ <<<"$Python_Version"
    Python_Version="${a}.${b}"
    if [[ "$Python_Version" == "3.11" ]]; then
        log "使用Python3.11" >&2
    elif [[ "$Python_Version" == "3.12" ]]; then
        log "使用Python3.12" >&2
    elif [[ "$Python_Version" == "3.13" ]]; then
        log "使用Python3.13" >&2
    else
        log "${RED}未检测到Python3.11/Python3.12/Python3.13，请手动安装Python3.11/Python3.12/Python3.13${NC}" >&2
        return 1
    fi
    python="$_python"
    return 0
}
declare -a python_build_deps=(
    libssl-dev zlib1g-dev libbz2-dev liblzma-dev lzma-dev
    libsqlite3-dev libgdbm-dev libreadline-dev
    tk-dev libncursesw5-dev libffi-dev libuuid-dev libgdbm-dev libdb-dev
    wget build-essential pkg-config
    uuid-dev
    libgdbm-dev
    libgdbm-compat-dev
    libncurses-dev
    libbluetooth-dev
    libnl-3-dev
    libb2-dev
)
declare -a fail2py_build_deps=()
#!/bin/bash
# 函数：compile_python
# 功能：编译并安装指定版本的 Python
# 参数：
#   $1 - Python 版本号 (必填，格式如 "3.9.6")
#   $2 - 安装路径前缀 (可选，默认 /usr/local)
# 特性：
#   1. 从华为云镜像下载 Python 源码
#   2. 自动安装编译依赖包
#   3. 多核并行编译 (使用 nproc 核心数)
#   4. 交互式进度提示与旋转动画
#   5. 支持编译过程取消 (按 ESC 键)
#   6. 错误重试机制 (下载/配置/编译)
#   7. 完成后可选创建 python3/pip3 软链接
# 注意：
#   - 强烈不建议在生产环境使用
#   - 依赖包安装失败可能影响编译
#   - 通过环境变量控制行为：
#        JOBS：设置并行编译数 (默认 nproc)
#        AUTO_COMPILE_PYTHON：自动模式开关 (true 时跳过交互)
# 返回值：
#   成功 - 输出 Python 可执行文件路径并返回 0
#   失败 - 返回非 0 错误码
# 作者：凡梦光影
# 依赖工具：whiptail (用于交互提示)
#
# 使用示例：
#   compile_python 3.9.6 /opt
#   AUTO_COMPILE_PYTHON=true compile_python 3.8.12
######################################################
compile_python() {
    # trap Ctrl c
    # local old_trap=$(trap -p INT)
    # trap '' INT # 🤔
    # by 凡梦光影
    local SPINNER="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    local version="$1"
    local prefix="${2:-/usr/local}"
    local a b
    IFS='.' read -r a b _ <<<"$version"
    local main_version="${a}.${b}"
    local Original_User="${Original_User:-/root}"
    local python="${prefix}/python${version}/bin/python${main_version}"
    local pip3="${prefix}/python${version}/bin/pip${main_version}"
    local JOBS="${JOBS:-$(nproc)}"
    local python_tmp_dir="${Original_User}/python_tmp"
    mkdir -p "${Original_User}/python_tmp/Download"
    mkdir -p "${prefix}"
    show_a_spinner() {
        local wait_pid="$1"
        local content="$2"
        # local log_file="$3"
        while kill -0 "$wait_pid" 2>/dev/null; do
            echo -ne "\033[99999999;1H\r${SPINNER:$i:1}${content}  按ESC取消\033[99999999;1H\033[1A" >&2
            ((i++))
            [[ $i -ge ${#SPINNER} ]] && i=0
            read -r -s -t 0.25 -d $'\e' _ && { kill -2 -"$wait_pid" 2>/dev/null && return 1; }
            # 发送INT的kill是 kill -2
        done
        return 0
    }
    log "${RED}请勿在生产环境使用本脚本！${NC}" >&2
    for dep in "${python_build_deps[@]}"; do
        yes $'\n' | apt install "$dep" -y -q >&2 || {
            fail2py_build_deps+=("$dep")
        }
    done
    if [[ ${#fail2py_build_deps[@]} -gt 0 ]]; then
        log "以下依赖安装失败：${fail2py_build_deps[*]}" >&2
        log "一般情况下是不会对编译造成影响的，但是为了防止意外，请手动安装这些依赖" >&2
    fi
    local retry=0
    [[ ! -f "${python_tmp_dir}/Download/Python-${version}.tar.xz" ]] && while ! {
        wget "https://mirrors.huaweicloud.com/python/${version}/Python-${version}.tar.xz" -O "$python_tmp_dir/Download/Python-${version}.tar.xz" >&2
        local wget_status=$?
        if [[ $wget_status == 8 ]]; then
            log "错误：404!不存在的python版本${version}，请检查输入及网络是否正确！" >&2
            return 1
        elif [[ $wget_status == 0 ]]; then
            true
        else false; fi
    }; do
        ((retry++)) && [[ "$retry" -ge 3 ]] && log "下载Python${version}失败，请手动下载" >&2 && return 1
        log "下载Python${version}失败，正在重试" >&2
        sleep 1
    done
    tar -xf "$python_tmp_dir/Download/Python-${version}.tar.xz" -C "$python_tmp_dir" >&2 || {
        log "解压Python${version}失败，请手动解压" >&2
        sudo rm -rf "$python_tmp_dir/Python-${version}" >/dev/null 1>&2
        sudo rm -rf "$python_tmp_dir/Download/Python-${version}.tar.xz" >/dev/null 1>&2
        return 1
    }
    # 加载旋转图标
    local i=0
    cd "$python_tmp_dir/Python-${version}" >&2 || {
        log "解压Python${version}失败，请手动解压" >&2
        return 1
    }
    make clean >/dev/null 2>&1
    # 编译Python
    log "开始编译Python${version}" >&2
    local retry=0
    while true; do
        {
            ./configure --prefix="${prefix}/python${version}" --enable-optimizations 1>./configure.log 2>&1
            echo $? >./configure.status
        } &
        configure_pid=$!
        if ! (show_a_spinner "$configure_pid" "配置Python${version}中..."); then
            [[ -z "$AUTO_COMPILE_PYTHON" || "$AUTO_COMPILE_PYTHON" == 'true' ]] && {
                [[ "$AUTO_COMPILE_PYTHON" == 'true' ]] && continue
                log "停止了配置，你要重来吗？" >&2 && read -r -p "是否重新配置Python${version}？(y/n)" choice && [[ "$choice" =~ ^[Yy] ]] && continue || return 1
            }
        fi
        configure_status=$(cat ./configure.status)
        if [[ "$configure_status" -eq 0 ]]; then
            break
        elif [[ "$configure_status" == 130 ]]; then
            sleep 1
        else
            log "配置Python${version}失败，正在重试" >&2
            log "一般的重试基本没有意义，但是也要试一下" >&2
            sleep 1
        fi
        ((retry++)) && [[ "$retry" -ge 3 ]] && log "配置Python${version}失败，请手动配置" >&2 && return 1
    done
    local retry=0
    while ! make -j"$JOBS" >&2; do
        [[ -z "$AUTO_COMPILE_PYTHON" || "$AUTO_COMPILE_PYTHON" == 'true' ]] && {
            ((retry++)) && [[ "$retry" -ge 3 ]] && log "编译Python${version}失败，请手动编译" >&2 && return 1
            [[ "$AUTO_COMPILE_PYTHON" == 'true' ]] && continue
            if bash_whiptail --title "编译Python" --yesno "编译Python${version}失败，是否重试？\n如果不确定，请选择是。" 8 60; then
                continue
            else
                log "编译Python${version}失败，请手动编译" >&2
                return 1
            fi
        }
    done
    local retry=0
    while true; do
        {
            make altinstall >&2
            echo $? >./make.status
        } &
        make_pid=$!
        (show_a_spinner "$make_pid" "安装Python${version}中...")
        local spinner_status=$?
        local make_status
        make_status="$(cat ./make.status)"
        [[ "$make_status" -eq 0 ]] && break || {
            ((retry++)) && [[ "$retry" -ge 3 ]] && log "安装Python${version}失败，请手动安装" >&2 && return 1
            log "安装Python${version}失败，正在重试" >&2
            sleep 1
        }
        if [[ $spinner_status == 130 ]]; then
            log "停止了安装，你要重来吗？" >&2
            read -r -p "$(log "是否重新安装Python${version}？(y/n"))" choice && [[ "$choice" == 'y' ]] && continue || return 1
        elif [[ $spinner_status == 1 ]]; then
            log "取消了安装" >&2
            break
        else
            break
        fi
    done
    make_status="$(cat ./make.status)"
    if [[ "$make_status" -eq 0 ]]; then
        log "安装Python${version}成功" >&2
    else
        log "安装Python${version}失败，请手动安装" >&2
        return 1
    fi
    # shellcheck disable=SC2164
    cd -
    [[ -z "$AUTO_COMPILE_PYTHON" || "$AUTO_COMPILE_PYTHON" == "true" ]] && {
        [[ "$AUTO_COMPILE_PYTHON" == 'true' ]] && echo "$python" && return 0
        if bash_whiptail --title "链接Python" --yesno "编译安装Python${version}完成，是否链接到python3？\n如果不确定，请选择否。" 8 60; then
            sudo ln -s "$python" /usr/local/bin/python3
            sudo ln -s "$pip3" /usr/local/bin/pip3
        fi
    }
    echo "$python"
    return 0
}
#https://mirrors.huaweicloud.com/python/{3.11.13}/Python-{3.11.13}.tar.xz
#https://mirrors.huaweicloud.com/python/{3.12.10}/Python-{3.12.10}.tar.xz
#https://mirrors.huaweicloud.com/python/3.13.5/Python-3.13.5.tar.xz
Deploy-FullStack() {
    Install-ProotEnvironment "$@"
    if [[ "$AUTO_SOURCES" == "false" || -z "$AUTO_SOURCES" ]]; then
        if bash_whiptail --title "换源" --yesno "是否为系统更换为阿里源？\n如果不确定，请选择否。" 8 60; then
            Update-PackageSources
        else
            true
        fi
    else
        Update-PackageSources
    fi
    CheckPythonVersion "$(command -v python3)" || {
        apt install python3 -y -q
    }
    CheckPythonVersion || {
        [[ -z "$AUTO_COMPILE_PYTHON" ]] && if __Python_Version=$(
            bash_whiptail --title "编译Python" --menu "是否编译Python？\n如果不确定，请选择python3.11。" 8 60 0 \
                '0' "不编译" \
                '1' "编译Python3.11" \
                '2' "编译Python3.12" \
                '3' "编译Python3.13" \
                3>&1 1>&2 2>&3
        ); then
            case $__Python_Version in
            1)
                compile_python 3.11.13
                ;;
            2)
                compile_python 3.12.10
                ;;
            3)
                compile_python 3.13.5
                ;;
            esac
        fi
    }
    CheckPythonVersion || {
        bash_whiptail --title "无法安装Python" --msgbox "无法安装Python，请手动安装Python" 8 60
        return 1
    }
    if ! sudo -u "$Original_User" bash --login -c "command -v uv >/dev/null"; then
        [[ "${INSTALL_UV}" == "false" || -z "$INSTALL_UV" ]] && {
            if bash_whiptail --title "安装全局uv" --yesno "是否安装uv？\n如果不确定，请选择否。\n× This environment is externally managed\n╰─> To install Python packages system-wide, try apt install\n    python3-xyz, where xyz is the package you are trying to\n    install.\n    \n    If you wish to install a non-Debian-packaged Python package,\n    create a virtual environment using python3 -m venv path/to/venv.\n    Then use path/to/venv/bin/python and path/to/venv/bin/pip. Make\n    sure you have python3-full installed.\n    \n    If you wish to install a non-Debian packaged Python application,\n    it may be easiest to use pipx install xyz, which will manage a\n    virtual environment for you. Make sure you have pipx installed.\n    \n    See /usr/share/doc/python3.11/README.venv for more information.\n\nnote: If you believe this is a mistake, please contact your Python installation or OS distribution provider. \nYou can override this, at the risk of breaking your Python installation or OS, by passing --break-system-packages.\nhint: See PEP 668 for the detailed specification." 8 60; then
                INSTALL_UV="true"
            else
                INSTALL_UV="false"
            fi
        } || INSTALL_UV="true"
        [[ "${AUTO_PIP_SOURCE}" == "false" || -z "$AUTO_PIP_SOURCE" ]] && if ! command -v pip >/dev/null; then
            log "pip未安装，开始安装pip"
            sudo apt install python3-pip -y || {
                log "${RED}pip安装失败，请检查网络连接或手动安装pip${NC}"
                exit 1
            }
        fi
        # 是否更换全局pip源
        [[ -z "$AUTO_PIP_SOURCE" ]] && if bash_whiptail --title "pip源选择" --yesno "是否更换pip源？\n不在国内请选择否。" 8 60; then
            AUTO_PIP_SOURCE="true"
        else
            AUTO_PIP_SOURCE="false"
        fi
        [[ "${AUTO_PIP_SOURCE}" == "true" ]] && sudo -u "$Original_User" bash -c "pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/"
        sudo -u "$Original_User" bash -c "pip install --break-system-packages uv -i https://mirrors.aliyun.com/pypi/simple/" || {
            log "${RED}uv安装失败，请检查网络连接或手动安装uv${NC}"
        }
    fi
    [[ "$AUTO_INSTALL_MONGODB" == "false" || -z "$AUTO_INSTALL_MONGODB" ]] && {
        if bash_whiptail --title "MongoDB安装" --yesno "是否安装MongoDB？\n如果不确定，请选择是。" 8 60; then
            AUTO_INSTALL_MONGODB="true"
        else
            AUTO_INSTALL_MONGODB="false"
        fi
    }
    DeployAskForVersion
    local MaiBot=$(Get-MaiMaiRepository MaiBot "$MaiBot_Version" '' "$target_proxy" "${WORKPATH}/MaiM-with-u/MaiBot")
    local MaiBot_Napcat_Adapter=$(Get-MaiMaiRepository MaiBot-Napcat-Adapter "$MaiBot_Napcat_Adapter_Version" '' "$target_proxy" "${WORKPATH}/MaiM-with-u/MaiBot-Napcat-Adapter")
    [[ -z "${MaiBot}" || -z "${MaiBot_Napcat_Adapter}" ]] && {
        log "获取MaiBot或适配器失败，请检查网络连接或手动下载。" >&2
        exit 1
    }
    Deploy-MaiBot "$MaiBot" "$MaiBot_Version" "$MaiBot_Napcat_Adapter" "$MaiBot_Napcat_Adapter_Version"
    command -v napcat >/dev/null && [[ "$AUTO_INSTALL_NAPCAT" == "false" || -z "$AUTO_INSTALL_NAPCAT" ]] && {
        if bash_whiptail --title "napcat安装" --yesno "是否安装napcat？\n如果不确定，请选择是。" 8 60; then
            AUTO_INSTALL_NAPCAT="true"
        else
            AUTO_INSTALL_NAPCAT="false"
        fi
    }
    if [[ "$AUTO_INSTALL_MONGODB" == "true" ]]; then
        [[ ! -x "${MaiM_bin}"/mongod ]] && Install-MongoDB
    fi
    if [[ "$AUTO_INSTALL_NAPCAT" == "true" ]]; then
        Invoke-NapcatInstall --docker n --cli y
        #传递自动参数
    fi
}

#
Deploy-MaiBot() {
    local WORKPATH="${WORKPATH:-./tmp}"
    local TARGET_FOLDER="${TARGET_FOLDER:-/opt/QQ/resources/app/app_launcher}"
    local venvPath="${MaiM_HOME}/MaiBotEnv" # MaiM_HOME=~/.local/MaiM-with-u
    local MaiBot="${1:-${WORKPATH}/MaiBot}"
    local Adapter="${2:-${WORKPATH}/MaiBot-Napcat-Adapter}"

}
#



Enter-ProotContainer() {
    : #  envType="mt"、"termux"、"unix"、"unknow"
    case "${envType}" in
    mt | unknow)
        if [ -d "${MaiM_HOME}/debian12/rootfs/root" ]; then
            exec bash "${MaiM_HOME}/debian12/start"
        else
            echo "未找到proot容器，请先安装完整Linux环境（proot）"
            return 1
        fi
        ;;
    termux | unix)
        if [ -f "${HOME}/.local/share/tmoe-linux/containers/proot/debian-bookworm_arm64/root" ]; then
            exec bash "${HOME}/.local/share/tmoe-linux/containers/proot/debian-bookworm_arm64/root/${self}"
        elif [ -d "${MaiM_HOME}/debian12/rootfs/root" ]; then
            exec bash "${MaiM_HOME}/debian12/start"
        else
            echo "未找到proot容器，请先安装完整Linux环境（proot）"
            return 1
        fi
        ;;
    esac
}

Configure-MaiMConfig() {
    local mode="${1:-"deploy"}"
    local MaiMDir="${WORKPATH}/MaiM-with-u"
    case "${mode}" in
    deploy)
        {
            qqNumberMaiM="$(Invoke-UserInputPrompt "现在如果你能直接输入用于登陆麦麦（给麦麦用的）QQ号码的话，我可以直接创建网络配置文件（也可以不输入但你就得自己去webUI配置了）:" "^[0-9]+$" "${qqNumberMaiM}")"
            while [[ -n "${qqNumberMaiM}" ]] && ! [[ "${qqNumberMaiM}" =~ ^[0-9]+$ ]]; do
                echo "你的输入似乎无效哦，直接回车以跳过"
                qqNumberMaiM="$(Invoke-UserInputPrompt "现在如果你能直接输入用于登陆麦麦（给麦麦用的）QQ号码的话，我可以直接创建网络配置文件（也可以不输入但你就得自己去webUI配置了）:" "^[0-9]+$" "${qqNumberMaiM}")"
            done
            if [[ -n "${qqNumberMaiM}" ]]; then
                sed -i "s/^qq = [0-9]\+/qq = ${qqNumberMaiM}/g" "${MaiM_HOME}/MaiBot/config/bot_config.toml"
                mkdir -p "${TARGET_FOLDER}/napcat/config"
                TODO "修改name部分，版本管理"
                cat >"${TARGET_FOLDER}/napcat/config/onebot11_${qqNumberMaiM}.json" <<EOF
{
  "network": {
    "httpServers": [
      {
        "enable": true,
        "name": "curl",
        "host": "0.0.0.0",
        "port": 3001,
        "enableCors": true,
        "enableWebsocket": true,
        "messagePostFormat": "array",
        "token": "",
        "debug": false
      }
    ],
    "httpSseServers": [],
    "httpClients": [],
    "websocketServers": [],
    "websocketClients": [
      {
        "enable": true,
        "name": "mmc063c",
        "url": "ws://localhost:8095/",
        "reportSelfMessage": false,
        "messagePostFormat": "array",
        "token": "",
        "debug": false,
        "heartInterval": 30000,
        "reconnectInterval": 30000
      }
    ],
    "plugins": []
  },
  "musicSignUrl": "",
  "enableLocalFile2Url": false,
  "parseMultMsg": false
}
EOF
                echo "反向连接配置文件已生成！"
            fi
            local APIKEY=""
            APIKEY="$(Invoke-UserInputPrompt "输入硅基流动API Key：" "^sk-[a-zA-Z0-9]+" "" "true")"
            sed -i "s/^SILICONFLOW_KEY=/SILICONFLOW_KEY=${APIKEY}/g" "${MaiM_HOME}/MaiBot/.env"
            echo "正在生成一键启动脚本！"
            echo "${qqNumberMaiM}" >"${Original_Users_HOME}"/.qnumber
            # (command -v screen>/dev/null) && MUXTYPE="screen"
            screen -dmS abdcefghijklmnopqrstuvwxyz123456789 bash -c 'sleep 2' && {
                MUXTYPE="screen"
            } || {
                echo -e "${BLUE}安装screen${NC}" # 有其他问题我也不想管了
                sudo apt install screen -q -y || echo "安装错误，如果是没网的话，没网你玩什么Linux？（纯恶意）"
                screen -dmS abdcefghijklmnopqrstuvwxyz123456789 bash -c 'sleep 2' && MUXTYPE="screen"
            }
            ! screen -ls | grep 'abdcefghijklmnopqrstuvwxyz123456789' && {
                echo -e "${RED}看起来你的环境不支持screen${NC}" # 部分proot环境对部分套字节依赖软件不支持，例如tmoe全能提供的proot中screen可以正常运行，但是无法重新连接screen -ls也是空
                # 但是实测tmux可用
                echo -e "${BLUE}那我就换tmux了喵(⑅˃◡˂⑅)${NC}"
                echo "screen重新连接失败"
                (command -v tmux >/dev/null) || sudo apt -q install tmux -y
                MUXTYPE="tmux"
            }
            echo "${MUXTYPE}" >"${Original_Users_HOME}/.mux_type"
            cat >"${Original_Users_HOME}/maiMStart" <<'EOF'
#!/bin/bash
# source ${MaiMStartConfig} # 以后用作版本管理
unset dbpath
Original_User="${SUDO_USER}"
[[ -n "${Original_User}" ]] && Original_Users_HOME="$(sudo -n -u "${Original_User}" bash -c 'echo ${HOME}')" # 如果被非root用户sudo，获取原用户的HOME
Original_Users_HOME="${Original_Users_HOME:-"${HOME}"}"
version="${version:-global}" # global是普通字符
MaiM_HOME="${MaiM_HOME:-"${Original_Users_HOME}/.local/MaiM-with-u"}"
mongod="$(command -v mongod 2>/dev/null || echo "${MaiM_bin:-${Original_Users_HOME}/.local/MaiM-with-u}/bin/mongod")"
[[ ! -x "${mongod}" ]] && mongod="${mongod:-${Original_Users_HOME}/.local/MaiM-with-u/bin/mongod}"
[[ -d "${Original_Users_HOME}/data/db" ]] && dbpath="${Original_Users_HOME}/data/db"
[[ -d "${MaiM_dbpath}" && -z "${dbpath}" ]] && dbpath="${MaiM_dbpath}"
[[ -d "${Original_Users_HOME}/.local/MaiM-with-u/data/db" && -z "${dbpath}" ]] && dbpath="${Original_Users_HOME}/.local/MaiM-with-u/data/db"
[[ -z "${dbpath}" ]] && dbpath="${Original_Users_HOME}/.local/MaiM-with-u/data/db" # 什么路径都没有的情况下
check_files() {
    local files=("${Original_Users_HOME}/.mux_type" "${Original_Users_HOME}/.qnumber")
    for file in "${files[@]}"; do
        if [[ ! -f "${file}" ]]; then
            echo "错误：找不到必要文件 ${file}"
            exit 1
        fi
    done
}
check_files
mkdir -p "${dbpath}"
"${mongod}" --dbpath "${dbpath}" --bind_ip 127.0.0.1 --fork --logpath "${dbpath}/log.txt"
sudo napcat start "$(cat "${Original_Users_HOME}/.qnumber")"
start_session() {
    local mux=$1
    local session=$2
    local cmd=$3
    case ${mux} in
        "screen")
            screen -dmS "${session}" bash -c "${cmd}"
            ;;
        "tmux")
            tmux new -d -s "${session}" bash -c "${cmd}"
            ;;
    esac
}
mux_type=$(cat "${Original_Users_HOME}/.mux_type")
adapter_cmd="cd \"${MaiM_HOME}/MaiBot-Napcat-Adapter\" && source \"${MaiM_HOME}/MaiBotEnv/bin/activate\" && python main.py"
bot_cmd="cd \"${MaiM_HOME}/MaiBot\" && source \"${MaiM_HOME}/MaiBotEnv/bin/activate\" && python3 bot.py"
case ${mux_type} in
    "screen"|"tmux")
        start_session "${mux_type}" "mmc-adapter" "${adapter_cmd}"
        start_session "${mux_type}" "mmc" "${bot_cmd}"
        ;;
    *)
        echo "错误：未知的终端复用器类型 '${mux_type}'"
        echo "TODO：在终端复用器不可用的情况下去查看输出内容（tail -f ）"
        exit 1
        #
        #nohup maimai > maimai.log 2>&1 & # tail -f
        #disown
        #
        ;;
esac
echo "启动完成，使用以下命令连接："
case ${mux_type} in
    "screen")
        echo "screen -r mmc          # 主机器人"
        echo "screen -r mmc-adapter   # 适配器"
        ;;
    "tmux")
        echo "tmux attach -t mmc        # 主机器人"
        echo "tmux attach -t mmc-adapter # 适配器"
        ;;
esac
echo "当前运行中的服务进程："
for pid in $(pgrep -f 'python'); do
    exe=$(readlink -f "/proc/${pid}/exe")
    cwd=$(readlink -f "/proc/${pid}/cwd")
    if [[ "${cwd}" == "${MaiM_HOME}/"* ]]; then
        echo "PID: ${pid} | 路径: ${exe} | 目录: ${cwd}"
    fi
done
EOF
            cp "${Original_Users_HOME}/maiMStart" "/bin/maiMStart"
            chmod +x "${BIN}/maiMStart"
            chmod +x "${Original_Users_HOME}/maiMStart"
            echo "已生成启动脚本在/bin/maiMStart！"
            sleep 1
            return 0
        }
        ;;
    # 以上与下方没有太大的关系，除了一个case的开始和函数定义起始
    #
    interactive)
        :
    esac
}

# 通用变量导出函数
# 用法：Export-Variables 输出文件名 变量名1 变量名2 ...
Export-Variables() {
    local OutputFile="$1"
    shift # 移出文件名参数，剩余参数为变量名

    true >"${OutputFile}" # 清空目标文件

    for VarName in "$@"; do
        # 检查变量是否存在
        if ! declare -p "${VarName}" &>/dev/null; then
            echo "警告: 变量 ${VarName} 不存在，已跳过" >&2
            continue
        fi

        # 获取变量声明语句并写入文件
        {
            declare -p "${VarName}" | sed -E 's/^declare (-[a-zA-Z-]+) /declare -g \1 /'
            echo
        } >>"${OutputFile}"
    done

    echo "变量已导出到 ${OutputFile} (可用 source 加载)"
}

Install-MTManagerProot() {
    local FILE="${WORKPATH}/${self}"
    local MARKER=$(echo 'cHJvb3RfZXhlY3V0YWJsZXNf5a6a5L2N56ymCg==' | base64 -d) # 定义解压标记
    local MaiM_HOME="${MaiM_HOME:-${Original_Users_HOME}/.local/MaiM-with-u}"
    local PROOT_bin="${MaiM_bin:-${MaiM_HOME}/bin}"
    local proot_tool # 使用下划线命名变量

    # 处理自定义安装路径
    if [[ -n "$1" && -d "$1" ]]; then
        PROOT_bin="$1"
        shift
    fi

    # 自解压部分
    echo "开始自解压..."
    local start_line=$(awk "/${MARKER}/{print NR+1; exit}" "${FILE}")
    local Extra_path="${MaiM_HOME:-"${Original_Users_HOME}/.local/MaiM-with-u"}"
    mkdir -p "${Extra_path}"
    if ! tail -n "+${start_line}" "${FILE}" | tar -xzvC "${Extra_path}"; then
        echo -e "${RED}错误: 脚本释放失败!${NC}"
        return 1
    fi

    # 复制proot_proc（假设正确名称）
    local prefix_dir="${PREFIX:-/usr/local/bin}"
    if ! cp -r "${Extra_path}/proot_proc" "${prefix_dir}"; then
        echo -e "${RED}错误: 无法复制proot_proc!(${Extra_path})${NC}"
        return 1
    fi
    # 设置执行权限
    chmod -R +x "${PROOT_bin}"
    echo -e "${GREEN}权限已设置。${NC}"
    # 定位proot-tool
    proot_tool=$(command -v proot-tool) || proot_tool="${PROOT_bin}/proot-tool"
    if [[ ! -x "${proot_tool}" ]]; then
        echo -e "${RED}错误: 未找到proot-tool!${NC}"
        return 1
    fi

    # 检查是否已安装Debian
    if [[ -s "${MaiM_HOME}/debian12/start" ]]; then
        echo "Debian12已存在，跳过安装。"
        tmoe="false"
        return
    fi

    # 下载并安装Debian12
    echo "下载Debian12镜像..."
    if ! Download-Debian12RootFS; then
        echo -e "${RED}错误: 下载失败!${NC}"
        return 1
    fi

    mkdir -p "${MaiM_HOME}/debian12" || return 1
    if ! "${proot_tool}" install "./${FILENAME}" "${MaiM_HOME}/debian12"; then
        echo -e "${RED}错误: 安装Debian失败!${NC}"
        return 1
    fi

    tmoe="false"
}

Install-TermuxProot() {
    # set -x
    echo "输入proot使用“Install-MTManagerProot”函数安装..."
    # r ead -r -p "请安装Debian12（bookworm）回车继续" ___
    ___="$(Invoke-UserInputPrompt "请安装Debian12（bookworm）键入tmoe继续" "tmoe" "proot")"
    # set +x
    if [[ "${___}" == "proot" ]]; then
        echo "使用脚本自解压的proot二进制...(arm)"
        Install-MTManagerProot "$@"
        tmoe="false"
        return
    fi
    if ! command -v curl >/dev/null 2>&1; then
        pkg install curl -y
    fi
    if ! [[ -f "${PREFIX}/bin/tmoe" ]]; then
        bash -c "$(curl -L gitee.com/mo2/linux/raw/2/2)"
    fi
    tmoe="true"
}

#↓napcat
Invoke-NapcatInstall() {
    # 安全下载安装脚本（处理重定向和证书验证）
    if [[ ! -f "./napcat.sh" ]]; then
        if ! curl -Lkf -o napcat.sh "https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.sh"; then
            echo -e "${RED}错误：无法下载安装脚本！${NC}" >&2
            return 1
        fi
    fi

    # 用户选择逻辑
    local INSTALL=true
    if command -v qq &>/dev/null; then
        local response=$(Invoke-UserInputPrompt "检测到QQ已安装，要强制重新安装NapCat？(y/N)" "^[Yy]" "N")
        [[ "$response" =~ ^[Yy] ]] && INSTALL=true
        [[ "$response" =~ ^[Nn] ]] && INSTALL=false
    fi

    # 生成控制脚本逻辑
    if ! command -v napcat &>/dev/null; then
        echo -e "${GREEN}正在生成NapCat控制脚本...${NC}"
        if ! __NAPCAT__; then
            echo -e "${RED}错误：控制脚本生成失败！${NC}" >&2
            return 2
        fi
        echo -e "${BLUE}控制脚本路径：$(command -v napcat)${NC}"
    fi

    # 执行安装并返回正确状态码
    [[ "${INSTALL}" == "true" ]] && bash napcat.sh "$@"
    return $?
}
#↑napcat

###
#工具函数？

Download-Debian12RootFS() {
    # 固定输出文件名
    FILENAME="LCX_Debian12.tar.xz"
    if Test-CacheAndRestore "${FILENAME}"; then
        return 0
    fi
    # 硬编码参数（只支持Debian12）
    local DISTRO="debian"
    local RELEASE="bookworm"
    local ARCH="arm64"
    [[ $(uname -m) != 'aarch64' ]] && ARCH="amd64"
    local VARIANT="default"
    local BASE_URL="https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/${DISTRO}/${RELEASE}/${ARCH}/${VARIANT}/"

    echo "正在获取最新Debian12镜像..."

    # 获取最新目录
    local LATEST_DIR=$(curl -fsSL "${BASE_URL}" |
        grep -oE 'href="[0-9]{8}_[0-9]{2}%3A[0-9]{2}/"' |
        sed 's/href="\(.*\)\/"/\1/; s/%3A/-/g' |
        sort -r | head -n1)

    [[ -z "${LATEST_DIR}" ]] && {
        echo "错误：无法获取最新版本目录！"
        echo "需要${FILENAME}，LXCrootfs文件，你可以手动下载其他类似文件("
        return 1
    }

    # 构建下载链接（注意URL中需要%3A）
    local ROOTFS_URL="${BASE_URL}${LATEST_DIR//-/%3A}/rootfs.tar.xz"

    echo "▶ 版本: ${LATEST_DIR//-/:}"
    echo "▶ 架构: ${ARCH}"
    echo "▶ 下载: ${ROOTFS_URL}"

    # 强制下载到固定文件名
    echo "开始下载..."
    if wget --show-progress -q -O "${FILENAME}" "${ROOTFS_URL}"; then
        cp "./${FILENAME}" "./${FILENAME}.cache"
        echo "√ 下载完成 → ${FILENAME}"
    else
        echo "× 下载失败！请检查网络连接"
        echo "LCX_Debian12.tar.xz的URL为：${ROOTFS_URL}"
        echo "你可以手动下载放到当前脚本位置：${PWD0}、或$(pwd)"
        rm -f "${FILENAME}" 2>/dev/null # 删除可能残留的无效文件
        return 1
    fi
}

Get-Environment() {
    #WHOAMI="$(whoami)"
    BIN="$(dirname "$(realpath "$(command -v sh)")")"
    if [[ "${BIN}" == *com.termux* ]]; then
        envType="termux"
        return 0
    elif [[ "${BIN}" == *bin.mt.plus* ]]; then # 以后要准备root兼容....
        envType="mt"
        return 0
    fi
    # 检测 Linux 发行版信息（不想认识的就不要勉强了喵~）
    if [[ -f "/etc/os-release" ]]; then
        # 安全读取 os-release (防止变量污染)
        os_id=$(awk -F= '$1=="ID" { gsub(/"/, "", $2); print $2 }' /etc/os-release)
        os_name=$(awk -F= '$1=="NAME" { gsub(/"/, "", $2); print $2 }' /etc/os-release)
        os_version=$(awk -F= '$1=="VERSION_ID" { gsub(/"/, "", $2); print $2 }' /etc/os-release)

        declare -A pkg_managers=(["apt"]="Debian/Ubuntu系" ["apt-get"]="Debian/Ubuntu系" ["dnf"]="Fedora/RHEL��")

        for Cmd in "${!pkg_managers[@]}"; do
            if command -v "${Cmd}" >/dev/null 2>&1; then
                envType="unix"
                return 0
            fi
        done
        envType="unknown"
        return 0
    else
        envType="unknown"
        return 0
    fi
}

Test-CacheAndRestore() {
    local FILENAME="$1" # 通过参数传入文件名
    local hash="${2:-}" # 传入哈希值进行校验
    local PWD0="${3:-${PWD0}}"

    local cached_file=""

    # 缓存检查优先级（按顺序检查）
    if [[ -s "./${FILENAME}.cache" ]]; then
        echo "√ 恢复当前目录缓存文件副本"
        cached_file="./${FILENAME}.cache"
    elif [[ -s "${PWD0}/${FILENAME}.cache" ]]; then
        echo "√ 恢复目录${PWD0}缓存文件副本"
        cached_file="${PWD0}/${FILENAME}.cache"
    elif [[ -s "./${FILENAME}" ]]; then
        echo "√ 发现当前目录缓存: ${FILENAME}"
        cp "./${FILENAME}" "./${FILENAME}.cache" || return 1
        cached_file="./${FILENAME}.cache"
    elif [[ -s "${PWD0}/${FILENAME}" ]]; then
        echo "��� 发现目录${PWD0}缓存: ${PWD0}/${FILENAME}"
        cp "${PWD0}/${FILENAME}" "./${FILENAME}.cache" || return 1
        cached_file="./${FILENAME}.cache"
    else
        # 没有找到任何缓存文件
        return 1
    fi

    # 复制缓存文件到目标位置
    cp "${cached_file}" "./${FILENAME}" || {
        echo "× 文件复制失败: ${cached_file} -> ./${FILENAME}"
        return 1
    }

    # 哈希校验（如果传入了哈希值）
    if [[ -n "${hash}" ]]; then
        local calculated_hash
        calculated_hash=$(sha256sum "./${FILENAME}" | cut -d' ' -f1) || {
            echo "× 计算文件哈希失败"
            return 1
        }

        if [[ "${calculated_hash}" != "${hash}" ]]; then
            echo "× 哈希校验失败"
            echo "  预期哈希: ${hash}"
            return 1
        fi
        return 0
    fi

    return 0
}

Install-MongoDB() {
    local MaiM_bin="${MaiM_bin:-${MaiM_HOME}/bin}"
    local MaiM_dbpath="${MaiM_dbpath:-${MaiM_HOME}/data/db}"
    local MONGODB="mongodb.tgz"
    local LIBSSL="libssl1.1.deb"
    Set-DownloadURL() {
        ARCH=$(uname -m)
        local USE_OFFICIAL_SOURCE=0

        # 检查是否传入了 --official 参数
        for arg in "$@"; do
            if [ "${arg}" = "--official" ]; then
                USE_OFFICIAL_SOURCE=1
                break
            fi
        done

        if [ "${ARCH}" = "aarch64" ]; then
            if [ ${USE_OFFICIAL_SOURCE} -eq 1 ]; then
                LIBSSL_URL="http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_arm64.deb"
                MONGO_URL="https://fastdl.mongodb.org/linux/mongodb-linux-aarch64-ubuntu2004-5.0.30.tgz"
            else
                LIBSSL_URL="https://alist.tianmoy.cn/d/MaiBot/linux/libssl1.1_1.1.1f-1ubuntu2_arm64.deb"
                MONGO_URL="https://alist.tianmoy.cn/d/MaiBot/linux/mongodb-linux-aarch64-ubuntu2004-5.0.9.tgz"
            fi
        elif [ "${ARCH}" = "x86_64" ]; then
            if [ ${USE_OFFICIAL_SOURCE} -eq 1 ]; then
                LIBSSL_URL="http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb"
                MONGO_URL="https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-ubuntu2004-5.0.30.tgz" # 被迫的...5.0.9在官网上不见了..
            else
                LIBSSL_URL="https://alist.tianmoy.cn/d/MaiBot/linux/libssl1.1_1.1.1f-1ubuntu2_amd64.deb"
                MONGO_URL="https://alist.tianmoy.cn/d/MaiBot/linux/mongodb-linux-x86_64-ubuntu2004-5.0.9.tgz"
            fi
        else
            echo "不支持的架构: ${ARCH}"
            return 1
        fi
    }
    Download-MongoDB() {
        echo "当前架构是：${ARCH}"
        echo "libssl1.1：${LIBSSL_URL}"
        echo "mongodb：${MONGO_URL}"
        echo -e "${GREEN}你可以在脚本提前下载好mongodb的二进制包，重命名为“mongodb.tgz”${NC}"

        # 通用下载函数
        _download_file() {
            local url=$1
            local output=$2
            local description=$3

            if ! Test-CacheAndRestore "${output}"; then
                echo "下载 ${description}..."
                # 启动下载进程
                { wget --show-progress -T 9999 -O "${output}" "${url}"; } &
                local wget_pid=$!
                # 启动监控进程
                {
                    printf "\r正在下载...Ctrl+C 不会退出脚本"
                    while kill -0 "${wget_pid}" 2>/dev/null; do
                        sleep 1
                    done
                    return
                } &
                local monitor_pid=$!
                # 设置信号处理：终止下载和监控进程，并恢复原始 trap
                trap 'kill -9 \"${wget_pid}\" \"${monitor_pid}\" 2>/dev/null; trap - SIGINT;stty isig' SIGINT
                # 等待下载完成
                echo "开始等待..."
                if wait "${wget_pid}"; then
                    kill "${monitor_pid}" 2>/dev/null
                    # eval "${original_trap}"
                    return 0
                else
                    kill "${monitor_pid}" 2>/dev/null
                    # eval "${original_trap}"
                    echo "下载 ${description} 失败，请检查网络连接"
                    rm -f "${output}"
                    return 1
                fi
            fi
            return 0
        }

        # 下载 libssl
        _download_file "${LIBSSL_URL}" "${LIBSSL}" "libssl1.1" || return 1

        # 下载 MongoDB
        _download_file "${MONGO_URL}" "${MONGODB}" "MongoDB" || return 1

        return 0
    }
    # 安装依赖
    echo "正在安装基础依赖..."
    Set-DownloadURL
    sudo apt-get install -y wget tar libcurl4 apt-utils curl
    Download-MongoDB || {
        log "失败：你的机子好像和alist不熟？"
        echo -e "${BLUE}换官方源再试试...${NC}"
        # rm -rf "${MONGODB}" "${LIBSSL}"
        Set-DownloadURL --official && Download-MongoDB
    }
    sudo mkdir "${WORKPATH}/TmpMongod"
    sudo dpkg -x $(basename "${LIBSSL}") / || exit 1
    tar -xzvf $(basename "${MONGODB}") -C "${WORKPATH}/TmpMongod"

    # 安装到MaiM_bin路径 可自定义
    mkdir -p "${MaiM_bin}"
    sudo install -m 755 "${WORKPATH}/TmpMongod/"mongodb-linux*/bin/* "${MaiM_bin}"
    sudo rm -rf "${WORKPATH}/TmpMongod"
    # 创建数据目录
    echo "创建的数据目录为：${MaiM_dbpath}"
    sudo mkdir -p "${MaiM_dbpath}"
    sudo chmod 777 "${MaiM_dbpath}"
    echo "已将数据目录（${MaiM_dbpath}）设置为777反正没人碰，如有危险请手动设置权限"
}

DEBUG() {
    #你喵了个 source还不允许混合文件了
    # set -x
    local MARKER=$(echo 'cHJvb3RfZXhlY3V0YWJsZXNf5a6a5L2N56ymCg==' | base64 -d)
    local start_line=$(awk "/${MARKER}/{print NR; exit}" "${PWD0}/${self}" || {
        log "致命错误：定位符不存在！" >&2
        exit 255
    })
    local tmpdir="$(mktemp)"
    trap 'rm "${tmpdir}">/dev/null 2>&1' EXIT
    head -n "${start_line}" "${PWD0}/${self}" >"${tmpdir}"
    echo "self=${self}" >>"${tmpdir}"
    bash --init-file "${tmpdir}" -i
    # set +x
}

###
###
Get-Environment
Initialize-ScriptEnvironment
check_root "$@"
IFS=' ' read -r __ScreenHeight __ScreenWidth < <(stty size)
if [ $# -gt 0 ]; then
    case "$1" in
    -h | --help | help)
        shift
        ;;
    -d | --dir)
        shift
        MaiM_HOME="${1:-${MaiM_HOME}}"
        MaiM_HOME="${MaiM_HOME:-${Original_Users_HOME}/.local/MaiM-with-u}"
        MaiM_bin="${MaiM_HOME}/bin"
        shift
        ;;
    -F | --fix)
        shift
        AUTO_FIX=true
        ;;
    -A | --auto)
        shift
        AUTO_RECOMMANDED=true
        ;;
    --auto-sources)
        shift
        AUTO_SOURCES=true
        ;;
    --auto-python)
        shift
        AUTO_COMPILE_PYTHON=true
        ;;
    --auto-dependencies)
        shift
        AUTO_INSTALL_DEPENDENCIES=true
        ;;
    --auto-mongodb)
        shift
        AUTO_INSTALL_MONGODB=true
        ;;
    --auto-napcat)
        shift
        AUTO_INSTALL_NAPCAT=true
        ;;
    --auto-config)
        shift
        ;;
    --auto-proot)
        shift
        AUTO_INSTALL_PROOT=true
        ;;
    --isolate-database)
        shift
        ISOLATE_DATABASE=true
        ;;
    --no-interact)
        shift
        INTERACTIVE=false
        ;;
    *)
        :
        ;;
    esac
    TODO "参数解析"
fi
###
Original_Users_HOME="${Original_Users_HOME:-"${HOME}"}"
MaiM_HOME="${MaiM_HOME:-${Original_Users_HOME}/.local/MaiM-with-u}"
MaiM_bin="${MaiM_bin:-"${MaiM_HOME}/bin"}"
if [[ "${BASHDB}" == "true" ]]; then
    :
    bash_whiptail
fi
if [[ "$0" == "${BASH_SOURCE}" ]]; then
    Main "$@"
fi

#下方的定位符用于确定proot.tar.gz的tail行数
#用于给环境受限的mt管理器等拥有运行权限的终端
#使用proot容器
# db.person_info.updateOne({ "user_id": "3617484699" }, { ${set}: { "relationship_value": 50 } });
#proot_executables_定位符
