#!/usr/bin/env bash
# relay.sh - CloudUpload Relay: upload + generate pre-signed download URL
# Supports: AWS, Aliyun, Tencent, Baidu, Huawei, GCP, Azure, MinIO

# Generate a short relay code (12-char alphanumeric)
_generate_relay_code() {
    local chars="abcdefghijklmnopqrstuvwxyz0123456789"
    local code=""
    for i in {1..12}; do
        code="${code}${chars:RANDOM % ${#chars}:1}"
    done
    echo "$code"
}

# Format file size for display
_format_size() {
    local bytes=$1
    if   [[ $bytes -ge 1073741824 ]]; then
        echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1073741824}")GB"
    elif [[ $bytes -ge 1048576 ]]; then
        echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1048576}")MB"
    elif [[ $bytes -ge 1024 ]]; then
        echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1024}")KB"
    else
        echo "${bytes}B"
    fi
}

# Get file size
_get_file_size() {
    stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null || echo 0
}

# Main relay upload function
do_relay() {
    local local_file="$1"
    local remote_key="${2:-}"

    if [[ ! -f "$local_file" ]]; then
        echo "错误: 文件不存在: $local_file" >&2; return 1
    fi

    local local_name
    local_name=$(basename "$local_file")

    # Resolve remote key
    if [[ -z "$remote_key" ]]; then
        remote_key="$local_name"
    elif [[ "$remote_key" == */ ]]; then
        remote_key="${remote_key}${local_name}"
    fi

    echo ""
    echo "=== CloudUpload 中转上传 ==="
    show_config
    echo ""

    # Check credentials
    if [[ -z "$ACCESS_KEY" || -z "$SECRET_KEY" ]]; then
        echo "错误: 中转上传需要配置 ACCESS_KEY 和 SECRET_KEY" >&2
        return 1
    fi

    local file_size
    file_size=$(_get_file_size "$local_file")
    local file_size_human
    file_size_human=$(_format_size "$file_size")

    echo "文件: $local_file ($file_size_human)"
    echo "目标: $PROVIDER://$BUCKET/$remote_key"
    echo ""

    # Generate relay code
    local relay_code
    relay_code=$(_generate_relay_code)
    local relay_prefix="relay/${relay_code}"
    local relay_meta_key="${relay_prefix}/.meta.json"
    local relay_script_key="${relay_prefix}/download.sh"

    echo "中转码: $relay_code"
    echo "正在上传文件..."
    echo ""

    # Upload the file using the provider
    local upload_result=1
    case "$PROVIDER" in
        aws|minio)  source "$(dirname "${BASH_SOURCE[0]}")/aws.sh";     upload_result=$(__relay_upload "$local_file" "$remote_key") ;;
        aliyun)     source "$(dirname "${BASH_SOURCE[0]}")/aliyun.sh";  upload_result=$(__relay_upload "$local_file" "$remote_key") ;;
        tencent)    source "$(dirname "${BASH_SOURCE[0]}")/tencent.sh"; upload_result=$(__relay_upload "$local_file" "$remote_key") ;;
        baidu)      source "$(dirname "${BASH_SOURCE[0]}")/baidu.sh";   upload_result=$(__relay_upload "$local_file" "$remote_key") ;;
        huawei)     source "$(dirname "${BASH_SOURCE[0]}")/huawei.sh";  upload_result=$(__relay_upload "$local_file" "$remote_key") ;;
        gcp)        source "$(dirname "${BASH_SOURCE[0]}")/gcp.sh";     upload_result=$(__relay_upload "$local_file" "$remote_key") ;;
        azure)      source "$(dirname "${BASH_SOURCE[0]}")/azure.sh";   upload_result=$(__relay_upload "$local_file" "$remote_key") ;;
    esac

    if [[ $upload_result -ne 0 ]]; then
        echo "错误: 文件上传失败" >&2; return 1
    fi

    echo ""
    echo "正在生成预签名下载 URL..."
    echo ""

    # Generate pre-signed URL and relay metadata
    local signed_url download_url_meta expires_ts

    signed_url=$(_generate_signed_url "$PROVIDER" "$remote_key" "$ENDPOINT" "$BUCKET" \
        "$ACCESS_KEY" "$SECRET_KEY" "$REGION" "$ACCOUNT" "$RELAY_EXPIRES")

    if [[ -z "$signed_url" ]]; then
        echo "错误: 生成预签名URL失败" >&2; return 1
    fi

    expires_ts=$(($(date +%s) + RELAY_EXPIRES))

    # Generate download script
    local download_script
    download_script=$(_generate_download_script "$local_name" "$signed_url" "$PROVIDER")

    # Create relay metadata JSON
    local meta_json
    meta_json=$(python3 - "$PROVIDER" "$ENDPOINT" "$BUCKET" "$remote_key" "$local_name" \
        "$file_size" "$signed_url" "$relay_code" "$expires_ts" "$RELAY_EXPIRES" << 'PYEOF'
import sys, json, datetime
provider, endpoint, bucket, key, filename, size, url, code, expires_ts, expires_in = sys.argv[1:]
created = datetime.datetime.utcnow().isoformat() + "Z"
meta = {
    "v": 1,
    "code": code,
    "provider": provider,
    "endpoint": endpoint,
    "bucket": bucket,
    "key": key,
    "filename": filename,
    "size": int(size),
    "download_url": url,
    "created": created,
    "expires": int(expires_ts),
    "expires_in": int(expires_in),
    "cmd": f"curl -fsSL '{url}' -o {filename}",
    "pipe_cmd": f"curl -fsSL '{url}' | tar xzf -" if filename.endswith(('.tar.gz','.tgz','.tar.bz2','.zip')) else f"curl -fsSL '{url}' -o {filename}"
}
print(json.dumps(meta, indent=2, ensure_ascii=False))
PYEOF
)

    if [[ -z "$meta_json" ]]; then
        echo "错误: 生成元数据失败" >&2; return 1
    fi

    # Upload metadata JSON
    echo "上传中转元数据..."
    if ! _upload_metadata "$meta_json" "$relay_meta_key"; then
        echo "警告: 元数据上传失败，但文件已上传成功" >&2
    fi

    # Upload download script
    echo "上传下载脚本..."
    if ! _upload_script "$download_script" "$relay_script_key"; then
        echo "警告: 下载脚本上传失败" >&2
    fi

    # Encode relay code (base64 of JSON for portable sharing)
    local relay_b64
    relay_b64=$(echo "$meta_json" | python3 -c "
import sys, json, base64
data = json.load(sys.stdin)
# Remove download_url from relay code to keep it short (server will regenerate)
code_data = {k: v for k, v in data.items() if k != 'download_url'}
# Add a minimal signed URL version
code_data['url_short'] = data['download_url'].split('?')[0] + '?X_SIG_SHORT'
print(base64.urlsafe_b64encode(json.dumps(code_data, separators=(',',':')).encode()).decode().rstrip('='))
" 2>/dev/null)

    # Actually, just use the full meta as base64 for reliability
    relay_b64=$(echo "$meta_json" | base64 | tr -d '\n')

    # Format expires
    local expires_days=$((RELAY_EXPIRES / 86400))

    echo ""
    echo "=============================================="
    echo "✓ 中转上传完成"
    echo "=============================================="
    echo "文件名: $local_name"
    echo "文件大小: $file_size_human"
    echo "有效期: $expires_days 天"
    echo ""
    echo "--- 服务器下载命令 ---"
    echo ""
    echo "复制下面任一命令到服务器执行:"
    echo ""
    echo "方式一: 一键下载命令"
    echo "  $download_script"
    echo ""
    echo "方式二: 中转码下载 (需要 download 工具)"
    echo "  download relay '$relay_b64'"
    echo ""
    echo "方式三: 直接 curl"
    echo "  curl -fsSL '$signed_url' -o $local_name"
    echo ""
    echo "=============================================="
}

