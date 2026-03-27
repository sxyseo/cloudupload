# gcp.ps1 - 谷歌云 GCS 上传 (Windows PowerShell)

function Do-Upload {
    param([string]$LocalFile, [string]$RemoteKey)

    Write-Host "文件: $LocalFile"
    Write-Host "目标: gs://$BUCKET/$RemoteKey"

    $method = Get-UploadMethod -Provider "gcp"

    switch ($method) {
        "gsutil"    { _Upload-Gsutil -LocalFile $LocalFile -RemoteKey $RemoteKey }
        "gcp-python"{ _Upload-GcpPy -LocalFile $LocalFile -RemoteKey $RemoteKey }
        "curl-jwt"  { _Upload-GcpPy -LocalFile $LocalFile -RemoteKey $RemoteKey }
        default     { Write-Error "无可用上传方式"; exit 1 }
    }
}

function _Upload-Gsutil {
    param([string]$LocalFile, [string]$RemoteKey)

    $args = @("cp", $LocalFile, "gs://$BUCKET/$RemoteKey")
    if ($Quiet) { $args += "-q" }
    & gsutil @args 2>&1 | ForEach-Object { if (-not $Quiet) { Write-Host $_ } }
    if ($LASTEXITCODE -eq 0) { _Generate-Url -RemoteKey $RemoteKey }
}

function _Upload-GcpPy {
    param([string]$LocalFile, [string]$RemoteKey)

    $py = @"
import sys,datetime,json,base64,hmac,hashlib,subprocess,os,urllib.parse
lf='$LocalFile';rk='$RemoteKey';bk='$BUCKET';em='$ACCESS_KEY';pk='$SECRET_KEY';q='$Quiet'
now=int(datetime.datetime.utcnow().timestamp())
hdr=base64.urlsafe_b64encode(json.dumps({'alg':'RS256','typ':'JWT'}).encode()).decode().rstrip('=')
pl=base64.urlsafe_b64encode(json.dumps({'iss':em,'scope':'https://www.googleapis.com/auth/devstorage.read_write','aud':'https://oauth2.googleapis.com/token','iat':now,'exp':now+3600}).encode()).decode().rstrip('=')
s=base64.urlsafe_b64encode(hmac.new(pk.encode(),(hdr+'.'+pl).encode(),hashlib.sha256).digest()).decode().rstrip('=')
jwt=hdr+'.'+pl+'.'+s
r=subprocess.run(['curl','-s','-X','POST','-H','Content-Type: application/x-www-form-urlencoded','-d',f'grant_type=urn:ietf:params:oauth2:grant-type:jwt-bearer&assertion={jwt}','https://oauth2.googleapis.com/token'],capture_output=True,text=True)
tok=json.loads(r.stdout).get('access_token')
if not tok: print(f'获取 token 失败: {r.stdout}',file=sys.stderr); sys.exit(1)
sz=os.path.getsize(lf)
url=f'https://storage.googleapis.com/upload/storage/v1/b/{bk}/o?uploadType=media&name={urllib.parse.quote(rk)}'
cmd=['curl','-s','-X','POST','-T',lf,'-H',f'Authorization: Bearer {tok}','-H','Content-Type: application/octet-stream','-H',f'Content-Length: {sz}',url]
if q=='false': cmd.insert(1,'-v')
r2=subprocess.run(cmd,capture_output=True,text=True)
if r2.returncode==0:
    print(); print('✓ 上传成功')
    print(f'URL: https://storage.googleapis.com/{bk}/{rk}')
else: print(f'上传失败',file=sys.stderr); sys.exit(1)
"@
    python -c $py
    if ($LASTEXITCODE -ne 0) { exit 1 }
    _Generate-Url -RemoteKey $RemoteKey
}

function _Generate-Url {
    param([string]$RemoteKey)
    Write-Host ""
    Write-Host "✓ 上传成功" -ForegroundColor Green
    Write-Host "URL: https://storage.googleapis.com/$BUCKET/$RemoteKey"
}
