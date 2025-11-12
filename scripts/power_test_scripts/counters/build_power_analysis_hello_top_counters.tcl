# build_power_analysis_hello_top_counters_fast.tcl
# Fast SAIF generation for hello_top_counters (behavioral sim)

# -------------------- Config --------------------
# How long to run (simulation time)
set SIM_TIME_US 200            ;# 200 us @100 MHz ≈ 20k cycles (tweak as needed)

# Threads for xelab (adjust to your CPU)
set XELAB_THREADS 8

# Optional: pass +define+ or parameters via xvlog here if needed
set XVLOG_EXTRA {}

# ---------------- Locate repo root ----------------
set _here [expr {[info script] ne "" ? [file dirname [info script]] : [pwd]}]
set script_dir [file normalize $_here]

set probe $script_dir
set repo_root ""
for {set i 0} {$i < 5} {incr i} {
    if {[file isdirectory [file join $probe common rtl]]} {
        set repo_root [file normalize $probe]
        break
    }
    set parent [file normalize [file join $probe ..]]
    if {$parent eq $probe} { break }
    set probe $parent
}
if {$repo_root eq ""} {
    return -code error "Could not locate repo root from $script_dir (no 'common/rtl' found up to 5 levels)"
}

# ---------------- Paths ----------------
set build_dir [file join $repo_root build hello_top_counters]
file mkdir $build_dir
cd $build_dir

set dut_rtl  [file join $repo_root common rtl power_test hello_top_counters]
set tb_sv    [file join $repo_root common tb hello_top_counters_tb.sv]

set rpt_dir  [file join $repo_root reports hello_top_counters]
file mkdir $rpt_dir

# Write SAIF to fast local disk first, then copy to repo
if {$::tcl_platform(platform) eq "windows"} {
    set saif_tmp  "C:/temp/hello_top_counters_timing.saif"
} else {
    set saif_tmp  "/tmp/hello_top_counters_timing.saif"
}
set saif_out [file join $rpt_dir hello_top_counters.saif]

puts "========================================"
puts "Fast SAIF Flow for hello_top_counters"
puts "Repo:        $repo_root"
puts "Work dir:    [pwd]"
puts "DUT RTL:     $dut_rtl"
puts "Testbench:   $tb_sv"
puts "SAIF (tmp):  $saif_tmp"
puts "SAIF (repo): $saif_out"
puts "Run time:    ${SIM_TIME_US}us"
puts "========================================"

# ---------------- Verify inputs ----------------
foreach f [list $tb_sv] {
    if {![file exists $f]} { error "File not found: $f" }
}
if {![file isdirectory $dut_rtl]} { error "RTL folder not found: $dut_rtl" }

# ---------------- Clean previous sim ----------------
if {[file exists "xsim.dir"]} {
    puts "Cleaning previous xsim build..."
    file delete -force "xsim.dir"
}
foreach f [glob -nocomplain *hello_top_counters_sim.wdb] { file delete -force $f }

# ---------------- Compile ----------------
puts "\n== Step 1: Compiling design and testbench =="
# Compile all .sv/.v under dut_rtl
set rtl_files [glob -nocomplain -directory $dut_rtl -types f -tails *.sv *.v]
if {[llength $rtl_files] == 0} { error "No RTL files found in $dut_rtl" }

if {[catch {
    foreach rf $rtl_files {
        exec xvlog -sv {*}$XVLOG_EXTRA [file join $dut_rtl $rf]
    }
    exec xvlog -sv $tb_sv
} emsg]} { error "Compilation failed:\n$emsg" }

puts "Compilation OK."

# ---------------- Elaborate ----------------
puts "\n== Step 2: Elaborating =="
# Try common TB module names without spamming the console
set elab_ok 0
foreach tbmod {hello_top_counters_tb tb_hello_top_counters} {
    if {!$elab_ok} {
        if {[catch {
            exec xelab -timescale 1ns/1ps -debug typical -mt $XELAB_THREADS \
                $tbmod -s hello_top_counters_sim
        } emsg]} {
            puts "  Failed with $tbmod"
        } else {
            set elab_ok 1
            set TBMOD $tbmod
            puts "  Elaborated with top testbench: $TBMOD"
        }
    }
}
if {!$elab_ok} { error "Elaboration failed with known TB names." }

# ---------------- Generate run script ----------------
puts "\n== Step 3: Sim & SAIF =="
set sim_tcl [file join $build_dir run_saif_temp.tcl]
set fh [open $sim_tcl w]

puts $fh "# Auto-generated: run SAIF quickly"
puts $fh "puts \"Starting XSim run for SAIF...\""
puts $fh "run 1 ns"

# Use the known testbench top module name directly
puts $fh "set top /${TBMOD}"
puts $fh "puts \"Top scope: \$top\""

# Let the testbench's own clock/reset run (it has always blocks)
puts $fh "puts \"Letting testbench initialize...\""
puts $fh "run 100 ns"

# Use the DUT instance directly (testbench instantiates as 'dut')
puts $fh "set dut_scope \${top}/dut"
puts $fh "puts \"Logging SAIF under: \$dut_scope\""

# Open SAIF and log (bounded to DUT subtree)
puts $fh "catch { close_saif }"
puts $fh "open_saif \"$saif_tmp\""
puts $fh "if {\[catch { log_saif \[get_objects -r \${dut_scope}/*\] } e\]} {"
puts $fh "  puts \"log_saif failed: \$e\""
puts $fh "  # Fallback: log everything (can be larger)"
puts $fh "  log_saif \[get_objects -r /*\]"
puts $fh "}"

# Run shorter window
puts $fh "puts \"Run ${SIM_TIME_US}us for activity...\""
puts $fh "run ${SIM_TIME_US} us"

puts $fh "close_saif"
puts $fh "puts \"SAIF written: $saif_tmp\""
puts $fh "quit"
close $fh

# ---------------- Run xsim batch ----------------
if {[catch {
    exec xsim hello_top_counters_sim -tclbatch $sim_tcl
} emsg]} {
    # xsim sometimes returns non-zero even if SAIF produced; continue to check file
    puts "xsim returned non-zero: $emsg"
}

# ---------------- Copy SAIF to repo ----------------
if {![file exists $saif_tmp]} {
    error "SAIF file not generated: $saif_tmp"
}
file copy -force $saif_tmp $saif_out
puts "\n========================================"
puts "SAIF ready: $saif_out"
puts "========================================"