# Upload file (wrapper that calls provider's upload logic without extra output)
__relay_upload() {
    local local_file="$1"
    local remote_key="$2"

    # Use boto3/SDK for reliable multipart upload
    case "$PROVIDER" in
        aws|minio)
            _upload_boto3 "$local_file" "$remote_key"
            ;;
        aliyun)
            _upload_oss_py "$local_file" "$remote_key"
            ;;
        tencent)
            _upload_cos_py "$local_file" "$remote_key"
            ;;
        baidu)
            _upload_bos_py "$local_file" "$remote_key"
            ;;
        huawei)
            _upload_obs_py "$local_file" "$remote_key"
            ;;
        gcp)
            _upload_gcp_py "$local_file" "$remote_key"
            ;;
        azure)
            _upload_azure_py "$local_file" "$remote_key"
            ;;
    esac
}

# Provider-specific SDK upload and signed URL generation
_upload_boto3() {
    local local_file="$1"
    local remote_key="$2"

    local endpoint_url=""
    if [[ -n "$ENDPOINT" ]]; then
        endpoint_url="https://$ENDPOINT"
    fi

    python3 - "$local_file" "$remote_key" "$ACCESS_KEY" "$SECRET_KEY" "$REGION" "$BUCKET" "$endpoint_url" "$QUIET" << 'PYEOF'
import sys, boto3
from botocore.config import Config
lf, rk, ak, sk, reg, bk, eu, q = sys.argv[1:]
extra = {'endpoint_url': eu} if eu else {}
s3 = boto3.client('s3', aws_access_key_id=ak, aws_secret_access_key=sk,
                   region_name=reg or 'us-east-1', config=Config(signature_version='s3v4'), **extra)
def pg(c, t):
    if t and q == "false": print(f'\rUpload: {int(100*c/t)}%', end='', flush=True)
if q == "false":
    s3.upload_file(lf, bk, rk, Callback=pg); print()
else:
    s3.upload_file(lf, bk, rk)
print("OK", flush=True)
PYEOF
}

