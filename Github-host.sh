
#!/bin/bash

# ==============================
# GitHub 连接优化脚本 (Linux Bash 版本)
# ==============================
#
# SYNOPSIS
#     诊断 GitHub 连接问题并智能优化 hosts 文件
#
# DESCRIPTION
#     本脚本专为仅需访问 GitHub 的用户设计，不依赖 Google 等其他境外网站。
#     它通过检测 GitHub 域名的 DNS 解析与 TCP 连通性，判断是否为 DNS 污染，
#     并据此智能更新 hosts 文件，提升访问成功率。
#     新增功能：IP测速优选、彩色用户界面、自动验证
#
# NOTES
#     Author: Harry (增强版)
#     Date: 2025-11-09
#     重要提示：请务必以 root 权限运行此脚本！否则无法写入 hosts 文件。
#

set -e

# ==============================
# 颜色输出函数
# ==============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

color_echo() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# ==============================
# 第零部分：初始化设置和权限检查
# ==============================

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    color_echo $RED "❌ 请使用 root 权限运行此脚本！"
    color_echo $YELLOW "请使用: sudo bash $0"
    exit 1
fi

color_echo $CYAN "🚀 正在启动 GitHub 智能优化器 (2025 Linux 增强版)..."
color_echo $YELLOW "🔍 本脚本将诊断 GitHub 连接问题并优化访问速度..."

# ==============================
# 第一部分：配置常量
# ==============================

# 定义需要解析的 GitHub 核心域名
GitHubDomains=(
    "github.com"
    "www.github.com"
    "gist.github.com"
    "api.github.com"
    "raw.githubusercontent.com"
    "assets-cdn.github.com"
)

# 使用 Google Public DNS (8.8.8.8) 作为"干净 DNS"源
ReliableDNS="8.8.8.8"

# ==============================
# 第二部分：辅助函数
# ==============================

