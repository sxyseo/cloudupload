#!/usr/bin/env bash
# gcp.sh - 谷歌云 GCS 上传 (Unix/Linux/macOS)

do_upload() {
    local local_file="$1"
    local remote_key="$2"
    local method
    method=$(get_upload_method "gcp")

    echo "文件: $local_file"
    echo "目标: gs://$BUCKET/$remote_key"

    case "$method" in
        gsutil)      _upload_gsutil "$local_file" "$remote_key" ;;
        gcp-python)  _upload_gcp_py "$local_file" "$remote_key" ;;
        curl-jwt)    _upload_curl "$local_file" "$remote_key" ;;
        *)           echo "错误: 无可用上传方式" >&2; return 1 ;;
    esac
}

_upload_gsutil() {
    local local_file="$1"
    local remote_key="$2"

    # 设置凭证
    if [[ -n "$ACCESS_KEY" && -n "$SECRET_KEY" ]]; then
        # ACCESS_KEY = service account email, SECRET_KEY = private key
        export CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE="$SECRET_KEY"
    fi

    local args=()
    [[ "$QUIET" == "true" ]] && args+=(-q)

    gsutil cp "$local_file" "gs://$BUCKET/$remote_key" "${args[@]}" 2>&1
    local rc=$?
    [[ $rc -eq 0 ]] && _generate_url "$remote_key"
    return $rc
}

_upload_gcp_py() {
    local local_file="$1"
    local remote_key="$2"

    # ACCESS_KEY = client_email, SECRET_KEY = private_key
    python3 - "$local_file" "$remote_key" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$QUIET" << 'PYEOF'
import sys, datetime, json, base64, hmac, hashlib

lf, rk, bk, email, priv_key, q = sys.argv[1:]

# 生成 JWT
now = int(datetime.datetime.utcnow().timestamp())
header = base64.urlsafe_b64encode(json.dumps({'alg': 'RS256', 'typ': 'JWT'}).encode()).decode().rstrip('=')
payload = base64.urlsafe_b64encode(json.dumps({
    'iss': email, 'scope': 'https://www.googleapis.com/auth/devstorage.read_write',
    'aud': 'https://oauth2.googleapis.com/token',
    'iat': now, 'exp': now + 3600
}).encode()).decode().rstrip('=')
signed = base64.urlsafe_b64encode(
    hmac.new(priv_key.encode(), (header+'.'+payload).encode(), hashlib.sha256).digest()
).decode().rstrip('=')
jwt = header + '.' + payload + '.' + signed

# 获取 access token
import subprocess
r = subprocess.run(['curl', '-s', '-X', 'POST',
    '-H', f'Content-Type: application/x-www-form-urlencoded',
    '-d', f'grant_type=urn:ietf:params:oauth2:grant-type:jwt-bearer&assertion={jwt}',
    'https://oauth2.googleapis.com/token'], capture_output=True, text=True)

token_data = json.loads(r.stdout)
access_token = token_data.get('access_token')
if not access_token:
    print(f'获取 token 失败: {token_data}', file=sys.stderr)
    sys.exit(1)

# 上传文件
url = f'https://storage.googleapis.com/upload/storage/v1/b/{bk}/o?uploadType=media&name={rk}'
import os
file_size = os.path.getsize(lf)

cmd = ['curl', '-s', '-X', 'POST', '-T', lf,
       '-H', f'Authorization: Bearer {access_token}',
       '-H', 'Content-Type: application/octet-stream',
       '-H', f'Content-Length: {file_size}', url]
if q == 'false': cmd.insert(1, '-v')

r2 = subprocess.run(cmd, capture_output=True, text=True)
if r2.returncode == 0:
    resp = json.loads(r2.stdout) if r2.stdout else {}
    print()
    print('✓ 上传成功')
    print(f'URL: https://storage.googleapis.com/{bk}/{rk}')
else:
    print(f'上传失败: {r2.stderr}', file=sys.stderr)
    sys.exit(1)
PYEOF
}

_upload_curl() {
    _upload_gcp_py "$@"
}

_generate_url() {
    local rk="$1"
    echo ""
    echo "✓ 上传成功"
    echo "URL: https://storage.googleapis.com/$BUCKET/$rk"
}
