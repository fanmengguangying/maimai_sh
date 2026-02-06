#!/usr/bin/env bash

# ========================================
# MaiBot 一键启动脚本
# ========================================

set -euo pipefail

# =============== 颜色定义 ===============
RED=$'\033[0;1;31;91m'
GREEN=$'\033[0;1;32;92m'
YELLOW=$'\033[0;1;33;93m'
BLUE=$'\033[0;1;34;94m'
MAGENTA=$'\033[0;1;35;95m'
CYAN=$'\033[0;1;36;96m'
NC=$'\033[0m'

# =============== 日志函数 ===============
log.info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
log.success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log.warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log.error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# =============== 配置读取 ===============
read_config() {
    local manual_qq="${1:-}"
    local config_file="${HOME}/.maibot_config"
    
    if [[ -f "${config_file}" ]]; then
        # shellcheck disable=SC1090
        source "${config_file}"
        log.info "已从 ${config_file} 读取配置"
    else
        log.warn "未找到配置文件 ${config_file}，请先运行部署脚本"
        if [[ -z "${manual_qq}" ]]; then
            return 1
        fi
    fi
    
    # 如果指定了 QQ 号，则覆盖配置文件中的值
    if [[ -n "${manual_qq}" ]]; then
        export NAPCAT_QQ="${manual_qq}"
        log.info "使用指定的 QQ 号: ${NAPCAT_QQ}"
    fi
    
    # 验证 QQ 号
    if [[ -z "${NAPCAT_QQ:-}" ]]; then
        log.error "未指定 QQ 号，请使用: $0 [QQ号] {start|stop|restart|status}"
        return 1
    fi
}

# =============== 检查依赖 ===============
check_dependencies() {
    log.info "检查依赖环境..."
    
    local required_cmds=("python3" "napcat" "git")
    local missing_deps=()
    
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log.error "缺少依赖: ${missing_deps[*]}"
        log.info "请先运行部署脚本: bash MaiBot_deploy.sh"
        return 1
    fi
    
    log.success "所有依赖已就绪"
    return 0
}

# =============== 启动 NapCat ===============
start_napcat() {
    log.info "正在启动 NapCat..."
    
    if [[ -z "${NAPCAT_QQ:-}" ]]; then
        log.error "未设置 NAPCAT_QQ 环境变量"
        return 1
    fi
    
    # 检查 napcat 是否已在运行
    if pgrep -f "qq --no-sandbox -q ${NAPCAT_QQ}" &>/dev/null; then
        log.warn "NapCat (QQ: ${NAPCAT_QQ}) 已在运行"
        return 0
    fi
    
    # 启动 NapCat
    napcat start "${NAPCAT_QQ}" || {
        log.error "NapCat 启动失败"
        return 1
    }
    
    log.success "NapCat 已启动 (QQ: ${NAPCAT_QQ})"
    sleep 3
    
    return 0
}

# =============== 启动 MaiBot ===============
start_maibot() {
    log.info "正在启动 MaiBot..."
    
    local maibot_dir="${HOME}/.local/MaiM-with-u/MaiBot"
    
    if [[ ! -d "${maibot_dir}" ]]; then
        log.error "MaiBot 目录不存在: ${maibot_dir}"
        log.info "请先运行部署脚本: bash MaiBot_deploy.sh"
        return 1
    fi
    
    cd "${maibot_dir}" || return 1
    
    # 检查是否已运行
    if pgrep -f "python3.*bot.py" &>/dev/null; then
        log.warn "MaiBot 已在运行"
        return 0
    fi
    
    # 检查配置文件
    if [[ ! -f "./config/bot_config.toml" ]]; then
        log.error "MaiBot 配置文件不存在"
        return 1
    fi
    
    # 后台启动 MaiBot
    nohup python3 bot.py > "${HOME}/.local/MaiM-with-u/MaiBot/logs/bot.log" 2>&1 &
    local pid=$!
    
    log.success "MaiBot 已启动 (PID: ${pid})"
    sleep 2
    
    return 0
}

# =============== 启动适配器 ===============
start_adapter() {
    log.info "正在启动 MaiBot-Napcat-Adapter..."
    
    local adapter_dir="${HOME}/.local/MaiM-with-u/MaiBot-Napcat-Adapter"
    
    if [[ ! -d "${adapter_dir}" ]]; then
        log.error "Adapter 目录不存在: ${adapter_dir}"
        log.info "请先运行部署脚本: bash MaiBot_deploy.sh"
        return 1
    fi
    
    cd "${adapter_dir}" || return 1
    
    # 检查是否已运行
    if pgrep -f "python3.*main.py" &>/dev/null; then
        log.warn "Adapter 已在运行"
        return 0
    fi
    
    # 检查配置文件
    if [[ ! -f "./config.toml" ]]; then
        log.error "Adapter 配置文件不存在"
        return 1
    fi
    
    # 后台启动适配器
    nohup python3 main.py > "${HOME}/.local/MaiM-with-u/MaiBot-Napcat-Adapter/logs/adapter.log" 2>&1 &
    local pid=$!
    
    log.success "Adapter 已启动 (PID: ${pid})"
    sleep 2
    
    return 0
}

# =============== 停止服务 ===============
stop_services() {
    log.info "正在停止所有服务..."
    
    # 停止 MaiBot
    if pgrep -f "python3.*bot.py" &>/dev/null; then
        pkill -f "python3.*bot.py"
        log.success "MaiBot 已停止"
    fi
    
    # 停止 NapCat
    if [[ -n "${NAPCAT_QQ:-}" ]]; then
        napcat stop "${NAPCAT_QQ}" 2>/dev/null || true
        log.success "NapCat 已停止"
    fi
	# 停止适配器
	if pgrep -f "python3.*main.py" &>/dev/null; then
		pkill -f "python3.*main.py"
		log.success "Adapter 已停止"
	fi
    
    log.success "所有服务已停止"
}