# 测速并选择最佳IP的函数
get_fastest_ip() {
    local domain=$1
    shift
    local ips=("$@")
    local best_ip=""
    local lowest_latency=999999
    
    color_echo $CYAN "⚡ 正在对 $domain 的 ${#ips[@]} 个候选IP进行测速..."
    
    for ip in "${ips[@]}"; do
        local total_latency=0
        local success_count=0
        local test_count=2
        
        for ((i=0; i<test_count; i++)); do
            if ping_result=$(ping -c 1 -W 2 "$ip" 2>/dev/null); then
                local ping_time=$(echo "$ping_result" | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
                total_latency=$(echo "$total_latency + $ping_time" | bc)
                ((success_count++))
            fi
        done
        
        if [[ $success_count -gt 0 ]]; then
            local avg_latency=$(echo "scale=2; $total_latency / $success_count" | bc)
            color_echo $GRAY "  📶 $ip : 平均延迟 ${avg_latency}ms ($success_count/$test_count 成功)"
            
            if (( $(echo "$avg_latency < $lowest_latency" | bc -l) )); then
                lowest_latency=$avg_latency
                best_ip=$ip
            fi
        else
            color_echo $GRAY "  ❌ $ip : 无法连接"
        fi
    done
    
    if [[ -n "$best_ip" ]]; then
        color_echo $GREEN "🏆 $domain 最佳IP: $best_ip (平均延迟 ${lowest_latency}ms)"
        echo "$best_ip"
    else
        color_echo $YELLOW "⚠️ 无法确定 $domain 的最佳IP，将使用第一个可用IP"
        echo "${ips[0]}"
    fi
}

# DNS 解析函数
resolve_dns() {
    local domain=$1
    local dns_server=$2
    dig +short "$domain" @"$dns_server" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1
}

# TCP 连通性测试
test_tcp_connection() {
    local ip=$1
    local port=443
    timeout 3 bash -c "echo > /dev/tcp/$ip/$port" 2>/dev/null
}

# ==============================
# 第三部分：诊断阶段
# ============================#!/bin/bash

# ==============================
# GitHub 连接优化脚本 (Linux Bash 版本)
# ==============================
#
# SYNOPSIS
#     诊断 GitHub 连接问题并智能优化 hosts 文件
#
# DESCRIPTION
#     本脚本专为仅需访问 GitHub 的用户设计，不依赖 Google 等其他境外网站。
#     它通过检测 GitHub 域名的 DNS 解析与 TCP 连通性，判断是否为 DNS 污染，
#     并据此智能更新 hosts 文件，提升访问成功率。
#     新增功能：IP测速优选、彩色用户界面、自动验证
#
# NOTES
#     Author: Harry (增强版)
#     Date: 2025-11-09
#     重要提示：请务必以 root 权限运行此脚本！否则无法写入 hosts 文件。
#

set -e

# ==============================
# 颜色输出函数
# ==============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

color_echo() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# ==============================
# 第零部分：初始化设置和权限检查
# ==============================

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    color_echo $RED "❌ 请使用 root 权限运行此脚本！"
    color_echo $YELLOW "请使用: sudo bash $0"
    exit 1
fi

color_echo $CYAN "🚀 正在启动 GitHub 智能优化器 (2025 Linux 增强版)..."
color_echo $YELLOW "🔍 本脚本将诊断 GitHub 连接问题并优化访问速度..."

# ==============================
# 第一部分：配置常量
# ==============================

# 定义需要解析的 GitHub 核心域名
GitHubDomains=(
    "github.com"
    "www.github.com"
    "gist.github.com"
    "api.github.com"
    "raw.githubusercontent.com"
    "assets-cdn.github.com"
)

# 使用 Google Public DNS (8.8.8.8) 作为"干净 DNS"源
ReliableDNS="8.8.8.8"

# ==============================
# 第二部分：辅助函数
# ==============================

# 测速并选择最佳IP的函数
get_fastest_ip() {
    local domain=$1
    shift
    local ips=("$@")
    local best_ip=""
    local lowest_latency=999999
    
    color_echo $CYAN "⚡ 正在对 $domain 的 ${#ips[@]} 个候选IP进行测速..."
    
    for ip in "${ips[@]}"; do
        local total_latency=0
        local success_count=0
        local test_count=2
        
        for ((i=0; i<test_count; i++)); do
            if ping_result=$(ping -c 1 -W 2 "$ip" 2>/dev/null); then
                local ping_time=$(echo "$ping_result" | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
                total_latency=$(echo "$total_latency + $ping_time" | bc)
                ((success_count++))
            fi
        done
        
        if [[ $success_count -gt 0 ]]; then
            local avg_latency=$(echo "scale=2; $total_latency / $success_count" | bc)
            color_echo $GRAY "  📶 $ip : 平均延迟 ${avg_latency}ms ($success_count/$test_count 成功)"
            
            if (( $(echo "$avg_latency < $lowest_latency" | bc -l) )); then
                lowest_latency=$avg_latency
                best_ip=$ip
            fi
        else
            color_echo $GRAY "  ❌ $ip : 无法连接"
        fi
    done
    
    if [[ -n "$best_ip" ]]; then
        color_echo $GREEN "🏆 $domain 最佳IP: $best_ip (平均延迟 ${lowest_latency}ms)"
        echo "$best_ip"
    else
        color_echo $YELLOW "⚠️ 无法确定 $domain 的最佳IP，将使用第一个可用IP"
        echo "${ips[0]}"
    fi
}

# DNS 解析函数
resolve_dns() {
    local domain=$1
    local dns_server=$2
    dig +short "$domain" @"$dns_server" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1
}

# TCP 连通性测试
test_tcp_connection() {
    local ip=$1
    local port=443
    timeout 3 bash -c "echo > /dev/tcp/$ip/$port" 2>/dev/null
}

# ==============================
# 第三部分：诊断阶段
# ==============================

color_echo $CYAN "🔍 [诊断阶段] 正在分析 GitHub 访问问题..."

# 检查必要的工具
for cmd in dig ping bc; do
    if ! command -v $cmd &> /dev/null; then
        color_echo $YELLOW "⚠️  安装必要工具: $cmd"
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y dnsutils iputils-ping bc
        elif command -v yum &> /dev/null; then
            yum install -y bind-utils iputils bc
        elif command -v dnf &> /dev/null; then
            dnf install -y bind-utils iputils bc
        else
            color_echo $RED "❌ 无法自动安装依赖，请手动安装: dig, ping, bc"
            exit 1
        fi
        break
    fi
done

# ----------------------------------------
# 3.1 DNS 污染检测
# ----------------------------------------
color_echo $YELLOW "📡 正在测试 GitHub 域名的 DNS 解析是否被污染..."

declare -A ValidIps
IsDnsPolluted=false

for domain in "${GitHubDomains[@]}"; do
    local_ip=$(resolve_dns "$domain" "")
    clean_ip=$(resolve_dns "$domain" "$ReliableDNS")
    
    if [[ -n "$local_ip" && -n "$clean_ip" ]]; then
        if [[ "$local_ip" != "$clean_ip" ]]; then
            IsDnsPolluted=true
            color_echo $YELLOW "   - 🚨 发现污染: $domain (本地: $local_ip, 清洁: $clean_ip)"
        else
            color_echo $GREEN "   - ✅ 解析正常: $domain ($clean_ip)"
        fi
        ValidIps["$domain"]=$clean_ip
    else
        color_echo $RED "   - ❌ 解析失败: $domain，使用后备 IP"
        case $domain in
            "github.com"|"gist.github.com"|"api.github.com"|"assets-cdn.github.com")
                ValidIps["$domain"]="20.205.243.166"
                ;;
            "raw.githubusercontent.com")
                ValidIps["$domain"]="185.199.108.133,185.199.109.133,185.199.110.133,185.199.111.133"
                ;;
            *)
                ValidIps["$domain"]="20.205.243.166"
                ;;
        esac
        
        if [[ $domain == "raw.githubusercontent.com" ]]; then
            color_echo $YELLOW "     🔧 使用后备 CDN IP: ${ValidIps[$domain]}"
        else
            color_echo $YELLOW "     🔧 使用后备 IP: ${ValidIps[$domain]}"
        fi
    fi
