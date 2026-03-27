#!/usr/bin/env bash
# baidu.sh - 百度云 BOS 上传 (Unix/Linux/macOS)

do_upload() {
    local local_file="$1"
    local remote_key="$2"
    local method
    method=$(get_upload_method "baidu")

    echo "文件: $local_file"
    echo "目标: bos://$BUCKET/$remote_key"

    case "$method" in
        boscli)      _upload_boscli "$local_file" "$remote_key" ;;
        bos-python)  _upload_bos_py "$local_file" "$remote_key" ;;
        curl-sign)   _upload_curl "$local_file" "$remote_key" ;;
        *)           echo "错误: 无可用上传方式" >&2; return 1 ;;
    esac
}

_upload_boscli() {
    local local_file="$1"
    local remote_key="$2"

    local cfg
    cfg=$(mktemp)
    printf '[BOS]\nhost=%s\ncredential=ak=%s;sk=%s\n' "$ENDPOINT" "$ACCESS_KEY" "$SECRET_KEY" > "$cfg"

    trap "rm -f '$cfg'" EXIT INT TERM

    boscli cp "$local_file" "bos://$BUCKET/$remote_key" --config-file "$cfg" 2>&1
    local rc=$?
    [[ $rc -eq 0 ]] && _generate_url "$remote_key"
    return $rc
}

_upload_bos_py() {
    local local_file="$1"
    local remote_key="$2"

    python3 - "$local_file" "$remote_key" "$ENDPOINT" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$QUIET" << 'PYEOF'
import sys
try:
    from baidubce import bce_client_configuration
    from baidubce.services.bos import BosClient
    from baidubce.auth.bce_credentials import BceCredentials
except ImportError:
    # baidubce v3
    from baidubce import services
    from baidubce.services.bos.bos_client import BosClient
    from baidubce.services.bos import bos_client

lf, rk, ep, bk, ak, sk, q = sys.argv[1:]

host = ep
credentials = type('', (), {'access_key_id': ak, 'secret_access_key': sk})()
config = type('', (), {'endpoint': f'https://{ep}', 'credentials': credentials})()
client = BosClient(config)

def prog(up, total):
    if total and q == "false":
        print(f'\r进度: {int(100*up/total)}%', end='', flush=True)

with open(lf, 'rb') as f:
    data = f.read()

if q == "false":
    print('上传中...', end='', flush=True)

response = client.put_object(bk, rk, data)

if response.status == 200:
    print()
    print('✓ 上传成功')
    print(f'URL: https://{bk}.{ep}/{rk}')
else:
    print(f'错误: HTTP {response.status}', file=sys.stderr)
    sys.exit(1)
PYEOF
}

_upload_curl() {
    local local_file="$1"
    local remote_key="$2"

    python3 - "$local_file" "$remote_key" "$ENDPOINT" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$QUIET" << 'PYEOF'
import sys, hmac, hashlib, base64, datetime, subprocess, urllib.parse

lf, rk, ep, bk, ak, sk, q = sys.argv[1:]
url = f'https://{bk}.{ep}/{urllib.parse.quote(rk)}'
date_now = datetime.datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')

# 百度云 BOS 签名
string_to_sign = f"PUT\n/\n{rk}\n{date_now}\n"
sig = base64.b64encode(hmac.new(sk.encode(), string_to_sign.encode(), hashlib.sha1).digest()).decode()

cmd = ['curl', '-s', '-X', 'PUT', '-T', lf,
       '-H', f'Date: {date_now}',
       '-H', 'Content-Type: application/octet-stream',
       '-H', f'Authorization: BOS {ak}:{sig}', url]
if q == "false": cmd.insert(1, '-v')
r = subprocess.run(cmd)
if r.returncode == 0:
    print('✓ 上传成功')
    print(f'URL: {url}')
sys.exit(r.returncode)
PYEOF
}

_generate_url() {
    local rk="$1"
    echo ""
    echo "✓ 上传成功"
    echo "URL: https://$BUCKET.$ENDPOINT/$rk"
}
