@echo off
setlocal

cd /d "%~dp0.."
if "%ACCEL_N%"=="" set ACCEL_N=2

echo Compiling N=%ACCEL_N% UVM corner-case testbench...
call xvlog -sv -L uvm --define ACCEL_N_%ACCEL_N% ^
    rtl\pe.sv ^
    rtl\input_skew_buffer.sv ^
    rtl\systolic_array.sv ^
    rtl\output_deskew_buffer.sv ^
    rtl\controller.sv ^
    rtl\accelerator.sv ^
    tb\uvm\accelerator_assertions.sv ^
    tb\uvm\accelerator_if.sv ^
    tb\uvm\accelerator_item.sv ^
    tb\uvm\accelerator_sequence.sv ^
    tb\uvm\accelerator_corner_sequence.sv ^
    tb\uvm\accelerator_driver.sv ^
    tb\uvm\accelerator_monitor.sv ^
    tb\uvm\accelerator_scoreboard.sv ^
    tb\uvm\accelerator_agent.sv ^
    tb\uvm\accelerator_env.sv ^
    tb\uvm\accelerator_test.sv ^
    tb\uvm\uvm_corner_top.sv

if errorlevel 1 exit /b 1

call xelab uvm_corner_top -s accelerator_uvm_n%ACCEL_N%_corner -L uvm --timescale 1ns/1ps

if errorlevel 1 exit /b 1

call xsim accelerator_uvm_n%ACCEL_N%_corner -runall

exit /b %errorlevel%
