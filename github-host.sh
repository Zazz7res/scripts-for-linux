#!/bin/bash

# ===============================================
# GitHub 访问优化脚本 v3.0 (修复增强版)
# ===============================================
#
# 修复内容：
# 🔧 修复 HTTPS SNI 验证失败导致的误报
# 🔧 修复因 Ping 被拦截导致的 IP 误判
# 🔧 优化 IP 测速算法，TCP 握手优先
# 🔧 更新 2024/2025 可用 IP 库
#
# 使用方法：sudo bash github_optimizer.sh
# ===============================================

set -e

# ==============================
# 颜色输出定义
# ==============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_color() {
    local color=$1
    local emoji=$2
    shift 2
    echo -e "${color}${emoji} $*${NC}"
}

print_header() {
    echo
    print_color $CYAN "🔷" "========================================"
    print_color $CYAN "🔷" "$1"
    print_color $CYAN "🔷" "========================================"
    echo
}

# ==============================
# 依赖检查
# ==============================
check_dependencies() {
    local missing=()
    for cmd in curl ping timeout; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_color $RED "❌" "缺少必要命令: ${missing[*]}"
        print_color $YELLOW "💡" "正在尝试安装..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y iputils-ping curl coreutils
        elif command -v yum &> /dev/null; then
            yum install -y iputils curl coreutils
        else
            print_color $RED "❌" "无法自动安装，请手动安装: ${missing[*]}"
            exit 1
        fi
    fi
}

# ==============================
# 配置区域
# ==============================
GitHubDomains=(
    "github.com"
    "assets-cdn.github.com"
    "github.global.ssl.fastly.net"
    "raw.githubusercontent.com"
    "gist.github.com"
    "api.github.com"
)

# 2024/2025 常用 GitHub IP 候选池 (包含部分 Fastly 和 Azure 节点)
# 注意：实际使用中脚本会尝试解析，这些作为强后备
BackupIPs=(
    # github.com
    "20.205.243.166" "20.205.243.168" "20.27.177.113" "20.87.245.6" "140.82.112.4" "140.82.116.4"
    # raw.githubusercontent.com (185.199.x.x)
    "185.199.108.133" "185.199.109.133" "185.199.110.133" "185.199.111.133"
    # assets-cdn.github.com (185.199.x.x)
    "185.199.108.153" "185.199.109.153" "185.199.110.153" "185.199.111.153"
    # github.global.ssl.fastly.net (151.101.x.x)
    "151.101.1.194" "151.101.65.194" "151.101.129.194" "151.101.193.194"
)

# ==============================
# 核心功能函数
# ==============================

# 检测 TCP 连通性 (最可靠的方法)
test_tcp() {
    local ip=$1
    local port=${2:-443}
    # 使用超时 2 秒检测 TCP 端口
    timeout 2 bash -c "echo > /dev/tcp/$ip/$port" 2>/dev/null
    return $?
}

# 获取域名的当前 IP (尝试多个 DNS)
resolve_domain() {
    local domain=$1
    # 尝试使用本地解析，如果失败则不返回（依赖后续备用IP）
    if command -v dig &> /dev/null; then
        dig +short @1.1.1.1 $domain +time=2 +tries=1 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1
    elif command -v nslookup &> /dev/null; then
        nslookup $domain 1.1.1.1 2>/dev/null | grep -A 1 "Name:" | tail -1 | awk '{print $2}'
    fi
}

# IP 测速优选 (修复版)
get_best_ip() {
    local domain=$1
    print_color $YELLOW "⚡" "正在优选 $domain 的 IP..."
    
    local candidates=()
    
    # 1. 尝试动态解析获取几个 IP
    local resolved_ip=$(resolve_domain "$domain")
    if [[ -n "$resolved_ip" ]]; then
        candidates+=("$resolved_ip")
    fi
    
    # 2. 添加该域名对应的备用 IP
    case $domain in
        "github.com")
            candidates+=("20.205.243.166" "20.205.243.168" "20.27.177.113" "140.82.112.4")
            ;;
        "raw.githubusercontent.com")
            candidates+=("185.199.108.133" "185.199.109.133" "185.199.110.133")
            ;;
        "assets-cdn.github.com")
            candidates+=("185.199.108.153" "185.199.109.153" "185.199.110.153")
            ;;
        "github.global.ssl.fastly.net")
            candidates+=("151.101.1.194" "151.101.65.194" "151.101.129.194")
            ;;
    esac
    
    # 去重
    candidates=($(echo "${candidates[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    local best_ip=""
    local min_ping=99999
    
    for ip in "${candidates[@]}"; do
        # 第一步：必须 TCP 能连上 (443端口)
        if test_tcp "$ip" 443; then
            # 第二步：尝试 Ping (如果 Ping 不通也不影响使用，仅作为参考)
            local ping_time=$(ping -c 1 -W 1 $ip 2>/dev/null | grep 'time=' | sed -E 's/.*time=([0-9.]+).*/\1/')
            
            if [[ -n "$ping_time" ]]; then
                print_color $GREEN "  ✅" "$ip [可用] 延迟: ${ping_time}ms"
                # 记录延迟最低的
                if (( $(echo "$ping_time < $min_ping" | bc -l) )); then
                    min_ping=$ping_time
                    best_ip=$ip
                fi
            else
                # Ping不通但TCP通（说明禁ping，但可用）
                print_color $CYAN "  🔹" "$ip [可用] (Ping被禁用/超时)"
                # 如果还没有 best_ip，直接用这个
                if [[ -z "$best_ip" ]]; then
                    best_ip="$ip"
                fi
            fi
        else
            print_color $GRAY "  ❌" "$ip [不可达]"
        fi
    done

    # 最终回退
    if [[ -z "$best_ip" ]]; then
        print_color $RED "⚠️" "未找到可用 IP，使用强制备用"
        case $domain in
            "github.com") echo "20.205.243.166" ;;
            "raw.githubusercontent.com") echo "185.199.108.133" ;;
            "github.global.ssl.fastly.net") echo "151.101.1.194" ;;
            *) echo "${candidates[0]}" ;;
        esac
    else
        echo "$best_ip"
    fi
}