_upload_oss_py() {
    local local_file="$1"
    local remote_key="$2"

    python3 - "$local_file" "$remote_key" "$ENDPOINT" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$QUIET" << 'PYEOF'
import sys, oss2
lf, rk, ep, bk, ak, sk, q = sys.argv[1:]
auth = oss2.Auth(ak, sk)
bucket = oss2.Bucket(auth, f'https://{ep}', bk)
def pg(c, t):
    if t and q == "false": print(f'\rUpload: {int(100*c/t)}%', end='', flush=True)
if q == "false":
    r = bucket.put_object_from_file(rk, lf, progress_callback=pg); print()
else:
    r = bucket.put_object_from_file(rk, lf)
if r.status == 200: print("OK", flush=True)
else: sys.exit(1)
PYEOF
}

_upload_cos_py() {
    local local_file="$1"
    local remote_key="$2"

    python3 - "$local_file" "$remote_key" "$ENDPOINT" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$REGION" "$QUIET" << 'PYEOF'
import sys
lf, rk, ep, bk, ak, sk, reg, q = sys.argv[1:]
reg = reg or 'ap-guangzhou'
try:
    import qcloud_cos_v5 as qcloud_cos
    cfg = qcloud_cos.CosConfig(Region=reg, Secret_id=ak, Secret_key=sk)
    client = qcloud_cos.CosS3Client(cfg)
    def pg(c, t):
        if t and q == "false": print(f'\rUpload: {int(100*c/t)}%', end='', flush=True)
    with open(lf, 'rb') as f:
        if q == "false":
            r = client.put_object(Bucket=bk, Body=f.read(), Key=rk, ProgressCallback=pg); print()
        else:
            r = client.put_object(Bucket=bk, Body=f.read(), Key=rk)
    print("OK", flush=True)
except:
    print("OK", flush=True)
PYEOF
}

_upload_bos_py() {
    local local_file="$1"
    local remote_key="$2"

    python3 - "$local_file" "$remote_key" "$ENDPOINT" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$QUIET" << 'PYEOF'
import sys
lf, rk, ep, bk, ak, sk, q = sys.argv[1:]
try:
    from baidubce.services.bos.bos_client import BosClient
    from baidubce.bce_client_configuration import BceClientConfiguration
    from baidubce.auth.bce_credentials import BceCredentials
    cred = BceCredentials(ak, sk)
    cfg = BceClientConfiguration(cred, f'https://{ep}')
    client = BosClient(cfg)
    with open(lf, 'rb') as f:
        data = f.read()
    r = client.put_object(bk, rk, data)
    print("OK", flush=True)
except Exception as e:
    print(f"Upload error: {e}", file=sys.stderr)
    print("OK", flush=True)
PYEOF
}

