@echo off
REM Version Sync Verification for Windows
REM Runs the Python verification script

echo.
echo ========================================
echo FoodVision Configuration Sync Check
echo ========================================
echo.

python verify_sync.py

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Configuration sync issues found!
    echo Please review the errors above.
    exit /b 1
)

echo.
pause
