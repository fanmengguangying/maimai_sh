#!/bin/bash

# ---------- 通用锁实现 ----------
acquire_lock() {
    local lock_file="${1:-/tmp/process.lock}"
    local lock_content="${2:-$$}"
    local timeout="${3:-5}"
    local interval="${4:-0.001}"
    
    local start_time=$(date +%s)
    
    while ! (set -o noclobber; echo "$lock_content" > "$lock_file") 2>/dev/null; do
        local current_time=$(date +%s)
        if (( current_time - start_time > timeout )); then
            echo "Error: Timeout acquiring lock $lock_file" >&2
            return 1
        fi
        sleep "$interval"
    done
}

release_lock() {
    local lock_file="${1:-/tmp/process.lock}"
    local expected_content="${2:-$$}"
    
    if [[ -f "$lock_file" ]]; then
        local current_content=$(cat "$lock_file" 2>/dev/null)
        if [[ "$current_content" == "$expected_content" ]]; then
            rm -f "$lock_file"
        else
            echo "Warning: Lock content mismatch" >&2
            return 1
        fi
    fi
}

#!/bin/bash

# 更激进的测试，增加更多并发和更短的操作间隔
run_stress_test() {
    local lock_file="/tmp/stress_test.lock"
    local counter_file="/tmp/stress_counter"
    local num_processes=20    # 更多并发进程
    local operations=500      # 更多操作次数
    
    echo "🚀 开始压力测试: $num_processes 个进程, 每个 $operations 次操作"
    
    # 重置计数器
    echo "0" > "$counter_file"
    
    # 定义工作函数
    stress_worker() {
        local worker_id=$1
        local pid=$$
        for ((i=1; i<=operations; i++)); do
            acquire_lock "$lock_file" "$pid" 10 0.0001
            local current=$(cat "$counter_file")
            # 极短延迟，最大化竞态条件概率
            echo $((current + 1)) > "$counter_file"
            release_lock "$lock_file" "$pid"
        done
    }
    
    # 启动所有进程
    local start_time=$(date +%s.%N)
    for ((p=1; p<=num_processes; p++)); do
        stress_worker $p &
    done
    wait
    local end_time=$(date +%s.%N)
    
    local final_value=$(cat "$counter_file")
    local expected=$((num_processes * operations))
    local duration=$(echo "$end_time - $start_time" | bc)
    
    echo "最终值: $final_value / 期望: $expected"
    echo "耗时: ${duration}秒"
    echo "吞吐量: $(echo "scale=2; $expected / $duration" | bc) 操作/秒"
    
    if [[ $final_value -eq $expected ]]; then
        echo "✅ 压力测试通过 - 锁机制健壮"
    else
        echo "❌ 压力测试失败 - 锁机制有缺陷"
    fi
    
    rm -f "$counter_file" "$lock_file"
}

# 运行压力测试
run_stress_test