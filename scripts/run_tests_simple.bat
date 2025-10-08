@echo off
REM =============================================================================
REM Simplified test script that handles spaces in Icarus path
REM =============================================================================

setlocal

REM Set the full path to iverilog (adjust if different)
set "IVERILOG_PATH=R:\icarus_verilog\iverilog\iverilog\bin"
set "PATH=%IVERILOG_PATH%;%PATH%"

echo =======================================================
echo   Accelerator Infrastructure Test Suite
echo =======================================================
echo.

REM Verify iverilog works
"%IVERILOG_PATH%\iverilog" -v >nul 2>&1
if errorlevel 1 (
    echo ERROR: Cannot find iverilog at: %IVERILOG_PATH%
    echo Please edit this script and set IVERILOG_PATH correctly
    pause
    exit /b 1
)

cd /d "%~dp0\.."
if not exist "build\test_results" mkdir "build\test_results"

set PASSED=0
set FAILED=0

REM =============================================================================
REM Test 1: Memory Controller
REM =============================================================================
echo Running: Memory Controller Test
echo -------------------------------------------------------

"%IVERILOG_PATH%\iverilog" -g2012 -o "build\test_results\test1.vvp" ^
    common\rtl\accel_pkg.sv ^
    common\rtl\bram_bank.sv ^
    common\rtl\memory_controller.sv ^
    common\tb\tb_memory_controller.sv ^
    > "build\test_results\tb_memory_controller_compile.log" 2>&1

if errorlevel 1 (
    echo   X COMPILE FAILED
    type "build\test_results\tb_memory_controller_compile.log"
    set /a FAILED+=1
) else (
    "%IVERILOG_PATH%\vvp" "build\test_results\test1.vvp" > "build\test_results\tb_memory_controller_sim.log" 2>&1
    findstr /i "pass" "build\test_results\tb_memory_controller_sim.log" >nul
    if errorlevel 1 (
        echo   X FAILED
        set /a FAILED+=1
    ) else (
        echo   PASSED
        set /a PASSED+=1
    )
)
echo.

REM =============================================================================
REM Test 2: Address Generator
REM =============================================================================
echo Running: Address Generator Test
echo -------------------------------------------------------

"%IVERILOG_PATH%\iverilog" -g2012 -o "build\test_results\test2.vvp" ^
    common\rtl\accel_pkg.sv ^
    common\rtl\addr_gen_unit.sv ^
    common\tb\tb_addr_gen_unit.sv ^
    > "build\test_results\tb_addr_gen_unit_compile.log" 2>&1

if errorlevel 1 (
    echo   X COMPILE FAILED
    type "build\test_results\tb_addr_gen_unit_compile.log"
    set /a FAILED+=1
) else (
    "%IVERILOG_PATH%\vvp" "build\test_results\test2.vvp" > "build\test_results\tb_addr_gen_unit_sim.log" 2>&1
    findstr /i "pass" "build\test_results\tb_addr_gen_unit_sim.log" >nul
    if errorlevel 1 (
        echo   X FAILED
        set /a FAILED+=1
    ) else (
        echo   PASSED
        set /a PASSED+=1
    )
)
echo.

REM =============================================================================
REM Test 3: Power Manager
REM =============================================================================
echo Running: Power Manager Test
echo -------------------------------------------------------

"%IVERILOG_PATH%\iverilog" -g2012 -o "build\test_results\test3.vvp" ^
    common\rtl\accel_pkg.sv ^
    common\rtl\power_manager.sv ^
    common\tb\tb_power_manager.sv ^
    > "build\test_results\tb_power_manager_compile.log" 2>&1

if errorlevel 1 (
    echo   X COMPILE FAILED
    type "build\test_results\tb_power_manager_compile.log"
    set /a FAILED+=1
) else (
    "%IVERILOG_PATH%\vvp" "build\test_results\test3.vvp" > "build\test_results\tb_power_manager_sim.log" 2>&1
    findstr /i "pass" "build\test_results\tb_power_manager_sim.log" >nul
    if errorlevel 1 (
        echo   X FAILED
        set /a FAILED+=1
    ) else (
        echo   PASSED
        set /a PASSED+=1
    )
)
echo.

REM =============================================================================
REM Test 4: Accelerator Controller
REM =============================================================================
echo Running: Accelerator Controller Test
echo -------------------------------------------------------

"%IVERILOG_PATH%\iverilog" -g2012 -o "build\test_results\test4.vvp" ^
    common\rtl\accel_pkg.sv ^
    common\rtl\bram_bank.sv ^
    common\rtl\memory_controller.sv ^
    common\rtl\addr_gen_unit.sv ^
    common\rtl\accel_controller.sv ^
    common\tb\tb_accel_controller.sv ^
    > "build\test_results\tb_accel_controller_compile.log" 2>&1

if errorlevel 1 (
    echo   X COMPILE FAILED
    type "build\test_results\tb_accel_controller_compile.log"
    set /a FAILED+=1
) else (
    "%IVERILOG_PATH%\vvp" "build\test_results\test4.vvp" > "build\test_results\tb_accel_controller_sim.log" 2>&1
    findstr /i "pass" "build\test_results\tb_accel_controller_sim.log" >nul
    if errorlevel 1 (
        echo   X FAILED
        set /a FAILED+=1
    ) else (
        echo   PASSED
        set /a PASSED+=1
    )
)
echo.

REM =============================================================================
REM Test 5: Integration Test
REM =============================================================================
echo Running: Integration Test
echo -------------------------------------------------------

"%IVERILOG_PATH%\iverilog" -g2012 -o "build\test_results\test5.vvp" ^
    common\rtl\accel_pkg.sv ^
    common\rtl\bram_bank.sv ^
    common\rtl\memory_controller.sv ^
    common\rtl\addr_gen_unit.sv ^
    common\rtl\accel_controller.sv ^
    common\rtl\power_manager.sv ^
    common\rtl\clock_gate.sv ^
    common\rtl\accel_top.sv ^
    common\tb\tb_accel_top.sv ^
    > "build\test_results\tb_accel_top_compile.log" 2>&1

if errorlevel 1 (
    echo   X COMPILE FAILED
    type "build\test_results\tb_accel_top_compile.log"
    set /a FAILED+=1
) else (
    "%IVERILOG_PATH%\vvp" "build\test_results\test5.vvp" > "build\test_results\tb_accel_top_sim.log" 2>&1
    findstr /i "pass" "build\test_results\tb_accel_top_sim.log" >nul
    if errorlevel 1 (
        echo   X FAILED
        set /a FAILED+=1
    ) else (
        echo   PASSED
        set /a PASSED+=1
    )
)
echo.

REM =============================================================================
REM Summary
REM =============================================================================
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
) else (
    echo Some tests failed. Check logs in build\test_results\
)

pause
