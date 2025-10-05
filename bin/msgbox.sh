#!/bin/bash

# shellcheck source="./display.sh"
# shellcheck disable=SC1091
# shellcheck disable=SC2155
# shellcheck disable=SC2059

source "./display.sh"
true <<'DISPLAY_HELP'
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

msgbox_background() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --backtitle)
            backtitle="$2"
            shift 2
            ;;
        *)
            echo "未知选项: $1"
            exit 1
            ;;
        esac
    done
    display region-save 'screen' reset screen screen-save update --fd 1 region-restore 'screen' 2>/dev/null
    display cursor-hide
    display false \
        color -f 32 -b 44 \
        clear \
        cursor-move 1 1 \
        printf "$backtitle" \
        cursor-move 999999 1 \
        printf "凡梦光影：按ESC键继续..."
}

debug() {
    [[ "$1" == false || "$1" == true ]] && [[ "$1" == true ]] && readarg="-t 10" || readarg="-t 0.01"
    local __IFS="$IFS"
    local IFS=' '
    local ALLINFO="$*"
    local row col rows cols
    read -r row col <<<"$(display get-cursor-position p)"
    read -r rows cols <<<"$(display get-screen-size p)"
    display region-save 'msgbox.back' reset screen
    local IFS="$__IFS"
    # 在屏幕中央下方显示调试信息
    display cursor-move "$((rows - 2))" "$((cols / 2 - ${#ALLINFO} / 2))" \
        color -f 37 -b 40 printf "row,col:$row,$col 调试信息: $ALLINFO" cursor-move "$row" "$col" update --fd 1
    display region-restore 'msgbox.back'
    read -r ${readarg?}
}

