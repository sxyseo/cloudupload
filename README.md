# CloudUpload

[English](#english) | [中文](#中文)

---

## English

### One Command to Upload Files to Any Cloud Storage

A cross-platform CLI tool that uploads files to any object storage with a single command.
Supports AWS S3, Alibaba Cloud OSS, Tencent Cloud COS, Baidu Cloud BOS, Huawei Cloud OBS, Google Cloud GCS, Azure Blob Storage, and MinIO.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Linux/macOS/Windows](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-blue)]()
[![Shell: Bash + PowerShell](https://img.shields.io/badge/Shell-Bash%20%2B%20PowerShell-blue)]()

#### Supported Cloud Providers

| Provider | Cloud | CLI Tool | Python SDK |
|----------|-------|----------|------------|
| `aws` | AWS S3 | `awscli` | `boto3` |
| `aliyun` | Alibaba Cloud OSS | `ossutil` | `oss2` |
| `tencent` | Tencent Cloud COS | `coscli` | `qcloud_cos_v5` |
| `baidu` | Baidu Cloud BOS | `boscli` | `baidubce` |
| `huawei` | Huawei Cloud OBS | `obsutil` | `obs` |
| `gcp` | Google Cloud GCS | `gsutil` | `google-cloud-storage` |
| `azure` | Azure Blob Storage | `az` | `azure-storage-blob` |
| `minio` | MinIO / S3 Compatible | AWS CLI | `boto3` |

### Features

- **8 cloud providers** out of the box
- **Cross-platform**: Linux, macOS, Windows (PowerShell)
- **Zero dependency** (mostly) — works with just `curl` and `python3`
- **Multi-level fallback**: Official CLI → Python SDK → curl + signature
- **Progress bar** and **multipart upload** via native CLI tools
- **Multi-profile** configuration for switching between storage buckets instantly
- **Auto-detection** of cloud provider from endpoint
- **Quiet mode** (`-q`) for CI/CD integration
- **Internationalization**: English and Chinese

### Quick Start

#### 1. Install

**Linux / macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/sxyseo/cloudupload/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/sxyseo/cloudupload/main/install.ps1 | iex
```

**Manual:**
```bash
git clone https://github.com/sxyseo/cloudupload.git ~/cloudupload
echo 'export PATH="$PATH:$HOME/cloudupload"' >> ~/.bashrc
source ~/.bashrc
```

#### 2. Configure

Copy and edit the config file:

```bash
cp config.example ~/.uploadrc
chmod 600 ~/.uploadrc
nano ~/.uploadrc
```

Example `~/.uploadrc`:

```bash
# Default profile
export UPLOAD_DEFAULT="my-oss"

# Alibaba Cloud OSS
export my-oss_PROVIDER="aliyun"
export my-oss_ENDPOINT="oss-cn-hangzhou.aliyuncs.com"
export my-oss_BUCKET="my-bucket"
export my-oss_ACCESS_KEY="LTAI..."
export my-oss_SECRET_KEY="..."

# AWS S3
export my-s3_PROVIDER="aws"
export my-s3_REGION="us-east-1"
export my-s3_BUCKET="my-bucket"
export my-s3_ACCESS_KEY="AKIA..."
export my-s3_SECRET_KEY="..."
```

#### 3. Upload

```bash
# Default profile
upload myfile.tar.gz

# Specify profile
upload myfile.tar.gz my-oss

# Upload to a directory
upload myfile.tar.gz my-s3 backup/

# Quiet mode (outputs URL only, great for scripts)
upload myfile.tar.gz -q

# List all profiles
upload -l

# Show config
upload -s my-oss
```

#### Windows PowerShell

```powershell
.\upload.ps1 myfile.tar.gz my-oss
.\upload.ps1 myfile.tar.gz -Quiet
.\upload.ps1 -List
```

### Dependency Requirements

| Tool | Purpose | Required? |
|------|---------|-----------|
| `python3` | Signature generation, SDK fallback | Recommended |
| `curl` | HTTP requests | Recommended |
| `aws` (AWS CLI) | AWS S3 / MinIO upload | Recommended for S3 |
| `ossutil` | Alibaba Cloud OSS upload | Recommended for OSS |
| `coscli` | Tencent Cloud COS upload | Recommended for COS |
| `obsutil` | Huawei Cloud OBS upload | Recommended for OBS |
| `gsutil` | Google Cloud GCS upload | Recommended for GCS |
| `az` | Azure Blob upload | Recommended for Azure |

> **Note**: CloudUpload works without any CLI tools. If no official CLI is installed,
> it automatically falls back to Python SDK, or finally to `curl` with proper signatures.

### Project Structure

```
cloudupload/
├── upload                  # Linux/macOS main entry
├── upload.ps1             # Windows PowerShell entry
├── install.sh              # One-line installer (Unix)
├── install.ps1             # One-line installer (Windows)
├── config.sh              # Config loader (Unix)
├── config.ps1             # Config loader (Windows)
├── config.example         # Config template
├── i18n/
│   ├── i18n.sh            # i18n strings (Unix)
│   └── i18n.ps1           # i18n strings (Windows)
├── lib/
│   ├── detect.sh/.ps1     # Tool detection
│   ├── aws.sh/.ps1        # AWS S3 / MinIO
│   ├── aliyun.sh/.ps1     # Alibaba Cloud OSS
│   ├── tencent.sh/.ps1    # Tencent Cloud COS
│   ├── baidu.sh/.ps1      # Baidu Cloud BOS
│   ├── huawei.sh/.ps1     # Huawei Cloud OBS
│   ├── gcp.sh/.ps1        # Google Cloud GCS
│   ├── azure.sh/.ps1       # Azure Blob
│   └── minio.sh/.ps1      # MinIO
├── LICENSE
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
└── SECURITY.md
```

### Multi-Language Support

CloudUpload auto-detects your system language (English or Chinese).

```bash
# Force English
upload myfile.tar.gz  # auto-detected

# Force Chinese
LANG=zh_CN.UTF-8 upload myfile.tar.gz
```

### How It Works

CloudUpload implements **3-tier fallback** for maximum compatibility:

```
Tier 1: Official CLI tool (aws, ossutil, coscli...)
        ↓ (not found)
Tier 2: Python SDK (boto3, oss2, qcloud_cos_v5...)
        ↓ (not found)
Tier 3: curl + Signature (portable, no extra deps)
```

### FAQ

**Q: Does it work without installing any CLI tools?**
A: Yes. Python SDK is the fallback, and `curl` + signature generation is the last resort.
   A minimal installation only requires `python3`.

**Q: Does it support large files?**
A: Yes. All official CLI tools (AWS CLI, ossutil, etc.) support multipart upload automatically.
   The Python SDK also handles multipart natively.

**Q: How do I protect my credentials?**
A: `chmod 600 ~/.uploadrc`. Never commit this file to version control.
   For CI/CD, use environment variables instead of the config file.

**Q: Can I use it in a CI/CD pipeline?**
A: Yes! Use `-q` (quiet mode) to output only the URL:
   ```bash
   URL=$(upload myfile.tar.gz -q)
   echo "Uploaded to: $URL"
   ```

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add a new cloud provider or submit changes.

### License

MIT License. See [LICENSE](LICENSE).

---

## 中文

### 一个命令，上传文件到任意云存储

跨平台 CLI 工具，一键上传文件到任意对象存储。支持 AWS S3、阿里云 OSS、腾讯云 COS、百度云 BOS、华为云 OBS、谷歌云 GCS、Azure Blob Storage、MinIO。

#### 支持的云厂商

| Provider | 云厂商 | 官方 CLI | Python SDK |
|----------|--------|----------|------------|
| `aws` | AWS S3 | `awscli` | `boto3` |
| `aliyun` | 阿里云 OSS | `ossutil` | `oss2` |
| `tencent` | 腾讯云 COS | `coscli` | `qcloud_cos_v5` |
| `baidu` | 百度云 BOS | `boscli` | `baidubce` |
| `huawei` | 华为云 OBS | `obsutil` | `obs` |
| `gcp` | 谷歌云 GCS | `gsutil` | `google-cloud-storage` |
| `azure` | Azure Blob Storage | `az` | `azure-storage-blob` |
| `minio` | MinIO / S3 兼容存储 | AWS CLI | `boto3` |

### 功能特性

- **8 大云厂商**开箱即用
- **跨平台**：Linux、macOS、Windows (PowerShell)
- **零依赖**（大部分情况下）— 只需 `curl` 和 `python3`
- **三级 fallback**：官方 CLI → Python SDK → curl + 签名
- **进度条**和**分片上传**（通过原生 CLI 工具）
- **多 Profile 配置**，一键切换不同存储桶
- **自动识别**云厂商
- **静默模式**（`-q`），适合 CI/CD 集成
- **国际化**：英文 + 中文

### 快速开始

#### 1. 安装

**Linux / macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/sxyseo/cloudupload/main/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/sxyseo/cloudupload/main/install.ps1 | iex
```

**手动安装:**
```bash
git clone https://github.com/sxyseo/cloudupload.git ~/cloudupload
echo 'export PATH="$PATH:$HOME/cloudupload"' >> ~/.bashrc
source ~/.bashrc
```

#### 2. 配置

复制并编辑配置文件：

```bash
cp config.example ~/.uploadrc
chmod 600 ~/.uploadrc
nano ~/.uploadrc
```

配置示例（`~/.uploadrc`）：

```bash
# 默认 profile
export UPLOAD_DEFAULT="my-oss"

# 阿里云 OSS
export my-oss_PROVIDER="aliyun"
export my-oss_ENDPOINT="oss-cn-hangzhou.aliyuncs.com"
export my-oss_BUCKET="my-bucket"
export my-oss_ACCESS_KEY="LTAI..."
export my-oss_SECRET_KEY="..."

# AWS S3
export my-s3_PROVIDER="aws"
export my-s3_REGION="us-east-1"
export my-s3_BUCKET="my-bucket"
export my-s3_ACCESS_KEY="AKIA..."
export my-s3_SECRET_KEY="..."
```

#### 3. 上传

```bash
# 使用默认 profile
upload myfile.tar.gz

# 指定 profile
upload myfile.tar.gz my-oss

# 上传到指定目录
upload myfile.tar.gz my-s3 backup/

# 静默模式（只输出 URL，适合脚本）
upload myfile.tar.gz -q

# 列出所有 profile
upload -l

# 显示配置
upload -s my-oss
```

#### Windows PowerShell

```powershell
.\upload.ps1 myfile.tar.gz my-oss
.\upload.ps1 myfile.tar.gz -Quiet
.\upload.ps1 -List
```

### 工具依赖

| 工具 | 用途 | 必需？ |
|------|------|--------|
| `python3` | 签名计算、SDK fallback | 推荐 |
| `curl` | HTTP 请求 | 推荐 |
| `aws` | AWS S3 / MinIO 上传 | S3 用户推荐 |
| `ossutil` | 阿里云 OSS 上传 | OSS 用户推荐 |
| `coscli` | 腾讯云 COS 上传 | COS 用户推荐 |
| `obsutil` | 华为云 OBS 上传 | OBS 用户推荐 |
| `gsutil` | 谷歌云 GCS 上传 | GCS 用户推荐 |
| `az` | Azure Blob 上传 | Azure 用户推荐 |

> **注意**：CloudUpload 即使不安装任何 CLI 工具也能工作。
> 如果没有官方 CLI，会自动 fallback 到 Python SDK，
> 最后 fallback 到 `curl` + 签名。

### 项目结构

```
cloudupload/
├── upload                  # Linux/macOS 主入口
├── upload.ps1             # Windows PowerShell 入口
├── install.sh              # 一键安装脚本 (Unix)
├── install.ps1             # 一键安装脚本 (Windows)
├── config.sh              # 配置加载 (Unix)
├── config.ps1             # 配置加载 (Windows)
├── config.example         # 配置模板
├── i18n/
│   ├── i18n.sh            # 国际化字符串 (Unix)
│   └── i18n.ps1           # 国际化字符串 (Windows)
├── lib/
│   ├── detect.sh/.ps1     # 工具检测
│   ├── aws.sh/.ps1        # AWS S3 / MinIO
│   ├── aliyun.sh/.ps1     # 阿里云 OSS
│   ├── tencent.sh/.ps1    # 腾讯云 COS
│   ├── baidu.sh/.ps1      # 百度云 BOS
│   ├── huawei.sh/.ps1     # 华为云 OBS
│   ├── gcp.sh/.ps1        # 谷歌云 GCS
│   ├── azure.sh/.ps1       # Azure Blob
│   └── minio.sh/.ps1      # MinIO
├── LICENSE
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
└── SECURITY.md
```

### 常见问题

**Q: 不安装任何 CLI 工具能用吗？**
A: 可以。Python SDK 是第一个 fallback，`curl` + 签名生成是最后的保底。
   最小化安装只需要 `python3`。

**Q: 支持大文件（> 5GB）吗？**
A: 支持。所有官方 CLI 工具（AWS CLI、ossutil 等）都支持 multipart 分片上传，
   不会把整个文件加载到内存。

**Q: 如何保护配置文件中的密钥？**
A: `chmod 600 ~/.uploadrc`，不要把此文件提交到代码仓库。
   CI/CD 环境建议使用环境变量代替配置文件。

**Q: 可以在 CI/CD 中使用吗？**
A: 可以！使用 `-q`（静默模式）只输出 URL：
   ```bash
   URL=$(upload myfile.tar.gz -q)
   echo "上传到: $URL"
   ```

### 参与贡献

参见 [CONTRIBUTING.md](CONTRIBUTING.md) 了解如何添加新的云厂商或提交修改。

### 许可证

MIT 许可证。参见 [LICENSE](LICENSE)。
