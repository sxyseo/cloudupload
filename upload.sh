#!/usr/bin/env bash
# upload.sh - 对象存储一键上传 CLI 工具
# 支持: S3 兼容存储 (AWS S3, MinIO, Backblaze...), 阿里云 OSS, 腾讯云 COS
# 用法: upload.sh [选项] <文件> [profile] [远程路径]
# 选项:
#   -q, --quiet    静默模式，只输出 URL
#   -l, --list     列出所有 profile
#   -s, --show     显示配置信息
#   -h, --help     显示帮助

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 默认值
QUIET="false"
SHOW_LIST="false"
SHOW_CONFIG="false"

# 解析参数
parse_args() {
    local args=("$@")
    local i=0

    while [[ $i -lt ${#args[@]} ]]; do
        case "${args[$i]}" in
            -q|--quiet)
                QUIET="true"
                shift
                ;;
            -l|--list)
                SHOW_LIST="true"
                ;;
            -s|--show)
                SHOW_CONFIG="true"
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                if [[ "$SHOW_CONFIG" == "true" && -z "$PROFILE" && "${args[$i]}" != -* ]]; then
                    # -s 后的第一个非选项参数是 profile
                    PROFILE="${args[$i]}"
                elif [[ -z "$FILE" && "${args[$i]}" != -* ]]; then
                    # 第一个非选项参数是文件
                    FILE="${args[$i]}"
                elif [[ -z "$REMOTE_KEY" && "${args[$i]}" != -* ]]; then
                    # 第二个非选项参数是远程路径
                    REMOTE_KEY="${args[$i]}"
                fi
                ;;
        esac
        i=$((i + 1))
    done
}

show_help() {
    cat << 'EOF'
upload - 对象存储一键上传 CLI 工具

用法:
    upload <文件> [profile] [远程路径]   上传文件
    upload -l                            列出所有 profile
    upload -s [profile]                  显示配置信息
    upload -h                            显示帮助

示例:
    upload myfile.tar.gz                 使用默认 profile 上传
    upload myfile.tar.gz oss             使用 oss profile 上传
    upload myfile.tar.gz s3 backup/     使用 s3 profile 上传到 backup/ 目录
    upload myfile.tar.gz -q              静默模式，只输出 URL

配置文件: ~/.uploadrc
EOF
}

main() {
    # 解析参数
    parse_args "$@"

    # 加载配置
    source "$SCRIPT_DIR/config.sh"

    if [[ "$SHOW_LIST" == "true" ]]; then
        echo "可用 profile:"
        list_profiles
        exit 0
    fi

    if [[ "$SHOW_CONFIG" == "true" ]]; then
        if ! load_config "$PROFILE"; then
            exit 1
        fi
        show_config
        exit 0
    fi

    if [[ -z "$FILE" ]]; then
        show_help
        exit 1
    fi

    # 解析文件路径（支持相对路径）
    if [[ "$FILE" != /* ]]; then
        FILE="$(pwd)/$FILE"
    fi

    if [[ ! -f "$FILE" ]]; then
        echo "错误: 文件不存在: $FILE" >&2
        exit 1
    fi

    local local_file="$FILE"
    local local_name
    local_name=$(basename "$local_file")

    # 确定远程路径
    if [[ -z "$REMOTE_KEY" ]]; then
        REMOTE_KEY="$local_name"
    else
        # 如果 remote_key 以 / 结尾，则在其后拼接文件名
        if [[ "$REMOTE_KEY" == */ ]]; then
            REMOTE_KEY="${REMOTE_KEY}${local_name}"
        fi
    fi

    # 加载配置
    if ! load_config "$PROFILE"; then
        exit 1
    fi

    if [[ "$QUIET" != "true" ]]; then
        echo "=== 对象存储一键上传 ==="
        show_config
        echo ""
    fi

    # 检测工具依赖
    source "$SCRIPT_DIR/lib/detect.sh"
    if ! detect_tools "$PROVIDER"; then
        exit 1
    fi

    # 调用对应的上传逻辑
    if [[ "$QUIET" != "true" ]]; then
        echo ""
    fi

    if [[ "$PROVIDER" == "s3" ]]; then
        source "$SCRIPT_DIR/lib/s3.sh"
        s3_upload "$local_file" "$REMOTE_KEY"
    elif [[ "$PROVIDER" == "oss" ]]; then
        source "$SCRIPT_DIR/lib/oss.sh"
        oss_upload "$local_file" "$REMOTE_KEY"
    elif [[ "$PROVIDER" == "cos" ]]; then
        # 腾讯云 COS，使用 S3 兼容方式
        source "$SCRIPT_DIR/lib/s3.sh"
        s3_upload "$local_file" "$REMOTE_KEY"
    else
        echo "错误: 不支持的 provider: $PROVIDER" >&2
        exit 1
    fi
}

main "$@"
