# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release
- 8 cloud providers: AWS S3, Alibaba Cloud OSS, Tencent Cloud COS, Baidu Cloud BOS, Huawei Cloud OBS, Google Cloud GCS, Azure Blob Storage, MinIO
- Cross-platform support: Linux, macOS, Windows (PowerShell)
- Multi-level fallback: CLI tools → Python SDK → curl + signature
- Multi-language support: English, Chinese (Simplified)
- One-line installer for Linux/macOS and PowerShell for Windows
- Multi-profile configuration via `~/.uploadrc`
- Progress bar and multipart upload support (via native CLI tools)
- Quiet mode (`-q`) for script integration
- Auto provider detection from endpoint
