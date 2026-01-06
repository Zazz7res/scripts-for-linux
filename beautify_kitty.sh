#!/bin/bash

# Kitty 终端美化脚本
# 功能：安装主题、配置字体、设置窗口样式、调整快捷键
# 作者：AI 助手
# 版本：1.0

set -e  # 遇到错误立即退出

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_info() {
    print_message "$BLUE" "[INFO] $1"
}

print_success() {
    print_message "$GREEN" "[SUCCESS] $1"
}

print_warning() {
    print_message "$YELLOW" "[WARNING] $1"
}

print_error() {
    print_message "$RED" "[ERROR] $1"
}

# 检查Kitty是否安装
check_kitty_installed() {
    if ! command -v kitty &> /dev/null; then
        print_error "Kitty 未安装。请先安装 Kitty 终端模拟器。"
        exit 1
    fi
    print_success "检测到 Kitty 已安装: $(kitty --version)"
}

# 备份现有配置
backup_config() {
    local config_dir="$HOME/.config/kitty"
    local config_file="$config_dir/kitty.conf"
    
    if [ -f "$config_file" ]; then
        local backup_file="$config_file.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$config_file" "$backup_file"
        print_success "已备份现有配置到: $backup_file"
    fi
}

# 安装主题
install_themes() {
    print_info "开始安装 Kitty 主题..."
    
    local themes_dir="$HOME/.config/kitty/kitty-themes"
    
    # 如果已存在，询问是否重新安装
    if [ -d "$themes_dir" ]; then
        read -p "主题目录已存在。是否重新安装？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "跳过主题安装。"
            return
        fi
        rm -rf "$themes_dir"
    fi
    
    # 克隆主题仓库
    print_info "正在从 GitHub 克隆主题仓库..."
    git clone --depth 1 https://github.com/dexpota/kitty-themes.git "$themes_dir" || {
        print_error "主题安装失败！"
        exit 1
    }
    
    print_success "主题安装成功！"
    print_info "主题目录: $themes_dir"
    print_info "你可以在 Kitty 中使用 'kitty +kitten themes' 命令切换主题"
}

# 配置字体
configure_fonts() {
    print_info "配置终端字体..."
    
    local config_dir="$HOME/.config/kitty"
    local config_file="$config_dir/kitty.conf"
    
    # 确保配置目录存在
    mkdir -p "$config_dir"
    
    # 添加字体配置到配置文件
    cat >> "$config_file" << EOF

# ==================== 字体配置 ====================
# 设置字体家族，按优先级顺序排列
font_family      Fira Code, Sarasa Mono SC, Noto Sans Mono, monospace

# 设置字体大小
font_size        13.0

# 粗体字体设置
bold_font        auto

# 斜体字体设置
italic_font      auto

# 粗斜体字体设置
bold_italic_font auto

# 调整行高
line_height      1.2

# 字符间距微调
letter_spacing   0.0
EOF
    
    print_success "字体配置已添加到 $config_file"
    print_info "字体设置将在下次重启 Kitty 时生效"
}

# 配置窗口和标签栏样式
configure_window_styles() {
    print_info "配置窗口和标签栏样式..."
    
    local config_file="$HOME/.config/kitty/kitty.conf"
    
    cat >> "$config_file" << EOF

# ==================== 窗口和标签栏样式 ====================
# 窗口边框宽度
window_border_width  1.0

# 窗口内边距
window_padding_width 8.0

# 窗口边圆角
window_margin_width 0.0

# 标签栏样式
tab_bar_style        powerline

# 活动标签前景色
active_tab_foreground #000000

# 活动标签背景色
active_tab_background #ffffff

# 非活动标签前景色
inactive_tab_foreground #888888

# 非活动标签背景色
inactive_tab_background #e0e0e0

# 标签栏最小宽度
tab_title_template "{index}: {title}"

# 窗口背景透明度（0-1）
background_opacity 0.95

# 模糊透明背景（macOS/Linux支持）
blur_radius        0
EOF
    
    print_success "窗口样式配置已添加"
}

# 配置快捷键
configure_shortcuts() {
    print_info "配置常用快捷键..."
    
    local config_file="$HOME/.config/kitty/kitty.conf"
    
    cat >> "$config_file" << EOF

# ==================== 快捷键配置 ====================
# 复制粘贴
map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard

# 新建标签页
map ctrl+t new_tab

# 关闭标签页
map ctrl+w close_tab

# 切换标签页
map ctrl+1 goto_tab 1
map ctrl+2 goto_tab 2
map ctrl+3 goto_tab 3
map ctrl+4 goto_tab 4
map ctrl+5 goto_tab 5

# 分屏操作
map ctrl+shift+v split_vsplit
map ctrl+shift+s split_hsplit

# 在分屏间移动
map ctrl+shift+left neighboring_window left
map ctrl+shift+right neighboring_window right
map ctrl+shift+up neighboring_window up
map ctrl+shift+down neighboring_window down

# 切换布局
map ctrl+shift+next_layout next_layout

# 滚动操作
map ctrl+shift+up scroll_line_up
map ctrl+shift+down scroll_line_down
map ctrl+shift+page_up scroll_page_up
map ctrl+shift+page_down scroll_page_down

# 调整字体大小
map ctrl+equal change_font_size all +2.0
map ctrl+minus change_font_size all -2.0
map ctrl+0 change_font_size all 0

# 打开配置文件
map ctrl+comma launch --stdin-source=@none --type=overlay kitty +kitten edit_config

# 重新加载配置
map ctrl+shift+r load_config_file
EOF
    
    print_success "快捷键配置已添加"
}

