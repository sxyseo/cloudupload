# azure.ps1 - Azure Blob Storage 上传 (Windows PowerShell)

function Do-Upload {
    param([string]$LocalFile, [string]$RemoteKey)

    Write-Host "文件: $LocalFile"
    Write-Host "目标: azure://$BUCKET/$RemoteKey"

    $method = Get-UploadMethod -Provider "azure"

    switch ($method) {
        "az-cli"      { _Upload-AzCli -LocalFile $LocalFile -RemoteKey $RemoteKey }
        "azure-python"{ _Upload-AzurePy -LocalFile $LocalFile -RemoteKey $RemoteKey }
        "curl-sas"    { _Upload-Curl -LocalFile $LocalFile -RemoteKey $RemoteKey }
        default       { Write-Error "无可用上传方式"; exit 1 }
    }
}

function _Upload-AzCli {
    param([string]$LocalFile, [string]$RemoteKey)

    $args = @("storage", "blob", "upload",
              "--container-name", $BUCKET,
              "--name", $RemoteKey,
              "--file", $LocalFile)
    if ($ACCOUNT -and $ACCESS_KEY) {
        $args += "--account-name", $ACCOUNT, "--account-key", $ACCESS_KEY
    }
    & az @args 2>&1 | ForEach-Object { if (-not $Quiet) { Write-Host $_ } }
    if ($LASTEXITCODE -eq 0) { _Generate-Url -RemoteKey $RemoteKey }
}

function _Upload-AzurePy {
    param([string]$LocalFile, [string]$RemoteKey)

    $py = @"
import sys
lf='$LocalFile'; rk='$RemoteKey'; acct='$ACCOUNT'; key='$ACCESS_KEY'; cont='$BUCKET'; q='$Quiet'
try:
    from azure.storage.blob import BlobServiceClient
    if key:
        svc=BlobServiceClient(account_name=acct,account_key=key)
    else:
        from azure.identity import DefaultAzureCredential
        svc=BlobServiceClient(account_url=f'https://{acct}.blob.core.windows.net',credential=DefaultAzureCredential())
    client=svc.get_blob_client(cont,rk)
    def pg(c,t):
        if t and q=='false': print(f'\r进度:{int(100*c/t)}%',end='',flush=True)
    with open(lf,'rb') as f:
        if q=='false': client.upload_blob(f,overwrite=True,progress_hook=pg); print()
        else: client.upload_blob(f,overwrite=True)
    print('✓ 上传成功')
    print(f'URL: https://{acct}.blob.core.windows.net/{cont}/{rk}')
except Exception as e:
    print(f'错误: {e}',file=sys.stderr); sys.exit(1)
"@
    python -c $py
    if ($LASTEXITCODE -ne 0) { exit 1 }
    _Generate-Url -RemoteKey $RemoteKey
}

function _Upload-Curl {
    param([string]$LocalFile, [string]$RemoteKey)

    $url = "https://$ACCOUNT.blob.core.windows.net/$BUCKET/$RemoteKey"
    if ($ACCESS_KEY -and -not $ACCESS_KEY.StartsWith('?')) {
        $url += "?sv=2021-06-08&ss=b&srt=sco&sp=rwdlacupit&se=2030-01-01T00:00:00Z&st=2024-01-01T00:00:00Z&spr=https&sig=$ACCESS_KEY"
    }

    Write-Host "URL: $url"
    $cmd = "curl -T `"$LocalFile`" `"$url`" -H `"x-ms-blob-type: BlockBlob`" -H `"Content-Type: application/octet-stream`""
    Invoke-Expression $cmd
    if ($LASTEXITCODE -eq 0) { Write-Host "✓ 上传成功" }
}

function _Generate-Url {
    param([string]$RemoteKey)
    Write-Host ""
    Write-Host "✓ 上传成功" -ForegroundColor Green
    Write-Host "URL: https://$ACCOUNT.blob.core.windows.net/$BUCKET/$RemoteKey"
}
