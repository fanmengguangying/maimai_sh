#!/bin/bash

UnixMenu() {
    while true; do
        [[ "$INTERACTIVE" == "true" || -z "$INTERACTIVE" ]] && choice=$(bash_whiptail --backtitle "只负责部署哦\(￣︶￣*\))" --title "主菜单 (Unix环境)" --menu "使用方向键选择\n请选择操作:" 0 60 0 \
            "A" "🔥全自动部署流程（处理错误）" \
            "1" "🎦开始部署（手动选择）" \
            "2" "🐱仅部署麦麦 " \
            "3" "💧仅安装mongodb（5.0.x）" \
            "4" "📱仅安装napcat" \
            "5" "📝配置麦麦" \
            "6" "📦安装proot（Debian12）" \
            "7" "🚫卸载" \
            "8" "👋退出脚本" \
            "proot" "🚀启动proot" \
            "move" "💨麦麦搬家" \
            "tool" "💬发送消息工具" 3>&1 1>&2 2>&3)

        [[ "$?" -ne 0 ]] && break #  检查bash_whiptail的返回值，表示用户选择了ESC或取消，则退出循环

        case "${choice}" in
        A)
            AUTO_RECOMMANDED="true"
            Deploy-FullStack "$@"
            ;;
        1)
            Deploy-FullStack "$@"
            ;;
        2)
            Deploy-MaiM
            ;;
        3)
            Install-MongoDB
            ;;
        4)
            Invoke-NapcatInstall --docker n --cli y
            ;;
        5)
            Configure-MaiMConfig "interactive"
            ;;
        6)
            Install-ProotEnvironment
            ;;
        7)
            Uninstall-Menu
            ;;
        8)
            bash_whiptail --title "再见" --msgbox "感谢使用！\n好用的话...夸我夸我(๑>؂<๑）" 8 60
            exit 0
            ;;
        proot)
            Enter-ProotContainer
            ;;
        move)
            MaiMmove
            ;;
        tool)
            Create-QQSendTool
            bash_whiptail --title "使用说明" --msgbox "已创建工具: qqsendsmsg.sh\n用法: qqsendsmsg QQ号 消息" 10 60
            ;;
        esac
        [[ "$INTERACTIVE" == "false" ]] && {
            Deploy-FullStack "$@"
            exit 0
        }
        # 操作完成后显示返回提示
        bash_whiptail --title "操作完成" --msgbox "按OK返回主菜单" 8 50
    done
}

# Android环境菜单
AndoridMenu() {
    while true; do
        [[ "$INTERACTIVE" == "true" || -z "$INTERACTIVE" ]] && choice=$(bash_whiptail --title "主菜单 (Android环境)" --menu "请选择操作：" 12 60 5 \
            "1" "🐱仅部署麦麦" \
            "2" "📦安装 proot（Debian12）" \
            "3" "🚫卸载" \
            "4" "👋退出脚本" \
            "proot" "🚀启动 proot" 3>&1 1>&2 2>&3)

        [ $? -ne 0 ] && break # 用户按ESC取消

        case "${choice}" in
        1)
            Deploy-MaiM
            ;;
        2)
            Install-ProotEnvironment "$@"
            ;;
        3)
            Uninstall-Menu
            ;;
        4)
            bash_whiptail --title "再见" --msgbox "感谢使用！" 8 60
            exit 0
            ;;
        proot)
            Enter-ProotContainer
            ;;
        esac
        [[ ! "$INTERACTIVE" == "true" ]] && {
            :
            exit 0
        }
        # 操作完成后显示返回提示
        bash_whiptail --title "操作完成" --msgbox "按OK返回主菜单" 8 50
    done
}

if [[ "$0" == "${BASH_SOURCE}" ]]; then
    exit 1
fi