@echo off
setlocal

cd /d "%~dp0.."

echo Compiling SystemVerilog...
call xvlog -sv ^
    rtl\pe.sv ^
    rtl\input_skew_buffer.sv ^
    rtl\systolic_array.sv ^
    rtl\output_deskew_buffer.sv ^
    rtl\controller.sv ^
    rtl\accelerator.sv ^
    tb\accelerator_tb.sv

if errorlevel 1 exit /b 1

echo Elaborating...
call xelab accelerator_tb -s accelerator_sim

if errorlevel 1 exit /b 1

echo Running simulation...
call xsim accelerator_sim -runall

exit /b %errorlevel%