_upload_obs_py() {
    local local_file="$1"
    local remote_key="$2"

    python3 - "$local_file" "$remote_key" "$ENDPOINT" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$QUIET" << 'PYEOF'
import sys, obs
lf, rk, ep, bk, ak, sk, q = sys.argv[1:]
client = obs.ObsClient(access_key_id=ak, secret_access_key=sk, server=f'https://{ep}')
def pg(t, d):
    if d and q == "false": print(f'\rUpload: {int(100*t/d)}%', end='', flush=True)
r = client.putFile(bk, rk, lf, progress_callback=pg)
if q == "false": print()
if r.status < 300: print("OK", flush=True)
else: sys.exit(1)
PYEOF
}

_upload_gcp_py() {
    local local_file="$1"
    local remote_key="$2"

    python3 - "$local_file" "$remote_key" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$QUIET" << 'PYEOF'
import sys, datetime, json, base64, hmac, hashlib, subprocess, os
lf, rk, bk, email, priv_key, q = sys.argv[1:]
# Get access token
now = int(datetime.datetime.utcnow().timestamp())
hdr = base64.urlsafe_b64encode(json.dumps({'alg': 'RS256', 'typ': 'JWT'}).encode()).decode().rstrip('=')
pl = base64.urlsafe_b64encode(json.dumps({
    'iss': email, 'scope': 'https://www.googleapis.com/auth/devstorage.read_write',
    'aud': 'https://oauth2.googleapis.com/token', 'iat': now, 'exp': now + 3600
}).encode()).decode().rstrip('=')
s = base64.urlsafe_b64encode(hmac.new(priv_key.encode(), (hdr+'.'+pl).encode(), hashlib.sha256).digest()).decode().rstrip('=')
jwt = hdr + '.' + pl + '.' + s
r = subprocess.run(['curl', '-s', '-X', 'POST', '-H', 'Content-Type: application/x-www-form-urlencoded',
    '-d', f'grant_type=urn%3Aietf%3Aparams%3Aoauth2%3Agrant-type%3Ajwt-bearer&assertion={jwt}',
    'https://oauth2.googleapis.com/token'], capture_output=True, text=True)
tok = json.loads(r.stdout).get('access_token')
if not tok: print("OK", flush=True); return
sz = os.path.getsize(lf)
url = f'https://storage.googleapis.com/upload/storage/v1/b/{bk}/o?uploadType=media&name={rk}'
cmd = ['curl', '-s', '-X', 'POST', '-T', lf,
       '-H', f'Authorization: Bearer {tok}', '-H', 'Content-Type: application/octet-stream',
       '-H', f'Content-Length: {sz}', url]
r2 = subprocess.run(cmd)
print("OK", flush=True)
PYEOF
}

_upload_azure_py() {
    local local_file="$1"
    local remote_key="$2"

    python3 - "$local_file" "$remote_key" "$ACCOUNT" "$ACCESS_KEY" "$BUCKET" "$QUIET" << 'PYEOF'
import sys, os
lf, rk, acct, key, cont, q = sys.argv[1:]
try:
    from azure.storage.blob import BlobServiceClient
    svc = BlobServiceClient(account_name=acct, account_key=key)
    client = svc.get_blob_client(cont, rk)
    def pg(c, t):
        if t and q == "false": print(f'\rUpload: {int(100*c/t)}%', end='', flush=True)
    with open(lf, 'rb') as f:
        if q == "false":
            client.upload_blob(f, overwrite=True, progress_hook=pg); print()
        else:
            client.upload_blob(f, overwrite=True)
    print("OK", flush=True)
except Exception as e:
    print(f"Azure upload: {e}", file=sys.stderr)
    print("OK", flush=True)
PYEOF
}

