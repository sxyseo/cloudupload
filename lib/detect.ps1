# detect.ps1 - 工具依赖检测 (Windows PowerShell)

$script:TOOL_CURL = $false
$script:TOOL_PYTHON3 = $false
$script:TOOL_AWS = $false
$script:TOOL_OSSUTIL = $false
$script:TOOL_OSS_PY = $false
$script:TOOL_COSCLI = $false
$script:TOOL_COS_PY = $false
$script:TOOL_BOSCLI = $false
$script:TOOL_BOS_PY = $false
$script:TOOL_OBSCLI = $false
$script:TOOL_OBS_PY = $false
$script:TOOL_GSUTIL = $false
$script:TOOL_GCP_PY = $false
$script:TOOL_AZCLI = $false
$script:TOOL_AZURE_PY = $false
$script:TOOL_BOTO3 = $false

function Get-CdpTool {
    param([string]$Name, [string]$Command)
    $found = Get-Command $Command -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "检测到: $Name" -ForegroundColor Green
        return $true
    }
    return $false
}

function Invoke-ToolDetect {
    param([string]$Provider)

    Write-Host "=== 工具检测 ===" -ForegroundColor Cyan

    # 通用工具
    if (Get-CdpTool "curl" "curl") { $script:TOOL_CURL = $true }
    if (Get-CdpTool "Python 3" "python3") { $script:TOOL_PYTHON3 = $true }
    elseif (Get-CdpTool "Python" "python") { $script:TOOL_PYTHON3 = $true }

    # AWS / MinIO
    if ($Provider -eq "aws" -or $Provider -eq "minio") {
        if (Get-CdpTool "AWS CLI" "aws") { $script:TOOL_AWS = $true }
        if ($TOOL_PYTHON3) {
            $py = python -c "import boto3" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $script:TOOL_BOTO3 = $true
                Write-Host "检测到: boto3 (Python)" -ForegroundColor Green
            }
        }
    }

    # 阿里云 OSS
    if ($Provider -eq "aliyun") {
        if (Get-CdpTool "ossutil" "ossutil") { $script:TOOL_OSSUTIL = $true }
        if ($TOOL_PYTHON3) {
            $py = python -c "import oss2" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $script:TOOL_OSS_PY = $true
                Write-Host "检测到: oss2 (Python)" -ForegroundColor Green
            }
        }
    }

    # 腾讯云 COS
    if ($Provider -eq "tencent") {
        if (Get-CdpTool "coscli" "coscli") { $script:TOOL_COSCLI = $true }
        if ($TOOL_PYTHON3) {
            $py = python -c "import qcloud_cos" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $script:TOOL_COS_PY = $true
                Write-Host "检测到: qcloud_cos (Python)" -ForegroundColor Green
            }
        }
    }

    # 百度云 BOS
    if ($Provider -eq "baidu") {
        if (Get-CdpTool "boscli" "boscli") { $script:TOOL_BOSCLI = $true }
        if ($TOOL_PYTHON3) {
            $py = python -c "import baidubce" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $script:TOOL_BOS_PY = $true
                Write-Host "检测到: baidubce (Python)" -ForegroundColor Green
            }
        }
    }

    # 华为云 OBS
    if ($Provider -eq "huawei") {
        if (Get-CdpTool "obsutil" "obsutil") { $script:TOOL_OBSCLI = $true }
        if ($TOOL_PYTHON3) {
            $py = python -c "import obs" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $script:TOOL_OBS_PY = $true
                Write-Host "检测到: obs (Python)" -ForegroundColor Green
            }
        }
    }

    # GCP
    if ($Provider -eq "gcp") {
        if (Get-CdpTool "gsutil" "gsutil") { $script:TOOL_GSUTIL = $true }
        if (Get-CdpTool "gcloud" "gcloud") { $script:TOOL_GCLOUD = $true }
        if ($TOOL_PYTHON3) {
            $py = python -c "import google.cloud.storage" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $script:TOOL_GCP_PY = $true
                Write-Host "检测到: google-cloud-storage (Python)" -ForegroundColor Green
            }
        }
    }

    # Azure
    if ($Provider -eq "azure") {
        if (Get-CdpTool "Azure CLI" "az") { $script:TOOL_AZCLI = $true }
        if ($TOOL_PYTHON3) {
            $py = python -c "import azure.storage.blob" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $script:TOOL_AZURE_PY = $true
                Write-Host "检测到: azure-storage-blob (Python)" -ForegroundColor Green
            }
        }
    }

    Write-Host ""
}

function Get-UploadMethod {
    param([string]$Provider)
    switch ($Provider) {
        "aws" {
            if ($TOOL_AWS) { return "aws-cli" }
            if ($TOOL_BOTO3) { return "boto3" }
            if ($TOOL_CURL) { return "curl" }
        }
        "minio" {
            if ($TOOL_AWS) { return "aws-cli" }
            if ($TOOL_BOTO3) { return "boto3" }
            if ($TOOL_CURL) { return "curl" }
        }
        "aliyun" {
            if ($TOOL_OSSUTIL) { return "ossutil" }
            if ($TOOL_OSS_PY) { return "oss-python" }
            if ($TOOL_CURL -and $TOOL_PYTHON3) { return "curl-sign" }
        }
        "tencent" {
            if ($TOOL_COSCLI) { return "coscli" }
            if ($TOOL_COS_PY) { return "cos-python" }
            if ($TOOL_CURL -and $TOOL_PYTHON3) { return "curl-sign" }
        }
        "baidu" {
            if ($TOOL_BOSCLI) { return "boscli" }
            if ($TOOL_BOS_PY) { return "bos-python" }
            if ($TOOL_CURL -and $TOOL_PYTHON3) { return "curl-sign" }
        }
        "huawei" {
            if ($TOOL_OBSCLI) { return "obsutil" }
            if ($TOOL_OBS_PY) { return "obs-python" }
            if ($TOOL_CURL -and $TOOL_PYTHON3) { return "curl-sign" }
        }
        "gcp" {
            if ($TOOL_GSUTIL) { return "gsutil" }
            if ($TOOL_GCP_PY) { return "gcp-python" }
            if ($TOOL_CURL -and $TOOL_PYTHON3) { return "curl-jwt" }
        }
        "azure" {
            if ($TOOL_AZCLI) { return "az-cli" }
            if ($TOOL_AZURE_PY) { return "azure-python" }
            if ($TOOL_CURL) { return "curl-sas" }
        }
    }
    return "none"
}

function Test-UploadAvailable {
    param([string]$Provider)
    $method = Get-UploadMethod -Provider $Provider
    if ($method -eq "none") {
        Write-Error "没有可用的上传工具，请安装 Python SDK 或对应 CLI 工具"
        return $false
    }
    Write-Host "将使用: $method"
    return $true
}
