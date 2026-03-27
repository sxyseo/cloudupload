#!/usr/bin/env bash
# detect.sh - Tool dependency detection (Unix/Linux/macOS)

TOOL_CURL="false" TOOL_PYTHON3="false" TOOL_AWS="false"
TOOL_OSSUTIL="false" TOOL_OSS_PY="false" TOOL_COSCLI="false"
TOOL_COS_PY="false" TOOL_BOSCLI="false" TOOL_BOS_PY="false"
TOOL_OBSCLI="false" TOOL_OBS_PY="false" TOOL_GSUTIL="false"
TOOL_GCP_PY="false" TOOL_AZCLI="false" TOOL_AZURE_PY="false"
TOOL_BOTO3="false" TOOL_OPENSSL="false"

check_tool() {
    local tool="$1"
    if command -v "$tool" &>/dev/null; then
        echo "检测到: $tool"
        return 0
    fi
    return 1
}

detect_tools() {
    local provider="$1"
    echo "=== 工具检测 ==="

    # Common tools
    check_tool curl && TOOL_CURL="true"
    check_tool python3 && TOOL_PYTHON3="true" || check_tool python && TOOL_PYTHON3="true"
    check_tool openssl && TOOL_OPENSSL="true"

    # AWS / MinIO
    if [[ "$provider" == "aws" || "$provider" == "minio" ]]; then
        check_tool aws && TOOL_AWS="true"
        if [[ "$TOOL_PYTHON3" == "true" ]]; then
            python3 -c "import boto3" 2>/dev/null && TOOL_BOTO3="true" && echo "检测到: boto3 (Python)"
        fi
    fi

    # Alibaba Cloud OSS
    if [[ "$provider" == "aliyun" ]]; then
        check_tool ossutil && TOOL_OSSUTIL="true"
        if [[ "$TOOL_PYTHON3" == "true" ]]; then
            python3 -c "import oss2" 2>/dev/null && TOOL_OSS_PY="true" && echo "检测到: oss2 (Python)"
        fi
    fi

    # Tencent Cloud COS
    if [[ "$provider" == "tencent" ]]; then
        check_tool coscli && TOOL_COSCLI="true"
        if [[ "$TOOL_PYTHON3" == "true" ]]; then
            python3 -c "import qcloud_cos_v5" 2>/dev/null && TOOL_COS_PY="true" && echo "检测到: qcloud_cos_v5 (Python)"
        fi
    fi

    # Baidu Cloud BOS
    if [[ "$provider" == "baidu" ]]; then
        check_tool boscli && TOOL_BOSCLI="true"
        if [[ "$TOOL_PYTHON3" == "true" ]]; then
            python3 -c "import baidubce" 2>/dev/null && TOOL_BOS_PY="true" && echo "检测到: baidubce (Python)"
        fi
    fi

    # Huawei Cloud OBS
    if [[ "$provider" == "huawei" ]]; then
        check_tool obsutil && TOOL_OBSCLI="true"
        if [[ "$TOOL_PYTHON3" == "true" ]]; then
            python3 -c "import obs" 2>/dev/null && TOOL_OBS_PY="true" && echo "检测到: obs (Python)"
        fi
    fi

    # Google Cloud GCS
    if [[ "$provider" == "gcp" ]]; then
        check_tool gsutil && TOOL_GSUTIL="true"
        check_tool gcloud && TOOL_GCLOUD="true"
        if [[ "$TOOL_PYTHON3" == "true" ]]; then
            python3 -c "import google.cloud.storage" 2>/dev/null && TOOL_GCP_PY="true" && echo "检测到: google-cloud-storage (Python)"
        fi
    fi

    # Azure Blob
    if [[ "$provider" == "azure" ]]; then
        check_tool az && TOOL_AZCLI="true"
        if [[ "$TOOL_PYTHON3" == "true" ]]; then
            python3 -c "import azure.storage.blob" 2>/dev/null && TOOL_AZURE_PY="true" && echo "检测到: azure-storage-blob (Python)"
        fi
    fi

    export TOOL_CURL TOOL_PYTHON3 TOOL_AWS TOOL_OSSUTIL TOOL_OSS_PY
    export TOOL_COSCLI TOOL_COS_PY TOOL_BOSCLI TOOL_BOS_PY
    export TOOL_OBSCLI TOOL_OBS_PY TOOL_GSUTIL TOOL_GCP_PY
    export TOOL_AZCLI TOOL_AZURE_PY TOOL_OPENSSL TOOL_BOTO3 TOOL_GCLOUD

    echo ""
}

get_upload_method() {
    local provider="$1"
    case "$provider" in
        aws|minio)
            [[ "$TOOL_AWS" == "true" ]] && echo "aws-cli" && return
            [[ "$TOOL_BOTO3" == "true" ]] && echo "boto3" && return
            [[ "$TOOL_CURL" == "true" ]] && echo "curl" && return
            ;;
        aliyun)
            [[ "$TOOL_OSSUTIL" == "true" ]] && echo "ossutil" && return
            [[ "$TOOL_OSS_PY" == "true" ]] && echo "oss-python" && return
            [[ "$TOOL_CURL" == "true" && "$TOOL_PYTHON3" == "true" ]] && echo "curl-sign" && return
            ;;
        tencent)
            [[ "$TOOL_COSCLI" == "true" ]] && echo "coscli" && return
            [[ "$TOOL_COS_PY" == "true" ]] && echo "cos-python" && return
            [[ "$TOOL_CURL" == "true" && "$TOOL_PYTHON3" == "true" ]] && echo "curl-sign" && return
            ;;
        baidu)
            [[ "$TOOL_BOSCLI" == "true" ]] && echo "boscli" && return
            [[ "$TOOL_BOS_PY" == "true" ]] && echo "bos-python" && return
            [[ "$TOOL_CURL" == "true" && "$TOOL_PYTHON3" == "true" ]] && echo "curl-sign" && return
            ;;
        huawei)
            [[ "$TOOL_OBSCLI" == "true" ]] && echo "obsutil" && return
            [[ "$TOOL_OBS_PY" == "true" ]] && echo "obs-python" && return
            [[ "$TOOL_CURL" == "true" && "$TOOL_PYTHON3" == "true" ]] && echo "curl-sign" && return
            ;;
        gcp)
            [[ "$TOOL_GSUTIL" == "true" ]] && echo "gsutil" && return
            [[ "$TOOL_GCP_PY" == "true" ]] && echo "gcp-python" && return
            [[ "$TOOL_CURL" == "true" && "$TOOL_PYTHON3" == "true" ]] && echo "curl-jwt" && return
            ;;
        azure)
            [[ "$TOOL_AZCLI" == "true" ]] && echo "az-cli" && return
            [[ "$TOOL_AZURE_PY" == "true" ]] && echo "azure-python" && return
            [[ "$TOOL_CURL" == "true" ]] && echo "curl-sas" && return
            ;;
    esac
    echo "none"
}

check_upload_available() {
    local provider="$1"
    local method
    method=$(get_upload_method "$provider")
    if [[ "$method" == "none" ]]; then
        echo "错误: $provider 没有可用的上传工具" >&2
        echo "请安装 Python SDK 或对应 CLI 工具" >&2
        return 1
    fi
    echo "将使用: $method"
    return 0
}
