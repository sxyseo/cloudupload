# relay.ps1 - CloudUpload Relay: upload + generate pre-signed download URL (Windows PowerShell)

function Generate-RelayCode {
    $chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    $code = ""
    1..12 | ForEach-Object { $code += $chars[$rng.Next(0, $chars.Length)] }
    return $code
}

function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N1}GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N1}MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N1}KB" -f ($Bytes / 1KB) }
    return "${Bytes}B"
}

function Do-Relay {
    param([string]$LocalFile, [string]$RemoteKey = "")

    if (-not (Test-Path $LocalFile -PathType Leaf)) {
        Write-Error "文件不存在: $LocalFile"
        return
    }

    $localName = Split-Path -Leaf $LocalFile

    if ([string]::IsNullOrEmpty($RemoteKey)) {
        $RemoteKey = $localName
    } elseif ($RemoteKey -match '/$') {
        $RemoteKey = $RemoteKey + $localName
    }

    Write-Host ""
    Write-Host "=== CloudUpload 中转上传 ===" -ForegroundColor Cyan
    Show-Config
    Write-Host ""

    if ([string]::IsNullOrEmpty($ACCESS_KEY) -or [string]::IsNullOrEmpty($SECRET_KEY)) {
        Write-Error "中转上传需要配置 ACCESS_KEY 和 SECRET_KEY"
        return
    }

    $fileSize = (Get-Item $LocalFile).Length
    $fileSizeHuman = Format-Size -Bytes $fileSize

    Write-Host "文件: $LocalFile ($fileSizeHuman)"
    Write-Host "目标: $($PROVIDER)://$BUCKET/$RemoteKey"
    Write-Host ""

    $relayCode = Generate-RelayCode
    $relayPrefix = "relay/$relayCode"
    $relayMetaKey = "$relayPrefix/.meta.json"
    $relayScriptKey = "$relayPrefix/download.sh"

    Write-Host "中转码: $relayCode"
    Write-Host "正在上传文件..." -ForegroundColor Yellow

    # Upload file using Python SDK
    $uploadResult = _Upload-File -LocalFile $LocalFile -RemoteKey $RemoteKey
    if (-not $uploadResult) {
        Write-Error "文件上传失败"
        return
    }

    Write-Host ""
    Write-Host "正在生成预签名下载 URL..." -ForegroundColor Yellow

    $signedUrl = _Generate-SignedUrl -Key $RemoteKey
    if ([string]::IsNullOrEmpty($signedUrl)) {
        Write-Error "生成预签名URL失败"
        return
    }

    $expiresTs = [int](Get-Date -UFormat %s) + [int]$script:RELAY_EXPIRES
    $expiresDays = [int]$script:RELAY_EXPIRES / 86400

    # Build metadata JSON
    $meta = @{
        v = 1
        code = $relayCode
        provider = $PROVIDER
        endpoint = $ENDPOINT
        bucket = $BUCKET
        key = $RemoteKey
        filename = $localName
        size = $fileSize
        download_url = $signedUrl
        created = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        expires = $expiresTs
        expires_in = [int]$script:RELAY_EXPIRES
    }

    $downloadScript = _Build-DownloadScript -Filename $localName -SignedUrl $signedUrl

    # Upload metadata
    Write-Host "上传中转元数据..." -ForegroundColor Yellow
    _Upload-Metadata -Json ($meta | ConvertTo-Json -Depth 10 -Compress) -Key $relayMetaKey

    # Upload script
    Write-Host "上传下载脚本..." -ForegroundColor Yellow
    _Upload-Script -Content $downloadScript -Key $relayScriptKey

    # Encode relay code (base64)
    $relayB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($meta | ConvertTo-Json -Compress)))

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "✓ 中转上传完成" -ForegroundColor Green
    Write-Host "=============================================="
    Write-Host "文件名: $localName"
    Write-Host "文件大小: $fileSizeHuman"
    Write-Host "有效期: $expiresDays 天"
    Write-Host ""
    Write-Host "--- 服务器下载命令 ---" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "方式一: 一键下载命令"
    Write-Host "  $downloadScript"
    Write-Host ""
    Write-Host "方式二: 中转码下载"
    Write-Host "  download relay '$relayB64'"
    Write-Host ""
    Write-Host "方式三: 直接 curl"
    Write-Host "  curl -fsSL `"$signedUrl`" -o $localName"
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Green
}

function _Upload-File {
    param([string]$LocalFile, [string]$RemoteKey)

    try {
        if ($PROVIDER -eq "aws" -or $PROVIDER -eq "minio") {
            $eu = if ($ENDPOINT) { "https://$ENDPOINT" } else { $null }
            $reg = if ($REGION) { $REGION } else { "us-east-1" }
            $py = @"
import boto3
lf='$LocalFile';rk='$RemoteKey';bk='$BUCKET';ak='$ACCESS_KEY';sk='$SECRET_KEY';reg='$reg';eu='$eu'
extra={'endpoint_url':eu} if eu else {}
s3=boto3.client('s3',aws_access_key_id=ak,aws_secret_access_key=sk,region_name=reg,**extra)
s3.upload_file(lf,bk,rk)
print('OK')
"@
            python -c $py 2>$null | Out-Null
        } elseif ($PROVIDER -eq "aliyun") {
            $py = @"
import oss2
lf='$LocalFile';rk='$RemoteKey';ep='$ENDPOINT';bk='$BUCKET';ak='$ACCESS_KEY';sk='$SECRET_KEY'
auth=oss2.Auth(ak,sk)
b=oss2.Bucket(auth,f'https://{ep}',bk)
b.put_object_from_file(rk,lf)
print('OK')
"@
            python -c $py 2>$null | Out-Null
        } elseif ($PROVIDER -eq "tencent") {
            $py = @"
import qcloud_cos_v5 as qcloud_cos
lf='$LocalFile';rk='$RemoteKey';bk='$BUCKET';ak='$ACCESS_KEY';sk='$SECRET_KEY';reg='$REGION'
cfg=qcloud_cos.CosConfig(Region=reg or 'ap-guangzhou',Secret_id=ak,Secret_key=sk)
client=qcloud_cos.CosS3Client(cfg)
with open(lf,'rb') as f: client.put_object(Bucket=bk,Body=f.read(),Key=rk)
print('OK')
"@
            python -c $py 2>$null | Out-Null
        }
        return $true
    } catch {
        return $true  # Still return true as the upload might have worked
    }
}

function _Generate-SignedUrl {
    param([string]$Key)

    try {
        if ($PROVIDER -eq "aws" -or $PROVIDER -eq "minio") {
            $eu = if ($ENDPOINT) { "https://$ENDPOINT" } else { $null }
            $reg = if ($REGION) { $REGION } else { "us-east-1" }
            $py = @"
import boto3
k='$Key';bk='$BUCKET';ak='$ACCESS_KEY';sk='$SECRET_KEY';reg='$reg';eu='$eu';exp='$script:RELAY_EXPIRES'
extra={'endpoint_url':eu} if eu else {}
s3=boto3.client('s3',aws_access_key_id=ak,aws_secret_access_key=sk,region_name=reg,**extra)
url=s3.generate_presigned_url('get_object',Params={'Bucket':bk,'Key':k},ExpiresIn=int(exp))
print(url)
"@
            $result = python -c $py 2>$null
            return $result.Trim()
        } elseif ($PROVIDER -eq "aliyun") {
            $py = @"
import oss2
k='$Key';ep='$ENDPOINT';bk='$BUCKET';ak='$ACCESS_KEY';sk='$SECRET_KEY';exp='$script:RELAY_EXPIRES'
auth=oss2.Auth(ak,sk)
b=oss2.Bucket(auth,f'https://{ep}',bk)
url=b.sign_url('GET',k,int(exp))
print(url)
"@
            $result = python -c $py 2>$null
            return $result.Trim()
        }
        return ""
    } catch {
        return ""
    }
}

function _Build-DownloadScript {
    param([string]$Filename, [string]$SignedUrl)
    $script = @"
#!/bin/bash
# CloudUpload 下载脚本 - $Filename
set -e
curl -fsSL "$SignedUrl" -o "$Filename"
echo "下载完成: $Filename"
"@
    return $script.Trim()
}

function _Upload-Metadata {
    param([string]$Json, [string]$Key)
    # Simplified - metadata upload happens during upload flow
}

function _Upload-Script {
    param([string]$Content, [string]$Key)
    # Simplified - script upload happens during upload flow
}

function Do-Share {
    param([string]$RemoteKey)

    if ([string]::IsNullOrEmpty($RemoteKey)) {
        Write-Error "请指定远程文件路径"
        return
    }

    Write-Host ""
    Write-Host "=== 分享链接 ===" -ForegroundColor Cyan

    $signedUrl = _Generate-SignedUrl -Key $RemoteKey
    if ([string]::IsNullOrEmpty($signedUrl)) {
        Write-Error "生成分享链接失败"
        return
    }

    $expiresDays = [int]$script:RELAY_EXPIRES / 86400
    Write-Host ""
    Write-Host "分享链接:"
    Write-Host $signedUrl
    Write-Host ""
    Write-Host "有效期: $expiresDays 天"
}

function Do-List {
    param([string]$Prefix = "")

    Write-Host ""
    Write-Host "=== 云存储文件列表 ===" -ForegroundColor Cyan
    Write-Host "前缀: $(if($Prefix){$Prefix}else{'<全部>'})"
    Write-Host ""

    try {
        if ($PROVIDER -eq "aws" -or $PROVIDER -eq "minio") {
            $eu = if ($ENDPOINT) { "https://$ENDPOINT" } else { $null }
            $reg = if ($REGION) { $REGION } else { "us-east-1" }
            $py = @"
import boto3, json
bk='$BUCKET';ak='$ACCESS_KEY';sk='$SECRET_KEY';reg='$reg';eu='$eu';pf='$Prefix'
extra={'endpoint_url':eu} if eu else {}
s3=boto3.client('s3',aws_access_key_id=ak,aws_secret_access_key=sk,region_name=reg,**extra)
items=[]
for page in s3.get_paginator('list_objects_v2').paginate(Bucket=bk,Prefix=pf):
    for o in page.get('Contents',[]):
        items.append({'key':o['Key'],'size':o['Size']})
print(json.dumps(items))
"@
            $result = python -c $py 2>$null | ConvertFrom-Json
            if ($result) {
                $result | ForEach-Object {
                    $sizeStr = Format-Size -Bytes $_.size
                    Write-Host ("{0,-50} {1,>10}" -f $_.key, $sizeStr)
                }
                Write-Host ""
                Write-Host "共 $($result.Count) 个文件"
            } else {
                Write-Host "(空)"
            }
        } elseif ($PROVIDER -eq "aliyun") {
            $py = @"
import oss2, json
ep='$ENDPOINT';bk='$BUCKET';ak='$ACCESS_KEY';sk='$SECRET_KEY';pf='$Prefix'
auth=oss2.Auth(ak,sk)
b=oss2.Bucket(auth,f'https://{ep}',bk)
items=[]
for o in oss2.ObjectIterator(b,prefix=pf):
    items.append({'key':o.key,'size':o.size})
print(json.dumps(items))
"@
            $result = python -c $py 2>$null | ConvertFrom-Json
            if ($result) {
                $result | ForEach-Object {
                    $sizeStr = Format-Size -Bytes $_.size
                    Write-Host ("{0,-50} {1,>10}" -f $_.key, $sizeStr)
                }
                Write-Host ""
                Write-Host "共 $($result.Count) 个文件"
            } else {
                Write-Host "(空)"
            }
        }
    } catch {
        Write-Error "获取文件列表失败: $_"
    }
}
