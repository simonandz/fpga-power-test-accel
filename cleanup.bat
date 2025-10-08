@echo off
REM cleanup.bat - Clean up temporary and log files from FPGA project

echo === FPGA Project Cleanup ===
echo Project directory: %CD%
echo.

REM 1. Remove backup log files
echo --- Cleaning backup logs ---
del /Q *.backup.log 2>nul
del /Q *.backup.jou 2>nul
del /Q build\*.backup.log 2>nul
del /Q build\*.backup.jou 2>nul
echo Backup logs cleaned

REM 2. Remove current log files
echo.
echo --- Cleaning current logs ---
del /Q vivado.log 2>nul
del /Q vivado.jou 2>nul
del /Q build\vivado.log 2>nul
del /Q build\vivado.jou 2>nul
del /Q build\xsim.log 2>nul
del /Q build\xsim.jou 2>nul
del /Q build\xvlog.log 2>nul
del /Q build\xelab.log 2>nul
echo Current logs cleaned

REM 3. Remove Xilinx temporary directories
echo.
echo --- Cleaning Xilinx temp directories ---
if exist .Xil (
    rmdir /S /Q .Xil
    echo .Xil removed
)
if exist xsim.dir (
    rmdir /S /Q xsim.dir
    echo xsim.dir removed
)
if exist build\xsim.dir (
    rmdir /S /Q build\xsim.dir
    echo build\xsim.dir removed
)
echo Temp directories cleaned

REM 4. Remove intermediate simulation files
echo.
echo --- Cleaning simulation intermediates ---
del /Q build\*.wdb 2>nul
del /Q build\*.pb 2>nul
del /Q build\run_simulation*.tcl 2>nul
if exist build\xsim (
    rmdir /S /Q build\xsim
    echo build\xsim removed
)
echo Simulation intermediates cleaned

REM 5. Remove temporary reports
echo.
echo --- Cleaning temporary reports ---
del /Q reports\temp_*.rpt 2>nul
del /Q design_nets_analysis.txt 2>nul
echo Temporary reports cleaned

echo.
echo === Cleanup Complete ===
echo.
echo Kept (important files):
echo   - Source files (common\rtl\, common\tb\)
echo   - Build outputs (build\*.dcp, build\*.bit)
echo   - Final reports (reports\*.rpt)
echo   - SAIF files (reports\*.saif)
echo   - Scripts (scripts\)
echo.
echo You can now commit to git or archive the project.
echo.
pause
