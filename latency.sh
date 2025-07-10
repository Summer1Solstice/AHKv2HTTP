#!/bin/bash
ip=""
port=
url="http://$ip:$port/latency"

ping_result=$(ping -w 10 "$ip")
read ping_result_min ping_result_avg ping_result_max <<< "$(echo "$ping_result" | awk 'match($0, /([0-9]+\.[0-9]{1,3})\/([0-9]+\.[0-9]{1,3})\/([0-9]+\.[0-9]{1,3})\//, m) {print m[1], m[2], m[3]}')"

# 保存 ping 结果到变量并输出
ping_output=$(echo -e "ping $ip\nmin:$ping_result_min/avg:$ping_result_avg/max:$ping_result_max")
echo "$ping_output"

# 初始化变量（等号前后不能有空格）
curl_result_min=100
curl_result_max=0
curl_result_sum=0

# 循环10次（0-9）
for i in 0 1 2 3 4 5 6 7 8 9
do
    # 生成随机整数
    random_value=$(($RANDOM))
    # 发送 POST 请求并获取延迟（增加错误处理）
    latency=$(curl -X POST -d "$random_value" -o /dev/null -s -w "%{time_total}" "$url")

    # 累加求和（注意：latency是浮点数，原生sh不支持浮点运算，这里先按字符串累加，最后用bc处理）
    curl_result_sum=$(echo "$curl_result_sum + $latency" | bc)
    
    # 判断最大值（用bc比较浮点数，输出1表示真，0表示假）
    if [ $(echo "$latency > $curl_result_max" | bc) -eq 1 ]; then
        curl_result_max=$latency
    fi
    
    # 判断最小值
    if [ $(echo "$latency < $curl_result_min" | bc) -eq 1 ]; then
        curl_result_min=$latency
    fi
done
curl_result_avg=$(echo "scale=3; $curl_result_sum *1000 / 10" | bc)

curl_result_min=$(echo "scale=3; $curl_result_min * 1000 / 1" | bc)
curl_result_max=$(echo "scale=3; $curl_result_max * 1000 / 1" | bc)
# 保存 curl 结果到变量并输出
curl_output=$(echo -e "curl $url\nmin:$curl_result_min/avg:$curl_result_avg/max:$curl_result_max")
echo "$curl_output"
result="$ping_output
$curl_output"
curl -X POST -d "$result" "$url"