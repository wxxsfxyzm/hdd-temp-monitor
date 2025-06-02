#!/bin/bash
# 调用原脚本，并传递参数 -t unraid -i short，这样就会跳过sda，并只输出温度数字
bash /boot/config/extras/virt-sensor/hdd_temp_monitor.sh -t unraid -i short