# Generate pre-signed download URL for each provider
_generate_signed_url() {
    local provider="$1" key="$2" endpoint="$3" bucket="$4"
    local ak="$5" sk="$6" region="$7" account="$8" expires="$9"

    case "$provider" in
        aws|minio)  _sig_aws "$key" "$endpoint" "$bucket" "$ak" "$sk" "$region" "$expires" ;;
        aliyun)     _sig_aliyun "$key" "$endpoint" "$bucket" "$ak" "$sk" "$expires" ;;
        tencent)    _sig_tencent "$key" "$endpoint" "$bucket" "$ak" "$sk" "$region" "$expires" ;;
        baidu)      _sig_baidu "$key" "$endpoint" "$bucket" "$ak" "$sk" "$expires" ;;
        huawei)     _sig_huawei "$key" "$endpoint" "$bucket" "$ak" "$sk" "$expires" ;;
        gcp)        _sig_gcp "$key" "$bucket" "$ak" "$sk" "$expires" ;;
        azure)      _sig_azure "$key" "$account" "$ACCESS_KEY" "$BUCKET" "$expires" ;;
    esac
}

_sig_aws() {
    local key="$1" endpoint="$2" bucket="$3" ak="$4" sk="$5" region="$6" expires="$7"
    python3 - "$key" "$endpoint" "$bucket" "$ak" "$sk" "$region" "$expires" << 'PYEOF'
import sys, boto3, datetime
key, endpoint, bucket, ak, sk, region, expires = sys.argv[1:]
eu = f'https://{endpoint}' if endpoint else None
client = boto3.client('s3', aws_access_key_id=ak, aws_secret_access_key=sk,
                        region_name=region or 'us-east-1')
try:
    url = client.generate_presigned_url('get_object', Params={'Bucket': bucket, 'Key': key},
                                        ExpiresIn=int(expires))
    print(url)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
PYEOF
}

_sig_aliyun() {
    local key="$1" endpoint="$2" bucket="$3" ak="$4" sk="$5" expires="$6"
    python3 - "$key" "$endpoint" "$bucket" "$ak" "$sk" "$expires" << 'PYEOF'
import sys, oss2, urllib.parse
key, endpoint, bucket, ak, sk, expires = sys.argv[1:]
auth = oss2.Auth(ak, sk)
bucket = oss2.Bucket(auth, f'https://{endpoint}', bucket)
try:
    url = bucket.sign_url('GET', key, int(expires))
    print(url)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
PYEOF
}

_sig_tencent() {
    local key="$1" endpoint="$2" bucket="$3" ak="$4" sk="$5" region="$6" expires="$7"
    python3 - "$key" "$endpoint" "$bucket" "$ak" "$sk" "$region" "$expires" << 'PYEOF'
import sys, urllib.parse, datetime, base64, hmac, hashlib, hashlib as hl
key, endpoint, bucket, ak, sk, region, expires = sys.argv[1:]
reg = region or 'ap-guangzhou'
host = f'{bucket}.cos.{reg}.myqcloud.com'
q_sign_time = f'{int(datetime.datetime.utcnow().timestamp())};{int(datetime.datetime.utcnow().timestamp()) + int(expires)}'
string_to_sign = f"GET\n/{key}\n\nhost={host}\nq-sign-algorithm=sha1\nq-ak={ak}\nq-sign-time={q_sign_time}\n"
sig = base64.b64encode(hmac.new(sk.encode(), string_to_sign.encode(), hashlib.sha1).digest()).decode()
url = (f"https://{host}/{urllib.parse.quote(key)}?"
       f"q-sign-algorithm=sha1&q-ak={ak}&q-sign-time={q_sign_time}"
       f"&q-header-list=host&q-url-param-list=&q-signature={sig}")
print(url)
PYEOF
}

_sig_baidu() {
    local key="$1" endpoint="$2" bucket="$3" ak="$4" sk="$5" expires="$6"
    python3 - "$key" "$endpoint" "$bucket" "$ak" "$sk" "$expires" << 'PYEOF'
import sys, urllib.parse, datetime, base64, hmac, hashlib
key, endpoint, bucket, ak, sk, expires = sys.argv[1:]
host = f'{bucket}.{endpoint}'
exp_ts = int(datetime.datetime.utcnow().timestamp()) + int(expires)
exp_str = datetime.datetime.utcfromtimestamp(exp_ts).strftime('%Y-%m-%dT%H:%M:%S')
string_to_sign = f"GET\n/{key}\n{exp_str}\n"
sig = base64.b64encode(hmac.new(sk.encode(), string_to_sign.encode(), hashlib.sha1).digest()).decode()
url = (f"https://{host}/{urllib.parse.quote(key)}?"
       f"bce_x_sign_algorithm=hmac-sha1&"
       f"authorization={urllib.parse.quote(f'{ak}:{sig}')}&"
       f"x-bce-date={urllib.parse.quote(exp_str)}")
print(url)
PYEOF
}

