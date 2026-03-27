# config.ps1 - 配置加载 (Windows PowerShell)
# 支持: aws, aliyun, tencent, baidu, huawei, gcp, azure, minio

$UPLOAD_CONFIG_FILE = if ($env:UPLOAD_CONFIG_FILE) { $env:UPLOAD_CONFIG_FILE } else { "$HOME\.uploadrc" }

function Load-Config {
    param([string]$Profile = "")

    if (-not (Test-Path $UPLOAD_CONFIG_FILE)) {
        Write-Error "配置文件不存在: $UPLOAD_CONFIG_FILE"
        Write-Host "提示: 请复制 config.example 到 $HOME\.uploadrc 并填入配置" -ForegroundColor Yellow
        return $false
    }

    # 获取默认 profile
    if ([string]::IsNullOrEmpty($Profile)) {
        $line = Select-String -Path $UPLOAD_CONFIG_FILE -Pattern '^\s*export\s+UPLOAD_DEFAULT=' | Select-Object -First 1
        if ($line) {
            $Profile = $line.Line -replace '.*=\s*', '' -replace '["'\''']', ''
        }
        if ([string]::IsNullOrEmpty($Profile)) { $Profile = "default" }
    }

    # 提取配置
    $script:PROVIDER    = _get $Profile "PROVIDER"
    $script:ENDPOINT    = _get $Profile "ENDPOINT"
    $script:BUCKET      = _get $Profile "BUCKET"
    $script:ACCESS_KEY  = _get $Profile "ACCESS_KEY"
    $script:SECRET_KEY  = _get $Profile "SECRET_KEY"
    $script:REGION      = _get $Profile "REGION"
    $script:URL_STYLE   = _get $Profile "URL_STYLE"
    $script:ACCOUNT     = _get $Profile "ACCOUNT"

    if ([string]::IsNullOrEmpty($PROVIDER) -and [string]::IsNullOrEmpty($ENDPOINT) -and [string]::IsNullOrEmpty($BUCKET)) {
        Write-Error "Profile '$Profile' 在配置文件中未找到"
        return $false
    }

    # 标准化 provider
    Normalize-Provider

    # 标准化 endpoint
    $script:ENDPOINT = $ENDPOINT -replace '^https?://', '' -replace '/+$', ''
    $script:URL_STYLE = if ([string]::IsNullOrEmpty($URL_STYLE)) { "virtual" } else { $URL_STYLE }

    $script:CURRENT_PROFILE = $Profile
    return $true
}

function _get {
    param([string]$Profile, [string]$Key)
    $pattern = "^\s*export\s+${Profile}_${Key}="
    $line = Select-String -Path $UPLOAD_CONFIG_FILE -Pattern $pattern | Select-Object -First 1
    if ($line) {
        return $line.Line -replace ".*=\s*", '' -replace '["'\''']', ''
    }
    return ""
}

function Normalize-Provider {
    $p = $PROVIDER.ToLower()
    switch ($p) {
        "s3" { $script:PROVIDER = "aws" }
        "oss" { $script:PROVIDER = "aliyun" }
        "aliyuncs" { $script:PROVIDER = "aliyun" }
        "cos" { $script:PROVIDER = "tencent" }
        "tencentcloud" { $script:PROVIDER = "tencent" }
        "bos" { $script:PROVIDER = "baidu" }
        "baiduyun" { $script:PROVIDER = "baidu" }
        "obs" { $script:PROVIDER = "huawei" }
        "huaweicloud" { $script:PROVIDER = "huawei" }
        "gcs" { $script:PROVIDER = "gcp" }
        "googlecloud" { $script:PROVIDER = "gcp" }
        "azure" { $script:PROVIDER = "azure" }
        "azureblob" { $script:PROVIDER = "azure" }
        "minio" { $script:PROVIDER = "minio" }
        "" {
            if ($ENDPOINT -match "aliyuncs\.com" -or $ENDPOINT -match "oss-") { $script:PROVIDER = "aliyun" }
            elseif ($ENDPOINT -match "myqcloud\.com" -or $ENDPOINT -match "cos\.") { $script:PROVIDER = "tencent" }
            elseif ($ENDPOINT -match "bcebos\.com") { $script:PROVIDER = "baidu" }
            elseif ($ENDPOINT -match "myhuaweicloud\.com" -or $ENDPOINT -match "obs\.") { $script:PROVIDER = "huawei" }
            elseif ($ENDPOINT -match "storage\.googleapis\.com") { $script:PROVIDER = "gcp" }
            elseif ($ENDPOINT -match "blob\.core\.windows\.net") { $script:PROVIDER = "azure" }
            elseif ($ENDPOINT -match "min\.io") { $script:PROVIDER = "minio" }
            else { $script:PROVIDER = "aws" }
        }
        default {
            Write-Warning "未知 provider '$PROVIDER'，将作为 S3 兼容存储处理"
            $script:PROVIDER = "aws"
        }
    }
}

function List-Profiles {
    if (-not (Test-Path $UPLOAD_CONFIG_FILE)) { return }
    Select-String -Path $UPLOAD_CONFIG_FILE -Pattern '^\s*export\s+[a-zA-Z0-9_-]+_(PROVIDER|ENDPOINT)=' |
        ForEach-Object { $_.Line -replace '.*export\s+([a-zA-Z0-9_-]*)_[A-Z].*', '$1' } |
        Sort-Object -Unique
}

function Show-Config {
    Write-Host "Profile:      $CURRENT_PROFILE"
    Write-Host "Provider:     $($PROVIDER ? $PROVIDER : '<未设置>')"
    Write-Host "Endpoint:     $($ENDPOINT ? $ENDPOINT : '<未设置>')"
    Write-Host "Bucket:       $($BUCKET ? $BUCKET : '<未设置>')"
    Write-Host "Region:       $($REGION ? $REGION : '<未设置>')"
    Write-Host "URL Style:    $URL_STYLE"
    Write-Host "Account:      $($ACCOUNT ? $ACCOUNT : '<未设置>')"
    Write-Host "Access Key:   $(if($ACCESS_KEY){'<已设置>'}else{'<未设置>'})"
    Write-Host "Secret Key:   $(if($SECRET_KEY){'<已设置>'}else{'<未设置>'})"
}

function List-Providers {
    Write-Host "支持的云厂商:"
    Write-Host "  aws      - AWS S3 / 兼容存储"
    Write-Host "  aliyun   - 阿里云 OSS"
    Write-Host "  tencent  - 腾讯云 COS"
    Write-Host "  baidu    - 百度云 BOS"
    Write-Host "  huawei   - 华为云 OBS"
    Write-Host "  gcp      - 谷歌云 GCS"
    Write-Host "  azure    - Azure Blob Storage"
    Write-Host "  minio    - MinIO / S3 兼容存储"
}