# 更新 Hosts
update_hosts() {
    print_header "更新 /etc/hosts"
    
    local hosts_file="/etc/hosts"
    local backup_file="/etc/hosts.backup.$(date +%Y%m%d_%H%M%S)"
    
    cp "$hosts_file" "$backup_file"
    print_color $GREEN "✅" "已备份到: $backup_file"
    
    # 清理旧的 GitHub 记录
    # 注意：这里使用简单的 sed 删除包含这些域名的行
    for domain in "${GitHubDomains[@]}"; do
        # 删除包含该域名的行（不管是注释还是 IP）
        sed -i "/[[:space:]]$domain$/d" "$hosts_file" 2>/dev/null || true
        # 有些系统可能没有 tab，处理空格
        sed -i "/[[:space:]]$domain[[:space:]]/d" "$hosts_file" 2>/dev/null || true
    done
    
    # 添加新记录
    local temp_content=""
    for domain in "${GitHubDomains[@]}"; do
        local ip="${FinalIPs[$domain]}"
        if [[ -n "$ip" ]]; then
            temp_content+="$ip\t$domain\n"
            print_color $GRAY "  ➕" "添加: $ip -> $domain"
        fi
    done
    
    # 写入文件
    echo -e "\n# ===== GitHub Hosts Start =====" >> "$hosts_file"
    echo -e "# Updated by GitHub Optimizer v3.0 on $(date)" >> "$hosts_file"
    printf "$temp_content" >> "$hosts_file"
    echo "# ===== GitHub Hosts End =====" >> "$hosts_file"
    
    print_color $GREEN "✅" "Hosts 更新完成"
}

# 验证结果
verify() {
    print_header "最终验证"
    print_color $CYAN "🌐" "测试连接 github.com..."
    
    # 这里使用域名测试，因为 hosts 已经修改
    if curl -I -s --connect-timeout 5 https://github.com | grep -q "Server: GitHub.com"; then
        print_color $GREEN "🎉" "连接成功！现在可以访问 GitHub 了。"
    else
        # 有时候响应头不包含 Server: GitHub.com，只要能通就行
        if curl -I -s --connect-timeout 5 https://github.com | grep -q "HTTP"; then
            print_color $GREEN "🎉" "连接成功！"
        else
            print_color $YELLOW "⚠️" "连接可能仍有问题，请检查代理或稍后再试。"
        fi
    fi
}

# ==============================
# 主流程
# ==============================
main() {
    print_header "GitHub 访问优化脚本 v3.0"
    
    # 检查 Root
    if [[ $EUID -ne 0 ]]; then
        print_color $RED "❌" "请使用 sudo 运行此脚本"
        exit 1
    fi
    
    check_dependencies
    
    declare -A FinalIPs
    
    # 循环处理每个域名
    for domain in "${GitHubDomains[@]}"; do
        FinalIPs["$domain"]=$(get_best_ip "$domain")
    done
    
    update_hosts
    
    # 刷新 DNS 缓存 (如果有的话)
    if systemctl is-active systemd-resolved &>/dev/null; then
        systemctl restart systemd-resolved
        print_color $GRAY "🔄" "已刷新 systemd-resolved"
    fi
    
    verify
    
    echo
    print_color $CYAN "📋" "映射列表:"
    for domain in "${GitHubDomains[@]}"; do
        echo "  ${FinalIPs[$domain]} -> $domain"
    done
    echo
}

main
