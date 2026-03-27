# huawei.ps1 - 华为云 OBS 上传 (Windows PowerShell)

function Do-Upload {
    param([string]$LocalFile, [string]$RemoteKey)

    Write-Host "文件: $LocalFile"
    Write-Host "目标: obs://$BUCKET/$RemoteKey"

    $method = Get-UploadMethod -Provider "huawei"

    switch ($method) {
        "obsutil"   { _Upload-Obsutil -LocalFile $LocalFile -RemoteKey $RemoteKey }
        "obs-python"{ _Upload-ObsPy -LocalFile $LocalFile -RemoteKey $RemoteKey }
        "curl-sign" { _Upload-Curl -LocalFile $LocalFile -RemoteKey $RemoteKey }
        default     { Write-Error "无可用上传方式"; exit 1 }
    }
}

function _Upload-Obsutil {
    param([string]$LocalFile, [string]$RemoteKey)

    $cfg = [System.IO.Path]::GetTempFileName() + ".cfg"
    @"
[DEFAULT]
access.key_id=$ACCESS_KEY
secret.access.key=$SECRET_KEY
server=$ENDPOINT
"@ | Out-File -FilePath $cfg -Encoding ASCII

    try {
        $args = @("cp", $LocalFile, "obs://$BUCKET/$RemoteKey", "-config", $cfg)
        if ($Quiet) { $args += "-q" }
        & obsutil @args 2>&1 | ForEach-Object { if (-not $Quiet) { Write-Host $_ } }
        if ($LASTEXITCODE -eq 0) { _Generate-Url -RemoteKey $RemoteKey }
    } finally {
        Remove-Item $cfg -Force -ErrorAction SilentlyContinue
    }
}

function _Upload-ObsPy {
    param([string]$LocalFile, [string]$RemoteKey)

    $py = @"
import sys
lf='$LocalFile'; rk='$RemoteKey'; ep='$ENDPOINT'; bk='$BUCKET'
ak='$ACCESS_KEY'; sk='$SECRET_KEY'; q='$Quiet'
try:
    import obs
    client=obs.ObsClient(access_key_id=ak,secret_access_key=sk,server=f'https://{ep}')
    def pg(t,d):
        if d and q=='false': print(f'\r进度:{int(100*t/d)}%',end='',flush=True)
    r=client.putFile(bk,rk,lf,progress_callback=pg)
    print()
    if r.status<300:
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
