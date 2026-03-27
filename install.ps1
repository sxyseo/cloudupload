# CloudUpload One-Line Installer for Windows PowerShell
# Usage: irm https://raw.githubusercontent.com/sxyseo/cloudupload/main/install.ps1 | iex
# Or:    powershell -Command "irm https://.../install.ps1 | iex"

$ErrorActionPreference = "Stop"
$REPO = "sxyseo/cloudupload"
$INSTALL_DIR = "$env:LOCALAPPDATA\CloudUpload"
$PROFILE_DIR = $PROFILE -replace '\\[^\\]+$', ''

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  CloudUpload Installer" -ForegroundColor Cyan
Write-Host "  Cross-platform object storage CLI" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Installing to: $INSTALL_DIR" -ForegroundColor Gray

# Download all files from GitHub
$BASE = "https://raw.githubusercontent.com/$REPO/main"

$files = @(
    "upload.ps1",
    "config.ps1",
    "install.ps1"
)

$libFiles = @(
    "lib/detect.ps1",
    "lib/aws.ps1",
    "lib/aliyun.ps1",
    "lib/tencent.ps1",
    "lib/baidu.ps1",
    "lib/huawei.ps1",
    "lib/gcp.ps1",
    "lib/azure.ps1",
    "lib/minio.ps1"
)

$i18nFiles = @(
    "i18n/i18n.ps1"
)

# Download main files
foreach ($f in $files) {
    $url = "$BASE/$f"
    $out = Join-Path $INSTALL_DIR $f
    $dir = Split-Path $out -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Write-Host "Downloading $f..." -ForegroundColor Yellow
    try {
        Invoke-RestMethod $url -OutFile $out -ErrorAction Stop
    } catch {
        Write-Host "Failed to download $f, trying master branch..." -ForegroundColor Yellow
        $url = $url -replace '/main/', '/master/'
        Invoke-RestMethod $url -OutFile $out -ErrorAction Stop
    }
}

# Download lib files
$libDir = Join-Path $INSTALL_DIR "lib"
New-Item -ItemType Directory -Path $libDir -Force | Out-Null
foreach ($f in $libFiles) {
    $url = "$BASE/$f"
    $out = Join-Path $INSTALL_DIR $f
    $dir = Split-Path $out -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Write-Host "Downloading $f..." -ForegroundColor Yellow
    try {
        Invoke-RestMethod $url -OutFile $out -ErrorAction Stop
    } catch {
        $url = $url -replace '/main/', '/master/'
        Invoke-RestMethod $url -OutFile $out -ErrorAction Stop
    }
}

# Download i18n
$i18nDir = Join-Path $INSTALL_DIR "i18n"
New-Item -ItemType Directory -Path $i18nDir -Force | Out-Null
foreach ($f in $i18nFiles) {
    $url = "$BASE/$f"
    $out = Join-Path $INSTALL_DIR $f
    Write-Host "Downloading $f..." -ForegroundColor Yellow
    try {
        Invoke-RestMethod $url -OutFile $out -ErrorAction Stop
    } catch {
        $url = $url -replace '/main/', '/master/'
        Invoke-RestMethod $url -OutFile $out -ErrorAction Stop
    }
}

# Download config.example
$configExample = Join-Path $INSTALL_DIR "config.example"
try {
    Invoke-RestMethod "$BASE/config.example" -OutFile $configExample -ErrorAction Stop
} catch {
    Invoke-RestMethod "$($BASE -replace '/main/', '/master/')/config.example" -OutFile $configExample -ErrorAction Stop
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "  powershell -File $INSTALL_DIR\upload.ps1 myfile.txt"
Write-Host ""
Write-Host "Add to PATH for convenience:" -ForegroundColor Cyan
Write-Host "  \$PATH += ';$INSTALL_DIR'"
Write-Host ""
Write-Host "First time: copy config.example to \$HOME\.uploadrc and fill in credentials" -ForegroundColor Yellow
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "All done!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
