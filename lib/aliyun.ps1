# aliyun.ps1 - 阿里云 OSS 上传 (Windows PowerShell)

function Do-Upload {
    param([string]$LocalFile, [string]$RemoteKey)

    Write-Host "文件: $LocalFile"
    Write-Host "目标: oss://$BUCKET/$RemoteKey"

    $method = Get-UploadMethod -Provider "aliyun"

    switch ($method) {
        "ossutil"    { _Upload-Ossutil -LocalFile $LocalFile -RemoteKey $RemoteKey }
        "oss-python" { _Upload-OssPy -LocalFile $LocalFile -RemoteKey $RemoteKey }
        "curl-sign"  { _Upload-Curl -LocalFile $LocalFile -RemoteKey $RemoteKey }
        default      { Write-Error "无可用上传方式"; exit 1 }
    }
}

function _Upload-Ossutil {
    param([string]$LocalFile, [string]$RemoteKey)

    $cfg = [System.IO.Path]::GetTempFileName() + ".cfg"
    @"
[Credentials]
accessKeyID=$ACCESS_KEY
accessKeySecret=$SECRET_KEY
[Bucket]
endpoint=$ENDPOINT
bucket=$BUCKET
"@ | Out-File -FilePath $cfg -Encoding ASCII

    try {
        $args = @("cp", $LocalFile, "oss://$BUCKET/$RemoteKey", "--config-file", $cfg)
        if ($Quiet) { $args += "-q" }
        & ossutil @args 2>&1 | ForEach-Object { if (-not $Quiet) { Write-Host $_ } }
        if ($LASTEXITCODE -eq 0) { _Generate-Url -RemoteKey $RemoteKey }
    } finally {
        Remove-Item $cfg -Force -ErrorAction SilentlyContinue
    }
}

function _Upload-OssPy {
    param([string]$LocalFile, [string]$RemoteKey)

    $py = @"
import oss2, sys
lf='$LocalFile'; rk='$RemoteKey'; ep='$ENDPOINT'; bk='$BUCKET'
ak='$ACCESS_KEY'; sk='$SECRET_KEY'; q='$Quiet'
auth=oss2.Auth(ak,sk)
bucket=oss2.Bucket(auth,f'https://{ep}',bk)
def pg(c,t):
    if t and q=='false': print(f'\r进度:{int(100*c/t)}%',end='',flush=True)
if q=='false': r=bucket.put_object_from_file(rk,lf,progress_callback=pg); print()
else: r=bucket.put_object_from_file(rk,lf)
if r.status==200:
    print('✓ 上传成功')
    print(f'URL: https://{bk}.{ep}/{rk}')
else:
    print(f'错误: HTTP {r.status}',file=sys.stderr); sys.exit(1)
"@
    python -c $py
    if ($LASTEXITCODE -ne 0) { exit 1 }
    _Generate-Url -RemoteKey $RemoteKey
}

function _Upload-Curl {
    param([string]$LocalFile, [string]$RemoteKey)

    $url = "https://$BUCKET.$ENDPOINT/$RemoteKey"
    $dateGmt = [System.DateTime]::UtcNow.ToString('ddd, dd MMM yyyy HH:mm:ss GMT', [System.Globalization.CultureInfo]::InvariantCulture)

    $sig = [Convert]::ToBase64String(
        [System.Security.Cryptography.HMACSHA1]::new().ComputeHash(
            [System.Text.Encoding]::UTF8.GetBytes($SECRET_KEY)
        )
    )

    $cmd = "curl -T `"$LocalFile`" `"$url`" -H `"Date: $dateGmt`" -H `"Content-Type: application/octet-stream`" -H `"Authorization: OSS $ACCESS_KEY`""
    Invoke-Expression $cmd
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ 上传成功"
        Write-Host "URL: https://$BUCKET.$ENDPOINT/$RemoteKey"
    }
}

function _Generate-Url {
    param([string]$RemoteKey)
    Write-Host ""
    Write-Host "✓ 上传成功" -ForegroundColor Green
    Write-Host "URL: https://$BUCKET.$ENDPOINT/$RemoteKey"
}
