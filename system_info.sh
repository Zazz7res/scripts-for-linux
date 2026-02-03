#!/bin/bash

echo "========================================"
echo "Ubuntu 25.04 硬件与驱动信息检测脚本"
echo "========================================"
echo "检测时间: $(date)"
echo "========================================\n"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}[警告] 命令 $1 未找到，相关检测将跳过${NC}"
        return 1
    fi
    return 0
}

echo -e "${BLUE}=================== 系统信息 ===================${NC}\n"

# 1. 系统版本信息
echo -e "${GREEN}[1] Ubuntu 系统版本:${NC}"
lsb_release -a 2>/dev/null || echo "lsb_release 命令未安装"

echo -e "\n${GREEN}[2] 内核版本:${NC}"
uname -a

echo -e "\n${GREEN}[3] 系统运行时间:${NC}"
uptime

echo -e "\n${BLUE}=================== CPU 信息 ===================${NC}\n"

# 2. CPU信息 (AMD 5600GT)
echo -e "${GREEN}[4] CPU 详细信息:${NC}"
if check_command "lscpu"; then
    lscpu | grep -E "(Model name|CPU\(s\):|Architecture:|Vendor ID:|CPU MHz:|CPU max MHz:|CPU min MHz:)"
fi

echo -e "\n${GREEN}[5] CPU 使用情况:${NC}"
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print "CPU空闲率: " 100-$1 "%"}'

echo -e "\n${BLUE}=================== 显卡信息 ===================${NC}\n"

# 3. 显卡信息 (AMD集成显卡)
echo -e "${GREEN}[6] PCI 显卡设备信息:${NC}"
if check_command "lspci"; then
    lspci -k | grep -A 2 -i "VGA\|Display\|3D"
fi

echo -e "\n${GREEN}[7] 显卡驱动和OpenGL信息:${NC}"
if check_command "glxinfo"; then
    glxinfo | grep -E "OpenGL vendor|OpenGL renderer|OpenGL version|OpenGL shading" | head -4
elif check_command "lshw"; then
    sudo lshw -c display 2>/dev/null | grep -E "product|vendor|driver|configuration" | head -10
fi

echo -e "\n${GREEN}[8] AMD 显卡特定信息:${NC}"
# 检查AMDGPU驱动
if [ -f /sys/kernel/debug/dri/0/name ]; then
    echo "显卡设备: $(cat /sys/kernel/debug/dri/0/name 2>/dev/null)"
fi

if [ -d /sys/class/drm ]; then
    echo "检测到的显示接口:"
    ls /sys/class/drm 2>/dev/null | grep -E "^card[0-9]" || echo "未找到显卡设备"
fi

echo -e "\n${BLUE}=================== 内存信息 ===================${NC}\n"

# 4. 内存信息
echo -e "${GREEN}[9] 内存使用情况:${NC}"
if check_command "free"; then
    free -h
fi

echo -e "\n${GREEN}[10] 内存详细信息:${NC}"
if check_command "dmidecode"; then
    sudo dmidecode --type memory 2>/dev/null | grep -E "Type:|Size:|Speed:|Manufacturer:|Part Number:" | head -20
else
    echo "dmidecode 命令未安装，使用 /proc/meminfo 信息:"
    grep -E "MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree" /proc/meminfo
fi

echo -e "\n${BLUE}=================== 主板与BIOS ===================${NC}\n"

# 5. 主板和BIOS信息
echo -e "${GREEN}[11] 主板信息:${NC}"
if check_command "dmidecode"; then
    sudo dmidecode -t baseboard 2>/dev/null | grep -E "Manufacturer|Product Name|Version|Serial Number" | head -5
fi

echo -e "\n${GREEN}[12] BIOS 信息:${NC}"
if check_command "dmidecode"; then
    sudo dmidecode -t bios 2>/dev/null | grep -E "Vendor|Version|Release Date" | head -5
fi

echo -e "\n${BLUE}=================== 存储设备 ===================${NC}\n"

# 6. 存储设备信息
echo -e "${GREEN}[13] 磁盘分区信息:${NC}"
if check_command "lsblk"; then
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,MODEL
fi

echo -e "\n${GREEN}[14] 磁盘使用情况:${NC}"
df -h --output=source,fstype,size,used,avail,pcent,target | head -20

echo -e "\n${GREEN}[15] SATA/AHCI 设备信息:${NC}"
if check_command "lspci"; then
    lspci | grep -i "SATA\|AHCI\|storage"
fi

echo -e "\n${BLUE}=================== 网络设备 ===================${NC}\n"

# 7. 网络设备信息
echo -e "${GREEN}[16] 网络接口信息:${NC}"
if check_command "ip"; then
    ip -br addr show
else
    ifconfig -a 2>/dev/null | head -20
fi

echo -e "\n${GREEN}[17] 网络设备驱动:${NC}"
if check_command "lspci"; then
    lspci -k | grep -A 2 -i "network\|ethernet"
