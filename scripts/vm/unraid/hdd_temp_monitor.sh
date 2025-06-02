#!/bin/bash

# 默认参数值
type="default"
info="short"

# 帮助信息
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Monitor disk temperatures and output maximum value"
    echo ""
    echo "Options:"
    echo "  -t, --type [default|unraid]  Disk type context (default: default)"
    echo "         default: include sda in monitoring"
    echo "         unraid:  skip monitoring sda"
    echo "  -i, --info [short|full]       Output information level (default: short)"
    echo "         short: output only maximum temperature"
    echo "         full:  output detailed disk information"
    echo "  -h, --help                    Show this help message"
    exit 0
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--type)
            type="$2"
            if [[ "$type" != "default" && "$type" != "unraid" ]]; then
                echo "Invalid type: $type. Valid values: default, unraid"
                exit 1
            fi
            shift 2
            ;;
        -i|--info)
            info="$2"
            if [[ "$info" != "short" && "$info" != "full" ]]; then
                echo "Invalid info: $info. Valid values: short, full"
                exit 1
            fi
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown parameter: $1"
            show_help
            ;;
    esac
done

# 最大温度初始值
max_temp=0

# 调试信息输出函数
debug_info() {
    if [[ "$info" == "full" ]]; then
        echo "$1" >&2  # 输出到 stderr 避免影响最终数字输出
    fi
}

# 获取所有SATA物理硬盘
debug_info "====== Starting Disk Temperature Monitor ======"
debug_info "Mode: type=$type, info=$info"
debug_info "Detected disks: $(ls /dev/sd? 2>/dev/null | tr '\n' ' ')"

for disk in /dev/sd?; do
    disk_name=$(basename "$disk")

    # 特殊处理 sda
    if [[ "$type" == "unraid" && "$disk_name" == "sda" ]]; then
        debug_info "Skipping virtual disk: $disk_name (type=unraid)"
        continue
    fi

    debug_info "--------------------------------------------"
    debug_info "Processing disk: $disk_name"

    # 检测是否处于待机状态
    standby_info=$(smartctl -i -n standby "$disk" 2>/dev/null)
    if echo "$standby_info" | grep -q "STANDBY"; then
        debug_info "Disk status: STANDBY (not active)"
        temp=0
    else
        # 获取温度信息
        temp_info=$(smartctl -A "$disk" | grep -i "Temperature_Celsius" | awk '{print $10}')
        if [[ -n "$temp_info" ]]; then
            temp=$temp_info
            debug_info "Disk status: ACTIVE"
            debug_info "Temperature: ${temp}°C"
        else
            debug_info "WARNING: Failed to get temperature for $disk_name"
            temp=0
        fi
    fi

    # 更新最高温度
    if [[ $temp -gt $max_temp ]]; then
        max_temp=$temp
    fi
done

# 输出最终结果
if [[ "$info" == "full" ]]; then
    debug_info "============================================"
    debug_info "Maximum temperature detected: ${max_temp}°C"
    debug_info "============================================"
fi

echo "$max_temp"