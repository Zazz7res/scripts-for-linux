#!/bin/bash

# ==============================================================================
# Linux 硬件诊断脚本 v5.2 - 修正版
# 修正项:
#   1. 修复 log_print "DIM" 未定义错误
#   2. 修复 sudo -n smartctl 误用（改为 sudo -n true）
#   3. 修复 APU 检测正则逻辑（两阶段检测）
#   4. 添加终端检测，避免重定向时颜色乱码
#   5. 修复 trap 退出码捕获
#   6. 支持多 GPU 检测
#   7. 报告文件权限设为 600
# ==============================================================================

# 严格模式
set -euo pipefail

SCRIPT_VERSION="5.2"
SCRIPT_NAME="Linux Hardware Inspector"
REPORT_DIR="${HOME}/.hw_inspector"
SAFE_HOSTNAME=$(hostname | tr -d '[:space:]' | tr -c '[:alnum:]-' '_')
REPORT_FILE="${REPORT_DIR}/hw_report_${SAFE_HOSTNAME}_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p "$REPORT_DIR"
TEMP_DIR=$(mktemp -d -t hwinspect_XXXXXX)

# 终端检测：仅在终端输出颜色
USE_COLOR=0
[[ -t 1 ]] && USE_COLOR=1

# 颜色定义（仅终端启用）
if [[ $USE_COLOR -eq 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; MAGENTA=''; NC=''
fi

# 全局状态
declare -g IS_ROOT=false
declare -ga WARNINGS=()

# 错误处理：显式保存退出码
EXIT_CODE=0
cleanup() {
    local exit_code=${1:-$?}
    if [[ $exit_code -ne 0 ]]; then
        echo -e "\n${RED}[FATAL] 脚本异常退出 (Code: $exit_code)${NC}" >&2
        echo "调试信息保留在: $TEMP_DIR" >&2
    else
        rm -rf "$TEMP_DIR" 2>/dev/null || true
    fi
}
trap 'EXIT_CODE=$?; cleanup $EXIT_CODE' EXIT INT TERM

# ==============================================================================
# 辅助函数
# ==============================================================================

log_print() {
    local level="$1"
    local msg="$2"
    local color="$NC"
    
    case "$level" in
        INFO)  color="$CYAN" ;;
        WARN)  color="$YELLOW" ;;
        ERROR) color="$RED" ;;
        OK)    color="$GREEN" ;;
    esac
    
    echo -e "${color}${msg}${NC}" | tee -a "$REPORT_FILE" || true
}

cmd_exists() {
    command -v "$1" &>/dev/null
}

run_cmd() {
    local desc="$1"
    shift
    local cmd=("$@")
    
    log_print "INFO" "\n▶ $desc"
    
    if ! cmd_exists "${cmd[0]}"; then
        log_print "WARN" "[忽略] 命令 '${cmd[0]}' 未安装"
        return 0
    fi
    
    "${cmd[@]}" 2>>"$TEMP_DIR/cmd_errors.log" | tee -a "$REPORT_FILE" || true
    
    if [[ -s "$TEMP_DIR/cmd_errors.log" ]]; then
        if ! grep -qiE "(unable to guess|deprecated|debug)" "$TEMP_DIR/cmd_errors.log"; then
            log_print "INFO" "  [提示] $(head -n 1 "$TEMP_DIR/cmd_errors.log" | tr -d '\n')"
        fi
        : > "$TEMP_DIR/cmd_errors.log"
    fi
}

# ==============================================================================
# 检测模块
# ==============================================================================

check_system_info() {
    log_print "INFO" "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    log_print "INFO" "${BLUE}║${NC}  系统环境概览                                               ${BLUE}║${NC}"
    log_print "INFO" "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    {
        printf "主机名: %s\n内核:   %s\n架构:   %s\n运行: %s\n" \
            "$(hostname)" \
            "$(uname -r)" \
            "$(uname -m)" \
            "$(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}')"
        
        if [[ -f /etc/os-release ]]; then
            grep PRETTY_NAME /etc/os-release | cut -d'"' -f2
        fi
    } | tee -a "$REPORT_FILE"
}

check_cpu() {
    log_print "INFO" "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    log_print "INFO" "${BLUE}║${NC}  CPU 处理器检测                                              ${BLUE}║${NC}"
    log_print "INFO" "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

    run_cmd "CPU 架构信息" lscpu
    
    local ucode=$(awk '/microcode/ {print $3; exit}' /proc/cpuinfo 2>/dev/null || echo "Unknown")
    echo "微码版本: $ucode" | tee -a "$REPORT_FILE"
    
    local flags=$(awk '/^flags/ {print $0; exit}' /proc/cpuinfo 2>/dev/null || echo "")
    local features=()
    [[ "$flags" =~ "vmx" ]] && features+=("Intel VT-x")
    [[ "$flags" =~ "svm" ]] && features+=("AMD-V")
    [[ "$flags" =~ "aes" ]] && features+=("AES-NI")
    [[ "$flags" =~ "avx2" ]] && features+=("AVX2")
    [[ "$flags" =~ "avx512" ]] && features+=("AVX-512")
    
    echo "硬件特性: ${features[*]:-无}" | tee -a "$REPORT_FILE"

    if cmd_exists sensors; then
        echo -e "\n实时温度:" | tee -a "$REPORT_FILE"
        sensors 2>/dev/null | grep -E 'Core|Package|Tctl|Tdie' | head -10 | tee -a "$REPORT_FILE" || true
    else
        log_print "WARN" "[未安装] lm-sensors (建议: sudo apt install lm-sensors)"
    fi
}

