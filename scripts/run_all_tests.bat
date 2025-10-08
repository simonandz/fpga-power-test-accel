@echo off
REM =============================================================================
REM Script: run_all_tests.bat
REM Description: Run all infrastructure testbenches (Windows batch version)
REM =============================================================================

setlocal enabledelayedexpansion

echo =======================================================
echo   Accelerator Infrastructure Test Suite
echo =======================================================
echo.

REM Change to project root
cd /d "%~dp0\.."

REM Create test output directory
if not exist "build\test_results" mkdir "build\test_results"

set PASSED=0
set FAILED=0

REM -----------------------------------------------------------------------------
REM Test 1: Memory Controller
REM -----------------------------------------------------------------------------
echo Running: Memory Controller Test
echo -------------------------------------------------------

call :run_test tb_memory_controller common\tb\tb_memory_controller.sv
echo.

REM -----------------------------------------------------------------------------
REM Test 2: Address Generator
REM -----------------------------------------------------------------------------
echo Running: Address Generator Test
echo -------------------------------------------------------

call :run_test tb_addr_gen_unit common\tb\tb_addr_gen_unit.sv
echo.

REM -----------------------------------------------------------------------------
REM Test 3: Accelerator Controller
REM -----------------------------------------------------------------------------
echo Running: Accelerator Controller Test
echo -------------------------------------------------------

call :run_test tb_accel_controller common\tb\tb_accel_controller.sv
echo.

REM -----------------------------------------------------------------------------
REM Test 4: Power Manager
REM -----------------------------------------------------------------------------
echo Running: Power Manager Test
echo -------------------------------------------------------

call :run_test tb_power_manager common\tb\tb_power_manager.sv
echo.

REM -----------------------------------------------------------------------------
REM Test 5: Integration Test
REM -----------------------------------------------------------------------------
echo Running: Integration Test
echo -------------------------------------------------------

call :run_test tb_accel_top common\tb\tb_accel_top.sv
echo.

REM -----------------------------------------------------------------------------
REM Summary
REM -----------------------------------------------------------------------------
echo =======================================================
echo   Test Summary
echo =======================================================
echo Passed: %PASSED%
echo Failed: %FAILED%
set /a TOTAL=%PASSED%+%FAILED%
echo Total:  %TOTAL%
echo.

if %FAILED% equ 0 (
    echo All tests passed!
    exit /b 0
) else (
    echo Some tests failed.
    echo Check logs in build\test_results\
    exit /b 1
)

REM =============================================================================
REM Subroutine: run_test
REM =============================================================================
:run_test
set TEST_NAME=%1
set TB_FILE=%2

REM Compile
xvlog -sv common\rtl\accel_pkg.sv ^
          common\rtl\bram_bank.sv ^
          common\rtl\memory_controller.sv ^
          common\rtl\addr_gen_unit.sv ^
          common\rtl\accel_controller.sv ^
          common\rtl\power_manager.sv ^
          common\rtl\clock_gate.sv ^
          %TB_FILE% ^
    > build\test_results\%TEST_NAME%_compile.log 2>&1

if errorlevel 1 (
    echo   X COMPILE FAILED
    echo   See build\test_results\%TEST_NAME%_compile.log
    set /a FAILED+=1
    goto :eof
)

REM Elaborate
xelab -debug typical %TEST_NAME% ^
    > build\test_results\%TEST_NAME%_elab.log 2>&1

if errorlevel 1 (
    echo   X ELABORATE FAILED
    echo   See build\test_results\%TEST_NAME%_elab.log
    set /a FAILED+=1
    goto :eof
)

REM Simulate
xsim %TEST_NAME% -R ^
    > build\test_results\%TEST_NAME%_sim.log 2>&1

if errorlevel 1 (
    echo   X SIMULATION FAILED
    echo   See build\test_results\%TEST_NAME%_sim.log
    set /a FAILED+=1
    goto :eof
)

REM Check for pass
findstr /i "pass" build\test_results\%TEST_NAME%_sim.log >nul
if %errorlevel% equ 0 (
    echo   PASSED
    set /a PASSED+=1
) else (
    echo   X FAILED
    echo   See build\test_results\%TEST_NAME%_sim.log
    set /a FAILED+=1
)

goto :eof
