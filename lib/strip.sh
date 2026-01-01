#!/bin/bash

# 🤔

strip_main(){
    local strip_script="${0}.load"
    # 修复正则表达式判断
    if [[ ! "$0" =~ \.load$ ]]; then
        # 保存函数定义到新文件
        echo '#!/bin/bash'>"$strip_script"
        declare -f >> "$strip_script" # 我们不能使用cat，因为它不会保留source
        echo "strip_main" >> "$strip_script"
        chmod +x "$strip_script"
        exec "$strip_script"
    fi
    
    # 读取文件内容
    mapfile -t strip_script_lines < "$strip_script"
    
    # 处理每一行
    for strip_script_line in "${strip_script_lines[@]}"; do
        # 跳过空行
        [[ -z "$strip_script_line" ]] && continue
        
        IFS=' ' read -r -a line <<< "$strip_script_line" # 我们以空格分割每一行
        
        # 跳过注释行
        if [[ "${line[0]}" =~ ^# ]]; then
            continue
        fi
        
        local strip_line_index=0
        local strip_line_index_max="${#line[@]}"
        local strip_line_finished=true
        
        for line_code in "${line[@]}"; do
            # 注释掉包含log的命令
            if [[ "$line_code" =~ log.* ]]; then
                [[ "$strip_line_finished" == true ]] && line[$strip_line_index]="# $line_code"
            fi
            case $strip_line_index in
            0)
                # 第一列通常是命令或函数名，保持不变
                :
                ;;
            "$strip_line_index_max")
                # 检查是否以反斜杠结尾（续行）
                [[ "$line_code" =~ \\$ ]] && strip_line_finished=false || strip_line_finished=true
                ;;
            *)
                :
                ;;
            esac
            ((strip_line_index++))
        done
        
        # 这里可以添加处理后的行输出
        # echo "${line[@]}"
    done
}

# 修复判断条件 - 检查脚本是否被直接执行
if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    # 被其他脚本source后决定是否需要strip_main，这样就得到了一个包含所有加载了库的单文件（如果它source了）
    exit 0
fi