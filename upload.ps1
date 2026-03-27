# upload.ps1 - CloudUpload: one command to upload to any cloud storage (Windows PowerShell)
# Supports: AWS S3, Alibaba Cloud OSS, Tencent Cloud COS, Baidu Cloud BOS,
#           Huawei Cloud OBS, Google Cloud GCS, Azure Blob, MinIO

param(
    [string]$File,
    [string]$Profile,
    [string]$RemoteKey,
    [switch]$Quiet,
    [switch]$List,
    [switch]$Show,
    [switch]$Help,
    [switch]$Providers,
    [string]$Lang = ""
)

$ErrorActionPreference = "Stop"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# Initialize i18n
. "$SCRIPT_DIR\i18n\i18n.ps1"
Initialize-I18n -Lang $Lang

. "$SCRIPT_DIR\config.ps1"
. "$SCRIPT_DIR\lib\detect.ps1"

function Show-Help {
    $lang = $script:I18N_LANG
    if ($lang -eq "zh") {
        Write-Host @"
CloudUpload - 一键上传文件到任意云存储

用法:
    .\upload.ps1 <文件> [profile] [远程路径]   上传文件
    .\upload.ps1 -List                        列出所有 profile
    .\upload.ps1 -Show [profile]               显示配置信息
    .\upload.ps1 -Providers                   显示支持的云厂商
    .\upload.ps1 -Lang <en|zh>               设置语言
    .\upload.ps1 -Help                        显示帮助

示例:
    .\upload.ps1 myfile.tar.gz                  使用默认 profile
    .\upload.ps1 myfile.tar.gz aliyun-oss       指定 profile
    .\upload.ps1 myfile.tar.gz s3 backup/      上传到备份目录
    .\upload.ps1 myfile.tar.gz -Quiet           静默模式，只输出 URL
    .\upload.ps1 -Lang zh -List                 显示中文 profile 列表

配置: $HOME\.uploadrc
"@
    } else {
        Write-Host @"
CloudUpload - One command to upload files to any cloud storage

Usage:
    .\upload.ps1 <file> [profile] [remote_path]   Upload file
    .\upload.ps1 -List                             List all profiles
    .\upload.ps1 -Show [profile]                  Show config
    .\upload.ps1 -Providers                       Show supported providers
    .\upload.ps1 -Lang <en|zh>                    Set language
    .\upload.ps1 -Help                            Show this help

Examples:
    .\upload.ps1 myfile.tar.gz                     Default profile
    .\upload.ps1 myfile.tar.gz aliyun-oss         Specify profile
    .\upload.ps1 myfile.tar.gz s3 backup/        Upload to directory
    .\upload.ps1 myfile.tar.gz -Quiet             Quiet mode, URL only

Config: $HOME\.uploadrc
"@
    }
}

# Main logic
if ($List) {
    $lang = $script:I18N_LANG
    Write-Host "Available profiles:"
    List-Profiles
    Write-Host ""
    List-Providers
    exit 0
}

if ($Providers) {
    List-Providers
    exit 0
}

if ($Show) {
    if (-not (Load-Config -Profile $Profile)) { exit 1 }
    Show-Config
    exit 0
}

if ($Help) {
    Show-Help
    exit 0
}

if ([string]::IsNullOrEmpty($File)) {
    Show-Help
    exit 1
}

# Resolve file path
$File = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($File)

if (-not (Test-Path $File -PathType Leaf)) {
    Write-Error "文件不存在: $File"
    exit 1
}

$LocalFile = $File
$LocalName = Split-Path -Leaf $File

# Resolve remote key
if ([string]::IsNullOrEmpty($RemoteKey)) {
    $RemoteKey = $LocalName
} elseif ($RemoteKey -match '/$') {
    $RemoteKey = $RemoteKey + $LocalName
}

# Load config
if (-not (Load-Config -Profile $Profile)) { exit 1 }

if (-not $Quiet) {
    Write-Host "=== CloudUpload ===" -ForegroundColor Cyan
    Show-Config
}

# Detect tools
Invoke-ToolDetect -Provider $PROVIDER

if (-not (Test-UploadAvailable -Provider $PROVIDER)) { exit 1 }

if (-not $Quiet) { Write-Host "" }

# Route
switch ($PROVIDER) {
    "aws"    { . "$SCRIPT_DIR\lib\aws.ps1";     Do-Upload -LocalFile $LocalFile -RemoteKey $RemoteKey }
    "minio"  { . "$SCRIPT_DIR\lib\aws.ps1";     Do-Upload -LocalFile $LocalFile -RemoteKey $RemoteKey }
    "aliyun" { . "$SCRIPT_DIR\lib\aliyun.ps1";  Do-Upload -LocalFile $LocalFile -RemoteKey $RemoteKey }
    "tencent"{ . "$SCRIPT_DIR\lib\tencent.ps1"; Do-Upload -LocalFile $LocalFile -RemoteKey $RemoteKey }
    "baidu"  { . "$SCRIPT_DIR\lib\baidu.ps1";   Do-Upload -LocalFile $LocalFile -RemoteKey $RemoteKey }
    "huawei" { . "$SCRIPT_DIR\lib\huawei.ps1";  Do-Upload -LocalFile $LocalFile -RemoteKey $RemoteKey }
    "gcp"    { . "$SCRIPT_DIR\lib\gcp.ps1";    Do-Upload -LocalFile $LocalFile -RemoteKey $RemoteKey }
    "azure"  { . "$SCRIPT_DIR\lib\azure.ps1";   Do-Upload -LocalFile $LocalFile -RemoteKey $RemoteKey }
    default  {
        Write-Error "不支持的 provider: $PROVIDER"
        exit 1
    }
}