# 配置滚动和性能
configure_scrolling_and_performance() {
    print_info "配置滚动和性能选项..."
    
    local config_file="$HOME/.config/kitty/kitty.conf"
    
    cat >> "$config_file" << EOF

# ==================== 滚动和性能配置 ====================
# 回滚行数
scrollback_lines      10000

# 滚动速度
scroll_speed          2.0

# 鼠标滚轮滚动乘数
wheel_scroll_multiplier 5.0

# 按住Shift键时滚动整个页面
shift_scroll_page     true

# 鼠标选择时复制到剪贴板
copy_on_select        clipboard

# 选择文本时自动复制
strip_trailing_spaces smart

# 终端提示符标记
shell_integration     enabled
EOF
    
    print_success "滚动和性能配置已添加"
}

# 安装Neofetch（可选）
install_neofetch() {
    print_info "安装 Neofetch（系统信息显示工具）..."
    
    if command -v neofetch &> /dev/null; then
        print_warning "Neofetch 已经安装，跳过。"
        return
    fi
    
    local os=$(uname -s)
    
    case "$os" in
        Linux)
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y neofetch
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm neofetch
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y neofetch
            elif command -v zypper &> /dev/null; then
                sudo zypper install -y neofetch
            else
                print_warning "无法自动安装 Neofetch，请手动安装。"
            fi
            ;;
        Darwin)
            if command -v brew &> /dev/null; then
                brew install neofetch
            else
                print_warning "Homebrew 未安装，无法自动安装 Neofetch。"
            fi
            ;;
        *)
            print_warning "不支持的操作系统: $os"
            ;;
    esac
    
    if command -v neofetch &> /dev/null; then
        print_success "Neofetch 安装成功！"
        print_info "你可以在终端中运行 'neofetch' 来查看系统信息"
    else
        print_warning "Neofetch 安装失败"
    fi
}

# 显示最终信息
show_final_info() {
    print_success "========================================"
    print_success "    Kitty 美化配置完成！"
    print_success "========================================"
    echo ""
    print_info "以下操作可能会让你更开心："
    echo ""
    echo "1.  重启 Kitty 终端以应用所有更改"
    echo "2.  在终端中运行: kitty +kitten themes  来切换主题"
    echo "3.  尝试新配置的快捷键（如 Ctrl+Shift+C 复制）"
    echo "4.  安装了 Neofetch 的用户可以运行: neofetch"
    echo ""
    print_info "配置文件位置: $HOME/.config/kitty/kitty.conf"
    print_info "主题目录位置: $HOME/.config/kitty/kitty-themes"
    echo ""
    print_warning "如果你想调整配置，可以直接编辑配置文件"
    print_warning "备份的配置文件可以在 ~/.config/kitty/ 目录中找到"
}

# 主函数
main() {
    clear
    print_message "$GREEN" "========================================"
    print_message "$GREEN" "    Kitty 终端美化脚本"
    print_message "$GREEN" "========================================"
    echo ""
    
    check_kitty_installed
    backup_config
    
    # 显示菜单
    echo ""
    print_info "请选择要执行的操作："
    echo "1) 完整美化（安装主题+字体+窗口样式+快捷键+Neofetch）"
    echo "2) 仅安装主题"
    echo "3) 仅配置字体"
    echo "4) 仅配置窗口样式"
    echo "5) 仅配置快捷键"
    echo "6) 仅安装 Neofetch"
    echo "7) 退出"
    echo ""
    read -p "请输入选项 (1-7): " choice
    
    case $choice in
        1)
            install_themes
            configure_fonts
            configure_window_styles
            configure_shortcuts
            configure_scrolling_and_performance
            install_neofetch
            show_final_info
            ;;
        2)
            install_themes
            ;;
        3)
            configure_fonts
            ;;
        4)
            configure_window_styles
            ;;
        5)
            configure_shortcuts
            ;;
        6)
            install_neofetch
            ;;
        7)
            print_info "退出脚本。"
            exit 0
            ;;
        *)
            print_error "无效选项，退出。"
            exit 1
            ;;
    esac
    
    print_success "执行完成！"
}

# 运行主函数
main
