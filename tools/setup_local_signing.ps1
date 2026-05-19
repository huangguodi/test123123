# 将本机 Android debug.keystore 复制到工程，并生成 android/key.properties
# 使本地 release 包与 GitHub CI 使用同一套签名（需先在 GitHub 配置相同证书的 Secrets）

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $env:USERPROFILE ".android\debug.keystore"
$dst = Join-Path $root "android\app\ci-debug.keystore"
$keyProps = Join-Path $root "android\key.properties"

if (-not (Test-Path $src)) {
    Write-Error "未找到本机 debug 证书: $src`n请先在本机执行一次 flutter build apk 以生成 debug.keystore。"
}

Copy-Item $src $dst -Force
@"
storePassword=android
keyPassword=android
keyAlias=AndroidDebugKey
storeFile=app/ci-debug.keystore
"@ | Set-Content -Path $keyProps -Encoding UTF8

Write-Host "OK 已配置本地签名:"
Write-Host "  证书: $dst"
Write-Host "  配置: $keyProps"
Write-Host ""
Write-Host "下一步: 运行 tools\export_debug_keystore_for_ci.ps1，把输出的 Base64 填到 GitHub Secrets。"