fi

echo -e "\n${BLUE}=================== 蓝牙设备 ===================${NC}\n"

# 8. 蓝牙设备信息
echo -e "${GREEN}[18] 蓝牙适配器信息:${NC}"
if check_command "hciconfig"; then
    hciconfig -a 2>/dev/null || echo "未检测到蓝牙适配器或蓝牙服务未运行"
else
    echo "hciconfig 命令未安装"
fi

echo -e "\n${GREEN}[19] 蓝牙设备与驱动:${NC}"
if check_command "lsusb"; then
    lsusb | grep -i bluetooth || echo "未找到蓝牙USB设备"
fi

echo -e "\n${GREEN}[20] 蓝牙内核模块:${NC}"
lsmod | grep -i bluetooth || echo "未加载蓝牙内核模块"

echo -e "\n${BLUE}=================== USB 设备 ===================${NC}\n"

# 9. USB设备信息
echo -e "${GREEN}[21] USB 设备列表:${NC}"
if check_command "lsusb"; then
    lsusb
fi

echo -e "\n${BLUE}=================== 声卡设备 ===================${NC}\n"

# 10. 声卡设备信息
echo -e "${GREEN}[22] 声卡设备信息:${NC}"
if check_command "lspci"; then
    lspci | grep -i audio
fi

echo -e "\n${GREEN}[23] 声卡驱动信息:${NC}"
if check_command "aplay"; then
    aplay -l 2>/dev/null || echo "aplay 命令执行失败"
fi

echo -e "\n${BLUE}=================== 内核与驱动 ===================${NC}\n"

# 11. 内核模块和驱动信息
echo -e "${GREEN}[24] 已加载的内核模块:${NC}"
lsmod | head -30

echo -e "\n${GREEN}[25] AMD相关内核模块:${NC}"
lsmod | grep -i amd

echo -e "\n${GREEN}[26] GPU相关内核模块:${NC}"
lsmod | grep -E "drm|gpu|radeon|amdgpu"

echo -e "\n${GREEN}[27] 内核消息中的硬件相关信息:${NC}"
dmesg | grep -i "drm\|amd\|gpu\|radeon" | tail -20

echo -e "\n${GREEN}[28] Xorg 显示服务器日志摘要:${NC}"
if [ -f /var/log/Xorg.0.log ]; then
    grep -E "(WW|EE|AMD|radeon|amdgpu|drm)" /var/log/Xorg.0.log | tail -15
else
    echo "Xorg 日志文件未找到"
fi

echo -e "\n${BLUE}=================== 系统日志 ===================${NC}\n"

# 12. 系统日志中的硬件错误
echo -e "${GREEN}[29] 系统日志中的硬件相关错误:${NC}"
journalctl --dmesg --since="1 hour ago" | grep -E "(error|fail|amd|drm)" | tail -10

echo -e "\n${BLUE}=================== 驱动状态摘要 ===================${NC}\n"

# 13. 驱动状态摘要
echo -e "${GREEN}[30] 驱动状态摘要:${NC}"
echo "1. 显卡驱动状态:"
if lsmod | grep -q "amdgpu"; then
    echo -e "   AMDGPU 驱动: ${GREEN}已加载${NC}"
else
    echo -e "   AMDGPU 驱动: ${RED}未加载${NC}"
fi

echo -e "\n2. 蓝牙驱动状态:"
if lsmod | grep -q "bluetooth"; then
    echo -e "   蓝牙驱动: ${GREEN}已加载${NC}"
else
    echo -e "   蓝牙驱动: ${YELLOW}未加载或未启用${NC}"
fi

echo -e "\n3. 网络驱动状态:"
if ip link show | grep -q "state UP"; then
    echo -e "   网络接口: ${GREEN}已启用${NC}"
else
    echo -e "   网络接口: ${YELLOW}未启用${NC}"
fi

echo -e "\n4. 音频驱动状态:"
if lsmod | grep -q "snd_hda"; then
    echo -e "   音频驱动: ${GREEN}已加载${NC}"
else
    echo -e "   音频驱动: ${YELLOW}未检测到标准音频驱动${NC}"
fi

echo -e "\n${BLUE}=================================================${NC}"
echo -e "${GREEN}检测完成!${NC}"
echo -e "${BLUE}=================================================${NC}"
echo -e "\n提示:"
echo "1. 如果需要更详细的信息，可以查看以下日志文件:"
echo "   - /var/log/Xorg.0.log (显示服务器日志)"
echo "   - /var/log/syslog (系统日志)"
echo "   - dmesg | grep -i amd (内核消息中的AMD相关信息)"
echo -e "\n2. 对于AMD集成显卡，确保已安装正确的驱动:"
echo "   - amdgpu (开源驱动，通常已内置)"
echo "   - firmware-amd-graphics (AMD显卡固件)"
echo -e "\n3. 如果遇到显示问题，可以尝试更新内核或安装更新的Mesa驱动"