done

# ----------------------------------------
# 3.2 TCP 连通性测试
# ----------------------------------------
color_echo $YELLOW "🔌 正在测试到 GitHub 服务器的 TCP 连通性（端口 443）..."

TestDomain="github.com"
TestIP=${ValidIps[$TestDomain]}

if test_tcp_connection "$TestIP" 443; then
    CanConnectToIP=true
    color_echo $GREEN "   - ✅ 成功连接到 $TestDomain ($TestIP:443)"
else
    CanConnectToIP=false
    color_echo $RED "   - ❌ 无法连接到 $TestDomain ($TestIP:443)"
fi

# 诊断结论
if [[ $CanConnectToIP == false ]]; then
    color_echo $RED "🛑 [诊断结论] GitHub IP 被 TCP 重置/阻断"
    echo "   - 无法连接到 GitHub 服务器（IP: $TestIP），即使 IP 正确。"
    echo "   - 原因：网络层阻断（如防火墙 RST）"
    echo "   - hosts 方案成功率：<10%"
    echo "   - 建议：请使用代理工具（如 Clash、V2Ray）绕过阻断。"
    
    read -p "是否仍要继续更新 hosts 文件？(y/N) [默认: N]: " continue
    if [[ ! $continue =~ ^[Yy] ]]; then
        exit
    fi
fi

# ----------------------------------------
# 3.3 诊断总结
# ----------------------------------------
color_echo $CYAN "📊 [诊断总结]"
if [[ $IsDnsPolluted == true ]]; then
    color_echo $GREEN "✅ [诊断结论] DNS 污染（最常见）"
    echo "   - 本地 DNS 返回了错误的 GitHub IP。"
    echo "   - hosts 方案成功率：高（70%~90%）"
    echo "   - 操作：即将更新 hosts 文件并进行IP测速优化..."