check_gpu() {
    log_print "INFO" "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    log_print "INFO" "${BLUE}║${NC}  GPU 显卡诊断                                                ${BLUE}║${NC}"
    log_print "INFO" "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    local has_nvidia=false has_amd=false has_intel=false
    
    if cmd_exists lspci; then
        lspci -nnk | grep -EA3 'VGA|3D|Display' | tee -a "$REPORT_FILE"
        lspci 2>/dev/null | grep -qi nvidia && has_nvidia=true || true
        lspci 2>/dev/null | grep -qiE "(amd|ati)" && has_amd=true || true
        lspci 2>/dev/null | grep -qi "intel.*vga" && has_intel=true || true
    fi

    # NVIDIA 检测
    if [[ "$has_nvidia" == true ]]; then
        echo -e "\n${GREEN}>>> NVIDIA 专用检测${NC}" | tee -a "$REPORT_FILE"
        if cmd_exists nvidia-smi; then
            LC_ALL=C nvidia-smi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu,power.draw --format=csv,noheader,nounits 2>/dev/null | \
            awk -F', ' '{
                printf "  型号: %s\n  驱动: %s\n  温度: %s°C\n  利用率: %s%%\n  功耗: %sW\n", $1, $2, $3, $4, $5
            }' | tee -a "$REPORT_FILE" || true
        else
            log_print "ERROR" "nvidia-smi 不可用 (建议: sudo apt install nvidia-utils)"
        fi
    fi

    # AMD 检测 - 支持多 GPU
    if [[ "$has_amd" == true ]]; then
        echo -e "\n${MAGENTA}>>> AMD 专用检测${NC}" | tee -a "$REPORT_FILE"
        
        local card_count=0
        for card_path in /sys/class/drm/card*/device; do
            [[ -f "$card_path/vendor" ]] || continue
            local vid=$(cat "$card_path/vendor" 2>/dev/null || echo "")
            [[ "$vid" == "0x1002" ]] || continue
            
            ((card_count++))
            echo -e "\n  --- GPU #${card_count} ---" | tee -a "$REPORT_FILE"
            
            local driver=$(readlink -f "$card_path/driver/module" 2>/dev/null | xargs basename 2>/dev/null || echo "Unknown")
            echo "  驱动: ${driver}" | tee -a "$REPORT_FILE"
            
            # 频率
            if [[ -f "$card_path/pp_dpm_sclk" ]]; then
                echo "  频率状态:" | tee -a "$REPORT_FILE"
                grep "\*" "$card_path/pp_dpm_sclk" 2>/dev/null | sed 's/^/    /' | tee -a "$REPORT_FILE" || echo "    [无法读取]" | tee -a "$REPORT_FILE"
            fi
            
            # 显存
            if [[ -f "$card_path/mem_info_vram_total" ]]; then
                local vram_total=$(($(cat "$card_path/mem_info_vram_total") / 1024 / 1024))
                local vram_used=$(($(cat "$card_path/mem_info_vram_used") / 1024 / 1024 2>/dev/null || echo 0))
                echo "  显存: ${vram_used}MB / ${vram_total}MB" | tee -a "$REPORT_FILE"
            fi

            # 温度
            local temp_input=$(find "$card_path/hwmon" -name "temp1_input" 2>/dev/null | head -n 1)
            if [[ -n "$temp_input" && -r "$temp_input" ]]; then
                local temp=$(cat "$temp_input" 2>/dev/null || echo 0)
                [[ "$temp" -gt 0 ]] && echo "  温度: $((temp/1000))°C" | tee -a "$REPORT_FILE"
            fi
        done

        # 修正：APU 检测（两阶段）
        if lspci -nn 2>/dev/null | grep -qiE "(renoir|cezanne|lucienne|barcelo|rembrandt|phoenix)"; then
            if lspci 2>/dev/null | grep -qiE "(amd|ati)"; then
                log_print "WARN" "  检测到 AMD APU，建议内存频率 ≥3600MHz 以获得最佳性能"
            fi
        fi
    fi
    
    if [[ "$has_intel" == true ]]; then
        echo -e "\n${CYAN}>>> Intel 专用检测${NC}" | tee -a "$REPORT_FILE"
        if cmd_exists intel_gpu_top; then
            timeout 1 intel_gpu_top -s 1000 2>/dev/null | head -20 | tee -a "$REPORT_FILE" || true
        else
            lsmod | grep -E 'i915|xe|i965' | head -5 | tee -a "$REPORT_FILE" || true
        fi
    fi
}

