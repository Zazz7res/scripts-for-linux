#!/bin/bash

# ===============================================
# GitHub 访问优化脚本 (Linux 增强版)
# ===============================================
#
# 功能特点：
# ✅ DNS污染检测与修复
# ✅ IP测速自动优选
# ✅ 彩色交互界面
# ✅ 安全备份与恢复
# ✅ 自动验证效果
# ✅ 智能错误处理
#
# 使用方法：sudo bash github_optimizer.sh
# 作者：AI助手 | 版本：v2.1
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
PURPLE='\033[0;35m'
GRAY='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m'

# 彩色输出函数
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
# 初始化检查
# ==============================
print_header "GitHub 访问优化脚本 v2.1"

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    print_color $RED "❌" "请使用 root 权限运行此脚本！"
    print_color $YELLOW "💡" "请使用: ${BOLD}sudo bash $0${NC}"
    exit 1
fi

# 检查操作系统
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    print_color $GREEN "✅" "检测到操作系统: $PRETTY_NAME"
else
    print_color $YELLOW "⚠️" "无法检测操作系统类型，继续执行..."
fi

# ==============================
# 配置常量
# ==============================
GitHubDomains=(
    "github.com"
    "www.github.com"
    "gist.github.com"
    "api.github.com"
    "raw.githubusercontent.com"
    "assets-cdn.github.com"
    "codeload.github.com"
    "github.global.ssl.fastly.net"
)

# 可靠 DNS 服务器
ReliableDNS=("8.8.8.8" "1.1.1.1" "208.67.222.222")

# 后备 IP 地址（2025年最新）
BackupIPs=(
    "20.205.243.166"    # github.com
    "185.199.108.133"   # raw.githubusercontent.com CDN
    "185.199.109.133"
    "185.199.110.133"
    "185.199.111.133"
    "151.101.1.194"     # github.global.ssl.fastly.net
)

# ==============================
# 工具函数
# ==============================

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