# =============== 查看状态 ===============
show_status() {
    log.info "=== 服务运行状态 ==="
    
    # 检查 NapCat
    if [[ -n "${NAPCAT_QQ:-}" ]]; then
        if napcat status "${NAPCAT_QQ}" 2>/dev/null | grep -q "${NAPCAT_QQ}"; then
            echo -e "${GREEN}[OK]${NC} NapCat 运行中 (QQ: ${NAPCAT_QQ})"
        else
            echo -e "${RED}[X]${NC} NapCat 未运行"
        fi
    fi
    
    # 检查 MaiBot
    if pgrep -f "python3.*bot.py" &>/dev/null; then
        echo -e "${GREEN}[OK]${NC} MaiBot 运行中"
    else
        echo -e "${RED}[X]${NC} MaiBot 未运行"
    fi
    
    # 检查 Adapter
    if pgrep -f "python3.*main.py" &>/dev/null; then
        echo -e "${GREEN}[OK]${NC} Adapter 运行中"
    else
        echo -e "${RED}[X]${NC} Adapter 未运行"
    fi
    
    echo ""
}

# =============== 查看日志 ===============
show_logs() {
    local service="${1:-}"
    
    case "${service}" in
        napcat)
            if [[ -n "${NAPCAT_QQ:-}" ]]; then
                napcat log "${NAPCAT_QQ}"
            else
                log.error "未设置 NAPCAT_QQ"
            fi
            ;;
        maibot)
            local maibot_log="${HOME}/.local/MaiM-with-u/MaiBot/logs/bot.log"
            if [[ -f "${maibot_log}" ]]; then
                tail -f "${maibot_log}"
            else
                log.error "MaiBot 日志文件不存在"
            fi
            ;;
        adapter)
            local adapter_log="${HOME}/.local/MaiM-with-u/MaiBot-Napcat-Adapter/logs/adapter.log"
            if [[ -f "${adapter_log}" ]]; then
                tail -f "${adapter_log}"
            else
                log.error "Adapter 日志文件不存在"
            fi
            ;;
        *)
            log.info "请指定服务: napcat|maibot|adapter"
            ;;
    esac
}

# =============== 帮助信息 ===============
show_help() {
    cat << EOF
${MAGENTA}MaiBot 启动脚本${NC}

${CYAN}用法:${NC}
  $0 [QQ号] {start|stop|restart|status|logs} [service]
  $0 {start|stop|restart|status|logs} [service]

${CYAN}命令:${NC}
  start [service]      启动服务 (不指定则启动全部)
  stop                 停止所有服务
  restart [service]    重启服务 (不指定则重启全部)
  status               查看所有服务状态
  logs [service]       查看服务日志 (napcat|maibot|adapter)
  help                 显示此帮助信息

${CYAN}示例 - 使用配置文件中的 QQ 号:${NC}
  $0 start              # 启动所有服务
  $0 start napcat      # 仅启动 NapCat
  $0 status            # 查看状态
  $0 logs maibot       # 查看 MaiBot 日志

${CYAN}示例 - 手动指定 QQ 号:${NC}
  $0 2220109544        # 使用指定 QQ 号启动所有服务
  $0 2220109544 start  # 同上
  $0 2220109544 start napcat   # 使用指定 QQ 号仅启动 NapCat
  $0 2220109544 stop   # 使用指定 QQ 号停止所有服务
  $0 2220109544 status # 查看指定 QQ 号的服务状态

EOF
}

# =============== 主函数 ===============
main() {
    local arg1="${1:-}"
    local arg2="${2:-}"
    local arg3="${3:-}"
    local cmd="start"
    local qq_num=""
    local service="all"
    
    # 参数解析：支持多种调用方式
    # maimai [QQ] [command] [service]
    # maimai [command] [service]
    if [[ "${arg1}" =~ ^[0-9]{5,11}$ ]]; then
        # 第一个参数是 QQ 号
        qq_num="${arg1}"
        cmd="${arg2:-start}"
        service="${arg3:-all}"
    else
        # 第一个参数是命令
        cmd="${arg1:-start}"
        service="${arg2:-all}"
    fi
    
    # 读取配置（如果指定了 QQ 号则覆盖）
    if ! read_config "${qq_num}"; then
        return 1
    fi
    
    case "${cmd}" in
        start)
            log.info "启动 MaiBot 服务..."
            check_dependencies || return 1
            
            case "${service}" in
                all)
                    start_napcat && start_maibot && start_adapter
                    ;;
                napcat)
                    start_napcat
                    ;;
                maibot)
                    start_maibot
                    ;;
                adapter)
                    start_adapter
                    ;;
                *)
                    log.error "未知的服务: ${service}"
                    return 1
                    ;;
            esac
            
            log.success "启动完成！"
            show_status
            ;;
            
        stop)
            stop_services
            ;;
            
        restart)
            log.info "重启 MaiBot 服务..."
            stop_services
            sleep 2
            
            case "${service}" in
                all)
                    start_napcat && start_maibot && start_adapter
                    ;;
                napcat)
                    start_napcat
                    ;;
                maibot)
                    start_maibot
                    ;;
                adapter)
                    start_adapter
                    ;;
                *)
                    log.error "未知的服务: ${service}"
                    return 1
                    ;;
            esac
            
            log.success "重启完成！"
            show_status
            ;;
            
        status)
            show_status
            ;;
            
        logs)
            show_logs "${service}"
            ;;
            
        help)
            show_help
            ;;
            
        *)
            log.error "未知命令: ${cmd}"
            show_help
            return 1
            ;;
    esac
}

# 执行主函数
main "$@"
