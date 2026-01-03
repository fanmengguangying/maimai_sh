#!/usr/bin/env bash
# ------------------------------------------------------------
#  Get-MaiMaiRepository —— 一键拉取 MaiBot 主仓库或适配器
# ------------------------------------------------------------
set -euo pipefail

#############################################
## 1. 常量表（全局）
#############################################
declare -A DIR_NAMES=(
    [MaiBot]=MaiBot
    [Adapter]=MaiBot-Napcat-Adapter
    [MaiBot-Napcat-Adapter]=MaiBot-Napcat-Adapter
)

# Git 地址
declare -A GIT_URLS_MB=(
    [main]=https://github.com/MaiM-with-u/MaiBot.git
    [dev]=https://github.com/MaiM-with-u/MaiBot.git
    [0.5.8-alpha]=https://github.com/MaiM-with-u/MaiBot.git
    [0.5.11-alpha]=https://github.com/MaiM-with-u/MaiBot.git
    [0.5.13-alpha]=https://github.com/MaiM-with-u/MaiBot.git
    [0.5.15hotfix-alpha]=https://github.com/MaiM-with-u/MaiBot.git
    [0.5.15-alpha]=https://github.com/MaiM-with-u/MaiBot.git
    [0.6.0-alpha]=https://github.com/MaiM-with-u/MaiBot.git
    [0.6.2-alpha]=https://github.com/MaiM-with-u/MaiBot.git
    [0.6.3-alpha]=https://github.com/MaiM-with-u/MaiBot.git
    [0.6.3-fix3-alpha]=https://github.com/MaiM-with-u/MaiBot.git
    [0.6.3-fix4-alpha]=https://github.com/MaiM-with-u/MaiBot.git
    [0.7.0-alpha]=https://github.com/MaiM-with-u/MaiBot.git
    [0.8.0-alpha]=https://github.com/MaiM-with-u/MaiBot.git
    [0.8.1-alpha]=https://github.com/MaiM-with-u/MaiBot.git
    [0.9.0-alpha]=https://github.com/MaiM-with-u/MaiBot.git
)

declare -A GIT_URLS_ADP=(
    [main]=https://github.com/MaiM-with-u/MaiBot-Napcat-Adapter.git
    [dev]=https://github.com/MaiM-with-u/MaiBot-Napcat-Adapter.git
    [0.2.3]=https://github.com/MaiM-with-u/MaiBot-Napcat-Adapter.git
    [0.4.2]=https://github.com/MaiM-with-u/MaiBot-Napcat-Adapter.git
)

# Zip 地址
declare -A ZIP_URLS_MB=(
    [dev]=https://github.com/MaiM-with-u/MaiBot/archive/refs/heads/dev.zip
    [main]=https://github.com/MaiM-with-u/MaiBot/archive/refs/heads/main.zip
    [0.5.8-alpha]=https://github.com/MaiM-with-u/MaiBot/archive/refs/tags/0.5.8-alpha.zip
    [0.5.11-alpha]=https://github.com/MaiM-with-u/MaiBot/archive/refs/tags/0.5.11-alpha.zip
    [0.5.13-alpha]=https://github.com/MaiM-with-u/MaiBot/archive/refs/tags/0.5.13-alpha.zip
    [0.5.15hotfix-alpha]=https://github.com/MaiM-with-u/MaiBot/archive/refs/tags/0.5.15hotfix-alpha.zip
    [0.5.15-alpha]=https://github.com/MaiM-with-u/MaiBot/archive/refs/tags/0.5.15-alpha.zip
    [0.6.0-alpha]=https://github.com/MaiM-with-u/MaiBot/archive/refs/tags/0.6.0-alpha.zip
    [0.6.2-alpha]=https://github.com/MaiM-with-u/MaiBot/archive/refs/tags/0.6.2-alpha.zip
    [0.6.3-alpha]=https://github.com/MaiM-with-u/MaiBot/archive/refs/tags/0.6.3-alpha.zip
    [0.6.3-fix3-alpha]=https://github.com/MaiM-with-u/MaiBot/archive/refs/tags/0.6.3-fix3-alpha.zip
    [0.6.3-fix4-alpha]=https://github.com/MaiM-with-u/MaiBot/archive/refs/tags/0.6.3-fix4-alpha.zip
    [0.7.0-alpha]=https://github.com/MaiM-with-u/MaiBot/archive/refs/tags/0.7.0-alpha.zip
    [0.8.0-alpha]=https://github.com/MaiM-with-u/MaiBot/archive/refs/tags/0.8.0-alpha.zip
    [0.8.1-alpha]=https://github.com/MaiM-with-u/MaiBot/archive/refs/tags/0.8.1-alpha.zip
    [0.9.0-alpha]=https://github.com/MaiM-with-u/MaiBot/archive/refs/tags/0.9.0-alpha.zip
)

