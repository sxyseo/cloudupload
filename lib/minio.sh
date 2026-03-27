# minio.sh - MinIO 上传 (Unix/Linux/macOS)
# MinIO 使用 S3 兼容协议，复用 aws.sh 实现

# MinIO 是 S3 兼容存储，直接 source aws.sh 即可
if [[ -f "${BASH_SOURCE[0]%/*}/aws.sh" ]]; then
    source "${BASH_SOURCE[0]%/*}/aws.sh"
else
    echo "错误: aws.sh 未找到，无法加载 MinIO 支持" >&2
    exit 1
fi
