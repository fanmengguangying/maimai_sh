#!/bin/bash

# shellcheck disable=SC2004
# shellcheck disable=SC2317
# shellcheck disable=SC2059
# shellcheck disable=SC2086

# set +x
SCREEN_BUFFER=()
SCREEN=""
declare -A SCREEN_REGIONS # 区域存储
__ABOUTRESET="false"
__DISPLAY_IFS=$'\u2063'   # 足够独特 # 作为IFS的分隔符，避免与其他字符冲突
__REGION_PREFIX="SCREEN:" # 用于标识区域的前缀，避免与其他内容冲突
append_to_screen() {
    # shellcheck disable=SC2190
    SCREEN_BUFFER+=("$1")
}

COORD_PATTERN='^~?[-0-9]+$'
RELATIVE_PATTERN='^~(-?[0-9]+)$'
pass() {
    true
}
# true <<'DISPLAY_HELP'
# display 终端显示控制工具
#
# 基本命令:
#   cursor-hide       隐藏光标
#   cursor-show       显示光标
#   screen-clear      清屏
#   screen-save       保存当前屏幕内容
#   screen-restore    恢复保存的屏幕内容
#   line-clear <行>   清除指定行
#   cursor-move <行> <列> 移动光标(支持相对坐标 ~5)
#   get-screen-size [rows|cols|p] 获取屏幕大小
#   get-cursor-position [row|col|p] 获取光标位置
#   cursor-save       保存光标位置
#   cursor-restore    恢复光标位置     
#   printf、echo <文本>       输出文本
#   repeat <字符串> <次数> 重复字符串
#   region-save <名称> 保存区域
#   region-restore <名称> 恢复区域
#   reset             重置显示状态
#   update [--fd <fd>=1]            输出所有更改
#   help           显示帮助信息
#
# 样式控制:
#   color [--fg <色>] [--bg <色>] 设置颜色
#   style <bold|dim|italic|underline|blink|inverse|reset> 设置文本样式
#
#
# 使用示例:
#   display cursor-move 5 10
#   display color --fg 31 --bg 40  # 红字黑底
#   display style bold
#   display echo "重要消息!"
#   display update
#
#   get_choice(){
#   display printf "请选择操作: " update --fd 2
#   read -r choice
#   display reset screen printf "你选择了:$choice" update --fd 2
#      echo "$choice"
#   }
#   ret="$(get_choice)" --输入1
#   echo "$ret" --输出1
# DISPLAY_HELP
display() {
    local __DISPLAY_DEBUG_COMMANDS="$*"
    local __DISPLAY_DEBUG__="$1"
    __DISPLAY_DEBUG__="${__DISPLAY_DEBUG__:-'false'}"
    [[ "$1" == "true" || "false" == "$1" ]] && shift
    # unset __DISPLAY_DEBUG__
    while [[ "$#" -gt 0 ]]; do
        local subcommand="${1:-help}"
        case "${subcommand}" in
        "wait") #-> Nothing
            #)
            shift 1
            sleep "$1"
            shift 1
            ;;
        "cursor-hide") #-> Nothing
            #)
            shift
            append_to_screen $'\033[?25l' # 隐藏光标
            ;;
        "cursor-show") #-> Nothing
            #)
            shift
            append_to_screen $'\033[?25h' # 恢复光标
            ;;
        "cursor-move") # -> Nothing
            #)
            shift
            if [[ $# -lt 2 ]]; then
                printf "错误：cursor-move 需要两个参数" >&2
                return 1
            fi
            local row="${1}"
            shift
            local col="${1}"
            shift
            if ! [[ "${row}" =~ ${COORD_PATTERN} && "${col}" =~ ${COORD_PATTERN} ]]; then
                printf "错误：cursor-move 需要整数参数" >&2
                return 1
            fi

            # 处理相对坐标 - 支持双相对坐标
            local row_is_relative=false
            local col_is_relative=false
            local row_offset=0
            local col_offset=0

            # 检查col是否为相对坐标
            if [[ "${col}" =~ ${RELATIVE_PATTERN} ]]; then
                col_is_relative=true
                col_offset=${BASH_REMATCH[1]}
            fi

            # 检查y是否为相对坐标
            if [[ "${row}" =~ ${RELATIVE_PATTERN} ]]; then
                row_is_relative=true
                row_offset=${BASH_REMATCH[1]}
            fi

            # 根据相对坐标类型生成移动序列
            # row col分别为行和列的绝对位置
            if [[ "${col_is_relative}" == true && "${row_is_relative}" == true ]]; then
                # 双相对坐标：先垂直移动，再水平移动
                if ((row_offset != 0)); then
                    if ((row_offset > 0)); then
                        append_to_screen "$(printf '\033[%sB' "${row_offset}")"
                    else
                        append_to_screen "$(printf '\033[%sA' "${row_offset#-}")"
                    fi
                fi
                if ((col_offset != 0)); then
                    if ((col_offset > 0)); then
                        # 向上相对移动的esc控制序列是： \033[5A
                        append_to_screen "$(printf '\033[%sC' "${col_offset}")"
                    else
                        append_to_screen "$(printf '\033[%sD' "${col_offset#-}")"
                    fi
                fi
            elif [[ "${row_is_relative}" == true ]]; then
                if ((row_offset > 0)); then
                    append_to_screen "$(printf '\033[%sB' "${row_offset}")"
                else
                    append_to_screen "$(printf '\033[%sA' "${row_offset#-}")"
                fi
            elif [[ "${col_is_relative}" == true ]]; then
                if ((col_offset > 0)); then
                    append_to_screen "$(printf '\033[%sC' "${col_offset}")" #  如果col_offset大于0，则向右移动col_offset个字符
                else
                    append_to_screen "$(printf '\033[%sD' "${col_offset#-}")" #  如果col_offset小于0，则向左移动col_offset个字符
                fi
            else
                # 绝对坐标
                append_to_screen "$(printf '\033[%s;%sH' "${row}" "${col}")" #  向第row行第col列移动
                # 我要移动到第三行第五列的esc控制符是： \033[3;5H
            fi
            ;;
        "cursor-movement")
            shift
            local __ACTION_UP="__ACTION_UP"
            local __ACTION_DOWN="__ACTION_DOWN"
            local __ACTION_LEFT="__ACTION_LEFT"
            local __ACTION_RIGHT="__ACTION_RIGHT"
            local __ACTION_QUIT="__ACTION_QUIT"
            local __ACTION_ENTER="__ACTION_ENTER"
            local __ACTION_ESC="__ACTION_ESC"
            local __ACTION_LOOP="__ACTION_LOOP"
            local __ACTION_INIT="__ACTION_INIT"
            local __CASE_KEY
            local CURSOR_MOVEMENT_FD=1
            local debug=false
            local button
            local cursor_old_stty
            local cursor_old_trap
            local __POS
            local __INPUTS=()
            __ACTION_UP() {
                display cursor-move "~-1" "~0" update --fd "$CURSOR_MOVEMENT_FD"
            }
            __ACTION_DOWN() {
                display cursor-move "~1" "~0" update --fd "$CURSOR_MOVEMENT_FD"
            }
            __ACTION_LEFT() {
                display cursor-move "~0" "~-1" update --fd "$CURSOR_MOVEMENT_FD"
            }
            __ACTION_RIGHT() {
                display cursor-move "~0" "~1" update --fd "$CURSOR_MOVEMENT_FD"
            }
            __ACTION_QUIT() {
                # printf "结束"
                [[ -n "$cursor_old_stty" ]] && command -v stty >/dev/null 2>&1 && stty "$cursor_old_stty"
            }
            __ACTION_ENTER() {
                return 0
            }
            __ACTION_ESC() {
                return 1
            }
            __ACTION_LOOP() {
                true
            }
            __ACTION_INIT() {
                command -v stty >/dev/null 2>&1 && cursor_old_stty="$(stty -g)" # 保存当前终端设置
                cursor_old_trap="$(trap -p EXIT)"                               # 保存当前的退出钩子
                # shellcheck disable=SC2064
                [[ -z "$cursor_old_trap" ]] && cursor_old_trap="true" # 如果没有设置退出钩子，则设置为默认的true
                trap "$cursor_old_trap;stty $cursor_old_stty" EXIT    # 恢复终端设置和退出钩子
                stty raw -echo                                        # 设置终端为原始模式
            }
            __ACTION_DEFAULT() {
                # 默认动作，处理其他按键
                local key="$1"
                if [[ -n "$key" ]]; then
                    __INPUTS+=("$key") # 将按键添加到输入数组
                fi
                return 0
            }
            # local loop
            local __ACTIONS
            local __ESC_ACTIONS
            local loop_enable="true" # 是否启用轮询
            local loop_time=0.1      # 轮询时间间隔
            local loop_setting=""
            declare -A __ACTIONS
            declare -A __ESC_ACTIONS
            # TODO 明天写！
            while [ "${#@}" -ge 2 ]; do
                case "$1" in
                --up)
                    shift
                    __ACTION_UP="${1:-__ACTION_UP}"
                    shift
                    ;;
                --down)
                    shift
                    __ACTION_DOWN="${1:-__ACTION_DOWN}"
                    shift
                    ;;
                --left)
                    shift
                    __ACTION_LEFT="${1:-__ACTION_LEFT}"
                    shift
                    ;;
                --right)
                    shift
                    __ACTION_RIGHT="${1:-__ACTION_RIGHT}"
                    shift
                    ;;
                --quit)
                    shift
                    __ACTION_QUIT="${1:-__ACTION_QUIT}"
                    shift
                    ;;
                --enter)
                    shift
                    __ACTION_ENTER="${1:-__ACTION_ENTER}"
                    shift
                    ;;
                --esc)
                    shift
                    __ACTION_ESC="${1:-__ACTION_ESC}"
                    shift
                    ;;
                --default)
                    shift
                    __ACTION_DEFAULT="${1:-__ACTION_DEFAULT}"
                    shift
                    ;;
                --loop)
                    shift
                    __ACTION_LOOP="${1:-__ACTION_LOOP}"
                    shift
                    ;;
                --loop_enable)
                    shift
                    loop_enable="${1:-true}"
                    shift
                    ;;
                --loop_time)
                    shift
                    loop_time="${1:-0.1}"
                    shift
                    ;;
                --init)
                    shift
                    __ACTION_INIT="${1:-__ACTION_INIT}"
                    shift
                    ;;
                --fd)
                    shift
                    local CURSOR_MOVEMENT_FD="${1:-1}" # 默认输出到标准输出
                    if [[ "$CURSOR_MOVEMENT_FD" =~ ^[0-9]+$ ]]; then
                        true
                    else
                        printf "错误: fd参数必须是一个数字！" >&2
                        exit 1
                    fi
                    shift
                    ;;
                --debug)
                    debug=true
                    shift
                    ;;
                --esc-key-*)
                    button="${1#--esc-key-}"
                    __ACTIONS["$button"]="$2"
                    printf "${button}注册了" >&2
                    shift 2
                    ;;
                --key-*)
                    button="${1#--key-}"
                    __ACTIONS["$button"]="$2"
                    printf "${button}注册了" >&2
                    shift 2
                    ;;
                *)
                    printf "未知选项: $1" >&2
                    exit 1
                    ;;
                esac
            done
            [[ "$loop_enable" == "true" ]] && loop_setting="-t $loop_time" # 控制是否轮询
            __CASE() {
                __CASE_KEY="$1"
                while true; do
                    case "$__CASE_KEY" in
                    "[" | "O")
                        IFS= read -r -s -n 1 ${loop_setting?} __CASE_KEY
                        continue
                        ;;
                    "A")
                        ((__movetimes++))
                        "$__ACTION_UP"
                        return $?
                        ;;
                    "B")
                        ((__movetimes++))
                        "$__ACTION_DOWN"
                        return $?
                        ;;
                    "C")
                        ((__movetimes++))
                        "$__ACTION_RIGHT"
                        return $?
                        ;;
                    "D")
                        ((__movetimes++))
                        "$__ACTION_LEFT"
                        return $?
                        ;;
                    *)
                        return 1
                        ;;
                    esac
                done
            }
            local __movetimes=0
            local key1 key2
            display region-save 'cursor-movement' reset screen 1>/dev/null 2>&1
            display cursor-move $(display get-cursor-position p) # 获取当前光标位置
            "$__ACTION_INIT" # 初始化动作
            while true; do
                # display cursor-save region-restore 'msgbox' cursor-restore
                if IFS= read -r -s -n 1 ${loop_setting?} key1; then
                    # 当read失败时表示普通轮询超时，当read成功时表示有输入，如此时key为空，则表示回车键
                    if [[ -z "$key1" ]]; then "$__ACTION_ENTER" || break; fi # 如不想退出函数请确保__ACTION_ENTER返回0
                fi
                if [[ "$key1" == $'\e' ]]; then
                    IFS= read -r -s -n 1 ${loop_setting?} key2 # 读取第二个字符
                    __CASE "$key2"
                    if [[ -z "$key2" ]]; then
                        "$__ACTION_ESC" || break
                    fi                                                  # 当$'\e'后没有字符时该键位ESC键 # 先触发ecs键动作，如不想退出函数请确保__ACTION_ESC返回0
                    "${__ESC_ACTIONS[$key2]:-__ACTION_DEFAULT}" "$key2" # 如果没有注册的动作则使用默认动作
                else
                    # pass(){ :; }
                    ${__ACTIONS[key1]:-'__ACTION_DEFAULT'} "$key1" # 写个屁posix反正我又不在sh运行
                fi
                if ((__movetimes > 100)); then
                    __POS="$(display get-cursor-position p)"
                    __IFS="$IFS"
                    IFS=' '
                    read -r row col <<<"$__POS"
                    IFS="$__IFS"
                    display region-restore 'cursor-movement' cursor-move "$row" "$col"
                    __movetimes=0
                fi
                "$__ACTION_LOOP"
                $debug && printf "按键: %q:%q\n" "$key1" "$key2" >&2
            done
            "$__ACTION_QUIT"
            return $?
            ;;
        "screen-clear" | "clear") #-> Nothing
            [[ "$__DISPLAY_DEBUG__" == "true" ]] && read -r -p "clear:按任意键继续" -n1 -s
            shift
            append_to_screen $'\033[2J'
            ;;
        "screen-save") # -> Nothing
            shift
            # ...需要检查$TERM降级操作 # 以后再说...
            append_to_screen $'\033[?1049h' #ds的ansl # 保存屏幕内容 需要update
            ;;
        "screen-restore") # -> Nothing
            shift
            append_to_screen $'\033[?1049l' #ds的anls # 恢复屏幕内容 需要update
            ;;
        "line-clear") # -> Nothing
            [[ "$__DISPLAY_DEBUG__" == "true" ]] && read -r -p "line-clear:按任意键继续" -n1 -s
            shift
            if [[ $# -lt 1 ]]; then
                printf "\033[2J 错误：line-clear 需要一个参数" >&2
                return 1
            fi
            local line="${1}"
            shift
            display cursor-save
            display cursor-move "${line}" 1
            append_to_screen $'\033[2K' # 修复清除行
            display cursor-restore
            ;;
        "get-cursor-position") # -> row or col or (row col)
            shift
            local row col

            # 优先使用 stty（更可靠）
            if command -v stty >/dev/null 2>&1; then
                # 保存当前终端设置
                local old_settings
                old_settings=$(stty -g)

                # 设置终端为原始模式
                stty raw -echo

                # 发送查询光标位置的ESC序列
                printf $'\e[6n' >/dev/tty

                # 读取响应
                local pos
                local response_raw=""
                local char

                # 逐字符读取直到遇到 'R'
                while IFS='' read -r -n 1 -t 2 char 2>/dev/null; do
                    response_raw+="$char"
                    [[ "$char" == "R" ]] && break
                done

                # 恢复终端设置
                stty "$old_settings"

                # 验证和解析响应
                if [[ "$response_raw" =~ ^\[([0-9]+)\;([0-9]+)R$ ]]; then
                    local row=$((${BASH_REMATCH[1]} - 1))
                    local col=$((${BASH_REMATCH[2]} - 1))

                    case "${1}" in
                    "row")
                        printf "$row"
                        return 0
                        ;;
                    "col")
                        printf "$col"
                        return 0
                        ;;
                    "p")
                        printf "$row $col"
                        return 0
                        ;;
                    esac
                else
                    # 尝试传统的数组解析方法（带验证）
                    if [[ "$response_raw" =~ \[([0-9]+)\;([0-9]+)R ]]; then
                        IFS=';' read -ra pos <<<"${BASH_REMATCH[1]};${BASH_REMATCH[2]}"
                        if [[ ${#pos[@]} -eq 2 ]] && [[ "${pos[0]}" =~ ^[0-9]+$ ]] && [[ "${pos[1]}" =~ ^[0-9]+$ ]]; then
                            local row=$((${pos[0]} - 0))
                            local col=$((${pos[1]} - 0))

                            case "${1}" in
                            "row")
                                printf "$row"
                                return 0
                                ;;
                            "col")
                                printf "$col"
                                return 0
                                ;;
                            "p")
                                printf "$row $col"
                                return 0
                                ;;
                            esac
                        else
                            printf "获取光标位置失败：数据格式错误" >&2
                            return 1
                        fi
                    else
                        printf "获取光标位置失败：响应格式不正确 ($response_raw)" >&2
                        return 1
                    fi
                fi
            else
                # 备用方法：使用原来的ESC序列方法（带验证）
                local pos
                # shellcheck disable=SC2034
                # shellcheck disable=SC2162
                printf $'\e[6n' >/dev/tty
                if IFS=';' read -s -d -r -R -a pos 2>/dev/null; then
                    # 验证数组内容
                    if [[ ${#pos[@]} -ge 2 ]] && [[ "${pos[0]}" =~ ^[^0-9]*([0-9]+)$ ]] && [[ "${pos[1]}" =~ ^[0-9]+$ ]]; then
                        local row_str="${BASH_REMATCH[1]}"
                        local col_str="${pos[1]}"

                        if [[ "$row_str" =~ ^[0-9]+$ ]] && [[ "$col_str" =~ ^[0-9]+$ ]]; then
                            local row=$((row_str - 1))
                            local col=$((col_str - 1))

                            case "${1}" in
                            "row")
                                printf "$row"
                                return 0
                                ;;
                            "col")
                                printf "$col"
                                return 0
                                ;;
                            "p")
                                printf "$row $col"
                                return 0
                                ;;
                            esac
                        else
                            printf "获取光标位置失败：数值格式错误" >&2
                            return 1
                        fi
                    else
                        printf "获取光标位置失败：响应数据不完整" >&2
                        return 1
                    fi
                else
                    printf "获取光标位置失败：无法读取响应" >&2
                    return 1
                fi
            fi
            shift
            ;;
        "get-screen-size") # -> rows or cols or (rows cols)
            shift
            local rows cols # 行数和列数
            # 优先使用 stty（更可靠）
            if command -v stty >/dev/null 2>&1; then
                read -r rows cols < <(stty size 2>/dev/null)
                if [[ -n "$rows" && -n "$cols" ]]; then
                    case "${1}" in
                    "rows")
                        printf "$rows"
                        return 0
                        ;;
                    "cols")
                        printf "$cols"
                        return 0
                        ;;
                    "p")
                        printf "$rows $cols"
                        return 0
                        ;;
                    esac
                    shift
                    return 0
                fi
            fi
            # 备用方法：ESC 序列（带超时）
            local size
            # shellcheck disable=SC2162
            if IFS=';' read -sdR -t 1 -p $'\e[18t' -a size 2>/dev/null; then
                local rows=${size[0]:2}
                local cols=${size[1]}
                case "${1}" in
                "rows")
                    printf "$rows"
                    return 0
                    ;;
                "cols")
                    printf "$cols"
                    return 0
                    ;;
                "p")
                    printf "$rows $cols"
                    return 0
                    ;;
                esac
            else
                printf "获取屏幕大小失败" >&2
                return 1
            fi
            shift
            ;;
        "cursor-save") # -> Nothing
            shift
            append_to_screen $'\033[s' # 保存光标位置
            ;;
        "cursor-restore") # -> Nothing
            shift
            append_to_screen $'\033[u' # 恢复光标位置
            ;;
        "printf" | "echo" | "write") # -> Nothing
            shift
            append_to_screen "$1"
            shift
            ;;
        "repeat") # -> Nothing
            shift
            [[ $# -lt 2 ]] && {
                printf "错误：需要字符串和重复次数" >&2
                return 1
            }

            local str="$1"
            local count="$2"
            shift 2

            # 分块处理提高性能
            local chunk_size=100
            local full_chunks=$((count / chunk_size))
            local remainder=$((count % chunk_size))

            local result=""
            for ((i = 0; i < full_chunks; i++)); do
                printf -v chunk "%${chunk_size}s" ""
                result+="${chunk// /$str}"
            done

            if ((remainder > 0)); then
                printf -v chunk "%${remainder}s" ""
                result+="${chunk// /$str}"
            fi

            append_to_screen "$result"
            ;;
        "color") # -> Nothing
            shift
            local fg=39 bg=49
            case "$1" in
            -f | --fg)
                fg="$2"
                shift 2
                ;;
            -b | --bg)
                bg="$2"
                shift 2
                ;;
            esac
            case "$1" in
            -f | --fg)
                fg="$2"
                shift 2
                ;;
            -b | --bg)
                bg="$2"
                shift 2
                ;;
            reset)
                append_to_screen $'\033[0m'
                shift
                ;;
            *)
                printf "错误：color 需要 -f 或 -b 参数\n" >&2
                return 1
                ;;
            esac
            append_to_screen "$(printf '\033[%s;%sm' "${fg}" "${bg}")"
            ;;
        "style") # -> Nothing
            shift
            case "$1" in
            bold) append_to_screen $'\033[1m' ;;
            dim) append_to_screen $'\033[2m' ;;
            italic) append_to_screen $'\033[3m' ;;
            underline) append_to_screen $'\033[4m' ;;
            blink) append_to_screen $'\033[5m' ;;
            inverse) append_to_screen $'\033[7m' ;;
            reset) append_to_screen $'\033[0m' ;;
            *)
                printf "未知样式: $1" >&2
                return 1
                ;;
            esac
            shift
            ;;
        "region-save") # -> Nothing
            shift
            __region_id="$1"
            shift
            # 我需要一个唯一分隔符，用于region-restore重新初始化缓冲区
            # SCREEN_REGIONS["$region_id"]="$(display update)" # 不可以，有风险
            __IFS="$IFS"
            IFS="$__DISPLAY_IFS"
            # set -x
            # _="${__REGION_PREFIX}${SCREEN_BUFFER[*]:-}"
            # set +x
            SCREEN_REGIONS["$__region_id"]="${__REGION_PREFIX}${SCREEN_BUFFER[*]:-}"
            IFS="$__IFS"
            ;;
        "region-restore") # -> Nothing
            shift
            __region_id="$1"
            shift
            region="${SCREEN_REGIONS["$__region_id"]}"
            if [[ -n "$region" ]]; then
                # 检查是否以区域前缀开头
                # set -x
                if [[ "${region:0:${#__REGION_PREFIX}}" != "${__REGION_PREFIX}" ]]; then
                    printf "区域ID '%s' 格式错误!" "$__region_id" >&2
                    # set +x
                    return 1
                fi
                # set +x
                # 去掉区域前缀
                region="${region:${#__REGION_PREFIX}}"
                __IFS="$IFS"
                IFS="$__DISPLAY_IFS"
                read -ra SCREEN_BUFFER <<<"$region"
                IFS="$__IFS"
            else
                printf "未找到区域: $__region_id" >&2
                # display reset screen # 改为空
                return 1
            fi
            ;;
        "reset") # -> Nothing
            shift
            case "$1" in
            "screen")
                SCREEN_BUFFER=()
                SCREEN=""
                shift
                ;;
            "region")
                # declare -A SCREEN_REGIONS # 区域存储
                SCREEN_REGIONS=()
                shift
                ;;
            *)
                SCREEN=""
                SCREEN_BUFFER=()
                SCREEN_REGIONS=()
                declare -A SCREEN_BUFFER=()
                declare -A SCREEN_REGIONS=()
                if [[ "$__ABOUTRESET" != "true" ]]; then
                    printf "DISPLAY:你重置了所有SCREEN相关！\n" >>"$HOME/.display.log" 2>/dev/null || true

                    # 退出时显示你干了什么鬼事！
                    local OTRAP
                    OTRAP="$(trap -p EXIT)"
                    printf "[$(date +"%Y-%m-%d %H:%M:%S")]DISPLAY:原EXIT trap: %s" "$OTRAP" >>"$HOME/.display.log"
                    if [[ -n "$OTRAP" ]]; then
                        local original_cmd
                        original_cmd="${OTRAP#*\'}"
                        original_cmd="${original_cmd%\'*}"
                        [[ -z "$original_cmd" ]] && original_cmd="true"
                        # shellcheck disable=SC2064
                        trap "${original_cmd}; grep 'DISPLAY' $HOME/.display.log 2>/dev/null || true" EXIT 2>/dev/null || true
                    else
                        trap "grep 'DISPLAY' $HOME/.display.log 2>/dev/null || true" EXIT 2>/dev/null || true
                    fi
                    __ABOUTRESET="true"
                else
                    :
                fi
                ;;
            esac
            # declare -gA SCREEN_REGIONS=()
            ;;
        "update")                                                                      # -> Nothing # 大部分情况下你不应该使用"$(display update)"
            [[ "$__DISPLAY_DEBUG__" == "true" ]] && read -r -p "update:按任意键继续" -n 1 -s #
            # update默认输出到stdout,但是可以显式指定fd
            shift
            local SCREEN
            local FD=1
            if [ "${1}" == "--fd" ]; then
                shift
                if [[ -n "$1" && "$1" =~ ^[0-9]+$ ]]; then
                    FD="$1"
                    shift
                else
                    printf "错误：update 需要一个有效的文件描述符\n" >&2
                    return 1
                fi
            fi
            __IFS="$IFS"
            IFS=''
            # [[ -z "$SCREEN" ]] && SCREEN="${SCREEN_BUFFER[*]}" # 会忽略region-restore后面的新输出，放弃
            SCREEN="${SCREEN_BUFFER[*]}"
            # shellcheck disable=SC2059
            printf "%s" "${SCREEN}" >&"$FD"
            IFS="$__IFS"
            ;;
        "help") # -> Nothing
            shift
            show_usage
            return 0
            ;;
        *)                                                                                                                  # -> Unknown command
            [[ "$__DISPLAY_DEBUG__" == "true" ]] && read -r -p "未知命令($subcommand):[$__DISPLAY_DEBUG_COMMANDS]按任意键继续" -n1 -s #
            printf "未知命令: %s\n" "$subcommand" >&2
            show_usage
            return 1
            ;;
        esac
    done
    # set +x
}