check_storage() {
    log_print "INFO" "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    log_print "INFO" "${BLUE}║${NC}  存储设备                                                    ${BLUE}║${NC}"
    log_print "INFO" "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,MODEL 2>/dev/null | grep -v "loop" | tee -a "$REPORT_FILE" || true
    
    if cmd_exists smartctl; then
        echo -e "\n[S.M.A.R.T 状态]" | tee -a "$REPORT_FILE"
        for dev in /dev/sd[a-z] /dev/nvme[0-9]n1; do
            [[ -e "$dev" ]] || continue
            
            # 修正：使用 sudo -n true 检查权限，避免执行无参数 smartctl
            if [[ "$IS_ROOT" == true ]] || (sudo -n true &>/dev/null 2>&1); then
                local health=$(sudo smartctl -H "$dev" 2>/dev/null | grep "SMART overall-health" || echo "")
                [[ -n "$health" ]] && echo "$dev: $health" | tee -a "$REPORT_FILE"
            else
                echo "$dev: [需要 root 权限]" | tee -a "$REPORT_FILE"
            fi
        done
    else
        log_print "WARN" "[未安装] smartmontools (建议: sudo apt install smartmontools)"
    fi
}

check_memory() {
    log_print "INFO" "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    log_print "INFO" "${BLUE}║${NC}  内存系统                                                    ${BLUE}║${NC}"
    log_print "INFO" "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    free -h | tee -a "$REPORT_FILE"
    
    if [[ "$IS_ROOT" == true ]] && cmd_exists dmidecode; then
        echo -e "\n[物理内存详情]" | tee -a "$REPORT_FILE"
        dmidecode -t memory 2>/dev/null | grep -E "Size:|Type:|Speed:|Manufacturer|Part Number" | grep -v "No Module Installed" | tee -a "$REPORT_FILE" || true
    else
        log_print "WARN" "需要 root 权限查看内存硬件详情 (dmidecode)"
    fi
}

check_network() {
    log_print "INFO" "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    log_print "INFO" "${BLUE}║${NC}  网络适配器                                                  ${BLUE}║${NC}"
    log_print "INFO" "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    ip -br addr show 2>/dev/null | grep -v "^lo" | tee -a "$REPORT_FILE" || {
        echo "[备用方案] 网络接口:" | tee -a "$REPORT_FILE"
        ip -o addr show | awk '{print $2, $4}' | grep -v "lo:" | tee -a "$REPORT_FILE"
    }
}

check_health() {
    log_print "INFO" "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    log_print "INFO" "${BLUE}║${NC}  硬件健康诊断                                                ${BLUE}║${NC}"
    log_print "INFO" "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    if ! dmesg -T &>/dev/null; then
        log_print "WARN" "无法读取内核日志 (需要 root 权限)"
        return
    fi
    
    local dmesg_output=$(dmesg -T 2>/dev/null || dmesg 2>/dev/null)
    
    if echo "$dmesg_output" | grep -qi "Machine check"; then
        log_print "ERROR" "⚠ 检测到 CPU 硬件错误 (MCE)"
        WARNINGS+=("CPU 硬件错误")
    else
        log_print "OK" "CPU 硬件错误: 无"
    fi
    
    if echo "$dmesg_output" | grep -qiE "critical temperature|CPU temperature above threshold|thermal event"; then
        log_print "ERROR" "⚠ 检测到过热记录"
        WARNINGS+=("系统过热")
    else
        log_print "OK" "过热记录: 无"
    fi
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    {
        echo "================================================================================"
        echo "  $SCRIPT_NAME v$SCRIPT_VERSION"
        echo "  生成时间: $(date)"
        echo "  系统: $(uname -srmo)"
        echo "================================================================================"
        echo ""
    } > "$REPORT_FILE"
    
    # 设置报告文件权限
    chmod 600 "$REPORT_FILE" 2>/dev/null || true
    
    if [[ $EUID -eq 0 ]]; then
        IS_ROOT=true
        log_print "OK" "✓ Root 权限模式 (可获取完整硬件信息)"
    else
        log_print "WARN" "⚠ 普通用户模式 (部分详情需 root 权限)"
    fi
    
    check_system_info
    check_cpu
    check_gpu
    check_memory
    check_storage
    check_network
    check_health
    
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    log_print "INFO" "  报告摘要"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    echo "报告文件: $REPORT_FILE" | tee -a "$REPORT_FILE"
    echo "权限: $(stat -c '%a' "$REPORT_FILE" 2>/dev/null || echo "unknown")" | tee -a "$REPORT_FILE"
    
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo -e "\n${RED}⚠ 需关注的问题:${NC}" | tee -a "$REPORT_FILE"
        printf '  - %s\n' "${WARNINGS[@]}" | tee -a "$REPORT_FILE"
    else
        echo -e "\n${GREEN}✓ 未发现严重硬件问题${NC}" | tee -a "$REPORT_FILE"
    fi
    
    echo -e "\n${CYAN}提示: 如需完整诊断，建议以 root 运行: sudo $0${NC}" | tee -a "$REPORT_FILE"
}

main "$@"
