@echo off
setlocal

cd /d "%~dp0..\quartus"
set QUARTUS_BIN=C:\altera_lite\25.1std\quartus\bin64

if not exist "%QUARTUS_BIN%\quartus_sh.exe" (
    echo Quartus executable not found: %QUARTUS_BIN%
    exit /b 1
)

call "%QUARTUS_BIN%\quartus_sh.exe" --flow compile de1_soc_accel
if errorlevel 1 exit /b 1

call "%QUARTUS_BIN%\quartus_sta.exe" de1_soc_accel
if errorlevel 1 exit /b 1

echo.
echo Quartus reports are in quartus\output_files
exit /b 0
