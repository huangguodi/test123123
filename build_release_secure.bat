@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo       Address Project - Secure Release Build
echo ========================================================
echo.

:: Proxy (Clash / V2Ray 等本地代理，默认端口 7890)
set "PROXY_HOST=127.0.0.1"
set "PROXY_PORT=7890"
set "HTTP_PROXY=http://%PROXY_HOST%:%PROXY_PORT%"
set "HTTPS_PROXY=http://%PROXY_HOST%:%PROXY_PORT%"
set "http_proxy=http://%PROXY_HOST%:%PROXY_PORT%"
set "https_proxy=http://%PROXY_HOST%:%PROXY_PORT%"
set "NO_PROXY=localhost,127.0.0.1,::1"
set "no_proxy=localhost,127.0.0.1,::1"
echo [Proxy] %HTTP_PROXY%
set "GRADLE_OPTS=-Dhttp.proxyHost=%PROXY_HOST% -Dhttp.proxyPort=%PROXY_PORT% -Dhttps.proxyHost=%PROXY_HOST% -Dhttps.proxyPort=%PROXY_PORT%"
echo.

:: 1. Define Variables
set "PROJECT_ROOT=%~dp0"
set "OUTPUT_DIR=%PROJECT_ROOT%release_output"
set "SYMBOLS_DIR=%OUTPUT_DIR%\symbols"
set "APK_SOURCE=%PROJECT_ROOT%build\app\outputs\flutter-apk\app-release.apk"
set "TIMESTAMP=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%"
set "TIMESTAMP=%TIMESTAMP: =0%"

:: 2. Clean Project
echo [1/5] Cleaning project...
call flutter clean
if %errorlevel% neq 0 (
    echo [ERROR] Flutter clean failed.
    pause
    exit /b %errorlevel%
)

:: 3. Prepare Output Directory
echo [2/5] Preparing output directory...
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
if not exist "%SYMBOLS_DIR%" mkdir "%SYMBOLS_DIR%"

:: 4. Build Release APK (Obfuscated)
echo [3/5] Building Release APK (Obfuscated)...
echo       Note: This may take a while...
call flutter build apk --release --obfuscate --split-debug-info="%SYMBOLS_DIR%"
if %errorlevel% neq 0 (
    echo [ERROR] Build failed.
    pause
    exit /b %errorlevel%
)

:: 5. Verify and Move APK
echo [4/5] Finalizing...
if exist "%APK_SOURCE%" (
    set "TARGET_NAME=address_release_secure_%TIMESTAMP%.apk"
    copy "%APK_SOURCE%" "%OUTPUT_DIR%\!TARGET_NAME!"
    
    echo.
    echo ========================================================
    echo [SUCCESS] Build Complete!
    echo.
    echo APK Location:
    echo   %OUTPUT_DIR%\!TARGET_NAME!
    echo.
    echo Debug Symbols (Keep this safe for de-obfuscation):
    echo   %SYMBOLS_DIR%
    echo ========================================================
    
    :: Open Output Directory
    explorer "%OUTPUT_DIR%"
) else (
    echo [ERROR] APK not found at expected path:
    echo %APK_SOURCE%
    pause
    exit /b 1
)

pause
