@echo off
setlocal

cd /d "%~dp0..\quartus"
set QUARTUS_BIN=C:\altera_lite\25.1std\quartus\bin64

if not exist "%QUARTUS_BIN%\quartus_sh.exe" (
    echo Quartus executable not found: %QUARTUS_BIN%
    exit /b 1
)

for %%N in (2 4 8) do (
    echo.
    echo ========================================
    echo Compiling accelerator benchmark N=%%N
    echo ========================================
    call "%QUARTUS_BIN%\quartus_sh.exe" --flow compile accelerator_benchmark_n%%N
    if errorlevel 1 (
        echo Benchmark N=%%N FAILED
        exit /b 1
    )
    call "%QUARTUS_BIN%\quartus_sta.exe" accelerator_benchmark_n%%N
    if errorlevel 1 (
        echo Timing analysis N=%%N FAILED
        exit /b 1
    )
)

echo.
echo All benchmark configurations completed successfully.
echo Reports: quartus\output_files_n2, output_files_n4, output_files_n8
exit /b 0