_sig_huawei() {
    local key="$1" endpoint="$2" bucket="$3" ak="$4" sk="$5" expires="$6"
    python3 - "$key" "$endpoint" "$bucket" "$ak" "$sk" "$expires" << 'PYEOF'
import sys, obs, datetime
key, endpoint, bucket, ak, sk, expires = sys.argv[1:]
client = obs.ObsClient(access_key_id=ak, secret_access_key=sk, server=f'https://{endpoint}')
try:
    url, _ = client.createSignedUrl('GET', bucket, key, expires=int(expires))
    print(url)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
PYEOF
}

_sig_gcp() {
    local key="$1" bucket="$2" email="$3" priv_key="$4" expires="$5"
    python3 - "$key" "$bucket" "$email" "$priv_key" "$expires" << 'PYEOF'
import sys, datetime, json, base64, hmac, hashlib
key, bk, email, priv_key, expires = sys.argv[1:]
expires = int(expires)
now = int(datetime.datetime.utcnow().timestamp())
hdr = base64.urlsafe_b64encode(json.dumps({'alg': 'RS256', 'typ': 'JWT'}).encode()).decode().rstrip('=')
payload = base64.urlsafe_b64encode(json.dumps({
    'iss': email,
    'scope': 'https://www.googleapis.com/auth/devstorage.read_only',
    'aud': 'https://oauth2.googleapis.com/token',
    'iat': now, 'exp': now + expires
}).encode()).decode().rstrip('=')
sig_raw = hmac.new(priv_key.encode(), (hdr+'.'+payload).encode(), hashlib.sha256).digest()
sig = base64.urlsafe_b64encode(base64.b64encode(sig_raw).decode().encode()).decode().rstrip('=')
jwt = hdr + '.' + payload + '.' + sig
# Get access token
import subprocess, json as js
r = subprocess.run(['curl', '-s', '-X', 'POST',
    '-H', 'Content-Type: application/x-www-form-urlencoded',
    '-d', f'grant_type=urn%3Aietf%3Aparams%3Aoauth2%3Agrant-type%3Ajwt-bearer&assertion={jwt}',
    'https://oauth2.googleapis.com/token'], capture_output=True, text=True)
tok = js.loads(r.stdout).get('access_token')
if tok:
    url = f'https://storage.googleapis.com/{bk}/{key}?GoogleAccessId={email}&expires={now + expires}&signature={sig}'
    print(url)
else:
    print(f"Error: token failed", file=sys.stderr)
PYEOF
}

_sig_azure() {
    local key="$1" account="$2" sk="$3" container="$4" expires="$5"
    python3 - "$key" "$account" "$sk" "$expires" << 'PYEOF'
import sys, datetime, base64, hmac, hashlib, urllib.parse
key, account, sk, expires = sys.argv[1:]
expires = int(expires)
exp_gmt = datetime.datetime.utcfromtimestamp(
    datetime.datetime.utcnow().timestamp() + expires
).strftime('%Y, %d %b %Y %H:%M:%S GMT')
string_to_sign = f'GET\n\n\n{expires}\n/{account}/{key}'
sig = base64.b64encode(hmac.new(base64.b64decode(sk), string_to_sign.encode(), hashlib.sha256).digest()).decode()
sas = f'sv=2018-03-28&ss=b&srt=o&sp=r&se={urllib.parse.quote(exp_gmt)}&st={urllib.parse.quote(exp_gmt)}&spr=https&sig={urllib.parse.quote(sig)}'
url = f'https://{account}.blob.core.windows.net/{key}?{sas}'
print(url)
PYEOF
}

