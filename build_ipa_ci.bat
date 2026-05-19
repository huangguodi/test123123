@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo   Push to GitHub and trigger iOS IPA build (CI)
echo   Note: IPA cannot be built locally on Windows.
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

set "REPO=https://github.com/huangguodi/test123123.git"
set "BRANCH=main"

cd /d "%~dp0"

where gh >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] GitHub CLI ^(gh^) not found.
    echo        After git push, open:
    echo        https://github.com/huangguodi/test123123/actions
    echo        and run workflow "iOS Build" manually.
    goto :done
)

echo [1/2] Checking latest push on %BRANCH%...
git fetch origin %BRANCH% 2>nul

echo [2/2] Triggering workflow_dispatch: iOS Build ...
gh workflow run "iOS Build" --repo huangguodi/test123123 --ref %BRANCH%
if %errorlevel% neq 0 (
    echo [WARN] Could not trigger workflow. Run it manually on GitHub Actions.
) else (
    echo [OK] Workflow triggered. Download IPA from Actions artifacts when done.
    start https://github.com/huangguodi/test123123/actions
)

:done
pause