# 安装必要工具
install_tools() {
    print_header "检查系统依赖"
    
    local tools=("dig" "ping" "curl" "bc")
    local to_install=()
    
    for tool in "${tools[@]}"; do
        if ! check_command "$tool"; then
            to_install+=("$tool")
        fi
    done
    
    if [[ ${#to_install[@]} -eq 0 ]]; then
        print_color $GREEN "✅" "所有必要工具已安装"
        return 0
    fi
    
    print_color $YELLOW "📦" "需要安装工具: ${to_install[*]}"
    
    if check_command "apt-get"; then
        apt-get update
        apt-get install -y dnsutils iputils-ping curl bc
    elif check_command "yum"; then
        yum install -y bind-utils iputils curl bc
    elif check_command "dnf"; then
        dnf install -y bind-utils iputils curl bc
    elif check_command "pacman"; then
        pacman -S --noconfirm bind-tools iputils curl bc
    else
        print_color $RED "❌" "无法自动安装依赖，请手动安装: ${to_install[*]}"
        return 1
    fi
    
    print_color $GREEN "✅" "工具安装完成"
}

# DNS 解析函数
resolve_dns() {
    local domain=$1
    local dns_server=$2
    dig +short +time=3 +tries=2 "$domain" @"$dns_server" 2>/dev/null | \
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1
}

# TCP 连通性测试
test_tcp_connection() {
    local ip=$1
    local port=${2:-443}
    timeout 3 bash -c "echo > /dev/tcp/$ip/$port" 2>/dev/null
}

# HTTP 可用性测试
test_http_connection() {
    local domain=$1
    local ip=$2
    timeout 5 curl -s -I -H "Host: $domain" --connect-timeout 3 "https://$ip" &>/dev/null
}

# ==============================
# 测速优选函数
# ==============================
get_fastest_ip() {
    local domain=$1
    shift
    local ips=("$@")
    local best_ip=""
    local lowest_latency=999999
    local valid_ips=()
    
    print_color $CYAN "⚡" "对 $domain 进行IP测速 (${#ips[@]}个候选IP)"
    
    # 首先筛选可连接的IP
    for ip in "${ips[@]}"; do
        if test_tcp_connection "$ip" 443; then
            valid_ips+=("$ip")
            print_color $GRAY "  🔹" "IP $ip 可连接，加入测速列表"
        else
            print_color $GRAY "  🔸" "IP $ip 无法连接，跳过"
        fi
    done
    
    if [[ ${#valid_ips[@]} -eq 0 ]]; then
        print_color $YELLOW "⚠️" "没有可用的IP，使用第一个IP: ${ips[0]}"
        echo "${ips[0]}"
        return
    fi
    
    # 对可用IP进行测速
    for ip in "${valid_ips[@]}"; do
        local total_latency=0
        local success_count=0
        local test_count=3
        
        for ((i=0; i<test_count; i++)); do
            if ping_result=$(timeout 2 ping -c 1 "$ip" 2>/dev/null); then
                if ping_time=$(echo "$ping_result" | grep 'time=' | sed -E 's/.*time=([0-9.]+) ms.*/\1/'); then
                    total_latency=$(echo "$total_latency + $ping_time" | bc)
                    ((success_count++))
                fi
            fi
            sleep 0.5
        done
        
        if [[ $success_count -gt 0 ]]; then
            local avg_latency=$(echo "scale=2; $total_latency / $success_count" | bc)
            print_color $GRAY "  📊" "$ip : 平均延迟 ${avg_latency}ms (${success_count}/${test_count})"
            
            if (( $(echo "$avg_latency < $lowest_latency" | bc -l) )); then
                lowest_latency=$avg_latency
                best_ip=$ip
            fi
        else
            print_color $GRAY "  ❌" "$ip : 测速失败"
        fi
    done
    
    if [[ -n "$best_ip" ]]; then
        print_color $GREEN "🏆" "$domain 最佳IP: $best_ip (延迟: ${lowest_latency}ms)"
        echo "$best_ip"
    else
        print_color $YELLOW "⚠️" "无法确定最佳IP，使用第一个可用IP: ${valid_ips[0]}"
        echo "${valid_ips[0]}"
    fi
}

# ==============================
# 诊断阶段
# ==============================
diagnose_github() {
    print_header "网络连接诊断"
    
    local IsDnsPolluted=false
    local CanConnectToIP=true
    declare -gA DomainIPs
    
    # 检查工具
    install_tools
    
    print_color $CYAN "🔍" "检查DNS解析..."
    
    # 测试每个域名的DNS解析
    for domain in "${GitHubDomains[@]}"; do
        print_color $GRAY "  🖥️" "检查: $domain"
        
        # 从多个可靠DNS获取IP
        local clean_ip=""
        for dns in "${ReliableDNS[@]}"; do
            clean_ip=$(resolve_dns "$domain" "$dns")
            if [[ -n "$clean_ip" ]]; then
                break
            fi
        done
        
        # 本地DNS解析
        local local_ip=$(resolve_dns "$domain" "")
        
        if [[ -z "$clean_ip" ]]; then
            print_color $RED "  ❌" "无法从可靠DNS解析 $domain"
            # 使用后备IP
            case $domain in
                "raw.githubusercontent.com")
                    clean_ip="185.199.108.133"
                    ;;
                "github.global.ssl.fastly.net")
                    clean_ip="151.101.1.194"
                    ;;
                *)
                    clean_ip="20.205.243.166"
                    ;;
            esac
            print_color $YELLOW "  🔧" "使用后备IP: $clean_ip"
        elif [[ -n "$local_ip" && "$local_ip" != "$clean_ip" ]]; then
            print_color $YELLOW "  🚨" "DNS污染: 本地=$local_ip, 清洁=$clean_ip"
            IsDnsPolluted=true
        else
            print_color $GREEN "  ✅" "解析正常: $clean_ip"
        fi
        
        DomainIPs["$domain"]=$clean_ip
        
        # 测试TCP连接
        if ! test_tcp_connection "$clean_ip" 443; then
            print_color $RED "  ❌" "无法连接到 $clean_ip:443"
            CanConnectToIP=false
        else
            print_color $GREEN "  ✅" "TCP连接正常"
        fi
    done
    
    # 输出诊断结论
    print_header "诊断结果"
    if [[ $IsDnsPolluted == true ]]; then
        print_color $GREEN "✅" "主要问题: DNS污染"
        print_color $CYAN "💡" "解决方案: 更新hosts文件可解决此问题"
    else
        print_color $YELLOW "⚠️" "DNS解析正常，可能需优化IP选择"
    fi
    
    if [[ $CanConnectToIP == false ]]; then
        print_color $RED "🚨" "严重: 网络连接被阻断"
        print_color $YELLOW "💡" "建议使用代理工具，hosts方案可能无效"
        
        read -p "$(print_color $YELLOW "❓" "是否继续尝试优化? (y/N): ")" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# ==============================
# IP优化阶段
# ==============================
optimize_ips() {
    print_header "IP测速优化"
    
    declare -gA OptimizedIPs
    
    for domain in "${GitHubDomains[@]}"; do
        local base_ip=${DomainIPs["$domain"]}
        local test_ips=("$base_ip")
        
        # 为重要域名添加多个测试IP
        case $domain in
            "github.com")
                test_ips+=("20.205.243.166" "20.205.243.168" "20.205.243.169")
                ;;
            "raw.githubusercontent.com")
                test_ips+=("185.199.108.133" "185.199.109.133" "185.199.110.133" "185.199.111.133")
                ;;
            "assets-cdn.github.com")
                test_ips+=("185.199.108.153" "185.199.109.153" "185.199.110.153" "185.199.111.153")
                ;;
        esac
        
        # 去除重复IP
        test_ips=($(printf "%s\n" "${test_ips[@]}" | sort -u))
        
        best_ip=$(get_fastest_ip "$domain" "${test_ips[@]}")
        OptimizedIPs["$domain"]=$best_ip
        
        # 验证HTTP连接
        if test_http_connection "$domain" "$best_ip"; then
            print_color $GREEN "  ✅" "HTTP连接验证成功"
        else
            print_color $YELLOW "  ⚠️" "HTTP连接验证失败，但IP可能仍可用"
        fi
    done
}

# ==============================
# 更新hosts文件
# ==============================
update_hosts() {
    print_header "更新系统hosts文件"
    
    local hosts_file="/etc/hosts"
    local backup_file="/etc/hosts.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 备份原文件
    cp "$hosts_file" "$backup_file"
    print_color $GREEN "✅" "已备份原文件: $backup_file"
    
    # 创建临时文件
    local temp_file=$(mktemp)
    local in_github_block=false
    local github_block_found=false
    
    # 处理原文件，移除旧的GitHub块
    while IFS= read -r line; do
        if [[ $line == "# ===== GitHub Hosts Start ====="* ]]; then
            in_github_block=true
            github_block_found=true
            continue
        fi
        
        if [[ $line == "# ===== GitHub Hosts End ====="* ]]; then
            in_github_block=false
            continue
        fi
        
        if [[ $in_github_block == false ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$hosts_file"
    
    # 添加新的GitHub块
    {
        echo ""
        echo "# ===== GitHub Hosts Start ====="
        echo "# 更新时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# 自动生成，请勿手动修改"
        echo "# ============================="
        
        for domain in "${GitHubDomains[@]}"; do
            echo -e "${OptimizedIPs[$domain]}\t$domain"
            print_color $GRAY "  ➕" "${OptimizedIPs[$domain]}    $domain"
        done
        
        echo "# ===== GitHub Hosts End ====="
    } >> "$temp_file"
    
    # 替换原文件
    mv "$temp_file" "$hosts_file"
    chmod 644 "$hosts_file"
    
    print_color $GREEN "✅" "hosts文件更新完成"
    
    if [[ $github_block_found == true ]]; then
        print_color $CYAN "🔄" "检测到并替换了旧的GitHub hosts配置"
    fi
}

# ==============================
# 刷新DNS缓存
# ==============================
flush_dns_cache() {
    print_header "刷新DNS缓存"
    
    local flushed=false
    
    if systemctl is-active systemd-resolved &>/dev/null; then
        systemctl restart systemd-resolved
        print_color $GREEN "✅" "已刷新 systemd-resolved DNS缓存"
        flushed=true
    fi
    
    if systemctl is-active NetworkManager &>/dev/null; then
        systemctl restart NetworkManager
        print_color $GREEN "✅" "已刷新 NetworkManager DNS缓存"
        flushed=true
    fi
    
    if check_command "nscd" && systemctl is-active nscd &>/dev/null; then
        systemctl restart nscd
        print_color $GREEN "✅" "已刷新 nscd DNS缓存"
        flushed=true
    fi
    
    # 通用方法
    if [[ $flushed == false ]]; then
        print_color $YELLOW "⚠️" "未找到标准DNS服务，尝试通用方法..."
        if check_command "service"; then
            service networking restart 2>/dev/null && \
            print_color $GREEN "✅" "已重启网络服务" || \
            print_color $YELLOW "⚠️" "网络服务重启失败，可能需要手动操作"
        else
            print_color $YELLOW "💡" "请手动重启网络或重新登录以应用更改"
        fi
    fi
}

# ==============================
# 验证效果
# ==============================
verify_optimization() {
    print_header "验证优化效果"
    
    local success_count=0
    local total_tests=0
    
    print_color $CYAN "🌐" "测试域名访问..."
    
    for domain in "${GitHubDomains[@]:0:4}"; do  # 测试前4个重要域名
        ((total_tests++))
        print_color $GRAY "  🧪" "测试: $domain"
        
        if resolved_ip=$(resolve_dns "$domain" ""); then
            if timeout 5 curl -s -I "https://$domain" &>/dev/null; then
                print_color $GREEN "  ✅" "访问成功 (解析到: $resolved_ip)"
                ((success_count++))
            else
                print_color $RED "  ❌" "访问失败 (解析到: $resolved_ip)"
            fi
        else
            print_color $RED "  ❌" "DNS解析失败"
        fi
    done
    
    # 成功率统计
    local success_rate=$((success_count * 100 / total_tests))
    
    print_color $CYAN "📊" "测试结果: $success_count/$total_tests 成功 (${success_rate}%)"
    
    if [[ $success_rate -ge 75 ]]; then
        print_color $GREEN "🎉" "优化成功！GitHub访问已显著改善"
    elif [[ $success_rate -ge 50 ]]; then
        print_color $YELLOW "⚠️" "优化部分成功，某些服务可能仍无法访问"
    else
        print_color $RED "😞" "优化效果不佳，建议检查网络环境或使用代理"
    fi
}

# ==============================
# 浏览器测试
# ==============================
browser_test() {
    print_header "浏览器测试"
    
    # 尝试打开浏览器
    local browsers=("xdg-open" "gnome-open" "kde-open" "sensible-browser")
    local browser_found=false
    
    for browser in "${browsers[@]}"; do
        if command -v "$browser" &>/dev/null; then
            browser_found=true
            print_color $CYAN "🌐" "使用 $browser 打开 GitHub..."
            
            # 在后台打开浏览器
            nohup "$browser" "https://github.com" &>/dev/null &
            
            read -p "$(print_color $YELLOW "❓" "是否同时打开 raw.githubusercontent.com 测试页? (y/N): ")" -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                nohup "$browser" "https://raw.githubusercontent.com/octocat/Hello-World/master/README" &>/dev/null &
                print_color $GREEN "✅" "已打开 raw.githubusercontent.com 测试页面"
            fi
            break
        fi
    done
    
    if [[ $browser_found == false ]]; then
        print_color $YELLOW "💡" "未找到图形界面浏览器，请手动访问:"
        echo "   🌐 https://github.com"
        echo "   📁 https://raw.githubusercontent.com/octocat/Hello-World/master/README"
    fi
}

# ==============================
# 主函数
# ==============================
main() {
    print_color $GREEN "🚀" "开始 GitHub 访问优化..."
    
    # 执行各个阶段
    diagnose_github
    optimize_ips
    update_hosts
    flush_dns_cache
    verify_optimization
    browser_test
    
    # 完成提示
    print_header "优化完成"
    print_color $GREEN "✅" "所有操作已完成！"
    echo
    print_color $CYAN "📋" "本次优化的最佳IP:"
    for domain in "${GitHubDomains[@]}"; do
        print_color $GRAY "  📍" "$domain → ${OptimizedIPs[$domain]}"
    done
    echo
    print_color $YELLOW "💡" "使用建议:"
    print_color $GRAY "  🔄" "建议每周运行一次本脚本以保持最佳速度"
    print_color $GRAY "  📦" "如需恢复: sudo cp /etc/hosts.backup.* /etc/hosts"
    print_color $GRAY "  🛠️" "问题反馈: 检查网络环境或使用代理工具"
    echo
    print_color $GREEN "🎯" "感谢使用 GitHub 访问优化脚本！"
}

# ==============================
# 脚本入口
# ==============================

# 检查是否直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 设置错误处理
    trap 'print_color $RED "💥" "脚本执行出错，退出码: $?"; exit 1' ERR
    
    # 执行主函数
    main "$@"
fi
