@echo off
setlocal

cd /d "%~dp0.."

echo Compiling software-visible accelerator...
call xvlog -sv ^
    rtl\pe.sv ^
    rtl\input_skew_buffer.sv ^
    rtl\systolic_array.sv ^
    rtl\output_deskew_buffer.sv ^
    rtl\controller.sv ^
    rtl\accelerator.sv ^
    rtl\tiled_gemm.sv ^
    rtl\software_accelerator.sv ^
    rtl\int8_projection.sv ^
    tb\software_accelerator_tb.sv ^
    tb\int8_projection_tb.sv

if errorlevel 1 exit /b 1

echo Elaborating...
call xelab software_accelerator_tb int8_projection_tb -s software_accelerator_sim --timescale 1ns/1ps

if errorlevel 1 exit /b 1

echo Running...
call xsim software_accelerator_sim -runall

exit /b %errorlevel%