msgbox_process_dialog() {
    local dialog_type="$1"
    local text="$2"
    local height="$3"
    local width="$4"
    local menu_height="$5"
    shift 5

    # echo "===== 对话框类型: $dialog_type ====="
    # echo "标题: $title"
    # echo "背景标题: $backtitle"
    # echo "文本: $text"
    # echo "高度: $height"
    # echo "宽度: $width"
    # echo "菜单高度: $menu_height"
    # echo "默认项: ${default_item:-无}"
    # echo "默认选否: $defaultno"
    # echo "完整按钮: $fullbuttons"
    # echo "无取消按钮: $nocancel"
    # debug "处理对话框: $dialog_type" \
    #     "文本: $text" \
    #     "高度: $height" \
    #     "宽度: $width" \
    #     "菜单高度: $menu_height" \
    #     "项目数量: $#" \
    #     "项目内容: $*"
    local count=0

    if [[ "$dialog_type" == "--checklist" || "$dialog_type" == "--radiolist" ]]; then
        # 三项一组: tag item status
        while [[ $# -ge 3 ]]; do
            local tag="$1"
            local item="$2"
            local status="$3"
            shift 3

            printf "[%s] %-15s %-25s 状态: %s\n" \
                "$([[ "$status" == "on" ]] && echo "X" || echo " ")" \
                "$tag" "$item" "$status"
            ((count++))
        done
    else
        ### width
        # local args=("$@") # 更改传值方式使用local -n
        local __max_item_length=0
        local __max_tag_length=0
        local __tag_length=0
        local __item_length=0
        local count=0
        local __tag_lengths=()
        local __item_lengths=()
        local __item_count=0
        local __tags=()
        local __items=()
        while [[ $# -ge 2 ]]; do
            # tag=$1  item=$2  shift 2
            __tag_length="$(Get-StringDisplayWidth "$1")"
            __item_length="$(Get-StringDisplayWidth "${2:-$default_item}")"
            __tags+=("$1")
            __items+=("$2")
            __tag_lengths+=("$__tag_length")
            __item_lengths+=("$__item_length")
            if ((__item_length > __max_item_length)); then
                __max_item_length="$__item_length"
            fi
            if ((__tag_length > __max_tag_length)); then
                __max_tag_length="$__tag_length"
            fi
            shift 2
            ((__item_count++))
        done
        [[ $# -eq 1 ]] && echo "错误: 传入的菜单参数数量不正确，不为偶数！" && return 1
        local __max_length=0
        __max_length=$((__max_item_length + __max_tag_length + 1)) # +1是为了给tag和item之间留一个空格
        # width==0 # 为0则标识自适应，否则为固定宽度。其中自适应模式下，与边界距离为10
        if [[ "$width" == 0 || "$width" -lt $((__max_length + 22)) ]]; then
            width="$((__max_length + 22))" # +22是为了给左右边界各留10个空格的空间
        elif [[ $((__max_length + 22)) -lt "$width" ]]; then
            # width="$width"
            :
        fi
        ### width

        ### height
        __divide_text_add() {
            # 局部变量声明
            local __menu_text_lenth=0
            local __menu_text_width=0
            local __menu_text_next_lenth=0
            local __menu_text_next_width=0
            local __menu_text="$1"
            local __menu_text_next
            local width=$((width - 4)) # 可用宽度
            # 计算当前文本的显示宽度和字符长度
            __menu_text_width="$(Get-StringDisplayWidth "$__menu_text")"
            __menu_text_lenth="${#__menu_text}"
            # 检查文本是否超过可用宽度
            if ((__menu_text_width > width)); then
                # 初始化二分法变量
                local __cut_positon=$((__menu_text_lenth / 2)) # 初始截取位置（文本长度一半）
                local __abs=$((__cut_positon / 2))             # 初始步长（截取位置的一半）
                # 二分法循环寻找最佳截取位置
                while true; do
                    # 截取测试文本并计算其宽度
                    local __cutted_menu_text_test="${__menu_text:0:__cut_positon}"
                    local __cutted_menu_text_width="$(Get-StringDisplayWidth "$__cutted_menu_text_test")"
                    # 调整截取位置
                    if ((__cutted_menu_text_width > width)); then
                        __cut_positon=$((__cut_positon - __abs)) # 太宽，向左移动
                    elif ((__cutted_menu_text_width < width - 3)); then
                        __cut_positon=$((__cut_positon + __abs)) # 太窄，向右移动
                    else
                        break # 找到合适位置，退出循环
                    fi
                    __abs=$((__abs / 2)) # 缩小步长
                done
                # 执行最终截取
                local __cutted_menu_text="${__menu_text:0:__cut_positon}"
                __menu_texts+=("$__cutted_menu_text") # 添加截取部分到结果数组
                # 准备剩余文本
                __menu_text_next="${__menu_text:__cut_positon}"
                # 计算剩余文本的长度和宽度
                __menu_text_next_width="$(Get-StringDisplayWidth "$__menu_text_next")"
                __menu_text_next_lenth="${#__menu_text_next}"
                # 处理剩余文本
                if ((__menu_text_next_width > width)); then
                    __divide_text_add "$__menu_text_next" # 递归处理剩余文本
                else
                    __menu_texts+=("$__menu_text_next") # 直接添加剩余文本
                fi
                # 增加行计数
                ((__menu_text_count++))
            else
                # 文本未超宽，直接添加
                __menu_texts+=("$__menu_text")
            fi
            # 增加总行计数
            ((__menu_text_count++))
        }
        local __menu_texts=()
        local __texts=()
        local __menu_text
        local __menu_text_count=0
        mapfile -t __texts <<<"$(echo -e "$text")" # 分割原始文本为行数组
        for __menu_text in "${__texts[@]}"; do
            [ -n "$__menu_text" ] && __divide_text_add "$__menu_text"
            # echo "'$__menu_text'" >&2 # 调试输出
        done
        # read -r
        # 简直雷打不动！
        height=$((menu_height + 2 + __menu_text_count + 1 + 2 + 1)) # 允许的选项数 + 上下底 + 文本换行 + 文本与菜单之间的空行 + 菜单与按钮的空行 + 按钮与底部的空行
        if [[ $menu_height -eq 0 ]]; then
            # menu_hight == 0 # 则标识自适应高度
            #############选项数#######上下底##文本换行##文本与菜单之间的空行##菜单与按钮的空行##按钮与底部的空行#
            height=$((__item_count + 2 + __menu_text_count + 1 + 2 + 1))
        fi
        ### height
        boxmsg_menu --title "$title" \
            --height "$height" \
            --width "$width" \
            --menu __menu_texts \
            --menu_height "$menu_height" \
            --tag_lengths __tag_lengths \
            --item_lengths __item_lengths \
            --max_tag_length "$__max_tag_length" \
            --tags __tags \
            --items __items
        local __STATUS=$?
        return "$__STATUS"
    fi
}

boxmsg_menu() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --title)
            local title="$2"
            shift 2
            ;;
        --width)
            local width="$2"
            shift 2
            ;;
        --height)
            local height="$2"
            shift 2
            ;;
        --menu)
            local -n menu_texts="$2"
            shift 2
            ;;
        --menu_height)
            local menu_height="$2"
            shift 2
            ;;
        --max_tag_length)
            local __max_tag_length="$2"
            shift 2
            ;;
        --tag_lengths)
            local -n tag_lengths="$2"
            shift 2
            ;;
        --item_lengths)
            local -n item_lengths="$2"
            shift 2
            ;;
        --tags)
            local -n tags="$2"
            shift 2
            ;;
        --items)
            local -n items="$2"
            shift 2
            ;;
        *)
            break
            ;;
        esac
    done
    #######计算########
    local __IFS="$IFS"
    local IFS=' '
    read -r rows cols <<<"$(display get-screen-size p)"
    local IFS="$__IFS"
    local rows="${rows:-24}"
    local cols="${cols:-80}"

    local title_length
    title_length="$(Get-StringDisplayWidth "$title")"
    title_length="${title_length:-0}"

    local left_pending=$((((width - title_length) / 2) - 3))
    local right_pending=$((width - title_length - left_pending - 6))
    ((left_pending < 0)) && left_pending=0
    ((right_pending < 0)) && right_pending=0
    local title_bar_length="$((left_pending + title_length + right_pending + 2))"
    local title_start_col=$(((cols - title_bar_length) / 2))
    local title_start_row=$(((rows - height) / 2))
    ########计算结束########
    # 白底红字是：color -f 31 -b 47
    # 白底黑字是：color -f 30 -b 47
    # 蓝底白字是：color -f 37 -b 44
    ########绘制标题行开始########
    display cursor-move "$title_start_row" "$title_start_col" cursor-save
    display color -f 30 -b 47 \
        printf "┌" \
        repeat "─" "$left_pending" \
        printf "┤ " \
        color -f 31 -b 47 \
        printf "$title" \
        color -f 30 -b 47 \
        printf " ├" \
        repeat "─" "$right_pending" \
        printf "┐" \
        cursor-restore \
        cursor-move "~1" "~0"
    #######绘制标题行结束###########
    # 换行 # 我需要一个函数用来给msgbox换行，这个函数就叫：msgbox_newline
    msgbox_newline() {
        local newline="${1:-''}"
        display cursor-save \
            color -f 30 -b 47 \
            printf "│" \
            repeat " " "$((width - 2))" \
            printf "│" \
            color -f 37 -b 40 \
            printf ' ' \
            cursor-restore
        [[ "$newline" != '-n' ]] && display cursor-move "~1" "~0"
    }
    false && msgbox_newline -n
    # 黑底白字是： color -f 37 -b 40
    #######文本绘制#######
    local __pendding=0
    local __text_lines=0
    for menu_text in "${menu_texts[@]}"; do
        __pendding=$((width - "$(Get-StringDisplayWidth "$menu_text")" - 3))
        display cursor-save \
            color -f 30 -b 47 \
            printf "│ ${menu_text}" \
            repeat " " "$__pendding" \
            printf "│" \
            color -f 37 -b 40 \
            printf ' ' \
            cursor-restore \
            cursor-move "~1" "~0"
        ((__text_lines++))
        # display update --fd 1
        # debug "menu_text: $menu_text/length: $(Get-StringDisplayWidth "$menu_text")"
    done
    #######文本绘制结束#######
    msgbox_newline
    #######绘制选项行开始#######
    draw_choice() {
        local tag="$1"
        local item="$2"
        local bettween="$3"
        local left_pendding="$4"
        local right_pendding="$5"
        local __is_selected="$6"
        local __selected_but_out="$7"
        display cursor-save \
            color -f 30 -b 47 \
            printf "│" \
            repeat " " "$left_pendding"
        if [[ "$__is_selected" == "true" ]]; then
            display color -f 37 -b 41 # 红底白字是：color -f 37 -b 41
        fi
        if [[ "$__selected_but_out" == "true" ]]; then
            display color -f 37 -b 44 # 蓝底白字是：color -f 37 -b 44
        fi
        display printf "${tag}" \
            repeat " " "$bettween" \
            printf "$item" \
            repeat " " "$((right_pendding - 9))" \
            color -f 30 -b 47 \
            repeat " " 9 \
            printf "│" \
            color -f 37 -b 40 \
            printf ' ' \
            cursor-restore \
            cursor-move "~1" "~0"
        # display update --fd 1
        # read -r -t 5
        # debug false "tag: $tag/item: $item/bettween: $bettween/left_pendding: $left_pendding/right_pendding: $right_pendding"
    }
    local __index=0
    local __is_selected="false"      # 红底白字是：color -f 37 -b 41
    local __selected_but_out="false" # 蓝底白字是：color -f 37 -b 44
    local __tag
    local __item
    local __tag_num="${#tags[@]}" # tag数量
    local __tag_length
    local __item_length
    local __bettween
    local __left_pending=0
    local __right_pending=0
    local __is_selected="false"
    local __left_pendings=()
    local __right_pendings=()
    local __bettweens=()
    for ((__index = 0; __index < __tag_num; __index++)); do
        __tag="${tags[__index]}"
        __item="${items[__index]}"
        __tag_length="${tag_lengths[__index]}"
        __item_length="${item_lengths[__index]}"
        __bettween=$((__max_tag_length - __tag_length + 1)) # +1是为了给tag和item之间留一个空格
        # __left_pending=$((((width - __tag_length - __max_item_length) / 2) - 1))     # -3是左边框和右边框各占一个字符，还有一个tag与item之间至少一个空格
        __left_pending=10 # TODO：这个值应该根据窗口大小来计算
        __right_pending=$((width - __left_pending - __tag_length - __bettween - __item_length - 3)) # -2是左边框和右边框各占一个字符
        draw_choice "$__tag" "$__item" "$__bettween" "$__left_pending" "$__right_pending" "$__is_selected" "$__selected_but_out"
        ########################
        __is_selected="false"
        __selected_but_out="false"
        __left_pendings+=("$__left_pending")
        __right_pendings+=("$__right_pending")
        __bettweens+=("$__bettween")
    done
    ########绘制选项行结束########
    msgbox_newline
    msgbox_newline
    ########绘制底部开始########
    draw_ok_cancle() {
        # 白底红字是：color -f 31 -b 47
        # 白底黑字是：color -f 30 -b 47
        # 蓝底白字是：color -f 37 -b 44
        # 红底白字是：color -f 37 -b 41
        # 计算 "<OK>" "Cancel" 的位置，然后输出
        local OK_Btton_left_pendding="$1"
        local bettween_length="$2"
        # local cancel_button="$4"
        local Cancel_Btton_right_pendding="$3"
        local selected="$4" # selected="OK"|"Cancel"|Null
        display cursor-save \
            color -f 30 -b 47 \
            printf "│" \
            repeat " " "$OK_Btton_left_pendding"
        if [[ "$selected" == 'OK' ]]; then
            display color -f 31 -b 41
        fi
        display printf "$ok_button" \
            color -f 30 -b 47 \
            repeat " " "$bettween_length"
        if [[ "$selected" == 'Cancel' ]]; then
            display color -f 31 -b 41
        fi
        display printf "$cancel_button" \
            color -f 30 -b 47 \
            repeat " " "$Cancel_Btton_right_pendding" \
            printf "│" \
            color -f 37 -b 40 \
            printf ' ' \
            cursor-restore \
            cursor-move "~1" "~0"
    }
    local OK_Btton_length
    local Cancel_Btton_length
    local OK_Btton_left_pendding
    local bettween_length
    local Cancel_Btton_right_pendding
    draw_bottom() {
        # local ok_button="<OK>"
        # local cancel_button="<Cancel>"
        OK_Btton_length="$(Get-StringDisplayWidth "$ok_button")"
        Cancel_Btton_length="$(Get-StringDisplayWidth "$cancel_button")"
        OK_Btton_left_pendding=$(((width / 3) - (OK_Btton_length / 2)))                                                               # 三分...以后要搞成可配置的
        Cancel_Btton_right_pendding=$(((width / 3) - (Cancel_Btton_length) / 2))                                                      # 三分...以后要搞成可配置的
        bettween_length=$((width - OK_Btton_left_pendding - Cancel_Btton_right_pendding - OK_Btton_length - Cancel_Btton_length - 2)) # -2是为了给左右边框各留一个空格

        ((OK_Btton_left_pendding < 0)) && OK_Btton_left_pendding=0
        ((Cancel_Btton_right_pendding < 0)) && Cancel_Btton_right_pendding=0
        ((bettween_length < 0)) && bettween_length=0
        draw_ok_cancle "$OK_Btton_left_pendding" "$bettween_length" "$Cancel_Btton_right_pendding" "Null" # 画底部的按钮
        msgbox_newline
        display cursor-save \
            color -f 30 -b 47 \
            printf "└" \
            repeat "─" "$((width - 2))" \
            printf "┘" \
            color -f 37 -b 40 \
            printf ' ' \
            cursor-restore \
            cursor-move "~1" "~0"
        # 现在画msgbox底下的黑边,体现立体感 # repeat ' ' "$width" \ 先硬编码
        display cursor-save \
            color -f 37 -b 44 \
            printf " " \
            color -f 37 -b 40 \
            repeat ' ' "$width" \
            cursor-restore \
            cursor-move "~1" "~0"
    }
    draw_bottom
    ########绘制底部结束########
    display update --fd 1 # 更新屏幕
    local __MENU_CHOICE_START_ROW=$((title_start_row + 2 + __text_lines))        # 菜单选项开始行
    local __MSGBOX_BUTTON_START_ROW=$((__MENU_CHOICE_START_ROW + __tag_num + 2)) # 按钮开始行
    local __MSGBOX_MENU_CHOICE=0                                                 # bash数组以0开始
    local __LAST_MSGBOX_MENU_CHOICE=0
    local __MSGBOX_MENU_BUTTON=0
    local __LAST_MSGBOX_MENU_BUTTON=0
    local __MSGBOX_MENU_STATUS=0
    __MSGBOX_MENU_ACTION_UP() {
        # 如果选中了按钮，则尝试取消选中
        # 0 为未选中，1 为选中 OK 按钮，2 为选中 Cancel 按钮
        __LAST_MSGBOX_MENU_BUTTON="$__MSGBOX_MENU_BUTTON"
        if ((__MSGBOX_MENU_BUTTON > 0)); then
            ((__MSGBOX_MENU_BUTTON--))
            if ((__MSGBOX_MENU_BUTTON == 0)); then
                __selected_but_out="false"
                return 0
            fi
            __selected_but_out="true"
            return 0
        fi
        # 如果没有选择按钮，则尝试选择上一个选项
        __LAST_MSGBOX_MENU_CHOICE="$__MSGBOX_MENU_CHOICE"
        if ((__MSGBOX_MENU_CHOICE > 0)); then
            ((__MSGBOX_MENU_CHOICE--))
            return 0
        fi
        return 0
    }
    __MSGBOX_MENU_ACTION_DOWN() {
        # 如果没有选中按钮，则尝试选择下一个选项
        __LAST_MSGBOX_MENU_CHOICE="$__MSGBOX_MENU_CHOICE"
        if ((__MSGBOX_MENU_BUTTON == 0)) && ((__MSGBOX_MENU_CHOICE < (__tag_num - 1))); then
            ((__MSGBOX_MENU_CHOICE++))
            return 0
        fi
        # 如果按钮未选中按钮，则尝试选中按钮
        # 0 为未选中，1 为选中 OK 按钮，2 为选中 Cancel 按钮
        __LAST_MSGBOX_MENU_BUTTON="$__MSGBOX_MENU_BUTTON"
        if ((__MSGBOX_MENU_BUTTON > 0)); then
            ((__MSGBOX_MENU_BUTTON++))
            if ((__MSGBOX_MENU_BUTTON > 2)); then
                __MSGBOX_MENU_BUTTON=2
            fi
            __selected_but_out="true" # 选中按钮,选项在原地
        fi
        return 0
    }
    __MSGBOX_MENU_ACTION_LEFT() {
        __LAST_MSGBOX_MENU_BUTTON="$__MSGBOX_MENU_BUTTON"
        ((__MSGBOX_MENU_BUTTON--))
        ((__MSGBOX_MENU_BUTTON < 0)) && __MSGBOX_MENU_BUTTON=0 && __selected_but_out="false" && return 0
        ((__MSGBOX_MENU_BUTTON == 0)) && __selected_but_out="false" && return 0
        ((__MSGBOX_MENU_BUTTON > 0)) && __selected_but_out="true" && return 0
    }
    __MSGBOX_MENU_ACTION_RIGHT() {
        __LAST_MSGBOX_MENU_BUTTON="$__MSGBOX_MENU_BUTTON"
        ((__MSGBOX_MENU_BUTTON++))
        if ((__MSGBOX_MENU_BUTTON > 2)); then
            __MSGBOX_MENU_BUTTON=2
        fi
        __selected_but_out="true"
        return 0
    }
    __MSGBOX_MENU_ACTION_ENTER() {
        case $__MSGBOX_MENU_BUTTON in
        0 | 1)
            printf "%s" "${tags[__MSGBOX_MENU_CHOICE]}" >&2
            __MSGBOX_MENU_STATUS=0 # 直接回车或选中确认按钮回车
            return 1
            ;;
        2)
            __MSGBOX_MENU_STATUS=1 # 选中取消按钮回车
            return 1
            ;;
        esac
    }
    __MSGBOX_MENU_ACTION_QUIT() {
        command -v stty >/dev/null 2>&1 && stty "$old"
        return "$__MSGBOX_MENU_STATUS" # 返回状态码，不被上一条命令干扰
    }
    __MSGBOX_MENU_ACTION_ESC() {
        __MSGBOX_MENU_STATUS=255
        return 1
    }
    __MENU_CURSOR_MOVEMENT_INIT() {
        display reset screen
        command -v stty >/dev/null 2>&1 && old="$(stty -g)" && stty raw -echo # 保存当前终端设置
    }
    __MSGBOX_MENU_LOOP() {
        if [[ "$__LAST_MSGBOX_MENU_CHOICE" != "$__MSGBOX_MENU_CHOICE" ]]; then
            display cursor-move "$((__MENU_CHOICE_START_ROW + __LAST_MSGBOX_MENU_CHOICE))" "$title_start_col"
            __tag="${tags[__LAST_MSGBOX_MENU_CHOICE]}"
            __item="${items[__LAST_MSGBOX_MENU_CHOICE]}"
            __tag_length="${tag_lengths[__LAST_MSGBOX_MENU_CHOICE]}"
            __item_length="${item_lengths[__LAST_MSGBOX_MENU_CHOICE]}"
            __bettween="${__bettweens[__LAST_MSGBOX_MENU_CHOICE]}"
            __left_pending="${__left_pendings[__LAST_MSGBOX_MENU_CHOICE]}"
            __right_pending="${__right_pendings[__LAST_MSGBOX_MENU_CHOICE]}"
            draw_choice "$__tag" "$__item" "$__bettween" "$__left_pending" "$__right_pending" "false" "false" # 取消选中选项 # 严格false
        fi
        display cursor-move "$((__MENU_CHOICE_START_ROW + __MSGBOX_MENU_CHOICE))" "$title_start_col"
        __tag="${tags[__MSGBOX_MENU_CHOICE]}"
        __item="${items[__MSGBOX_MENU_CHOICE]}"
        __tag_length="${tag_lengths[__MSGBOX_MENU_CHOICE]}"
        __item_length="${item_lengths[__MSGBOX_MENU_CHOICE]}"
        __left_pending="${__left_pendings[__MSGBOX_MENU_CHOICE]}"
        __right_pending="${__right_pendings[__MSGBOX_MENU_CHOICE]}"
        __bettween="${__bettweens[__MSGBOX_MENU_CHOICE]}"
        draw_choice "$__tag" "$__item" "$__bettween" "$__left_pending" "$__right_pending" "true" "$__selected_but_out" # 选中选项
        [[ "$__LAST_MSGBOX_MENU_BUTTON" != "$__MSGBOX_MENU_BUTTON" ]] && display cursor-move "$__MSGBOX_BUTTON_START_ROW" "$title_start_col" && case "$__MSGBOX_MENU_BUTTON" in
        0)
            draw_ok_cancle "$OK_Btton_left_pendding" "$bettween_length" "$Cancel_Btton_right_pendding" "Null" # 画底部的按钮 # 未选中按钮
            ;;
        1)
            draw_ok_cancle "$OK_Btton_left_pendding" "$bettween_length" "$Cancel_Btton_right_pendding" "OK" # 画底部的按钮 # 选中 OK 按钮
            ;;
        2)
            draw_ok_cancle "$OK_Btton_left_pendding" "$bettween_length" "$Cancel_Btton_right_pendding" "Cancel" # 画底部的按钮 # 选中 Cancel 按钮
            ;;
        esac
        display update --fd "$CURSOR_MOVEMENT_FD"
        display reset screen

    }
    display cursor-movement \
        --up __MSGBOX_MENU_ACTION_UP \
        --down __MSGBOX_MENU_ACTION_DOWN \
        --left __MSGBOX_MENU_ACTION_LEFT \
        --right __MSGBOX_MENU_ACTION_RIGHT \
        --quit __MSGBOX_MENU_ACTION_QUIT \
        --enter __MSGBOX_MENU_ACTION_ENTER \
        --esc __MSGBOX_MENU_ACTION_ESC \
        --init __MENU_CURSOR_MOVEMENT_INIT \
        --loop __MSGBOX_MENU_LOOP
    local __STATUS=$?
    # display cursor-show update cursor-movement # 方便数字....
    display region-save msgbox.back reset screen
    display printf "\n" color reset update --fd 1 # 重置颜色
    return "$__STATUS"
    # printf '我是被测试的值！' 1>&2 # 测试传值
}

