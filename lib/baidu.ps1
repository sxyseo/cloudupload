# baidu.ps1 - 百度云 BOS 上传 (Windows PowerShell)

function Do-Upload {
    param([string]$LocalFile, [string]$RemoteKey)

    Write-Host "文件: $LocalFile"
    Write-Host "目标: bos://$BUCKET/$RemoteKey"

    $method = Get-UploadMethod -Provider "baidu"

    switch ($method) {
        "boscli"    { _Upload-BosCli -LocalFile $LocalFile -RemoteKey $RemoteKey }
        "bos-python"{ _Upload-BosPy -LocalFile $LocalFile -RemoteKey $RemoteKey }
        "curl-sign" { _Upload-Curl -LocalFile $LocalFile -RemoteKey $RemoteKey }
        default     { Write-Error "无可用上传方式"; exit 1 }
    }
}

function _Upload-BosCli {
    param([string]$LocalFile, [string]$RemoteKey)

    $cfg = [System.IO.Path]::GetTempFileName() + ".cfg"
    @"
[BOS]
host=$ENDPOINT
credential=ak=$ACCESS_KEY;sk=$SECRET_KEY
"@ | Out-File -FilePath $cfg -Encoding ASCII

    try {
        boscli cp $LocalFile "bos://$BUCKET/$RemoteKey" --config-file $cfg 2>&1 | ForEach-Object {
            if (-not $Quiet) { Write-Host $_ }
        }
        if ($LASTEXITCODE -eq 0) { _Generate-Url -RemoteKey $RemoteKey }
    } finally {
        Remove-Item $cfg -Force -ErrorAction SilentlyContinue
    }
}

function _Upload-BosPy {
    param([string]$LocalFile, [string]$RemoteKey)

    $py = @"
import sys
lf='$LocalFile'; rk='$RemoteKey'; ep='$ENDPOINT'; bk='$BUCKET'
ak='$ACCESS_KEY'; sk='$SECRET_KEY'; q='$Quiet'
try:
    from baidubce.services.bos.bos_client import BosClient
    from baidubce.bce_client_configuration import BceClientConfiguration
    from baidubce.auth.bce_credentials import BceCredentials
    cred=BceCredentials(ak,sk)
    cfg=BceClientConfiguration(cred,f'https://{ep}')
    client=BosClient(cfg)
    with open(lf,'rb') as f: data=f.read()
    r=client.put_object(bk,rk,data)
    if r.status==200:
        print('✓ 上传成功')
        print(f'URL: https://{bk}.{ep}/{rk}')
    else:
        print(f'错误: HTTP {r.status}',file=sys.stderr); sys.exit(1)
except Exception as e:
    print(f'错误: {e}',file=sys.stderr); sys.exit(1)
"@
    python -c $py
    if ($LASTEXITCODE -ne 0) { exit 1 }
    _Generate-Url -RemoteKey $RemoteKey
}

function _Upload-Curl {
    param([string]$LocalFile, [string]$RemoteKey)

    $url = "https://$BUCKET.$ENDPOINT/$RemoteKey"
    Write-Host "URL: $url"
    $cmd = "curl -T `"$LocalFile`" `"$url`""
    Invoke-Expression $cmd
    if ($LASTEXITCODE -eq 0) { Write-Host "✓ 上传成功" }
}

function _Generate-Url {
    param([string]$RemoteKey)
    Write-Host ""
    Write-Host "✓ 上传成功" -ForegroundColor Green
    Write-Host "URL: https://$BUCKET.$ENDPOINT/$RemoteKey"
}
