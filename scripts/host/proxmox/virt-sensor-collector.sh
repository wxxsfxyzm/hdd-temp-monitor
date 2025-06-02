#!/bin/bash
VMID=103
TIMEOUT=2.5 # 超时设定为2.5s

# 动态查找 virt-temp 设备节点
VIRT_DEVICE="virt_temp"
HW_MON_PATH=$(find -L /sys/class/hwmon -maxdepth 2 -name "name" -exec grep -l "$VIRT_DEVICE" {} + 2>/dev/null | xargs dirname)

# 验证是否找到设备
if [[ -z "$HW_MON_PATH" ]]; then
    logger "错误：未找到 $VIRT_DEVICE 设备节点！"
    exit 1
fi

# 构建完整的温度文件路径
TEMP_FILE="${HW_MON_PATH}/temp1_input"

# 检查虚拟机是否开机
status=$(qm status $VMID)
if [[ "$status" != *"running"* ]]; then
    exit 0
fi

# 带超时的获取温度命令
result=$(timeout $TIMEOUT qm guest exec $VMID bash /boot/config/extras/virt-sensor/report_temp.sh 2>&1)
# echo "result:$result"

# 检查超时
if [[ $? -eq 124 ]]; then
    logger "QGA执行超时 ($TIMEOUT秒)"
    exit 1
fi

# 解析并写入温度
if temp=$(echo "$result" | jq -r '.["out-data"]' | tr -d '\n'); then
    temp=$((temp * 1000))
    # echo "temp:$temp"
    echo "$temp" > "$TEMP_FILE"
else
    # echo "temp:$temp"
    logger "解析温度失败"
    exit 1
fi