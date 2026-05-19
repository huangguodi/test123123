@echo off
set "SRC=%USERPROFILE%\.android\debug.keystore"
set "DST=%~dp0..\android\app\ci-debug.keystore"

if not exist "%SRC%" (
    echo [ERROR] Not found: %SRC%
    echo Run "flutter build apk" once on this PC to create debug.keystore.
    exit /b 1
)

copy /Y "%SRC%" "%DST%"
echo [OK] Copied to android\app\ci-debug.keystore
echo Next:
echo   git add android\app\ci-debug.keystore android\key.properties
echo   git commit -m "Add debug keystore for CI"
echo   git push
exit /b 0
