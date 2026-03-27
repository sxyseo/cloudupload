#!/usr/bin/env bash
# i18n.sh - Internationalization support for CloudUpload (Unix/Linux/macOS)
# Usage: source i18n.sh [lang]  (lang: en | zh, default: auto-detect)

detect_lang() {
    local lang="${1:-}"
    if [[ -n "$lang" ]]; then
        echo "$lang"
        return
    fi
    # Auto-detect from environment
    local l="${LANG:-${LC_ALL:-en}}"
    if [[ "$l" == zh* ]]; then
        echo "zh"
    else
        echo "en"
    fi
}

i18n_init() {
    local lang
    lang=$(detect_lang "${1:-}")
    export I18N_LANG="$lang"
}

# Text strings
i18n() {
    local key="$1"
    case "$I18N_LANG" in
        zh) _i18n_zh "$key" ;;
        *)  _i18n_en "$key" ;;
    esac
}

_i18n_en() {
    case "$1" in
        # Common
        ok)          echo "OK" ;;
        error)       echo "Error" ;;
        warning)     echo "Warning" ;;
        info)        echo "INFO" ;;
        detecting)   echo "Detecting" ;;
        success)     echo "Success" ;;
        failed)      echo "Failed" ;;
        done)        echo "Done" ;;
        yes)         echo "Yes" ;;
        no)          echo "No" ;;
        exit)        echo "Exit" ;;

        # Config
        cfg_not_found)       echo "Config file not found: $2" ;;
        cfg_hint)            echo "Hint: copy config.example to ~/.uploadrc and fill in your credentials" ;;
        profile_not_found)   echo "Profile '$2' not found in config file" ;;
        profile_loaded)      echo "Profile loaded" ;;
        cfg_file)            echo "Config file" ;;
        profile)             echo "Profile" ;;
        provider)            echo "Provider" ;;
        endpoint)            echo "Endpoint" ;;
        bucket)              echo "Bucket" ;;
        region)              echo "Region" ;;
        url_style)           echo "URL Style" ;;
        account)             echo "Account" ;;
        access_key)          echo "Access Key" ;;
        secret_key)          echo "Secret Key" ;;
        not_set)             echo "<not set>" ;;
        is_set)              echo "<is set>" ;;

        # Tools
        tool_check)       echo "=== Tool Detection ===" ;;
        tool_detected)     echo "Detected: $2" ;;
        tool_not_found)    echo "Not found: $2" ;;
        tool_required)      echo "$2 is recommended for best experience" ;;
        tool_install_hint) echo "Install: $2" ;;
        tool_recommended)  echo "Recommended for $2 support:" ;;
        upload_method)     echo "Upload method" ;;
        using_tool)        echo "Using: $2" ;;
        no_tool)           echo "No upload tool available" ;;
        tool_install_help) echo "Please install Python SDK or corresponding CLI tool" ;;

        # Upload
        uploading)      echo "=== CloudUpload ===" ;;
        file)           echo "File" ;;
        target)         echo "Target" ;;
        file_not_found) echo "File not found: $2" ;;
        upload_success)  echo "Upload successful" ;;
        url_label)      echo "URL" ;;
        upload_failed)  echo "Upload failed" ;;
        progress)       echo "Progress" ;;

        # Help
        help_title)     echo "CloudUpload - One command to upload files to any cloud storage" ;;
        usage)          echo "Usage" ;;
        options)        echo "Options" ;;
        examples)       echo "Examples" ;;
        config_hint)    echo "Config: ~/.uploadrc" ;;

        # Profiles
        available_profiles) echo "Available profiles" ;;
        supported_providers) echo "Supported cloud providers" ;;
        provider_aws)       echo "AWS S3 / Compatible storage" ;;
        provider_aliyun)    echo "Alibaba Cloud OSS" ;;
        provider_tencent)   echo "Tencent Cloud COS" ;;
        provider_baidu)     echo "Baidu Cloud BOS" ;;
        provider_huawei)    echo "Huawei Cloud OBS" ;;
        provider_gcp)       echo "Google Cloud GCS" ;;
        provider_azure)     echo "Azure Blob Storage" ;;
        provider_minio)     echo "MinIO / S3 Compatible storage" ;;

        # Install
        install_title)      echo "CloudUpload Installer" ;;
        install_subtitle)   echo "Cross-platform object storage upload CLI" ;;
        install_to)          echo "Install to" ;;
        install_confirm)     echo "Install to $2? [Y/n]" ;;
        install_cancel)      echo "Installation cancelled" ;;
        install_success)    echo "Installation complete!" ;;
        install_done)       echo "All done!" ;;
        install_add_path)   echo "Add $2 to PATH:" ;;
        install_cmd)        echo "  source ~/.bashrc" ;;
        os_detected)        echo "Detected OS" ;;
        install_shell)      echo "Installing Shell version..." ;;
        install_ps)         echo "Installing PowerShell version..." ;;
        install_copying)    echo "Copying files..." ;;
        install_symlink)    echo "Created symlink" ;;
        install_deps)       echo "Checking dependencies..." ;;
        install_cfg)        echo "Checking config file..." ;;
        install_cfg_created) echo "Config file created" ;;
        install_cfg_exists) echo "Config file already exists" ;;
        install_example)     echo "Run examples:" ;;
        install_first)      echo "First time usage:" ;;
        run_example)        echo "  $2" ;;
        run_help)           echo "  $2" ;;
        run_list)           echo "  $2" ;;

        # Relay / Download
        relay_title)       echo "=== CloudUpload Relay ===" ;;
        relay_uploading)   echo "Uploading and generating relay code..." ;;
        relay_success)    echo "Relay upload complete!" ;;
        relay_code_label) echo "Relay Code:" ;;
        relay_server_hint) echo "Copy and run on server:" ;;
        relay_cmd_curl)   echo "One-line download (curl):" ;;
        relay_code_short) echo "Short Code:" ;;
        relay_no_cred)    echo "Credentials required for relay upload" ;;
        relay_code_decode_err) echo "Failed to decode relay code" ;;
        relay_url_expires) echo "URL expires in $2" ;;
        relay_file_size)  echo "Size" ;;
        relay_filename)   echo "Filename" ;;
        relay_created)    echo "Created" ;;
        relay_cmd_hint)   echo "Run on server:" ;;
        relay_share)      echo "Share link:" ;;
        relay_list_title) echo "=== File List ===" ;;
        relay_list_empty) echo "No files found" ;;
        relay_share_title) echo "=== Share Link ===" ;;
        relay_share_expires) echo "Share link expires in $2" ;;
        relay_meta_upload) echo "Uploading relay metadata..." ;;
        relay_script_upload) echo "Uploading download script..." ;;
        relay_script_hint) echo "Or download script directly:" ;;
        relay_download_start) echo "Starting download..." ;;
        relay_download_complete) echo "Download complete!" ;;
        relay_download_failed) echo "Download failed" ;;
        relay_download_progress) echo "Downloaded $2" ;;
        relay_downloading)   echo "Downloading from cloud storage..." ;;
        relay_fetch_meta)   echo "Fetching relay metadata..." ;;
        relay_meta_found)   echo "Relay metadata found" ;;
        relay_meta_notfound) echo "Relay metadata not found or expired" ;;
        relay_incorrect_provider) echo "Provider mismatch in relay code" ;;

        # List
        list_title)        echo "=== Cloud Storage File List ===" ;;
        list_col_name)    echo "Name" ;;
        list_col_size)    echo "Size" ;;
        list_col_modified) echo "Modified" ;;
        list_empty)       echo "(empty)" ;;
        list_prefix)      echo "Prefix" ;;
        list_count)       echo "$2 files found" ;;

        # Share
        share_title)      echo "=== CloudStorage Share Link ===" ;;
        share_url)       echo "Share URL:" ;;
        share_expires_in) echo "Expires in $2" ;;
        share_generate)  echo "Generating share link..." ;;
        share_failed)    echo "Failed to generate share link" ;;
        share_key)       echo "Remote key" ;;

        # Download
        download_title)   echo "=== CloudUpload Download ===" ;;
        download_no_args) echo "Usage: download relay <code>" ;;
        download_no_curl) echo "curl is required for download" ;;
        download_no_python) echo "python3 is required to decode relay code" ;;
        download_write_err) echo "Failed to write file: $2" ;;
        download_complete) echo "Download complete: $2" ;;
        download_usage)   echo "Usage: download relay <code> [output_file]" ;;
        download_piping)  echo "Piping downloaded content" ;;

        # Error
        unknown_option)     echo "Unknown option: $2" ;;
        no_file)            echo "No file specified" ;;
        unsupported_provider) echo "Unsupported provider: $2" ;;
        no_credential)      echo "Credential not configured" ;;
        file_not_exist)     echo "File does not exist: $2" ;;
    esac
}

