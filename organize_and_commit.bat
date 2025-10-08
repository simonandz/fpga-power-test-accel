@echo off
REM organize_and_commit.bat - Clean up and prepare for git commit

echo === FPGA Project Organization and Git Commit ===
echo.

REM Step 1: Clean up temporary files
echo Step 1: Running cleanup...
call cleanup.bat
echo.

REM Step 2: Add .gitignore
echo Step 2: Adding .gitignore...
git add .gitignore
echo .gitignore added
echo.

REM Step 3: Add important new files
echo Step 3: Adding important source files and scripts...

REM Add new testbench
git add common/tb/hello_tb_postsyn.sv

REM Add all new power analysis scripts
git add scripts/power_test_scripts/hybrid_fixed.tcl
git add scripts/power_test_scripts/manual_activity_correct.tcl
git add scripts/power_test_scripts/analyze_design_nets.tcl
git add scripts/power_test_scripts/vivado_power_report.tcl

REM Add cleanup scripts
git add cleanup.bat
git add cleanup.sh

REM Add updated README
git add README.md

echo Source files and scripts added
echo.

REM Step 4: Add modified files (selectively)
echo Step 4: Adding modified important files...
git add scripts/power_test_scripts/build_power_analysis.tcl

REM Add final power reports (not test reports)
git add reports/hello_top_power_saif.rpt
git add reports/hello_top_power_hybrid_fixed.rpt

echo Modified files added
echo.

REM Step 5: Check status
echo Step 5: Current git status:
echo.
git status
echo.

REM Step 6: Show what will be committed
echo ========================================
echo Files staged for commit:
git diff --cached --name-status
echo ========================================
echo.

echo Ready to commit!
echo.
echo Suggested commit message:
echo "Add comprehensive power analysis framework with multiple methodologies"
echo.
echo Run this command to commit:
echo git commit -m "Add comprehensive power analysis framework with multiple methodologies"
echo.
echo Then push with:
echo git push origin main
echo.
pause
