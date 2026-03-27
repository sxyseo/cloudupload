#!/usr/bin/env bash
# aliyun.sh - 阿里云 OSS 上传 (Unix/Linux/macOS)

do_upload() {
    local local_file="$1"
    local remote_key="$2"
    local method
    method=$(get_upload_method "aliyun")

    echo "文件: $local_file"
    echo "目标: oss://$BUCKET/$remote_key"

    case "$method" in
        ossutil)     _upload_ossutil "$local_file" "$remote_key" ;;
        oss-python)  _upload_oss_py "$local_file" "$remote_key" ;;
        curl-sign)   _upload_curl "$local_file" "$remote_key" ;;
        *)           echo "错误: 无可用上传方式" >&2; return 1 ;;
    esac
}

_upload_ossutil() {
    local local_file="$1"
    local remote_key="$2"

    local cfg
    cfg=$(mktemp)
    printf '[Credentials]\naccessKeyID=%s\naccessKeySecret=%s\n[Bucket]\nendpoint=%s\nbucket=%s\n' \
        "$ACCESS_KEY" "$SECRET_KEY" "$ENDPOINT" "$BUCKET" > "$cfg"

    trap "rm -f '$cfg'" EXIT INT TERM

    local args=()
    [[ "$QUIET" == "true" ]] && args+=(-q)

    ossutil cp "$local_file" "oss://$BUCKET/$remote_key" --config-file "$cfg" "${args[@]}" 2>&1
    local rc=$?
    [[ $rc -eq 0 ]] && _generate_url "$remote_key"
    return $rc
}

_upload_oss_py() {
    local local_file="$1"
    local remote_key="$2"

    python3 - "$local_file" "$remote_key" "$ENDPOINT" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$QUIET" << 'PYEOF'
import sys, oss2

lf, rk, ep, bk, ak, sk, q = sys.argv[1:]
auth = oss2.Auth(ak, sk)
bucket = oss2.Bucket(auth, f'https://{ep}', bk)

def prog(c, t):
    if t and q == "false":
        print(f'\r进度: {int(100*c/t)}%', end='', flush=True)

if q == "false":
    r = bucket.put_object_from_file(rk, lf, progress_callback=prog)
    print()
else:
    r = bucket.put_object_from_file(rk, lf)

if r.status == 200:
    url = f'https://{bk}.{ep}/{rk}'
    print('✓ 上传成功')
    print(f'URL: {url}')
else:
    print(f'错误: HTTP {r.status}', file=sys.stderr)
    sys.exit(1)
PYEOF
    [[ $? -eq 0 ]] && _generate_url "$remote_key"
}

_upload_curl() {
    local local_file="$1"
    local remote_key="$2"

    python3 - "$local_file" "$remote_key" "$ENDPOINT" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$QUIET" << 'PYEOF'
import sys, hmac, hashlib, base64, datetime, subprocess, urllib.parse

lf, rk, ep, bk, ak, sk, q = sys.argv[1:]

url = f'https://{bk}.{ep}/{urllib.parse.quote(rk)}'
date_gmt = datetime.datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')
string_to_sign = f"PUT\n\napplication/octet-stream\n{date_gmt}\n/{bk}/{rk}"
sig = base64.b64encode(hmac.new(sk.encode(), string_to_sign.encode(), hashlib.sha1).digest()).decode()

cmd = ['curl', '-s', '-X', 'PUT', '-T', lf,
       '-H', f'Date: {date_gmt}',
       '-H', 'Content-Type: application/octet-stream',
       '-H', f'Authorization: OSS {ak}:{sig}', url]
if q == "false": cmd.insert(1, '-v')
r = subprocess.run(cmd)
if r.returncode == 0:
    print('✓ 上传成功')
    print(f'URL: https://{bk}.{ep}/{rk}')
sys.exit(r.returncode)
PYEOF
}

_generate_url() {
    local rk="$1"
    echo ""
    echo "✓ 上传成功"
    echo "URL: https://$BUCKET.$ENDPOINT/$rk"
}