_i18n_zh() {
    case "$1" in
        # Common
        ok)          echo "确定" ;;
        error)       echo "错误" ;;
        warning)     echo "警告" ;;
        info)        echo "提示" ;;
        detecting)   echo "检测中" ;;
        success)     echo "成功" ;;
        failed)      echo "失败" ;;
        done)        echo "完成" ;;
        yes)         echo "是" ;;
        no)          echo "否" ;;
        exit)        echo "退出" ;;

        # Config
        cfg_not_found)       echo "配置文件不存在: $2" ;;
        cfg_hint)            echo "提示: 请复制 config.example 到 ~/.uploadrc 并填入配置" ;;
        profile_not_found)   echo "配置文件中未找到 profile '$2'" ;;
        profile_loaded)      echo "配置已加载" ;;
        cfg_file)            echo "配置文件" ;;
        profile)             echo "Profile" ;;
        provider)            echo "云厂商" ;;
        endpoint)            echo "端点" ;;
        bucket)              echo "存储桶" ;;
        region)              echo "区域" ;;
        url_style)           echo "URL 方式" ;;
        account)             echo "账户" ;;
        access_key)          echo "Access Key" ;;
        secret_key)          echo "Secret Key" ;;
        not_set)             echo "<未设置>" ;;
        is_set)              echo "<已设置>" ;;

        # Tools
        tool_check)       echo "=== 工具检测 ===" ;;
        tool_detected)     echo "检测到: $2" ;;
        tool_not_found)    echo "未检测到: $2" ;;
        tool_required)      echo "推荐安装 $2 以获得最佳体验" ;;
        tool_install_hint) echo "安装方式: $2" ;;
        tool_recommended)  echo "推荐安装以支持 $2:" ;;
        upload_method)     echo "上传方式" ;;
        using_tool)        echo "将使用: $2" ;;
        no_tool)           echo "没有可用的上传工具" ;;
        tool_install_help) echo "请安装 Python SDK 或对应 CLI 工具" ;;

        # Upload
        uploading)      echo "=== CloudUpload ===" ;;
        file)           echo "文件" ;;
        target)         echo "目标" ;;
        file_not_found) echo "文件不存在: $2" ;;
        upload_success)  echo "上传成功" ;;
        url_label)      echo "URL" ;;
        upload_failed)  echo "上传失败" ;;
        progress)       echo "进度" ;;

        # Help
        help_title)     echo "CloudUpload - 一键上传文件到任意云存储" ;;
        usage)          echo "用法" ;;
        options)        echo "选项" ;;
        examples)       echo "示例" ;;
        config_hint)    echo "配置: ~/.uploadrc" ;;

        # Profiles
        available_profiles) echo "可用 profile" ;;
        supported_providers) echo "支持的云厂商" ;;
        provider_aws)       echo "AWS S3 / 兼容存储" ;;
        provider_aliyun)    echo "阿里云 OSS" ;;
        provider_tencent)   echo "腾讯云 COS" ;;
        provider_baidu)     echo "百度云 BOS" ;;
        provider_huawei)    echo "华为云 OBS" ;;
        provider_gcp)       echo "谷歌云 GCS" ;;
        provider_azure)     echo "Azure Blob Storage" ;;
        provider_minio)     echo "MinIO / S3 兼容存储" ;;

        # Install
        install_title)      echo "CloudUpload 一键安装" ;;
        install_subtitle)   echo "跨平台对象存储上传 CLI" ;;
        install_to)          echo "安装到" ;;
        install_confirm)     echo "安装到 $2 ? [Y/n]" ;;
        install_cancel)      echo "安装取消" ;;
        install_success)    echo "安装完成！" ;;
        install_done)       echo "全部完成！" ;;
        install_add_path)   echo "建议将 $2 添加到 PATH:" ;;
        install_cmd)        echo "  source ~/.bashrc" ;;
        os_detected)        echo "检测到系统" ;;
        install_shell)      echo "正在安装 Shell 版本..." ;;
        install_ps)         echo "正在安装 PowerShell 版本..." ;;
        install_copying)    echo "复制文件..." ;;
        install_symlink)    echo "已创建符号链接" ;;
        install_deps)       echo "检查依赖工具..." ;;
        install_cfg)        echo "检查配置文件..." ;;
        install_cfg_created) echo "已创建配置文件" ;;
        install_cfg_exists) echo "配置文件已存在" ;;
        install_example)     echo "使用示例:" ;;
        install_first)      echo "首次使用:" ;;
        run_example)        echo "  $2" ;;
        run_help)           echo "  $2" ;;
        run_list)           echo "  $2" ;;

        # Relay / Download
        relay_title)       echo "=== CloudUpload 中转 ===" ;;
        relay_uploading)   echo "正在上传并生成中转码..." ;;
        relay_success)    echo "中转上传完成！" ;;
        relay_code_label) echo "中转码:" ;;
        relay_server_hint) echo "复制到服务器执行:" ;;
        relay_cmd_curl)   echo "一键下载命令 (curl):" ;;
        relay_code_short) echo "短码:" ;;
        relay_no_cred)    echo "中转上传需要配置凭据" ;;
        relay_code_decode_err) echo "中转码解析失败" ;;
        relay_url_expires) echo "URL 有效期: $2" ;;
        relay_file_size)  echo "大小" ;;
        relay_filename)   echo "文件名" ;;
        relay_created)    echo "创建时间" ;;
        relay_cmd_hint)   echo "服务器执行:" ;;
        relay_share)      echo "分享链接:" ;;
        relay_list_title) echo "=== 文件列表 ===" ;;
        relay_list_empty) echo "没有找到文件" ;;
        relay_share_title) echo "=== 分享链接 ===" ;;
        relay_share_expires) echo "分享链接有效期: $2" ;;
        relay_meta_upload) echo "上传中转元数据..." ;;
        relay_script_upload) echo "上传下载脚本..." ;;
        relay_script_hint) echo "或直接下载脚本:" ;;
        relay_download_start) echo "开始下载..." ;;
        relay_download_complete) echo "下载完成！" ;;
        relay_download_failed) echo "下载失败" ;;
        relay_download_progress) echo "已下载 $2" ;;
        relay_downloading)   echo "从云存储下载中..." ;;
        relay_fetch_meta)   echo "获取中转元数据..." ;;
        relay_meta_found)   echo "找到中转元数据" ;;
        relay_meta_notfound) echo "中转元数据未找到或已过期" ;;
        relay_incorrect_provider) echo "中转码中的云厂商信息不匹配" ;;

        # List
        list_title)        echo "=== 云存储文件列表 ===" ;;
        list_col_name)    echo "文件名" ;;
        list_col_size)    echo "大小" ;;
        list_col_modified) echo "修改时间" ;;
        list_empty)       echo "(空)" ;;
        list_prefix)      echo "前缀" ;;
        list_count)       echo "共 $2 个文件" ;;

        # Share
        share_title)      echo "=== 云存储分享链接 ===" ;;
        share_url)       echo "分享 URL:" ;;
        share_expires_in) echo "有效期: $2" ;;
        share_generate)  echo "正在生成分享链接..." ;;
        share_failed)    echo "生成分享链接失败" ;;
        share_key)       echo "远程路径" ;;

        # Download
        download_title)   echo "=== CloudUpload 下载 ===" ;;
        download_no_args) echo "用法: download relay <code> [output_file]" ;;
        download_no_curl) echo "下载需要 curl" ;;
        download_no_python) echo "解析中转码需要 python3" ;;
        download_write_err) echo "写入文件失败: $2" ;;
        download_complete) echo "下载完成: $2" ;;
        download_usage)   echo "用法: download relay <code> [output_file]" ;;
        download_piping)  echo "管道下载内容" ;;

        # Error
        unknown_option)     echo "未知选项: $2" ;;
        no_file)            echo "未指定文件" ;;
        unsupported_provider) echo "不支持的云厂商: $2" ;;
        no_credential)      echo "未配置凭据" ;;
        file_not_exist)     echo "文件不存在: $2" ;;
    esac
}
