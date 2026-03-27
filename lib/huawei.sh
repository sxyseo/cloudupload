#!/usr/bin/env bash
# huawei.sh - 华为云 OBS 上传 (Unix/Linux/macOS)

do_upload() {
    local local_file="$1"
    local remote_key="$2"
    local method
    method=$(get_upload_method "huawei")

    echo "文件: $local_file"
    echo "目标: obs://$BUCKET/$remote_key"

    case "$method" in
        obsutil)     _upload_obsutil "$local_file" "$remote_key" ;;
        obs-python)  _upload_obs_py "$local_file" "$remote_key" ;;
        curl-sign)   _upload_curl "$local_file" "$remote_key" ;;
        *)           echo "错误: 无可用上传方式" >&2; return 1 ;;
    esac
}

_upload_obsutil() {
    local local_file="$1"
    local remote_key="$2"

    local cfg
    cfg=$(mktemp)
    printf '[DEFAULT]\naccess.key_id=%s\nsecret.access.key=%s\nserver=%s\n' \
        "$ACCESS_KEY" "$SECRET_KEY" "$ENDPOINT" > "$cfg"

    trap "rm -f '$cfg'" EXIT INT TERM

    local args=()
    [[ "$QUIET" == "true" ]] && args+=(-q)

    obsutil cp "$local_file" "obs://$BUCKET/$remote_key" -config "$cfg" "${args[@]}" 2>&1
    local rc=$?
    [[ $rc -eq 0 ]] && _generate_url "$remote_key"
    return $rc
}

_upload_obs_py() {
    local local_file="$1"
    local remote_key="$2"

    python3 - "$local_file" "$remote_key" "$ENDPOINT" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$QUIET" << 'PYEOF'
import sys, obs

lf, rk, ep, bk, ak, sk, q = sys.argv[1:]
client = obs.ObsClient(access_key_id=ak, secret_access_key=sk, server=f'https://{ep}')

if q == "false":
    def prog(transferred, total):
        if total: print(f'\r进度: {int(100*transferred/total)}%', end='', flush=True)
    r = client.putFile(bk, rk, lf, progress_callback=prog)
    print()
else:
    r = client.putFile(bk, rk, lf)

if r.status < 300:
    print('✓ 上传成功')
    print(f'URL: https://{bk}.{ep}/{rk}')
else:
    print(f'错误: HTTP {r.status} {r.reason}', file=sys.stderr)
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

# 华为云 OBS 签名
string_to_sign = f"PUT\n\napplication/octet-stream\n{date_now}\n/{bk}/{rk}"
sig = base64.b64encode(hmac.new(sk.encode(), string_to_sign.encode(), hashlib.sha1).digest()).decode()

cmd = ['curl', '-s', '-X', 'PUT', '-T', lf,
       '-H', f'Date: {date_now}',
       '-H', 'Content-Type: application/octet-stream',
       '-H', f'Authorization: OBS {ak}:{sig}', url]
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