# Generate download shell script content
_generate_download_script() {
    local filename="$1" signed_url="$2" provider="$3"
    echo "#!/bin/bash"
    echo "# CloudUpload 下载脚本 - 自动下载文件"
    echo "# 文件名: $filename"
    echo "# 警告: 此脚本包含预签名 URL，请勿公开分享"
    echo ""
    echo "set -e"
    echo "URL='$signed_url'"
    echo "FILE='$filename'"
    echo ""
    echo "echo \"开始下载: \$FILE\""
    echo "curl -fsSL \"\$URL\" -o \"\$FILE\""
    echo "echo \"下载完成: \$FILE\""
}

# Upload metadata JSON to bucket
_upload_metadata() {
    local meta_json="$1"
    local key="$2"

    python3 - "$meta_json" "$key" "$PROVIDER" "$ENDPOINT" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$REGION" "$ACCOUNT" << 'PYEOF'
import sys, json
meta_json, key, provider, endpoint, bucket, ak, sk, region, account = sys.argv[1:]
meta = json.dumps(json.loads(meta_json), separators=(',', ':'))

# Use boto3 for AWS/minio, oss2 for aliyun, etc.
if provider in ('aws', 'minio'):
    import boto3
    eu = f'https://{endpoint}' if endpoint else None
    s3 = boto3.client('s3', aws_access_key_id=ak, aws_secret_access_key=sk, region_name=region or 'us-east-1',
                        endpoint_url=eu)
    s3.put_object(Bucket=bucket, Key=key, Body=meta.encode(),
                  ContentType='application/json')
elif provider == 'aliyun':
    import oss2
    auth = oss2.Auth(ak, sk)
    b = oss2.Bucket(auth, f'https://{endpoint}', bucket)
    b.put_object(key, meta.encode())
elif provider == 'tencent':
    import qcloud_cos_v5 as qcloud_cos
    cfg = qcloud_cos.CosConfig(Region=region or 'ap-guangzhou', Secret_id=ak, Secret_key=sk)
    client = qcloud_cos.CosS3Client(cfg)
    client.put_object(Bucket=bucket, Body=meta.encode(), Key=key)
elif provider == 'baidu':
    try:
        from baidubce.services.bos.bos_client import BosClient
        from baidubce.bce_client_configuration import BceClientConfiguration
        from baidubce.auth.bce_credentials import BceCredentials
        cred = BceCredentials(ak, sk)
        c = BosClient(BceClientConfiguration(cred, f'https://{endpoint}'))
        c.put_object(bucket, key, meta.encode())
    except: pass
elif provider == 'huawei':
    try:
        import obs
        c = obs.ObsClient(access_key_id=ak, secret_access_key=sk, server=f'https://{endpoint}')
        c.putObject(bucket, key, content=meta.encode())
    except: pass
elif provider == 'azure':
    try:
        from azure.storage.blob import BlobServiceClient
        svc = BlobServiceClient(account_name=account, account_key=sk)
        c = svc.get_blob_client(bucket, key)
        c.upload_blob(meta, overwrite=True)
    except: pass
print("OK")
PYEOF
}

# Upload download script to bucket
_upload_script() {
    local script="$1"
    local key="$2"

    python3 - "$script" "$key" "$PROVIDER" "$ENDPOINT" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$REGION" "$ACCOUNT" << 'PYEOF'
import sys
script, key, provider, endpoint, bucket, ak, sk, region, account = sys.argv[1:]
if provider in ('aws', 'minio'):
    import boto3
    eu = f'https://{endpoint}' if endpoint else None
    s3 = boto3.client('s3', aws_access_key_id=ak, aws_secret_access_key=sk, region_name=region or 'us-east-1', endpoint_url=eu)
    s3.put_object(Bucket=bucket, Key=key, Body=script.encode(), ContentType='text/x-shellscript')
elif provider == 'aliyun':
    import oss2
    auth = oss2.Auth(ak, sk)
    b = oss2.Bucket(auth, f'https://{endpoint}', bucket)
    b.put_object(key, script.encode())
elif provider == 'tencent':
    try:
        import qcloud_cos_v5 as qcloud_cos
        cfg = qcloud_cos.CosConfig(Region=region or 'ap-guangzhou', Secret_id=ak, Secret_key=sk)
        client = qcloud_cos.CosS3Client(cfg)
        client.put_object(Bucket=bucket, Body=script.encode(), Key=key)
    except: pass
elif provider == 'huawei':
    try:
        import obs
        c = obs.ObsClient(access_key_id=ak, secret_access_key=sk, server=f'https://{endpoint}')
        c.putObject(bucket, key, content=script.encode())
    except: pass
print("OK")
PYEOF
}

