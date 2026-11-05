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
    rtl\tiled_gemm.sv ^
    tb\accelerator_tb.sv ^
    tb\accelerator_sweep_tb.sv ^
    tb\tiled_gemm_tb.sv

if errorlevel 1 exit /b 1

echo Elaborating...
call xelab accelerator_sweep_tb tiled_gemm_tb -s accelerator_sim --timescale 1ns/1ps

if errorlevel 1 exit /b 1

echo Running simulation...
call xsim accelerator_sim -runall

exit /b %errorlevel%
