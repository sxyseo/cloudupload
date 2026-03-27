#!/usr/bin/env bash
# azure.sh - Azure Blob Storage 上传 (Unix/Linux/macOS)

do_upload() {
    local local_file="$1"
    local remote_key="$2"
    local method
    method=$(get_upload_method "azure")

    echo "文件: $local_file"
    echo "目标: azure://$BUCKET/$remote_key"

    case "$method" in
        az-cli)       _upload_az_cli "$local_file" "$remote_key" ;;
        azure-python) _upload_azure_py "$local_file" "$remote_key" ;;
        curl-sas)     _upload_curl "$local_file" "$remote_key" ;;
        *)            echo "错误: 无可用上传方式" >&2; return 1 ;;
    esac
}

_upload_az_cli() {
    local local_file="$1"
    local remote_key="$2"

    # Azure CLI 使用登录凭证或环境变量
    if [[ -n "$ACCOUNT" && -n "$ACCESS_KEY" ]]; then
        az storage blob upload \
            --account-name "$ACCOUNT" \
            --account-key "$ACCESS_KEY" \
            --container-name "$BUCKET" \
            --name "$remote_key" \
            --file "$local_file" \
            2>&1
    else
        az storage blob upload \
            --container-name "$BUCKET" \
            --name "$remote_key" \
            --file "$local_file" \
            2>&1
    fi

    local rc=$?
    [[ $rc -eq 0 ]] && _generate_url "$remote_key"
    return $rc
}

_upload_azure_py() {
    local local_file="$1"
    local remote_key="$2"

    python3 - "$local_file" "$remote_key" "$ACCOUNT" "$ACCESS_KEY" "$BUCKET" "$ENDPOINT" "$QUIET" << 'PYEOF'
import sys
try:
    from azure.storage.blob import BlobServiceClient, ContentSettings
except ImportError:
    from azure.storage.blob import BlockBlobService as BlobServiceClient

lf, rk, acct, key, cont, ep, q = sys.argv[1:]

if key:
    svc = BlobServiceClient(account_name=acct, account_key=key)
else:
    # 使用默认凭证
    from azure.identity import DefaultAzureCredential
    cred = DefaultAzureCredential()
    ep_url = f'https://{acct}.blob.core.windows.net'
    svc = BlobServiceClient(account_url=ep_url, credential=cred)

client = svc.get_blob_client(cont, rk)

if q == "false":
    def prog(cur, total):
        if total: print(f'\r进度: {int(100*cur/total)}%', end='', flush=True)
    with open(lf, 'rb') as f:
        client.upload_blob(f, overwrite=True, progress_hook=prog)
    print()
else:
    with open(lf, 'rb') as f:
        client.upload_blob(f, overwrite=True)

print('✓ 上传成功')
url = f'https://{acct}.blob.core.windows.net/{cont}/{rk}'
print(f'URL: {url}')
PYEOF
}

_upload_curl() {
    local local_file="$1"
    local remote_key="$2"

    # 使用 SAS token
    python3 - "$local_file" "$remote_key" "$ACCOUNT" "$ACCESS_KEY" "$BUCKET" "$QUIET" << 'PYEOF'
import sys, subprocess, urllib.parse

lf, rk, acct, sas, cont, q = sys.argv[1:]

url = f'https://{acct}.blob.core.windows.net/{cont}/{urllib.parse.quote(rk)}'
if sas:
    url += f'?{sas}'

cmd = ['curl', '-s', '-X', 'PUT', '-T', lf,
       '-H', 'x-ms-blob-type: BlockBlob',
       '-H', 'Content-Type: application/octet-stream', url]
if q == "false": cmd.insert(1, '-v')

r = subprocess.run(cmd)
if r.returncode == 0:
    print('✓ 上传成功')
    print(f'URL: https://{acct}.blob.core.windows.net/{cont}/{rk}')
sys.exit(r.returncode)
PYEOF
}

_generate_url() {
    local rk="$1"
    echo ""
    echo "✓ 上传成功"
    echo "URL: https://$ACCOUNT.blob.core.windows.net/$BUCKET/$rk"
}