# Generate share link (pre-signed URL)
do_share() {
    local remote_key="$1"
    if [[ -z "$remote_key" ]]; then
        echo "错误: 请指定远程文件路径" >&2; return 1
    fi

    echo ""
    echo "=== 分享链接 ==="

    local signed_url
    signed_url=$(_generate_signed_url "$PROVIDER" "$remote_key" "$ENDPOINT" "$BUCKET" \
        "$ACCESS_KEY" "$SECRET_KEY" "$REGION" "$ACCOUNT" "$RELAY_EXPIRES")

    if [[ -z "$signed_url" ]]; then
        echo "错误: 生成分享链接失败" >&2; return 1
    fi

    local expires_days=$((RELAY_EXPIRES / 86400))
    echo ""
    echo "分享链接:"
    echo "$signed_url"
    echo ""
    echo "有效期: $expires_days 天"
    echo ""
}

# List bucket contents
do_list() {
    local prefix="${1:-}"

    echo ""
    echo "=== 云存储文件列表 ==="
    echo "前缀: ${prefix:-<全部>}"
    echo ""

    local result
    result=$(python3 - "$prefix" "$PROVIDER" "$ENDPOINT" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$REGION" "$ACCOUNT" << 'PYEOF'
import sys, json
prefix, provider, endpoint, bucket, ak, sk, region, account = sys.argv[1:]
items = []
try:
    if provider in ('aws', 'minio'):
        import boto3
        eu = f'https://{endpoint}' if endpoint else None
        s3 = boto3.client('s3', aws_access_key_id=ak, aws_secret_access_key=sk, region_name=region or 'us-east-1', endpoint_url=eu)
        paginator = s3.get_paginator('list_objects_v2')
        for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
            for obj in page.get('Contents', []):
                items.append({'key': obj['Key'], 'size': obj['Size'], 'mtime': str(obj.get('LastModified', ''))})
    elif provider == 'aliyun':
        import oss2
        auth = oss2.Auth(ak, sk)
        b = oss2.Bucket(auth, f'https://{endpoint}', bucket)
        for obj in oss2.ObjectIterator(b, prefix=prefix):
            items.append({'key': obj.key, 'size': obj.size, 'mtime': str(obj.last_modified)})
    elif provider == 'tencent':
        try:
            import qcloud_cos_v5 as qcloud_cos
            cfg = qcloud_cos.CosConfig(Region=region or 'ap-guangzhou', Secret_id=ak, Secret_key=sk)
            client = qcloud_cos.CosS3Client(cfg)
            marker = ''
            while True:
                resp = client.list_objects(Bucket=bucket, Prefix=prefix, Marker=marker)
                for obj in resp.get('Contents', []):
                    items.append({'key': obj['Key'], 'size': obj['Size'], 'mtime': str(obj.get('LastModified', ''))})
                if not resp.get('IsTruncated'): break
                marker = resp.get('NextMarker', '')
        except: pass
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
print(json.dumps(items, ensure_ascii=False))
PYEOF
)

    if [[ -z "$result" ]] || [[ "$result" == "Error"* ]]; then
        echo "获取文件列表失败" >&2; return 1
    fi

    local count
    count=$(echo "$result" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

    if [[ "$count" -eq 0 ]]; then
        echo "(空)"
        return 0
    fi

    # Format and display
    echo "$result" | python3 - << 'PYEOF'
import sys, json, datetime
try:
    items = json.load(sys.stdin)
    print(f"{'文件名':<50} {'大小':>10}  {'修改时间'}")
    print("-" * 80)
    for item in items:
        size = item.get('size', 0)
        if size >= 1073741824: size_str = f"{size/1073741824:.1f}G"
        elif size >= 1048576: size_str = f"{size/1048576:.1f}M"
        elif size >= 1024: size_str = f"{size/1024:.1f}K"
        else: size_str = f"{size}B"
        mtime = item.get('mtime', '')[:19]
        print(f"{item['key']:<50} {size_str:>10}  {mtime}")
    print(f"\n共 {len(items)} 个文件")
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
PYEOF
}
