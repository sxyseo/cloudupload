#!/usr/bin/env bash
# config.sh - Configuration loader with i18n support (Unix/Linux/macOS)
# Supports: aws, aliyun, tencent, baidu, huawei, gcp, azure, minio

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPLOAD_CONFIG_FILE="${UPLOAD_CONFIG_FILE:-$HOME/.uploadrc}"

# Load i18n
if [[ -f "$SCRIPT_DIR/i18n/i18n.sh" ]]; then
    source "$SCRIPT_DIR/i18n/i18n.sh"
    i18n_init
fi

# Export config variables
PROVIDER="" ENDPOINT="" BUCKET="" ACCESS_KEY="" SECRET_KEY="" REGION=""
URL_STYLE="" CURRENT_PROFILE="" ACCOUNT="" RELAY_EXPIRES=""

load_config() {
    local profile="${1:-}"

    if [[ ! -f "$UPLOAD_CONFIG_FILE" ]]; then
        echo "错误: 配置文件不存在: $UPLOAD_CONFIG_FILE" >&2
        echo "请复制 config.example 到 ~/.uploadrc 并填入配置" >&2
        return 1
    fi

    # Get default profile
    if [[ -z "$profile" ]]; then
        profile=$(grep -E '^\s*export\s+UPLOAD_DEFAULT=' "$UPLOAD_CONFIG_FILE" 2>/dev/null \
            | head -1 | sed 's/.*=\s*//;s/^["'\'']\?//;s/["'\'']\?$//')
        profile="${profile:-default}"
    fi

    # Extract config (supports quoted values)
    _get() {
        grep -E "^\s*export\s+${profile}_${1}=" "$UPLOAD_CONFIG_FILE" 2>/dev/null \
            | head -1 | sed 's/.*=\s*//;s/^["'\'']\?//;s/["'\'']\?$//'
    }

    PROVIDER=$(_get "PROVIDER")
    ENDPOINT=$(_get "ENDPOINT")
    BUCKET=$(_get "BUCKET")
    ACCESS_KEY=$(_get "ACCESS_KEY")
    SECRET_KEY=$(_get "SECRET_KEY")
    REGION=$(_get "REGION")
    URL_STYLE=$(_get "URL_STYLE")
    ACCOUNT=$(_get "ACCOUNT")
    RELAY_EXPIRES=$(_get "RELAY_EXPIRES")

    # Check if profile exists
    if [[ -z "$PROVIDER" && -z "$ENDPOINT" && -z "$BUCKET" ]]; then
        echo "错误: profile '$profile' 在配置文件中未找到" >&2
        return 1
    fi

    # Normalize provider
    _normalize_provider

    # Normalize endpoint
    ENDPOINT="${ENDPOINT#http://}"
    ENDPOINT="${ENDPOINT#https://}"
    ENDPOINT="${ENDPOINT%/}"

    # Defaults
    URL_STYLE="${URL_STYLE:-virtual}"
    RELAY_EXPIRES="${RELAY_EXPIRES:-604800}"  # 7 days default

    export PROVIDER ENDPOINT BUCKET ACCESS_KEY SECRET_KEY REGION URL_STYLE ACCOUNT RELAY_EXPIRES
    export CURRENT_PROFILE="$profile"

    return 0
}

_normalize_provider() {
    local p="${PROVIDER,,}"
    case "$p" in
        s3|aws|amazon)              PROVIDER="aws" ;;
        oss|aliyun|aliyuncs|aliyun-oss) PROVIDER="aliyun" ;;
        cos|tencent|tencentcloud|qcloud) PROVIDER="tencent" ;;
        bos|baidu|baiduyun|bce)     PROVIDER="baidu" ;;
        obs|huawei|huaweicloud|hwcloud) PROVIDER="huawei" ;;
        gcs|gcp|google|googlecloud|google-cloud-storage) PROVIDER="gcp" ;;
        azure|azureblob|azurestorage|azure-blob) PROVIDER="azure" ;;
        minio|minio-storage)         PROVIDER="minio" ;;
        "")
            # Infer from endpoint
            if   [[ "$ENDPOINT" == *"aliyuncs.com"* ]] || [[ "$ENDPOINT" == *"oss-"* ]]; then PROVIDER="aliyun"
            elif [[ "$ENDPOINT" == *"myqcloud.com"* ]] || [[ "$ENDPOINT" == *"cos."* ]]; then PROVIDER="tencent"
            elif [[ "$ENDPOINT" == *"bcebos.com"* ]];   then PROVIDER="baidu"
            elif [[ "$ENDPOINT" == *"myhuaweicloud.com"* ]] || [[ "$ENDPOINT" == *"obs."* ]]; then PROVIDER="huawei"
            elif [[ "$ENDPOINT" == *"storage.googleapis.com"* ]]; then PROVIDER="gcp"
            elif [[ "$ENDPOINT" == *"blob.core.windows.net"* ]]; then PROVIDER="azure"
            elif [[ "$ENDPOINT" == *"min.io"* ]] || [[ "$p" == "minio" ]]; then PROVIDER="minio"
            else PROVIDER="aws"; fi
            ;;
        *) echo "警告: 未知 provider '$PROVIDER'，将作为 S3 兼容存储处理" >&2; PROVIDER="aws" ;;
    esac
}

list_profiles() {
    if [[ ! -f "$UPLOAD_CONFIG_FILE" ]]; then return 1; fi
    grep -E '^\s*export\s+[a-zA-Z0-9_-]+_(PROVIDER|ENDPOINT)=' "$UPLOAD_CONFIG_FILE" 2>/dev/null \
        | sed 's/.*export\s\+\([a-zA-Z0-9_-]*\)_[A-Z]*/\1/' \
        | sort -u
}

show_config() {
    local expires_days
    expires_days=$((RELAY_EXPIRES / 86400))
    echo "Profile:      $CURRENT_PROFILE"
    echo "Provider:     ${PROVIDER:-<未设置>}"
    echo "Endpoint:     ${ENDPOINT:-<未设置>}"
    echo "Bucket:       ${BUCKET:-<未设置>}"
    echo "Region:       ${REGION:-<未设置>}"
    echo "URL Style:    $URL_STYLE"
    echo "Account:      ${ACCOUNT:-<未设置>}"
    echo "Relay Expires:${expires_days} days"
    echo "Access Key:   ${ACCESS_KEY:+<已设置>}"
    echo "Secret Key:   ${SECRET_KEY:+<已设置>}"
}

list_providers() {
    echo "支持的云厂商:"
    echo "  aws      - AWS S3 / 兼容存储"
    echo "  aliyun   - 阿里云 OSS"
    echo "  tencent  - 腾讯云 COS"
    echo "  baidu    - 百度云 BOS"
    echo "  huawei   - 华为云 OBS"
    echo "  gcp      - 谷歌云 GCS"
    echo "  azure    - Azure Blob Storage"
    echo "  minio    - MinIO / S3 兼容存储"
}

# Run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 0 ]]; then
        echo "用法: source config.sh [profile]  # 加载配置"
        echo "      ./config.sh [profile]        # 显示配置"
    else
        if load_config "$1"; then
            show_config
        else
            exit 1
        fi
    fi
fi
