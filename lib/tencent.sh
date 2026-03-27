#!/usr/bin/env bash
# tencent.sh - 腾讯云 COS 上传 (Unix/Linux/macOS)

do_upload() {
    local local_file="$1"
    local remote_key="$2"
    local method
    method=$(get_upload_method "tencent")

    echo "文件: $local_file"
    echo "目标: cos://$BUCKET/$remote_key"

    case "$method" in
        coscli)      _upload_coscli "$local_file" "$remote_key" ;;
        cos-python)  _upload_cos_py "$local_file" "$remote_key" ;;
        curl-sign)   _upload_curl "$local_file" "$remote_key" ;;
        *)           echo "错误: 无可用上传方式" >&2; return 1 ;;
    esac
}

_upload_coscli() {
    local local_file="$1"
    local remote_key="$2"

    # coscli 配置通过配置文件或环境变量
    export COS_SECRETID="$ACCESS_KEY"
    export COS_SECRETKEY="$SECRET_KEY"

    local cfg
    cfg=$(mktemp)
    printf '[cos]\nbucket=%s\nregion=%s\nsecret_id=%s\nsecret_key=%s\n' \
        "$BUCKET" "${REGION:-ap-guangzhou}" "$ACCESS_KEY" "$SECRET_KEY" > "$cfg"

    trap "rm -f '$cfg'" EXIT INT TERM

    coscli cp "$local_file" "cos://$BUCKET/$remote_key" --config-file "$cfg" 2>&1
    local rc=$?
    [[ $rc -eq 0 ]] && _generate_url "$remote_key"
    return $rc
}

_upload_cos_py() {
    local local_file="$1"
    local remote_key="$2"

    python3 - "$local_file" "$remote_key" "$ENDPOINT" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$REGION" "$QUIET" << 'PYEOF'
import sys, qcloud_cos COS  # cos-python 2.x

lf, rk, ep, bk, ak, sk, reg, q = sys.argv[1:]
reg = reg or 'ap-guangzhou'

# 从 endpoint 提取 region
import re
m = re.search(r'cos\.([a-z0-9-]+)\.', ep or '')
if m: reg = m.group(1)

cos_cfg = qcloud_cos.CosConfig(Region=reg, Secret_id=ak, Secret_key=sk)
client = qcloud_cos.CosS3Client(cos_cfg)

if q == "false":
    from qcloud_cos import CosServiceResponse
    def prog(consumed_bytes, total_bytes):
        if total_bytes: print(f'\r进度: {int(100*consumed_bytes/total_bytes)}%', end='', flush=True)
    with open(lf, 'rb') as f:
        r = client.put_object(Bucket=bk, Body=f, Key=rk, ProgressCallback=prog)
    print()
else:
    with open(lf, 'rb') as f:
        r = client.put_object(Bucket=bk, Body=f, Key=rk)

url = f'https://{bk}.cos.{reg}.myqcloud.com/{rk}'
print('✓ 上传成功')
print(f'URL: {url}')
PYEOF
}

_upload_curl() {
    local local_file="$1"
    local remote_key="$2"

    python3 - "$local_file" "$remote_key" "$ENDPOINT" "$BUCKET" "$ACCESS_KEY" "$SECRET_KEY" "$REGION" "$QUIET" << 'PYEOF'
import sys, hmac, hashlib, base64, datetime, subprocess, urllib.parse

lf, rk, ep, bk, ak, sk, reg, q = sys.argv[1:]
reg = reg or 'ap-guangzhou'

url = f'https://{bk}.cos.{reg}.myqcloud.com/{urllib.parse.quote(rk)}'
date_now = datetime.datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')

# 腾讯云 COS 签名
origin_str = f"PUT\n/\n{rk}\n{date_now}\n"
sig = base64.b64encode(hmac.new(sk.encode(), origin_str.encode(), hashlib.sha1).digest()).decode()

cmd = ['curl', '-s', '-X', 'PUT', '-T', lf,
       '-H', f'Date: {date_now}',
       '-H', 'Content-Type: application/octet-stream',
       '-H', f'Authorization: q-sign-algorithm=sha1&q-ak={ak}&q-sign-time={int(datetime.datetime.utcnow().timestamp())};{int(datetime.datetime.utcnow().timestamp())+3600}&q-header-list=date;host&q-url-param-list=&q-signature={sig}',
       url]
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
    local reg="${REGION:-ap-guangzhou}"
    echo ""
    echo "✓ 上传成功"
    echo "URL: https://$BUCKET.cos.$reg.myqcloud.com/$rk"
}
