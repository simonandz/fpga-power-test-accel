@echo off
REM Full benchmark flow for MLP accelerator
REM Runs simulation, synthesis, implementation, and generates reports

echo ================================================================
echo MLP Full Benchmark Flow
echo ================================================================
echo.

REM Check if Vivado is in PATH
where vivado >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Vivado not found in PATH
    echo Please run from Vivado command prompt or add Vivado to PATH
    exit /b 1
)

REM Create output directories
if not exist reports\benchmark mkdir reports\benchmark

echo Step 1: Running Vivado benchmark flow...
echo.
vivado -mode batch -source scripts/run_benchmark.tcl -log reports/benchmark/vivado.log -journal reports/benchmark/vivado.jou

echo.
echo Step 2: Extracting metrics...
echo.
python scripts/extract_metrics.py mlp

echo.
echo ================================================================
echo Benchmark complete! Check reports/benchmark/ for results
echo ================================================================