else
    color_echo $YELLOW "⚠️ [诊断结论] 可能是 hosts 条目过期或 CDN IP 变动"
    echo "   - DNS 解析正常，但旧 hosts 可能失效。"
    echo "   - hosts 方案成功率：中（30%~50%）"
    echo "   - 操作：仍将更新 hosts 以确保最新。"
fi

# ==============================
# 第四部分：IP测速优化
# ==============================
color_echo $CYAN "⚡ [优化阶段] 正在对获取到的IP进行测速优选..."

declare -A OptimizedIps

for domain in "${GitHubDomains[@]}"; do
    ips_str=${ValidIps[$domain]}
    
    # 处理逗号分隔的多个IP
    if [[ $ips_str == *,* ]]; then
        IFS=',' read -ra ips <<< "$ips_str"
        if [[ ${#ips[@]} -gt 1 ]]; then
            best_ip=$(get_fastest_ip "$domain" "${ips[@]}")
            OptimizedIps["$domain"]=$best_ip
        else
            OptimizedIps["$domain"]=${ips[0]}
            color_echo $GREEN "✅ $domain 直接使用获取到的IP: ${ips[0]}"
        fi
    else
        # 单个IP验证
        if ping -c 1 -W 2 "$ips_str" &>/dev/null; then
            ping_time=$(ping -c 1 -W 2 "$ips_str" | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
            color_echo $GREEN "✅ $domain 验证通过: $ips_str (延迟: ${ping_time}ms)"
        else
            color_echo $YELLOW "⚠️ $domain 无法ping通: $ips_str，但仍将使用此IP"
        fi
        OptimizedIps["$domain"]=$ips_str
    fi
done

# ==============================
# 第五部分：更新 hosts 文件
# ==============================
color_echo $CYAN "🛠️ [执行阶段] 正在更新 hosts 文件..."

HostsPath="/etc/hosts"
BackupPath="/etc/hosts.github_backup_$(date +'%Y%m%d_%H%M%S')"

# 备份 hosts 文件
cp "$HostsPath" "$BackupPath"
color_echo $GREEN "✅ 已备份原始 hosts 文件到: $BackupPath"

# 清理旧的 GitHub hosts 块
temp_hosts=$(mktemp)
in_gitblock=false

while IFS= read -r line; do
    if [[ $line =~ ^#\ =+\ GitHub\ Hosts\ Start\ =+ ]]; then
        in_gitblock=true
        continue
    fi
    if [[ $line =~ ^#\ =+\ GitHub\ Hosts\ End\ =+ ]]; then
        in_gitblock=false
        continue
    fi
    if [[ $in_gitblock == false ]]; then
        echo "$line" >> "$temp_hosts"
    fi
done < "$HostsPath"

# 构建新的 hosts 块
{
    echo "# =================================================="
    echo "# GitHub Hosts Start"
    echo "# Updated by GitHub Optimizer on $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# This block is managed by script. Do not edit manually."
    echo "# =================================================="
    
    for domain in "${GitHubDomains[@]}"; do
        ip=${OptimizedIps[$domain]}
        echo -e "$ip\t$domain"
        color_echo $GRAY "  • 添加: $ip    $domain"
    done
    
    echo "# =================================================="
    echo "# GitHub Hosts End"
    echo "# =================================================="
} >> "$temp_hosts"

# 写入新的 hosts 文件
mv "$temp_hosts" "$HostsPath"
color_echo $GREEN "✅ hosts 文件已成功更新！"

# 刷新DNS缓存
color_echo $CYAN "🔄 正在刷新 DNS 缓存..."
if command -v resolvectl &> /dev/null; then
    # 使用 resolvectl (systemd-resolved 的新命令)
    resolvectl flush-caches
    color_echo $GREEN "✅ 已使用 resolvectl 刷新 DNS 缓存"
elif command -v systemd-resolve &> /dev/null; then
    # 使用 systemd-resolve (旧版本)
    systemd-resolve --flush-caches
    color_echo $GREEN "✅ 已使用 systemd-resolve 刷新 DNS 缓存"
elif systemctl is-active nscd &> /dev/null; then
    # 使用 nscd
    systemctl restart nscd
    color_echo $GREEN "✅ 已重启 nscd 服务刷新 DNS 缓存"
else
    # 通用方法
    color_echo $YELLOW "⚠️  未找到标准的 DNS 缓存刷新工具，尝试通用方法..."
    if command -v service &> /dev/null; then
        service networking restart 2>/dev/null || true
        color_echo $GREEN "✅ 已重启网络服务"
    else
        color_echo $YELLOW "⚠️  无法刷新 DNS 缓存，您可能需要手动重启网络服务或重启系统"
    fi
fi

# ==============================
# 第六部分：验证测试
# ==============================
color_echo $CYAN "🔍 [验证阶段] 正在验证 GitHub 连接..."

test_domains=("github.com" "raw.githubusercontent.com")
for domain in "${test_domains[@]}"; do
    echo -n "🌐 测试访问 $domain..."
    if resolved_ip=$(resolve_dns "$domain" ""); then
        if ping -c 1 -W 2 "$resolved_ip" &>/dev/null; then
            color_echo $GREEN " ✔️ 成功 (解析到 $resolved_ip)"
        else
            color_echo $RED " ❌ 失败 (解析到 $resolved_ip)"
        fi
    else
        color_echo $RED " ❌ 解析失败"
    fi
done

# ==============================
# 第七部分：自动验证
# ==============================
color_echo $GREEN "🎉 [完成] 正在尝试打开 GitHub 页面验证效果..."

# 尝试使用各种浏览器打开
browsers=("xdg-open" "gnome-open" "kde-open" "sensible-browser" "x-www-browser")

for browser in "${browsers[@]}"; do
    if command -v "$browser" &> /dev/null; then
        "$browser" "https://github.com" 2>/dev/null &
        color_echo $GREEN "✅ 已启动浏览器打开 GitHub"
        break
    fi
done

read -p "是否同时打开 raw.githubusercontent.com 测试页面? (y/N) [默认: N]: " open_raw
if [[ $open_raw =~ ^[Yy] ]]; then
    for browser in "${browsers[@]}"; do
        if command -v "$browser" &> /dev/null; then
            "$browser" "https://raw.githubusercontent.com/github/docs/main/README.md" 2>/dev/null &
            color_echo $GREEN "✅ 已打开 raw.githubusercontent.com 测试页面"
            break
        fi
    done
fi

# ==============================
# 第八部分：完成提示
# ==============================
color_echo $CYAN "============================================"
color_echo $GREEN "          🎯 GitHub 优化完成！"
color_echo $CYAN "============================================"
echo "✅ 您现在应该可以快速访问 GitHub 及其相关服务"
echo "📌 本次使用的最佳 IP:"
for domain in "${GitHubDomains[@]}"; do
    echo "   • $domain -> ${OptimizedIps[$domain]}"
done

color_echo $YELLOW "💡 实用提示:"
echo "   • 如果访问速度不理想，可以重新运行此脚本获取最新IP"
echo "   • 如需恢复原始设置，请执行:"
echo "     sudo cp '$BackupPath' '$HostsPath'"
echo "     然后运行适当的DNS缓存刷新命令"
echo ""
echo "   • 建议每周运行一次此脚本，以应对 GitHub IP 变动。"
echo "   • 若仍无法访问，可能需使用代理工具。"

color_echo $CYAN "============================================"
color_echo $GREEN "          操作完成！"
color_echo $CYAN "============================================"
echo ""
echo "✅ 脚本执行完毕，浏览器应已打开 GitHub"
echo ""
color_echo $YELLOW "📌 按任意键继续..." 
read -n 1 -s==

color_echo $CYAN "🔍 [诊断阶段] 正在分析 GitHub 访问问题..."

# 检查必要的工具
for cmd in dig ping bc; do
    if ! command -v $cmd &> /dev/null; then
        color_echo $YELLOW "⚠️  安装必要工具: $cmd"
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y dnsutils iputils-ping bc
        elif command -v yum &> /dev/null; then
            yum install -y bind-utils iputils bc
        elif command -v dnf &> /dev/null; then
            dnf install -y bind-utils iputils bc
        else
            color_echo $RED "❌ 无法自动安装依赖，请手动安装: dig, ping, bc"
            exit 1
        fi
        break
    fi
done

# ----------------------------------------
# 3.1 DNS 污染检测
# ----------------------------------------
color_echo $YELLOW "📡 正在测试 GitHub 域名的 DNS 解析是否被污染..."

declare -A ValidIps
IsDnsPolluted=false

for domain in "${GitHubDomains[@]}"; do
    local_ip=$(resolve_dns "$domain" "")
    clean_ip=$(resolve_dns "$domain" "$ReliableDNS")
    
    if [[ -n "$local_ip" && -n "$clean_ip" ]]; then
        if [[ "$local_ip" != "$clean_ip" ]]; then
            IsDnsPolluted=true
            color_echo $YELLOW "   - 🚨 发现污染: $domain (本地: $local_ip, 清洁: $clean_ip)"
        else
            color_echo $GREEN "   - ✅ 解析正常: $domain ($clean_ip)"
        fi
        ValidIps["$domain"]=$clean_ip
    else
        color_echo $RED "   - ❌ 解析失败: $domain，使用后备 IP"
        case $domain in
            "github.com"|"gist.github.com"|"api.github.com"|"assets-cdn.github.com")
                ValidIps["$domain"]="20.205.243.166"
                ;;
            "raw.githubusercontent.com")
                ValidIps["$domain"]="185.199.108.133,185.199.109.133,185.199.110.133,185.199.111.133"
                ;;
            *)
                ValidIps["$domain"]="20.205.243.166"
                ;;
        esac
        
        if [[ $domain == "raw.githubusercontent.com" ]]; then
            color_echo $YELLOW "     🔧 使用后备 CDN IP: ${ValidIps[$domain]}"
        else
            color_echo $YELLOW "     🔧 使用后备 IP: ${ValidIps[$domain]}"
        fi
    fi
done

# ----------------------------------------
# 3.2 TCP 连通性测试
# ----------------------------------------
color_echo $YELLOW "🔌 正在测试到 GitHub 服务器的 TCP 连通性（端口 443）..."

TestDomain="github.com"
TestIP=${ValidIps[$TestDomain]}

if test_tcp_connection "$TestIP" 443; then
    CanConnectToIP=true
    color_echo $GREEN "   - ✅ 成功连接到 $TestDomain ($TestIP:443)"
else
    CanConnectToIP=false
    color_echo $RED "   - ❌ 无法连接到 $TestDomain ($TestIP:443)"
fi

# 诊断结论
if [[ $CanConnectToIP == false ]]; then
    color_echo $RED "🛑 [诊断结论] GitHub IP 被 TCP 重置/阻断"
    echo "   - 无法连接到 GitHub 服务器（IP: $TestIP），即使 IP 正确。"
    echo "   - 原因：网络层阻断（如防火墙 RST）"
    echo "   - hosts 方案成功率：<10%"
    echo "   - 建议：请使用代理工具（如 Clash、V2Ray）绕过阻断。"
    
    read -p "是否仍要继续更新 hosts 文件？(y/N) [默认: N]: " continue
    if [[ ! $continue =~ ^[Yy] ]]; then
        exit
    fi
fi

# ----------------------------------------
# 3.3 诊断总结
# ----------------------------------------
color_echo $CYAN "📊 [诊断总结]"
if [[ $IsDnsPolluted == true ]]; then
    color_echo $GREEN "✅ [诊断结论] DNS 污染（最常见）"
    echo "   - 本地 DNS 返回了错误的 GitHub IP。"
    echo "   - hosts 方案成功率：高（70%~90%）"
    echo "   - 操作：即将更新 hosts 文件并进行IP测速优化..."
else
    color_echo $YELLOW "⚠️ [诊断结论] 可能是 hosts 条目过期或 CDN IP 变动"
    echo "   - DNS 解析正常，但旧 hosts 可能失效。"
    echo "   - hosts 方案成功率：中（30%~50%）"
    echo "   - 操作：仍将更新 hosts 以确保最新。"
fi

# ==============================
# 第四部分：IP测速优化
# ==============================
color_echo $CYAN "⚡ [优化阶段] 正在对获取到的IP进行测速优选..."

declare -A OptimizedIps

for domain in "${GitHubDomains[@]}"; do
    ips_str=${ValidIps[$domain]}
    
    # 处理逗号分隔的多个IP
    if [[ $ips_str == *,* ]]; then
        IFS=',' read -ra ips <<< "$ips_str"
        if [[ ${#ips[@]} -gt 1 ]]; then
            best_ip=$(get_fastest_ip "$domain" "${ips[@]}")
            OptimizedIps["$domain"]=$best_ip
        else
            OptimizedIps["$domain"]=${ips[0]}
            color_echo $GREEN "✅ $domain 直接使用获取到的IP: ${ips[0]}"
        fi
    else
        # 单个IP验证
        if ping -c 1 -W 2 "$ips_str" &>/dev/null; then
            ping_time=$(ping -c 1 -W 2 "$ips_str" | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
            color_echo $GREEN "✅ $domain 验证通过: $ips_str (延迟: ${ping_time}ms)"
        else
            color_echo $YELLOW "⚠️ $domain 无法ping通: $ips_str，但仍将使用此IP"
        fi
        OptimizedIps["$domain"]=$ips_str
    fi
done

# ==============================
# 第五部分：更新 hosts 文件
# ==============================
color_echo $CYAN "🛠️ [执行阶段] 正在更新 hosts 文件..."

HostsPath="/etc/hosts"
BackupPath="/etc/hosts.github_backup_$(date +'%Y%m%d_%H%M%S')"

# 备份 hosts 文件
cp "$HostsPath" "$BackupPath"
color_echo $GREEN "✅ 已备份原始 hosts 文件到: $BackupPath"

# 清理旧的 GitHub hosts 块
temp_hosts=$(mktemp)
in_gitblock=false

while IFS= read -r line; do
    if [[ $line =~ ^#\ =+\ GitHub\ Hosts\ Start\ =+ ]]; then
        in_gitblock=true
        continue
    fi
    if [[ $line =~ ^#\ =+\ GitHub\ Hosts\ End\ =+ ]]; then
        in_gitblock=false
        continue
    fi
    if [[ $in_gitblock == false ]]; then
        echo "$line" >> "$temp_hosts"
    fi
done < "$HostsPath"

# 构建新的 hosts 块
{
    echo "# =================================================="
    echo "# GitHub Hosts Start"
    echo "# Updated by GitHub Optimizer on $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# This block is managed by script. Do not edit manually."
    echo "# =================================================="
    
    for domain in "${GitHubDomains[@]}"; do
        ip=${OptimizedIps[$domain]}
        echo -e "$ip\t$domain"
        color_echo $GRAY "  • 添加: $ip    $domain"
    done
    
    echo "# =================================================="
    echo "# GitHub Hosts End"
    echo "# =================================================="
} >> "$temp_hosts"

# 写入新的 hosts 文件
mv "$temp_hosts" "$HostsPath"
color_echo $GREEN "✅ hosts 文件已成功更新！"

# 刷新DNS缓存
color_echo $CYAN "🔄 正在刷新 DNS 缓存..."
if command -v resolvectl &> /dev/null; then
    # 使用 resolvectl (systemd-resolved 的新命令)
    resolvectl flush-caches
    color_echo $GREEN "✅ 已使用 resolvectl 刷新 DNS 缓存"
elif command -v systemd-resolve &> /dev/null; then
    # 使用 systemd-resolve (旧版本)
    systemd-resolve --flush-caches
    color_echo $GREEN "✅ 已使用 systemd-resolve 刷新 DNS 缓存"
elif systemctl is-active nscd &> /dev/null; then
    # 使用 nscd
    systemctl restart nscd
    color_echo $GREEN "✅ 已重启 nscd 服务刷新 DNS 缓存"
else
    # 通用方法
    color_echo $YELLOW "⚠️  未找到标准的 DNS 缓存刷新工具，尝试通用方法..."
    if command -v service &> /dev/null; then
        service networking restart 2>/dev/null || true
        color_echo $GREEN "✅ 已重启网络服务"
    else
        color_echo $YELLOW "⚠️  无法刷新 DNS 缓存，您可能需要手动重启网络服务或重启系统"
    fi
fi

# ==============================
# 第六部分：验证测试
# ==============================
color_echo $CYAN "🔍 [验证阶段] 正在验证 GitHub 连接..."

test_domains=("github.com" "raw.githubusercontent.com")
for domain in "${test_domains[@]}"; do
    echo -n "🌐 测试访问 $domain..."
    if resolved_ip=$(resolve_dns "$domain" ""); then
        if ping -c 1 -W 2 "$resolved_ip" &>/dev/null; then
            color_echo $GREEN " ✔️ 成功 (解析到 $resolved_ip)"
        else
            color_echo $RED " ❌ 失败 (解析到 $resolved_ip)"
        fi
    else
        color_echo $RED " ❌ 解析失败"
    fi
done

# ==============================
# 第七部分：自动验证
# ==============================
color_echo $GREEN "🎉 [完成] 正在尝试打开 GitHub 页面验证效果..."

# 尝试使用各种浏览器打开
browsers=("xdg-open" "gnome-open" "kde-open" "sensible-browser" "x-www-browser")

for browser in "${browsers[@]}"; do
    if command -v "$browser" &> /dev/null; then
        "$browser" "https://github.com" 2>/dev/null &
        color_echo $GREEN "✅ 已启动浏览器打开 GitHub"
        break
    fi
done

read -p "是否同时打开 raw.githubusercontent.com 测试页面? (y/N) [默认: N]: " open_raw
if [[ $open_raw =~ ^[Yy] ]]; then
    for browser in "${browsers[@]}"; do
        if command -v "$browser" &> /dev/null; then
            "$browser" "https://raw.githubusercontent.com/github/docs/main/README.md" 2>/dev/null &
            color_echo $GREEN "✅ 已打开 raw.githubusercontent.com 测试页面"
            break
        fi
    done
fi

# ==============================
# 第八部分：完成提示
# ==============================
color_echo $CYAN "============================================"
color_echo $GREEN "          🎯 GitHub 优化完成！"
color_echo $CYAN "============================================"
echo "✅ 您现在应该可以快速访问 GitHub 及其相关服务"
echo "📌 本次使用的最佳 IP:"
for domain in "${GitHubDomains[@]}"; do
    echo "   • $domain -> ${OptimizedIps[$domain]}"
done

color_echo $YELLOW "💡 实用提示:"
echo "   • 如果访问速度不理想，可以重新运行此脚本获取最新IP"
echo "   • 如需恢复原始设置，请执行:"
echo "     sudo cp '$BackupPath' '$HostsPath'"
echo "     然后运行适当的DNS缓存刷新命令"
echo ""
echo "   • 建议每周运行一次此脚本，以应对 GitHub IP 变动。"
echo "   • 若仍无法访问，可能需使用代理工具。"

color_echo $CYAN "============================================"
color_echo $GREEN "          操作完成！"
color_echo $CYAN "============================================"
echo ""
echo "✅ 脚本执行完毕，浏览器应已打开 GitHub"
echo ""
color_echo $YELLOW "📌 按任意键继续..." 
read -n 1 -s