msgbox() {
    # screen_size=$(display get-screen-size p)
    # 初始化变量
    local backtitle="" title="" clear_screen=0 default_item=""
    local defaultno=0 fullbuttons=0 nocancel=0
    local yes_button="<Yes>" no_button="<No>" ok_button="<Ok>" cancel_button="<Cancel>"
    local dialog_type="" dialog_args=()

    # 支持的对话框类型列表
    local dialog_types=("--menu" "--checklist" "--radiolist" "--inputbox" "--passwordbox"
        "--textbox" "--msgbox" "--yesno" "--infobox" "--gauge")

    # 解析全局选项
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --backtitle)
            backtitle="$2"
            shift 2
            ;;
        --title)
            title="$2"
            shift 2
            ;;
        --clear)
            clear_screen=1
            shift
            ;;
        --default-item)
            default_item="$2"
            shift 2
            ;;
        --defaultno)
            defaultno=1
            shift
            ;;
        --fb | --fullbuttons)
            fullbuttons=1 # 很少用，且较难实现，以后再写
            shift
            ;;
        --nocancel)
            nocancel=1
            shift
            ;;
        --yes-button)
            yes_button="$2"
            shift 2
            ;;
        --no-button)
            if [[ "$defaultno" -eq 1 ]]; then
                shift 2 # 如果默认选择是No，则将Yes按钮设置为No按钮
            else
                no_button="$2"
                shift 2
            fi
            ;;
        --ok-button)
            ok_button="$2"
            shift 2
            ;;
        --cancel-button)
            cancel_button="$2"
            shift 2
            ;;
        *)
            # 检查是否是对话框类型
            if [[ " ${dialog_types[*]} " == *" $1 "* ]]; then
                dialog_type="$1"
                shift
                dialog_args=("$@")
                break
            else
                echo "未知选项: $1" >&2
                return 1
            fi
            ;;
        esac
    done

    # 检查是否指定了对话框类型
    if [[ -z "$dialog_type" ]]; then
        echo "错误: 未指定对话框类型" >&2
        return 1
    fi

    msgbox_background --backtitle "$backtitle"

    # 解析对话框特定参数
    case "$dialog_type" in
    --menu | --checklist | --radiolist)
        # 格式: text height width menu_height [tag item status]...
        if [[ ${#dialog_args[@]} -lt 4 ]]; then
            echo "错误: $dialog_type 需要至少4个参数" >&2
            return 1
        fi

        local text="${dialog_args[0]}"
        local height="${dialog_args[1]}"
        local width="${dialog_args[2]}"
        local menu_height="${dialog_args[3]}"
        local items=("${dialog_args[@]:4}")

        # 验证项目数量
        if [[ "$dialog_type" == "--checklist" || "$dialog_type" == "--radiolist" ]]; then
            # 每个项目需要3个参数: tag item status
            if [[ $((${#items[@]} % 3)) -ne 0 ]]; then
                echo "错误: $dialog_type 需要每组 tag/item/status 三个参数" >&2
                return 1
            fi
        else
            # 每个项目需要2个参数: tag item
            if [[ $((${#items[@]} % 2)) -ne 0 ]]; then
                echo "错误: $dialog_type 需要每组 tag/item 两个参数" >&2
                return 1
            fi
        fi

        # 处理对话框
        msgbox_process_dialog "$dialog_type" "$text" "$height" "$width" "$menu_height" "${items[@]}"
        local __STATUS=$?
        # return "$__STATUS"
        ;;
    --inputbox | --passwordbox)
        # 格式: text height width [init]
        if [[ ${#dialog_args[@]} -lt 3 ]]; then
            echo "错误: $dialog_type 需要至少3个参数" >&2
            return 1
        fi

        local text="${dialog_args[0]}"
        local height="${dialog_args[1]}"
        local width="${dialog_args[2]}"
        local init="${dialog_args[3]:-''}"

        # 处理对话框
        process_input_dialog "$dialog_type" "$text" "$height" "$width" "$init"
        ;;

    --textbox)
        # 格式: file height width
        if [[ ${#dialog_args[@]} -lt 3 ]]; then
            echo "错误: $dialog_type 需要至少3个参数" >&2
            return 1
        fi

        local file="${dialog_args[0]}"
        local height="${dialog_args[1]}"
        local width="${dialog_args[2]}"

        # 处理对话框
        process_textbox "$file" "$height" "$width"
        ;;

    --msgbox | --yesno | --infobox)
        # 格式: text height width
        if [[ ${#dialog_args[@]} -lt 3 ]]; then
            echo "错误: $dialog_type 需要至少3个参数" >&2
            return 1
        fi

        local text="${dialog_args[0]}"
        local height="${dialog_args[1]}"
        local width="${dialog_args[2]}"

        # 处理对话框
        process_simple_dialog "$dialog_type" "$text" "$height" "$width"
        ;;

    --gauge)
        # 格式: text height width [percent]
        if [[ ${#dialog_args[@]} -lt 3 ]]; then
            echo "错误: $dialog_type 需要至少3个参数" >&2
            return 1
        fi

        local text="${dialog_args[0]}"
        local height="${dialog_args[1]}"
        local width="${dialog_args[2]}"
        local percent="${dialog_args[3]:-0}"

        # 处理对话框
        process_gauge "$text" "$height" "$width" "$percent"
        ;;

    *)
        echo "错误: 不支持的对话框类型: $dialog_type" >&2
        return 1
        ;;
    esac
    [[ "$clear_screen" -eq 1 ]] && display clear update reset screen # 清屏
    display region-save 'screen' reset screen screen-restore update --fd 1 region-restore 'screen' 2>/dev/null
    return "$__STATUS"
}
# 生成随机中文文本的函数（长度差距更大）
generate_random_text() {
    local text_type="$1"

    # 扩展的中文词库
    local adjectives=("神秘莫测的" "奇幻绚烂的" "梦幻缥缈的" "彩虹斑斓的" "星空璀璨的" "温柔如水的" "可爱至极的" "魔法无穷的" "古老沧桑的" "未来科幻的" "闪亮夺目的" "柔软如云的" "威严庄重的" "活泼可爱的")
    local nouns=("花园" "宝箱" "城堡" "森林" "海洋" "星球" "咖啡馆" "图书馆" "工坊" "实验室" "剧场" "博物馆" "宫殿" "秘境" "仙境" "乐园")
    local animals=("小猫咪" "软萌兔子" "独角兽王子" "火凤凰公主" "憨厚熊猫" "优雅海豚" "彩色蝴蝶" "胖胖龙猫" "九尾狐仙" "呆萌企鹅" "威武雄狮" "神秘黑豹")
    local foods=("香甜草莓蛋糕" "清香抹茶冰淇淋" "七彩彩虹糖果" "软糯棉花糖云朵" "浓郁黑巧克力" "金黄蜂蜜琥珀" "粉嫩樱花仙饼" "传统手工月饼" "热腾腾汤圆" "丝滑奶茶布丁")
    local verbs=("优雅地飞舞着" "静静地闪烁着" "轻柔地歌唱着" "缓缓地漂浮着" "欢快地旋转着" "绚烂地绽放着" "活泼地跳跃着" "自由地游泳着" "飞快地奔跑着" "安详地沉睡着")

    # 长短句素材库
    # local short_phrases=("在这里" "很久很久以前" "突然间" "据传说" "有一天")
    local medium_phrases=("在遥远的银河系边缘" "在时间的长河中静静流淌" "伴随着古老钟声的回响" "当第一缕晨光穿透云层")
    local long_phrases=("在那个被遗忘的古老传说中，时光倒流，星辰重新排列" "穿越了无数个平行宇宙的维度壁垒，我们终于抵达了这个神奇的地方" "当宇宙中所有的星星都为这一刻而闪烁，古老的魔法阵开始缓缓运转")

    case "$text_type" in
    "title")
        local length=$((RANDOM % 3))
        case $length in
        0) # 短标题 (5-10字)
            local random_animal=${animals[$RANDOM % ${#animals[@]}]}
            echo "${random_animal%%[的公主王子仙]*}"
            ;;
        1) # 中等标题 (15-25字)
            local random_adj=${adjectives[$RANDOM % ${#adjectives[@]}]}
            local random_noun=${nouns[$RANDOM % ${#nouns[@]}]}
            local random_animal=${animals[$RANDOM % ${#animals[@]}]}
            echo "${random_animal}的${random_adj}${random_noun}探险记"
            ;;
        2) # 长标题 (30-50字)
            local random_adj1=${adjectives[$RANDOM % ${#adjectives[@]}]}
            local random_adj2=${adjectives[$RANDOM % ${#adjectives[@]}]}
            local random_noun1=${nouns[$RANDOM % ${#nouns[@]}]}
            local random_noun2=${nouns[$RANDOM % ${#nouns[@]}]}
            local random_animal=${animals[$RANDOM % ${#animals[@]}]}
            echo "穿越时空的${random_animal}在${random_adj1}${random_noun1}与${random_adj2}${random_noun2}之间的奇幻冒险传说"
            ;;
        esac
        ;;
    "backtitle")
        local length=$((RANDOM % 4))
        case $length in
        0) # 极短 (8-12字)
            echo "按键继续魔法之旅"
            ;;
        1) # 短 (20-30字)
            local random_food=${foods[$RANDOM % ${#foods[@]}]}
            echo "享用${random_food}的同时，请按任意键开启奇妙旅程"
            ;;
        2) # 中等 (40-60字)
            local random_phrase=${medium_phrases[$RANDOM % ${#medium_phrases[@]}]}
            local random_verb=${verbs[$RANDOM % ${#verbs[@]}]}
            echo "${random_phrase}，魔法精灵们${random_verb}，等待着你的到来，请使用键盘上的魔法按键"
            ;;
        3) # 超长 (80-120字)
            local random_long=${long_phrases[$RANDOM % ${#long_phrases[@]}]}
            local random_animal=${animals[$RANDOM % ${#animals[@]}]}
            local random_food=${foods[$RANDOM % ${#foods[@]}]}
            echo "${random_long}，${random_animal}正在品尝着${random_food}，它们告诉我，只有真正勇敢的冒险者才能解锁这些神秘的功能"
            ;;
        esac
        ;;
    "menu")
        local length=$((RANDOM % 5))
        local version="v$((RANDOM % 9 + 1)).$((RANDOM % 9999)).$((RANDOM % 99))"

        case $length in
        0) # 极简版本 (20-30字)
            printf "魔法工具箱 ${version}\n选择你的冒险路径"
            ;;
        1) # 简短版本 (50-70字)
            local random_adj=${adjectives[$RANDOM % ${#adjectives[@]}]}
            local random_noun=${nouns[$RANDOM % ${#nouns[@]}]}
            printf "欢迎来到${random_adj}${random_noun} ${version}！\n这里有无数神奇的工具等待你的发现。\n请使用方向键探索，回车键确认选择。"
            ;;
        2) # 中等版本 (100-150字)
            local random_adj1=${adjectives[$RANDOM % ${#adjectives[@]}]}
            local random_adj2=${adjectives[$RANDOM % ${#adjectives[@]}]}
            local random_noun1=${nouns[$RANDOM % ${#nouns[@]}]}
            local random_animal=${animals[$RANDOM % ${#animals[@]}]}
            local random_food=${foods[$RANDOM % ${#foods[@]}]}
            printf "欢迎来到${random_adj1}${random_noun1}的奇妙世界 ${version}！\n在这个${random_adj2}维度里，${random_animal}正在制作${random_food}，每一个选项都蕴含着古老的魔法力量。\n请小心使用方向键在选项间穿梭，用回车键激活你选中的魔法阵。\n记住，每一次选择都可能改变整个宇宙的命运！"
            ;;
        3) # 超长版本 (200-300字)
            local random_long=${long_phrases[$RANDOM % ${#long_phrases[@]}]}
            local random_animal1=${animals[$RANDOM % ${#animals[@]}]}
            local random_animal2=${animals[$RANDOM % ${#animals[@]}]}
            local random_food1=${foods[$RANDOM % ${#foods[@]}]}
            local random_food2=${foods[$RANDOM % ${#foods[@]}]}
            local random_noun1=${nouns[$RANDOM % ${#nouns[@]}]}
            local random_noun2=${nouns[$RANDOM % ${#nouns[@]}]}
            printf "${random_long}。\n\n欢迎，勇敢的旅行者，来到这个被称为 ${version} 的神奇空间！这里是${random_animal1}与${random_animal2}共同守护的${random_noun1}，它们世世代代传承着制作${random_food1}和${random_food2}的古老秘方。\n\n传说中，只有通过正确的按键组合，才能解锁隐藏在这个${random_noun2}深处的终极秘密。方向键是你在这个多维空间中移动的魔法导航器，而回车键则是激活时空传送门的神圣钥匙。\n\n请谨慎选择你的道路，因为每一个决定都将书写属于你自己的传奇故事..."
            ;;
        4) # 超长版本 (200-300字)
            local random_long=${long_phrases[$RANDOM % ${#long_phrases[@]}]}
            local random_animal1=${animals[$RANDOM % ${#animals[@]}]}
            local random_animal2=${animals[$RANDOM % ${#animals[@]}]}
            local random_food1=${foods[$RANDOM % ${#foods[@]}]}
            local random_food2=${foods[$RANDOM % ${#foods[@]}]}
            local random_noun1=${nouns[$RANDOM % ${#nouns[@]}]}
            local random_noun2=${nouns[$RANDOM % ${#nouns[@]}]}
            printf "${random_long}。\n\n欢迎，勇敢的旅行者，来到这个被称为 ${version} 的神奇空间！这里是${random_animal1}与${random_animal2}共同守护的${random_noun1}，它们世世代代传承着制作${random_food1}和${random_food2}的古老秘方。\n\n传说中，只有通过正确的按键组合，才能解锁隐藏在这个${random_noun2}深处的终极秘密。方向键是你在这个多维空间中移动的魔法导航器，而回车键则是激活时空传送门的神圣钥匙。\n\n请谨慎选择你的道路，因为每一个决定都将书写属于你自己的传奇故事..."
            ;;
        esac
        ;;
    "option")
        local length=$((RANDOM % 4))
        case $length in
        0) # 超短 (3-6字)
            local simple_words=("魔法门" "传送阵" "宝箱" "秘境" "仙域" "星门")
            echo "${simple_words[$RANDOM % ${#simple_words[@]}]}"
            ;;
        1) # 短 (8-15字)
            local random_adj=${adjectives[$RANDOM % ${#adjectives[@]}]}
            local random_noun=${nouns[$RANDOM % ${#nouns[@]}]}
            echo "${random_adj}${random_noun}"
            ;;
        2) # 中等 (20-35字)
            local random_animal=${animals[$RANDOM % ${#animals[@]}]}
            local random_food=${foods[$RANDOM % ${#foods[@]}]}
            local random_noun=${nouns[$RANDOM % ${#nouns[@]}]}
            echo "${random_animal}的${random_food}制作${random_noun}"
            ;;
        3) # 长 (40-60字)
            local random_adj1=${adjectives[$RANDOM % ${#adjectives[@]}]}
            local random_adj2=${adjectives[$RANDOM % ${#adjectives[@]}]}
            local random_noun1=${nouns[$RANDOM % ${#nouns[@]}]}
            local random_noun2=${nouns[$RANDOM % ${#nouns[@]}]}
            local random_verb=${verbs[$RANDOM % ${#verbs[@]}]}
            echo "跨越${random_adj1}${random_noun1}与${random_adj2}${random_noun2}的时空隧道，在其中${random_verb}的神秘传送装置"
            ;;
        4) # 超长 (80-120字)
            local random_long=${long_phrases[$RANDOM % ${#long_phrases[@]}]}
            local random_animal=${animals[$RANDOM % ${#animals[@]}]}
            local random_noun=${nouns[$RANDOM % ${#nouns[@]}]}
            echo "据古老传说记载，${random_long}之后，${random_animal}建立了这个能够连接无数平行宇宙的${random_noun}，它拥有改写现实规则的终极力量"
            ;;
        esac
        ;;
    esac
}

# 生成完整的msgbox命令（长度差距更大）
generate_random_msgbox() {
    local title=$(generate_random_text "title")
    local r_backtitle=$(generate_random_text "backtitle")
    local r_menu_text=$(generate_random_text "menu")

    # 生成选项文本（每个选项长度随机且差距很大）
    local options=()
    for _ in {0..9}; do
        options+=("$(generate_random_text "option")")
    done
    #     whiptail --title "穿越时空的九尾狐仙在闪亮夺目的乐园与温柔如水的城堡之间的奇幻冒险传说" \
    #         --menu "在那个被遗忘的古老传说中，时光倒流，星辰重新排列。
    # 欢迎，勇敢的旅行者，来到这个被称为 v8.2256.87 的神奇空间！这里是憨厚熊猫与小猫咪共同守护的乐园，它们世世代代传承着制作金黄蜂蜜琥珀和软糯棉花糖云朵的古老秘方。
    # 传说中，只有通过正确的按键组合，才能解锁隐藏在这个图书馆深处的终极秘密。方向键是你在这个多维空间中移动的魔法导航器，而回车键则是激活时空传送门的神圣钥匙。
    # 请谨慎选择你的道路，因为每一个决定都将书写属于你自己的传奇故事..." \
    #         0 80 0 \
    #         "1" "🍭 跨越彩虹斑斓的实验室与古老沧桑的宫殿的时空隧道，在其中欢快地旋转着的神秘传送装置:图形界面管理(桌面环境,窗口管理器,登录管理器)" \
    #         "2" "🥝 彩虹斑斓的剧场:软件中心(浏览器,游戏,多媒体播放器)" \
    #         "3" "🌺 跨越彩虹斑斓的花园与威严庄重的森林的时空隧道，在其中飞快地奔跑着的神秘传送装置:秘密花园(教育工具,系统优化,实验性功能)" \
    #         "4" "🌈 跨越奇幻绚烂的海洋与星空璀璨的咖啡馆的时空隧道，在其中轻柔地歌唱着的神秘传送装置:桌面美化工坊(主题,图标,壁纸定制)" \
    #         "5" "🌌 温柔如水的秘境:远程连接(VNC,X11转发,RDP协议)" \
    #         "6" "📺 彩虹斑斓的海洋:视频下载器(哔哩哔哩,YouTube,在线解析)" \
    #         "7" "🍥 星门:软件源管理(镜像站点,更新源,包管理)" \
    #         "8" "🍧 魔法门:系统更新(*°▽°*升级所有组件)" \
    #         "9" "🍩 柔软如云的仙境:常见问题解答(故障排除,使用指南)" \
    #         "0" "🌚 仙域:退出程序(告别这个奇妙的世界)"
    true && msgbox --title "${title}" \
        --backtitle "${r_backtitle}" \
        --menu "${r_menu_text}" 0 80 "0" \
        "1" "🍭 ${options[0]}:图形界面管理(桌面环境,窗口管理器,登录管理器)" \
        "12" "🥝 ${options[1]}:软件中心(浏览器,游戏,多媒体播放器)" \
        "123" "🌺 ${options[2]}:秘密花园(教育工具,系统优化,实验性功能)" \
        "1234" "🌈 ${options[3]}:桌面美化工坊(主题,图标,壁纸定制)" \
        "12345" "🌌 ${options[4]}:远程连接(VNC,X11转发,RDP协议)" \
        "123456" "📺 ${options[5]}:视频下载器(哔哩哔哩,YouTube,在线解析)" \
        "1237" "🍥 ${options[6]}:软件源管理(镜像站点,更新源,包管理)" \
        "48" "🍧 ${options[7]}:系统更新(*°▽°*升级所有组件)" \
        "93" "🍩 ${options[8]}:常见问题解答(故障排除,使用指南)" \
        "0你" "🌚 ${options[9]}:退出程序(告别这个奇妙的世界)"
    msgbox --title "${title}" \
        --backtitle "${r_backtitle}" \
        --menu "${r_menu_text}" 0 80 "0" \
        "1" "🍭 ${options[0]}:图形界面管理(桌面环境,窗口管理器,登录管理器)" \
        "2" "🥝 ${options[1]}:软件中心(浏览器,游戏,多媒体播放器)" \
        "3" "🌺 ${options[2]}:秘密花园(教育工具,系统优化,实验性功能)" \
        "4" "🌈 ${options[3]}:桌面美化工坊(主题,图标,壁纸定制)" \
        "5" "🌌 ${options[4]}:远程连接(VNC,X11转发,RDP协议)" \
        "6" "📺 ${options[5]}:视频下载器(哔哩哔哩,YouTube,在线解析)" \
        "7" "🍥 ${options[6]}:软件源管理(镜像站点,更新源,包管理)" \
        "8" "🍧 ${options[7]}:系统更新(*°▽°*升级所有组件)" \
        "9" "🍩 ${options[8]}:常见问题解答(故障排除,使用指南)" \
        "0" "🌚 ${options[9]}:退出程序(告别这个奇妙的世界)"
    ret="$(
        msgbox --title "${title}" \
            --backtitle "${r_backtitle}" \
            --menu "${r_menu_text}" 0 80 "0" \
            "1" "🍭 ${options[0]}:图形界面管理(桌面环境,窗口管理器,登录管理器)" \
            "2" "🥝 ${options[1]}:软件中心(浏览器,游戏,多媒体播放器)" \
            "3" "🌺 ${options[2]}:秘密花园(教育工具,系统优化,实验性功能)" \
            "4" "🌈 ${options[3]}:桌面美化工坊(主题,图标,壁纸定制)" \
            "5" "🌌 ${options[4]}:远程连接(VNC,X11转发,RDP协议)" \
            "6" "📺 ${options[5]}:视频下载器(哔哩哔哩,YouTube,在线解析)" \
            "7" "🍥 ${options[6]}:软件源管理(镜像站点,更新源,包管理)" \
            "8" "🍧 ${options[7]}:系统更新(*°▽°*升级所有组件)" \
            "9" "🍩 ${options[8]}:常见问题解答(故障排除,使用指南)" \
            "0" "🌚 ${options[9]}:退出程序(告别这个奇妙的世界)" \
            3>&1 1>&2 2>&3
    )"
    # [ -n $val ]是检查变量是否非空
    if [ -n "$ret" ]; then
        echo -e "你选择了: '$ret'"
    else
        echo "没有选择任何选项"
    fi
}

# 使用示例
# Get-StringDisplayWidth "传说中，只有通过正确的按键组合，才能解锁隐藏在这个森林深处的终极秘密。方向键是你在这个多维空间中移动的魔法导航器，而回车键则是激活时空传送门的神圣钥匙。"
# read -r
# echo "生成随机长度差距很大的msgbox："
# echo "================================"
if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    # 如果脚本是直接运行的，则调用函数
    generate_random_msgbox
else
    # 如果脚本是被其他脚本或命令调用的，则定义函数
    # echo "脚本被其他脚本或命令调用，定义函数："
    :
    # 这里可以定义函数或其他操作
fi
# echo ""
# echo "再次生成（观察长度差异）："
# echo "========================="
# generate_random_msgbox
