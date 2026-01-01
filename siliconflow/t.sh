#!/bin/bash

URL="http://localhost:3699/v1/chat/completions"
AUTH="Bearer sk-khjoxsbsgmhoraxrxrzmaoyvrlhafbmusrrlawtlgcnupzwp"
TOTAL=100
CONCURRENT=20

echo "开始并发测试: $TOTAL 个请求，并发数: $CONCURRENT"
start_time=$(date +%s)

for i in $(seq 1 $TOTAL); do
  data=$(jq -c -n --arg content "并发请求编号 $i" '{
    "model": "moonshotai/Kimi-K2-Instruct-0905",
    "messages": [{"role": "user", "content": $content}],
    "stream": false,
    "max_tokens": 500,
    "enable_thinking": false
  }')
  
  curl -s "$URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: $AUTH" \
    -d "$data" > "/dev/null" 2>&1 &
  
  # 控制并发
  if (( i % CONCURRENT == 0 )); then
    wait
    echo "已完成 $i/$TOTAL 个请求"
  fi
done

wait
end_time=$(date +%s)
duration=$((end_time - start_time))

echo "测试完成!"
echo "总请求数: $TOTAL"
echo "总耗时: $duration 秒"
echo "平均 QPS: $(echo "scale=2; $TOTAL/$duration" | bc)"
