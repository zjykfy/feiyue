#!/bin/bash
# cd /root/iptv
# read -p "确定要运行脚本吗？(y/n): " choice

# 判断用户的选择，如果不是"y"则退出脚本
# if [ "$choice" != "y" ]; then
#     echo "脚本已取消."
#     exit 0
# fi

time=$(date +%m%d%H%M)
i=0

if [ $# -eq 0 ]; then
  echo "请选择城市："
  echo "1. 湖北（Hubei_dianxin）"
  echo "0. 全部"
  read -t 10 -p "输入选择或在10秒内无输入将默认选择全部: " city_choice

  if [ -z "$city_choice" ]; then
      echo "未检测到输入，自动选择全部选项..."
      city_choice=0
  fi

else
  city_choice=$1
fi

# 根据用户选择设置城市和相应的stream
case $city_choice in
    1)
        city="Hubei_dianxin"
        stream="rtp/239.69.1.204:10866"
        channel_key="湖北"
#        url_fofa=$(echo  '"udpxy" && country="CN" && region="Hubei" && org="Chinanet" && protocol="http"' | base64 |tr -d '\n')
#        url_fofa="https://fofa.info/result?qbase64="$url_fofa
        url_fofa="https://raw.githubusercontent.com/zjykfy/fa/refs/heads/main/Hubei_dianxin.txt"$url_fofa
        ;;
    0)
        # 如果选择是“全部选项”，则逐个处理每个选项
        for option in {1..15}; do
          bash  "$0" $option  # 假定fofa.sh是当前脚本的文件名，$option将递归调用
        done
        exit 0
        ;;

    *)
        echo "错误：无效的选择。"
        exit 1
        ;;
esac



# 使用城市名作为默认文件名，格式为 CityName.ip
ipfile="ip/${city}.ip"
only_good_ip="ip/${city}.onlygood.ip"
rm -f $only_good_ip
# 搜索最新 IP
echo "===============从 fofa 检索 ip+端口================="
curl -o test.html "$url_fofa"
#echo $url_fofa
echo "$ipfile"
grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$' test.html | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+' > "$ipfile"
rm -f test.html
# 遍历文件 A 中的每个 IP 地址
while IFS= read -r ip; do
    # 尝试连接 IP 地址和端口号，并将输出保存到变量中
    tmp_ip=$(echo -n "$ip" | sed 's/:/ /')
    echo "nc -w 1 -v -z $tmp_ip 2>&1"
    output=$(nc -w 1 -v -z $tmp_ip 2>&1)
    echo $output    
    # 如果连接成功，且输出包含 "succeeded"，则将结果保存到输出文件中
    if [[ $output == *"succeeded"* ]]; then
        # 使用 awk 提取 IP 地址和端口号对应的字符串，并保存到输出文件中
        echo "$output" | grep "succeeded" | awk -v ip="$ip" '{print ip}' >> "$only_good_ip"
    fi
done < "$ipfile"

echo "===============检索完成================="

# 检查文件是否存在
if [ ! -f "$only_good_ip" ]; then
    echo "错误：文件 $only_good_ip 不存在。"
    exit 1
fi

lines=$(wc -l < "$only_good_ip")
echo "【$only_good_ip】内 ip 共计 $lines 个"

line_i=0
mkdir -p tmpip
while read -r line; do
    ip=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')  # 去除首尾空格
    
    # 如果行不为空，则写入临时文件
    if [ -n "$ip" ]; then
        echo "$ip" > "tmpip/ip_$line_i.txt"  # 保存为 tmpip 目录下的临时文件
        ((line_i++))
    fi
done < "$only_good_ip"

line_i=0
for temp_file in tmpip/ip_*.txt; do
      ((line_i++))
     ip=$(<"$temp_file")  # 从临时文件中读取 IP 地址
     a=$(./speed.sh "$ip" "$stream")
     echo "第 $line_i/$lines 个：$ip $a"
     echo "$ip $a" >> "speedtest_${city}_$time.log"
done
rm -rf tmpip/*

awk '/M|k/{print $2"  "$1}' "speedtest_${city}_$time.log" | sort -n -r >"result/result_fofa_${city}.txt"
cat "result/result_${city}.txt"
ip1=$(awk 'NR==1{print $2}' result/result_${city}.txt)
ip2=$(awk 'NR==2{print $2}' result/result_${city}.txt)
ip3=$(awk 'NR==3{print $2}' result/result_${city}.txt)
rm -f "speedtest_${city}_$time.log"

# 用 2 个最快 ip 生成对应城市的 txt 文件
program="template/template_${city}.txt"

sed "s/ipipip/$ip1/g" "$program" > tmp1.txt
sed "s/ipipip/$ip2/g" "$program" > tmp2.txt
cat tmp1.txt tmp2.txt > "txt/${city}.txt"

rm -rf tmp1.txt tmp2.txt


#--------------------合并所有城市的txt文件为:   zubo.txt-----------------------------------------

echo "湖北,#genre#" >zubo.txt
cat txt/Hubei_dianxin.txt >>zubo.txt


for a in result/*.txt; do echo "";echo "========================= $(basename "$a") ==================================="; cat $a; done