declare -A ZIP_URLS_ADP=(
    [main]=https://github.com/MaiM-with-u/MaiBot-Napcat-Adapter/archive/refs/heads/main.zip
    [dev]=https://github.com/MaiM-with-u/MaiBot-Napcat-Adapter/archive/refs/heads/dev.zip
    [0.2.3]=https://github.com/MaiM-with-u/MaiBot-Napcat-Adapter/archive/refs/tags/0.2.3.zip
    [0.4.2]=https://github.com/MaiM-with-u/MaiBot-Napcat-Adapter/archive/refs/tags/0.4.2.zip
)

#############################################
## 2. 工具函数
#############################################

# 根据目标名返回关联数组名
GIT:get_url_map() {
    local target=$1 way=$2
    case "$target" in
        MaiBot)
            [[ $way == zip ]] && echo ZIP_URLS_MB || echo GIT_URLS_MB
            ;;
        Adapter|MaiBot-Napcat-Adapter)
            [[ $way == zip ]] && echo ZIP_URLS_ADP || echo GIT_URLS_ADP
            ;;
        *)
            echo ""
            ;;
    esac
}

# 校验本地目录是否有效
GIT:validate_directory() {
    local dir=$1 way=$2
    case "$way" in
        zip) [[ -d "$dir/src" && -d "$dir/template" && -f "$dir/requirements.txt" ]] ;;
        git) git -C "$dir" rev-parse --git-dir &>/dev/null ;;
        *)   false ;;
    esac
}

# 下载核心
GIT:download_repository() {
    local way=$1 url=$2 dir=$3
    case "$way" in
        git)
            git clone "$url" "$dir" >&2
            ;;
        zip)
            local tmpdir tmpzip
            tmpdir=$(mktemp -d) && trap "rm -rf '$tmpdir'" RETURN
            tmpzip=$tmpdir/dl.zip
            wget -O "$tmpzip" "$url" >&2
            unzip -q "$tmpzip" -d "$tmpdir"
            mkdir -p "$dir"
            mv "$tmpdir"/*/* "$dir"
            ;;
        *)
            log.error "未知下载方式: $way"
            return 1
            ;;
    esac
}

# 后处理：切分支 + 适配器黑名单
GIT:post_process() {
    local way=$1 target=$2 tag=$3 dir=$4
    if [[ $way == git ]]; then
        git -C "$dir" -c advice.detachedHead=false switch "$tag" &>/dev/null ||
        git -C "$dir" -c advice.detachedHead=false checkout "$tag" &>/dev/null
    fi
    if [[ $target == Adapter || $target == MaiBot-Napcat-Adapter ]]; then
        sed -i 's/private_list_type = "whitelist"/private_list_type = "blacklist"/' \
            "$dir/template/template_config.toml"
        sed -i 's/group_list_type = "whitelist"/group_list_type = "blacklist"/' \
            "$dir/template/template_config.toml"
        cp "$dir/template/template_config.toml" "$dir/config.toml"
    fi
}

#############################################
## 3. 主入口
#############################################
# Get-MaiMaiRepository MaiBot main git "" ""
# Get-MaiMaiRepository Adapter main git "" ""
Get-MaiMaiRepository() {
    local target=${1:-} tag=${2:-} way=${3:-git} proxy=${4:-} custom_dir=${5:-}
    [[ -z $target || -z $tag ]] && { log.error "目标/标签不能为空"; return 1; }

    # 自动选择 way
    if [[ -z $way ]]; then
        command -v git &>/dev/null && way=git || way=zip
    fi

    # 取地址表
    local -n url_map=$(GIT:get_url_map "$target" "$way")
    [[ -z ${url_map[$tag]:-} ]] && { log.error "无效标签: $tag"; return 1; }

    local url=${url_map[$tag]}
    [[ -n $proxy ]] && url="${proxy%/}/${url#*://}"

    # 生成目录
    local work=${WORKPATH:-./tmp}
    local dir=${custom_dir:-$work/MaiM-with-u/${DIR_NAMES[$target]}}
    dir=$(realpath -m "$dir")   # 绝对路径
    [[ $dir == "/" ]] && { log.error "禁止操作根目录"; return 1; }
    [[ $dir != *"/MaiM-with-u/"* ]] && { log.error "目录必须包含 /MaiM-with-u/"; return 1; }

    # 已存在且有效 -> 直接返回
    if GIT:validate_directory "$dir" "$way"; then
        log.info "已存在有效目录，跳过: $dir"
        printf '%s\n' "$dir"
        return 0
    fi

    # 重试 3 次
    local retry=0
    while (( retry < 3 )); do
        rm -rf "$dir"
        mkdir -p "$dir"
        if GIT:download_repository "$way" "$url" "$dir"; then
            GIT:post_process "$way" "$target" "$tag" "$dir"
            printf '%s\n' "$dir"
            return 0
        fi
        ((retry++))
        log.warn "下载失败，第 $retry 次重试..."
        sleep 2
    done

    log.error "3 次重试均失败，放弃"
    return 1
}

#############################################
## 4. 直接执行时给出提示
#############################################
[[ $0 == "${BASH_SOURCE[0]}" ]] && {
    log.info "本脚本仅支持被 source 后调用 Get-MaiMaiRepository"
    exit 1
}
