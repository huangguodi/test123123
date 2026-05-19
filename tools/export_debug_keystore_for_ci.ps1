# 导出本机 debug.keystore 的 Base64，用于 GitHub Actions Secrets（不要提交到 Git 仓库）

$ErrorActionPreference = "Stop"
$src = Join-Path $env:USERPROFILE ".android\debug.keystore"

if (-not (Test-Path $src)) {
    Write-Error "未找到: $src"
}

$bytes = [System.IO.File]::ReadAllBytes($src)
$b64 = [Convert]::ToBase64String($bytes)
$outFile = Join-Path $PSScriptRoot "debug_keystore.base64.txt"

Set-Content -Path $outFile -Value $b64 -NoNewline -Encoding ASCII

Write-Host "========================================"
Write-Host "  GitHub 仓库 Settings -> Secrets -> Actions"
Write-Host "  新建以下 4 个 Secret（值如下）"
Write-Host "========================================"
Write-Host ""
Write-Host "ANDROID_KEYSTORE_BASE64"
Write-Host "  -> 完整内容见文件: $outFile"
Write-Host "  （或复制下面一行，很长）"
Write-Host ""
Write-Host "ANDROID_KEYSTORE_PASSWORD  = android"
Write-Host "ANDROID_KEY_ALIAS          = AndroidDebugKey"
Write-Host "ANDROID_KEY_PASSWORD       = android"
Write-Host ""
Write-Host "注意:"
Write-Host "  1. 不要把 .keystore / base64 文件 commit 到 Git"
Write-Host "  2. 配置完成后 push 代码，Android Build  workflow 会用同一证书打 APK"
Write-Host "  3. 证书指纹需与 lib/core/security/obfuscator.dart 中一致"
Write-Host ""

# 尝试打印 SHA256 指纹（需 keytool）
$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if ($keytool) {
    Write-Host "本机 debug 证书 SHA256 指纹:"
    & keytool -list -v -keystore $src -storepass android -alias AndroidDebugKey 2>$null |
        Select-String "SHA256"
}
