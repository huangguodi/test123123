@echo off
setlocal
set "KT=C:\Program Files\Java\jdk1.8.0_202\bin\keytool.exe"
set "KS=%~dp0..\android\app\ci-debug.keystore"

if not exist "%KT%" (
    echo [ERROR] keytool not found: %KT%
    echo Install JDK or edit KT path in this script.
    exit /b 1
)

echo Generating %KS% ...
"%KT%" -genkeypair -v -keystore "%KS%" -storepass android -alias AndroidDebugKey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=LeYing Debug,O=LeYing,C=CN"

echo.
echo SHA256 fingerprint:
"%KT%" -list -v -keystore "%KS%" -storepass android -alias AndroidDebugKey | findstr SHA256

echo.
echo Next: run rotate script with the fingerprint above:
echo   dart run tools/rotate_android_signing.dart "PASTE_SHA256_HERE"
echo Then update obfuscator.dart and native-lib.cpp from script output.
pause
