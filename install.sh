#!/usr/bin/env bash
# install.sh - CloudUpload one-line installer (Unix/Linux/macOS)
# Usage: curl -fsSL https://raw.githubusercontent.com/sxyseo/cloudupload/main/install.sh | bash

set -e

REPO_NAME="cloudupload"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/cloudupload}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
REPO_URL="https://github.com/sxyseo/cloudupload"
BRANCH="${BRANCH:-main}"

# Colors (disable if not a TTY)
if [[ ! -t 1 ]]; then
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
else
    RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
fi

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }

detect_os() {
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)  ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        i386|i686) ARCH="386" ;;
    esac

    # Windows detection
    if [[ "$OS" == *"mingw"* || "$OS" == *"msys"* || -n "$windir" ]]; then
        OS="windows"
    fi

    info "检测到系统: $OS ($ARCH)"
}

install_shell() {
    info "正在安装 Shell 版本..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR"

    # Files to copy
    local main_files=("upload" "config.sh" "config.ps1" "upload.ps1" "install.sh" "install.ps1" "config.example")
    for f in "${main_files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$f" ]]; then
            cp "$SCRIPT_DIR/$f" "$INSTALL_DIR/$f"
        fi
    done

    # lib directory
    if [[ -d "$SCRIPT_DIR/lib" ]]; then
        cp -r "$SCRIPT_DIR/lib" "$INSTALL_DIR/"
    fi

    # i18n directory
    if [[ -d "$SCRIPT_DIR/i18n" ]]; then
        cp -r "$SCRIPT_DIR/i18n" "$INSTALL_DIR/"
    fi

    # .github directory (issue templates)
    if [[ -d "$SCRIPT_DIR/.github" ]]; then
        cp -r "$SCRIPT_DIR/.github" "$INSTALL_DIR/"
    fi

    # Set executable
    chmod +x "$INSTALL_DIR/upload" "$INSTALL_DIR/install.sh"
    find "$INSTALL_DIR/lib" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

    # Create symlink
    if [[ ! -e "$BIN_DIR/upload" ]]; then
        ln -sf "$INSTALL_DIR/upload" "$BIN_DIR/upload"
        success "已创建符号链接: $BIN_DIR/upload"
    fi

    # Check PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        warn "建议将 $BIN_DIR 添加到 PATH:"
        warn "  echo 'export PATH=\"\$PATH:$BIN_DIR\"' >> ~/.bashrc"
        warn "  source ~/.bashrc"
    fi

    success "Shell 版本安装完成！"
}

install_dependencies() {
    info "检查依赖工具..."

    local missing=()
    if ! command -v python3 &>/dev/null && ! command -v python &>/dev/null; then
        missing+=("python3")
    fi
    if ! command -v curl &>/dev/null; then
        missing+=("curl")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "建议安装以下工具以获得完整功能: ${missing[*]}"
    fi

    # AWS CLI
    if ! command -v aws &>/dev/null; then
        echo ""
        info "提示: 未检测到 AWS CLI，安装可获得更好的 S3 支持:"
        info "  Linux:   curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o awscliv2.zip"
        info "           unzip awscliv2.zip && sudo ./aws/install"
        info "  macOS:   brew install awscli"
    fi

    # ossutil
    if ! command -v ossutil &>/dev/null; then
        echo ""
        info "提示: 未检测到 ossutil，安装可获得更好的阿里云 OSS 支持:"
        info "  Linux:   wget https://gosspublic.alicdn.com/ossutil/ossutil64 -O /usr/local/bin/ossutil"
        info "  macOS:   wget https://gosspublic.alicdn.com/ossutil/ossutilmac64 -O /usr/local/bin/ossutil"
    fi
}

setup_config() {
    info "检查配置文件..."
    local cfg_file="$HOME/.uploadrc"
    if [[ ! -f "$cfg_file" ]]; then
        if [[ -f "$SCRIPT_DIR/config.example" ]]; then
            cp "$SCRIPT_DIR/config.example" "$cfg_file"
            chmod 600 "$cfg_file"
            success "已创建配置文件: $cfg_file"
            info "请编辑配置文件填入你的云存储凭据"
        fi
    else
        success "配置文件已存在: $cfg_file"
    fi
}

main() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -z "$SCRIPT_DIR" ]] || [[ ! -d "$SCRIPT_DIR" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    fi

    echo ""
    echo "====================================="
    echo "  CloudUpload 一键安装"
    echo "  跨平台对象存储上传 CLI"
    echo "====================================="
    echo ""

    detect_os

    if [[ ! -t 0 ]]; then
        CONFIRM="y"
    fi

    if [[ "$CONFIRM" != "y" ]]; then
        read -p "安装到 $INSTALL_DIR ? [Y/n]: " CONFIRM
        CONFIRM="${CONFIRM:-y}"
    fi

    if [[ "${CONFIRM,,}" != "y" && "${CONFIRM,,}" != "" ]]; then
        info "安装取消"
        exit 0
    fi

    if [[ "$OS" == "windows" ]]; then
        warn "Windows 系统请使用 PowerShell 安装: irm .../install.ps1 | iex"
    else
        install_shell
    fi

    install_dependencies
    setup_config

    echo ""
    echo "====================================="
    success "安装完成！"
    echo "====================================="
    echo ""
    echo "使用示例:"
    echo "  upload myfile.tar.gz                  # 使用默认 profile"
    echo "  upload myfile.tar.gz aliyun-oss       # 指定 profile"
    echo "  upload -l                             # 列出所有 profile"
    echo "  upload -h                             # 显示帮助"
    echo ""
    echo "配置文件: $HOME/.uploadrc"
    echo ""
}

main "$@"