show_usage() {
    cat <<'DISPLAY_HELP'
display 终端显示控制工具

基本命令:
  cursor-hide       隐藏光标
  cursor-show       显示光标
  screen-clear      清屏
  screen-save       保存当前屏幕内容
  screen-restore    恢复保存的屏幕内容
  line-clear <行>   清除指定行
  cursor-move <行> <列> 移动光标(支持相对坐标 ~5)
  get-screen-size [rows|cols|p] 获取屏幕大小
  get-cursor-position [row|col|p] 获取光标位置
  cursor-save       保存光标位置
  cursor-restore    恢复光标位置     
  printf、echo <文本>       输出文本
  repeat <字符串> <次数> 重复字符串
  region-save <名称> 保存区域
  region-restore <名称> 恢复区域
  reset             重置显示状态
  update [--fd <fd>=1]            输出所有更改
  help           显示帮助信息

样式控制:
  color [--fg <色>] [--bg <色>] 设置颜色
  style <bold|dim|italic|underline|blink|inverse|reset> 设置文本样式


使用示例:
  display cursor-move 5 10
  display color --fg 31 --bg 40  # 红字黑底
  display style bold
  display echo "重要消息!"
  display update

  get_choice(){
  display printf "请选择操作: " update --fd 2
  read -r choice
  display reset screen printf "你选择了:$choice" update --fd 2
     echo "$choice"
  }
  ret="$(get_choice)" --输入1
  echo "$ret" --输出1
DISPLAY_HELP
}
false && display
#################
# Get-StringDisplayWidth() {
#     local str="$1"
#     local width=0
#     local char

