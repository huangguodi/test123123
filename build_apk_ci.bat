@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo   Push to GitHub - Android APK CI (same as local release)
echo ========================================================
echo.

:: Proxy (local Clash / V2Ray, port 7890)
set "PROXY_HOST=127.0.0.1"
set "PROXY_PORT=7890"
set "HTTP_PROXY=http://%PROXY_HOST%:%PROXY_PORT%"
set "HTTPS_PROXY=http://%PROXY_HOST%:%PROXY_PORT%"
set "http_proxy=http://%PROXY_HOST%:%PROXY_PORT%"
set "https_proxy=http://%PROXY_HOST%:%PROXY_PORT%"
set "NO_PROXY=localhost,127.0.0.1,::1"
set "no_proxy=localhost,127.0.0.1,::1"
echo [Proxy] %HTTP_PROXY%
echo.

set "BRANCH=main"
cd /d "%~dp0"

echo [1/3] Git status...
git status -sb
echo.

set /p CONFIRM="Commit and push to GitHub? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Cancelled.
    goto :done
)

echo [2/3] Commit...
git add -A
git -c user.name=huangguodi -c user.email=huangguodi@users.noreply.github.com commit -m "Update project" 2>nul
if %errorlevel% neq 0 (
    echo [INFO] Nothing to commit or commit skipped.
)

echo [3/3] Push origin %BRANCH%...
git push origin %BRANCH%
if %errorlevel% neq 0 (
    echo [ERROR] Push failed.
    goto :done
)

echo.
echo [OK] Pushed. APK will build on GitHub Actions (ubuntu).
echo      Download: https://github.com/huangguodi/test123123/actions
echo      Workflow: Android Build
echo      Artifacts: android-apk, android-symbols
echo.
start https://github.com/huangguodi/test123123/actions

:done
pause
