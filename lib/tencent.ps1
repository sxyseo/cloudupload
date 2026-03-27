# tencent.ps1 - 腾讯云 COS 上传 (Windows PowerShell)

function Do-Upload {
    param([string]$LocalFile, [string]$RemoteKey)

    Write-Host "文件: $LocalFile"
    Write-Host "目标: cos://$BUCKET/$RemoteKey"

    $method = Get-UploadMethod -Provider "tencent"

    switch ($method) {
        "coscli"    { _Upload-CosCli -LocalFile $LocalFile -RemoteKey $RemoteKey }
        "cos-python"{ _Upload-CosPy -LocalFile $LocalFile -RemoteKey $RemoteKey }
        "curl-sign" { _Upload-Curl -LocalFile $LocalFile -RemoteKey $RemoteKey }
        default     { Write-Error "无可用上传方式"; exit 1 }
    }
}

function _Upload-CosCli {
    param([string]$LocalFile, [string]$RemoteKey)

    $env:COS_SECRETID = $ACCESS_KEY
    $env:COS_SECRETKEY = $SECRET_KEY
    $reg = if ($REGION) { $REGION } else { "ap-guangzhou" }

    coscli cp $LocalFile "cos://$BUCKET/$RemoteKey" 2>&1 | ForEach-Object {
        if (-not $Quiet) { Write-Host $_ }
    }
    if ($LASTEXITCODE -eq 0) { _Generate-Url -RemoteKey $RemoteKey }
}

function _Upload-CosPy {
    param([string]$LocalFile, [string]$RemoteKey)

    $reg = if ($REGION) { $REGION } else { "ap-guangzhou" }

    $py = @"
import sys
lf='$LocalFile'; rk='$RemoteKey'; bk='$BUCKET'
ak='$ACCESS_KEY'; sk='$SECRET_KEY'; reg='$reg'; q='$Quiet'
try:
    import qcloud_cos_v5 as qcloud_cos
    cfg=qcloud_cos.CosConfig(Region=reg,Secret_id=ak,Secret_key=sk)
    client=qcloud_cos.CosS3Client(cfg)
    if q=='false':
        def pg(c,t):
            if t: print(f'\r进度:{int(100*c/t)}%',end='',flush=True)
        with open(lf,'rb') as f:
            r=client.put_object(Bucket=bk,Body=f,Key=rk,ProgressCallback=pg)
        print()
    else:
        with open(lf,'rb') as f:
            r=client.put_object(Bucket=bk,Body=f,Key=rk)
    print('✓ 上传成功')
    print(f'URL: https://{bk}.cos.{reg}.myqcloud.com/{rk}')
except Exception as e:
    print(f'错误: {e}', file=sys.stderr)
    sys.exit(1)
"@
    python -c $py
    if ($LASTEXITCODE -ne 0) { exit 1 }
    _Generate-Url -RemoteKey $RemoteKey
}

function _Upload-Curl {
    param([string]$LocalFile, [string]$RemoteKey)

    $reg = if ($REGION) { $REGION } else { "ap-guangzhou" }
    $url = "https://$BUCKET.cos.$reg.myqcloud.com/$RemoteKey"
    Write-Host "URL: $url"

    $cmd = "curl -T `"$LocalFile`" `"$url`""
    Invoke-Expression $cmd
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ 上传成功"
    }
}

function _Generate-Url {
    param([string]$RemoteKey)
    $reg = if ($REGION) { $REGION } else { "ap-guangzhou" }
    Write-Host ""
    Write-Host "✓ 上传成功" -ForegroundColor Green
    Write-Host "URL: https://$BUCKET.cos.$reg.myqcloud.com/$RemoteKey"
}
