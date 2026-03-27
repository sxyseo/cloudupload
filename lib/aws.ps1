# aws.ps1 - AWS S3 / MinIO 上传 (Windows PowerShell)
# aws provider 和 minio provider 共用

function Do-Upload {
    param([string]$LocalFile, [string]$RemoteKey)

    Write-Host "文件: $LocalFile"
    Write-Host "目标: $($PROVIDER)://$BUCKET/$RemoteKey"

    $method = Get-UploadMethod -Provider $PROVIDER

    switch ($method) {
        "aws-cli"  { _Upload-AwsCli -LocalFile $LocalFile -RemoteKey $RemoteKey }
        "boto3"    { _Upload-Boto3 -LocalFile $LocalFile -RemoteKey $RemoteKey }
        "curl"     { _Upload-Curl -LocalFile $LocalFile -RemoteKey $RemoteKey }
        default    { Write-Error "无可用上传方式"; exit 1 }
    }
}

function _Upload-AwsCli {
    param([string]$LocalFile, [string]$RemoteKey)

    $env:AWS_ACCESS_KEY_ID = $ACCESS_KEY
    $env:AWS_SECRET_ACCESS_KEY = $SECRET_KEY
    $env:AWS_DEFAULT_REGION = if ($REGION) { $REGION } else { "us-east-1" }

    $extra = @()
    if ($ENDPOINT) {
        $extra += "--endpoint-url", "https://$ENDPOINT"
    }
    if ($URL_STYLE -eq "path") {
        $extra += "--addressing-style", "path"
    }
    if ($Quiet) {
        $extra += "--no-progress"
    }

    $dest = "s3://$BUCKET/$RemoteKey"
    $cmd = @("aws", "s3", "cp", $LocalFile, $dest) + $extra
    & @cmd 2>&1 | ForEach-Object { if (-not $Quiet) { Write-Host $_ } }
    if ($LASTEXITCODE -eq 0) {
        _Generate-Url -RemoteKey $RemoteKey
    }
}

function _Upload-Boto3 {
    param([string]$LocalFile, [string]$RemoteKey)

    $endpointUrl = if ($ENDPOINT) { "https://$ENDPOINT" } else { "" }
    $region = if ($REGION) { $REGION } else { "us-east-1" }

    $py = @"
import boto3
from botocore.config import Config
import sys

lf='$LocalFile'
rk='$RemoteKey'
ak='$ACCESS_KEY'
sk='$SECRET_KEY'
reg='$region'
bk='$BUCKET'
eu='$endpointUrl'
q='$Quiet'

extra={}
if eu: extra['endpoint_url']=eu
s3=boto3.client('s3',aws_access_key_id=ak,aws_secret_access_key=sk,region_name=reg,config=Config(signature_version='s3v4'),**extra)
def prog(c,t):
    if t and q=='false': print(f'\r进度:{int(100*c/t)}%',end='',flush=True)
if q=='false': s3.upload_file(lf,bk,rk,Callback=prog); print()
else: s3.upload_file(lf,bk,rk)
url=eu+('/'+bk+'/'+rk) if eu else f'https://{bk}.s3.{reg}.amazonaws.com/{rk}'
print(); print('✓ 上传成功'); print(f'URL: {url}')
"@

    python -c $py
    if ($LASTEXITCODE -ne 0) { exit 1 }
    _Generate-Url -RemoteKey $RemoteKey
}

function _Upload-Curl {
    param([string]$LocalFile, [string]$RemoteKey)

    if (-not $ACCESS_KEY -or -not $SECRET_KEY) {
        Write-Error "curl 上传需要配置 ACCESS_KEY 和 SECRET_KEY"
        exit 1
    }

    $url = if ($URL_STYLE -eq "path" -or -not $ENDPOINT) {
        "https://$($ENDPOINT ? $ENDPOINT : 's3.amazonaws.com')/$BUCKET/$RemoteKey"
    } else {
        "https://$BUCKET.$ENDPOINT/$RemoteKey"
    }

    Write-Host "URL: $url"
    $curlCmd = "curl -T `"$LocalFile`" `"$url`""
    Invoke-Expression $curlCmd
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ 上传成功"
    }
}

function _Generate-Url {
    param([string]$RemoteKey)
    if ($PROVIDER -eq "aws") {
        if ($ENDPOINT) {
            $url = "https://$BUCKET.$ENDPOINT/$RemoteKey"
        } else {
            $r = if ($REGION) { $REGION } else { "us-east-1" }
            $url = "https://$BUCKET.s3.$r.amazonaws.com/$RemoteKey"
        }
    } elseif ($PROVIDER -eq "minio") {
        $url = "https://$ENDPOINT/$BUCKET/$RemoteKey"
    }
    Write-Host ""
    Write-Host "✓ 上传成功" -ForegroundColor Green
    Write-Host "URL: $url"
}
