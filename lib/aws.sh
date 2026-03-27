#!/usr/bin/env bash
# aws.sh - AWS S3 / MinIO 上传 (Unix/Linux/macOS)
# aws provider 和 minio provider 共用此实现（都使用 AWS S3 兼容协议）

do_upload() {
    local local_file="$1"
    local remote_key="$2"
    local method
    method=$(get_upload_method "$PROVIDER")

    echo "文件: $local_file"
    echo "目标: $PROVIDER://$BUCKET/$remote_key"

    case "$method" in
        aws-cli)  _upload_aws_cli "$local_file" "$remote_key" ;;
        boto3)    _upload_boto3 "$local_file" "$remote_key" ;;
        curl)     _upload_curl "$local_file" "$remote_key" ;;
        *)        echo "错误: 无可用上传方式" >&2; return 1 ;;
    esac
}

_upload_aws_cli() {
    local local_file="$1"
    local remote_key="$2"

    export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
    export AWS_DEFAULT_REGION="${REGION:-us-east-1}"

    local extra_args=""
    if [[ -n "$ENDPOINT" && "$PROVIDER" == "minio" ]]; then
        extra_args="--endpoint-url https://$ENDPOINT"
    fi
    if [[ "$PROVIDER" == "aws" && -n "$ENDPOINT" ]]; then
        extra_args="--endpoint-url https://$ENDPOINT"
    fi

    if [[ "$URL_STYLE" == "path" ]]; then
        extra_args="$extra_args --addressing-style path"
    fi

    if [[ "$QUIET" == "true" ]]; then
        extra_args="$extra_args --no-progress"
    fi

    aws s3 cp "$local_file" "s3://$BUCKET/$remote_key" $extra_args 2>&1
    if [[ $? -eq 0 ]]; then
        _generate_url "$remote_key"
    else
        return 1
    fi
}

_upload_boto3() {
    local local_file="$1"
    local remote_key="$2"

    local endpoint_url=""
    if [[ -n "$ENDPOINT" ]]; then
        endpoint_url="https://$ENDPOINT"
    fi

    python3 - "$local_file" "$remote_key" "$ACCESS_KEY" "$SECRET_KEY" "$REGION" "$BUCKET" "$endpoint_url" "$QUIET" "$URL_STYLE" << 'PYEOF'
import sys
import boto3
from botocore.config import Config

local_file, remote_key, access_key, secret_key, region, bucket, endpoint_url, quiet, url_style = sys.argv[1:]

extra_args = {}
if endpoint_url:
    extra_args['endpoint_url'] = endpoint_url

s3 = boto3.client('s3', aws_access_key_id=access_key, aws_secret_access_key=secret_key,
                  region_name=region or 'us-east-1', config=Config(signature_version='s3v4'), **extra_args)

def progress(consumed, total):
    if total and quiet == "false":
        pct = int(100 * consumed / total)
        print(f"\r进度: {pct}%", end='', flush=True)

if quiet == "false":
    s3.upload_file(local_file, bucket, remote_key, Callback=progress)
    print()
else:
    s3.upload_file(local_file, bucket, remote_key)

# 生成 URL
url = None
if endpoint_url:
    if url_style == "path":
        url = f"{endpoint_url}/{bucket}/{remote_key}"
    else:
        url = f"{endpoint_url}/{remote_key}"
else:
    url = f"https://{bucket}.s3.{region or 'us-east-1'}.amazonaws.com/{remote_key}"

print()
print("✓ 上传成功")
print(f"URL: {url}")
PYEOF
}

_upload_curl() {
    local local_file="$1"
    local remote_key="$2"

    if [[ -z "$ACCESS_KEY" || -z "$SECRET_KEY" ]]; then
        echo "错误: curl 上传需要配置 ACCESS_KEY 和 SECRET_KEY" >&2; return 1
    fi

    local url
    if [[ "$URL_STYLE" == "path" || -z "$ENDPOINT" ]]; then
        url="https://${ENDPOINT:-s3.amazonaws.com}/$BUCKET/$remote_key"
    else
        url="https://$BUCKET.$ENDPOINT/$remote_key"
    fi

    python3 - "$local_file" "$remote_key" "$url" "$ACCESS_KEY" "$SECRET_KEY" "$REGION" "$BUCKET" "$QUIET" << 'PYEOF'
import sys, hmac, hashlib, datetime, subprocess

local_file, remote_key, url, access_key, secret_key, region, bucket, quiet = sys.argv[1:]

# 计算 payload hash
import hashlib
with open(local_file, 'rb') as f:
    payload = f.read()
payload_hash = hashlib.sha256(payload).hexdigest()

date_now = datetime.datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')
date_short = date_now[:8]
service = 's3'
region = region or 'us-east-1'
host = url.split('://')[1].split('/')[0].split(':')[0]

canonical_uri = '/' + remote_key
signed_headers = 'host;x-amz-content-sha256;x-amz-date'
canonical_headers = f"host:{host}\nx-amz-content-sha256:{payload_hash}\nx-amz-date:{date_now}\n"
canonical_request = f"PUT\n{canonical_uri}\n\n{canonical_headers}\n{signed_headers}\n{payload_hash}"
canonical_hash = hashlib.sha256(canonical_request.encode()).hexdigest()
credential_scope = f"{date_short}/{region}/{service}/aws4_request"
string_to_sign = f"AWS4-HMAC-SHA256\n{date_now}\n{credential_scope}\n{canonical_hash}"

def sign(key, msg):
    return hmac.new(key, msg.encode(), hashlib.sha256).digest()

k = sign(f"AWS4{secret_key}".encode(), date_short)
k = sign(k, region)
k = sign(k, service)
k = sign(k, 'aws4_request')
signature = hmac.new(k, string_to_sign.encode(), hashlib.sha256).hexdigest()

auth = (f"AWS4-HMAC-SHA256 Credential={access_key}/{credential_scope}, "
        f"SignedHeaders={signed_headers}, Signature={signature}")

cmd = ['curl', '-s', '-X', 'PUT', '-T', local_file,
       '-H', f'x-amz-content-sha256:{payload_hash}',
       '-H', f'x-amz-date:{date_now}',
       '-H', f'Authorization:{auth}', url]
if quiet == "true": cmd.insert(1, '-s')
else: cmd.insert(1, '-v')

r = subprocess.run(cmd)
if r.returncode == 0:
    print("✓ 上传成功")
    print(f"URL: {url}")
sys.exit(r.returncode)
PYEOF
}

_generate_url() {
    local remote_key="$1"
    local url=""
    case "$PROVIDER" in
        aws)
            if [[ -n "$ENDPOINT" ]]; then
                url="https://$BUCKET.$ENDPOINT/$remote_key"
            else
                url="https://$BUCKET.s3.${REGION:-us-east-1}.amazonaws.com/$remote_key"
            fi
            ;;
        minio)
            url="https://$ENDPOINT/$BUCKET/$remote_key"
            ;;
    esac
    echo ""
    echo "✓ 上传成功"
    echo "URL: $url"
}
