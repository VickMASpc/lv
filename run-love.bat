@echo off
setlocal

where love >nul 2>nul
if %errorlevel%==0 (
    love "%~dp0"
    exit /b %errorlevel%
)

echo LOVE was not found on PATH.
echo Install LOVE 11.x from https://love2d.org/ and make sure `love` is available in PATH.
exit /b 1