#     # 使用while循环逐个字符处理
#     while IFS='' read -r -n 1 char; do
#         wcwidth "${char}"
#         ((width += $?))
#     done <<<"${str}"

#     echo "${width}"
# }
Get-StringDisplayWidth() {
    local str="$1"
    local width=0
    local i=0
    local len=${#str}
    local char code
    # 直接遍历字符串，避免read的I/O开销
    while ((i < len)); do
        char="${str:$i:1}"
        [[ -z "$char" ]] && {
            ((i++))
            continue
        }
        # 内联wcwidth逻辑，避免函数调用
        printf -v code '%d' "'$char"
        # 全角字符检测
        if ((code >= 0x4E00 && code <= 0x9FFF || \
            code >= 0x3400 && code <= 0x4DBF || \
            code >= 0x20000 && code <= 0x2A6DF || \
            code >= 0x3040 && code <= 0x309F || \
            code >= 0x30A0 && code <= 0x30FF || \
            code >= 0xAC00 && code <= 0xD7AF || \
            code >= 0x3000 && code <= 0x303F || \
            code >= 0xFF00 && code <= 0xFFEF)); then
            ((width += 2))
        elif [[ "$char" == $'\t' ]]; then
            ((width += 4))
        else
            ((width += 1))
        fi
        ((i++))
    done
    echo "$width"
}
# 不写为函数是为了省去函数调用的性能损失，开发时请编辑函数未展开的脚本