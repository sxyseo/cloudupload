# i18n.ps1 - Internationalization support for CloudUpload (Windows PowerShell)

$script:I18N_LANG = "en"

function Initialize-I18n {
    param([string]$Lang = "")

    if ($Lang) {
        $script:I18N_LANG = $Lang
    } else {
        $culture = [System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName
        if ($culture -eq "zh") {
            $script:I18N_LANG = "zh"
        } else {
            $script:I18N_LANG = "en"
        }
    }
}

function T {
    param([string]$Key, [string]$Arg1 = "", [string]$Arg2 = "")

    switch ($script:I18N_LANG) {
        "zh" { $text = _i18n_zh $Key $Arg1 $Arg2 }
        default { $text = _i18n_en $Key $Arg1 $Arg2 }
    }

    if ($text -match '\{1\}|\{2\}') {
        $text -f $Arg1, $Arg2
    } else {
        $text
    }
}

function _i18n_en {
    param($k, $a1, $a2)
    switch ($k) {
        "ok"           { "OK" }
        "error"        { "Error" }
        "warning"      { "Warning" }
        "info"         { "INFO" }
        "success"      { "Success" }
        "failed"       { "Failed" }
        "done"         { "Done" }
        "detecting"    { "Detecting..." }
        "tool_check"   { "=== Tool Detection ===" }
        "tool_found"   { "Detected: $a1" }
        "tool_missing" { "Not found: $a1" }
        "upload_method"{ "Upload method" }
        "using"        { "Using: $a1" }
        "no_tool"      { "No upload tool available" }
        "no_tool_hint" { "Please install Python SDK or corresponding CLI tool" }
        "uploading"    { "=== CloudUpload ===" }
        "file"         { "File" }
        "target"       { "Target" }
        "file_not_found"{ "File not found: $a1" }
        "upload_ok"    { "Upload successful" }
        "url"          { "URL" }
        "upload_fail"  { "Upload failed" }
        "progress"     { "Progress" }
        "cfg_not_found"{ "Config file not found: $a1" }
        "cfg_hint"     { "Copy config.example to $a1 and fill in your credentials" }
        "profile_nf"   { "Profile '$a1' not found in config file" }
        "profile"      { "Profile" }
        "provider"     { "Provider" }
        "endpoint"     { "Endpoint" }
        "bucket"       { "Bucket" }
        "region"       { "Region" }
        "url_style"    { "URL Style" }
        "account"      { "Account" }
        "access_key"  { "Access Key" }
        "secret_key"  { "Secret Key" }
        "not_set"     { "<not set>" }
        "is_set"      { "<is set>" }
        "providers"    { "Supported cloud providers" }
        "profiles"     { "Available profiles" }
        "p_aws"       { "AWS S3 / Compatible storage" }
        "p_aliyun"    { "Alibaba Cloud OSS" }
        "p_tencent"   { "Tencent Cloud COS" }
        "p_baidu"     { "Baidu Cloud BOS" }
        "p_huawei"    { "Huawei Cloud OBS" }
        "p_gcp"       { "Google Cloud GCS" }
        "p_azure"     { "Azure Blob Storage" }
        "p_minio"     { "MinIO / S3 Compatible storage" }
        "install_title"{ "CloudUpload Installer" }
        "install_sub"  { "Cross-platform object storage upload CLI" }
        "install_confirm"{ "Install to $a1? [Y/n]" }
        "install_cancel"{ "Installation cancelled" }
        "install_ok"  { "Installation complete!" }
        "install_done" { "All done!" }
        "install_path" { "Add $a1 to PATH:" }
        "install_copy" { "Copying files..." }
        "install_symlink"{ "Symlink created" }
        "install_deps" { "Checking dependencies..." }
        "install_cfg"  { "Checking config file..." }
        "install_cfg_ok"{"Config file created" }
        "install_cfg_exists"{"Config file already exists" }
        "install_examples"{ "Run examples:" }
        "run_example"  { "  $a1" }
        "unknown_opt"  { "Unknown option: $a1" }
        "no_file"      { "No file specified" }
        "bad_provider" { "Unsupported provider: $a1" }
        "no_cred"      { "Credential not configured" }
        "file_noexist" { "File does not exist: $a1" }
    }
}

function _i18n_zh {
    param($k, $a1, $a2)
    switch ($k) {
        "ok"           { "确定" }
        "error"        { "错误" }
        "warning"      { "警告" }
        "info"         { "提示" }
        "success"      { "成功" }
        "failed"       { "失败" }
        "done"         { "完成" }
        "detecting"    { "检测中..." }
        "tool_check"   { "=== 工具检测 ===" }
        "tool_found"   { "检测到: $a1" }
        "tool_missing" { "未检测到: $a1" }
        "upload_method"{ "上传方式" }
        "using"        { "将使用: $a1" }
        "no_tool"      { "没有可用的上传工具" }
        "no_tool_hint" { "请安装 Python SDK 或对应 CLI 工具" }
        "uploading"    { "=== CloudUpload ===" }
        "file"         { "文件" }
        "target"       { "目标" }
        "file_not_found"{ "文件不存在: $a1" }
        "upload_ok"    { "上传成功" }
        "url"          { "URL" }
        "upload_fail"  { "上传失败" }
        "progress"     { "进度" }
        "cfg_not_found"{ "配置文件不存在: $a1" }
        "cfg_hint"     { "请复制 config.example 到 $a1 并填入配置" }
        "profile_nf"   { "配置文件中未找到 profile '$a1'" }
        "profile"      { "Profile" }
        "provider"     { "云厂商" }
        "endpoint"     { "端点" }
        "bucket"       { "存储桶" }
        "region"       { "区域" }
        "url_style"    { "URL 方式" }
        "account"      { "账户" }
        "access_key"  { "Access Key" }
        "secret_key"  { "Secret Key" }
        "not_set"     { "<未设置>" }
        "is_set"      { "<已设置>" }
        "providers"    { "支持的云厂商" }
        "profiles"     { "可用 profile" }
        "p_aws"       { "AWS S3 / 兼容存储" }
        "p_aliyun"    { "阿里云 OSS" }
        "p_tencent"   { "腾讯云 COS" }
        "p_baidu"     { "百度云 BOS" }
        "p_huawei"    { "华为云 OBS" }
        "p_gcp"       { "谷歌云 GCS" }
        "p_azure"     { "Azure Blob Storage" }
        "p_minio"     { "MinIO / S3 兼容存储" }
        "install_title"{ "CloudUpload 一键安装" }
        "install_sub"  { "跨平台对象存储上传 CLI" }
        "install_confirm"{ "安装到 $a1 ? [Y/n]" }
        "install_cancel"{ "安装取消" }
        "install_ok"  { "安装完成！" }
        "install_done" { "全部完成！" }
        "install_path" { "建议将 $a1 添加到 PATH:" }
        "install_copy" { "复制文件..." }
        "install_symlink"{"已创建符号链接" }
        "install_deps" { "检查依赖工具..." }
        "install_cfg"  { "检查配置文件..." }
        "install_cfg_ok"{"已创建配置文件" }
        "install_cfg_exists"{"配置文件已存在" }
        "install_examples"{"使用示例:" }
        "run_example"  { "  $a1" }
        "unknown_opt"  { "未知选项: $a1" }
        "no_file"      { "未指定文件" }
        "bad_provider" { "不支持的云厂商: $a1" }
        "no_cred"      { "未配置凭据" }
        "file_noexist" { "文件不存在: $a1" }
    }
}
