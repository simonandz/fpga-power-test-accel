# Comprehensive Test Script for CNN Modules
# Tests shared modules (mac_array_9x, maxpool_2x2) and CNN modules
# Saves all results to respective results directories

# Auto-detect repo root
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
    return -code error "Could not locate repo root from $script_dir"
}

# Set paths
set common_rtl  [file normalize [file join $repo_root common rtl]]
set common_tb   [file normalize [file join $repo_root common tb]]
set common_results [file normalize [file join $repo_root common results]]

set cnn_rtl     [file normalize [file join $repo_root cnn rtl]]
set cnn_tb      [file normalize [file join $repo_root cnn tb]]
set cnn_results [file normalize [file join $repo_root cnn results]]

set build_dir   [file normalize [file join $repo_root build test_all_cnn]]

puts "========================================"
puts "CNN Module Test Suite"
puts "========================================"
puts "repo_root:       $repo_root"
puts "common_results:  $common_results"
puts "cnn_results:     $cnn_results"
puts "build_dir:       $build_dir"
puts "========================================\n"

# Create directories
file mkdir $build_dir
file mkdir $common_results
file mkdir $cnn_results

# Test counter
set total_tests 0
set passed_tests 0
set failed_tests 0

# Procedure to run a single test
proc run_test {test_name rtl_files tb_file results_dir} {
    global build_dir total_tests passed_tests failed_tests

    incr total_tests
    puts "\n========================================"
    puts "Test $total_tests: $test_name"
    puts "========================================\n"

    cd $build_dir

    # Clean
    file delete -force xsim.dir
    catch {file delete -force *.jou *.log *.pb *.wdb}

    # Compile RTL
    puts "\[1/4\] Compiling RTL files..."
    foreach rtl $rtl_files {
        if {[file exists $rtl]} {
            puts "  Compiling: $rtl"
            if {[catch {exec xvlog -sv $rtl} result]} {
                puts "ERROR: RTL compilation failed"
                puts $result
                incr failed_tests
                return 0
            }
        } else {
            puts "ERROR: RTL file not found: $rtl"
            incr failed_tests
            return 0
        }
    }

    # Compile testbench
    puts "\n\[2/4\] Compiling testbench..."
    if {![file exists $tb_file]} {
        puts "ERROR: Testbench not found: $tb_file"
        incr failed_tests
        return 0
    }
    puts "  Compiling: $tb_file"
    if {[catch {exec xvlog -sv $tb_file} result]} {
        puts "ERROR: Testbench compilation failed"
        puts $result
        incr failed_tests
        return 0
    }

    # Elaborate
    puts "\n\[3/4\] Elaborating design..."
    set tb_module [file rootname [file tail $tb_file]]
    if {[catch {exec xelab $tb_module -debug typical -s ${test_name}_sim} result]} {
        puts "ERROR: Elaboration failed"
        puts $result
        incr failed_tests
        return 0
    }

    # Simulate
    puts "\n\[4/4\] Running simulation..."
    set sim_tcl [file join $build_dir run_${test_name}.tcl]
    set sim_fh [open $sim_tcl w]
    puts $sim_fh "run all"
    puts $sim_fh "quit"
    close $sim_fh

    if {[catch {exec xsim ${test_name}_sim -tclbatch $sim_tcl} result]} {
        if {[string match "*FAIL*" $result] || [string match "*ERROR*" $result]} {
            puts "SIMULATION FAILED"
            puts $result
            incr failed_tests

            if {[file exists xsim.log]} {
                file copy -force xsim.log [file join $results_dir ${test_name}_FAILED.log]
            }
            return 0
        }
    }

    # Check results
    puts $result
    if {[string match "*ALL TESTS PASSED*" $result]} {
        puts "\n  Test PASSED: $test_name"
        incr passed_tests

        if {[file exists xsim.log]} {
            file copy -force xsim.log [file join $results_dir ${test_name}.log]
        }
        return 1
    } else {
        puts "\n  Test FAILED: $test_name"
        incr failed_tests

        if {[file exists xsim.log]} {
            file copy -force xsim.log [file join $results_dir ${test_name}_FAILED.log]
        }
        return 0
    }
}

#============================================================================
# Test Shared Modules (new for CNN)
#============================================================================

puts "\n###################################"
puts "# TESTING COMMON/SHARED MODULES"
puts "###################################\n"

# Test 1: mac_array_9x
run_test "mac_array_9x" \
    [list "$common_rtl/mac_array_9x.sv"] \
    "$common_tb/tb_mac_array_9x.sv" \
    "$common_results"

# Test 2: maxpool_2x2
run_test "maxpool_2x2" \
    [list "$common_rtl/maxpool_2x2.sv"] \
    "$common_tb/tb_maxpool_2x2.sv" \
    "$common_results"

#============================================================================
# Test CNN Modules
#============================================================================

puts "\n###################################"
puts "# TESTING CNN MODULES"
puts "###################################\n"

# Test 3: cnn_memory_subsystem
run_test "cnn_memory_subsystem" \
    [list "$cnn_rtl/cnn_memory_subsystem.sv"] \
    "$cnn_tb/tb_cnn_memory_subsystem.sv" \
    "$cnn_results"

# Test 4: cnn_compute_datapath
run_test "cnn_compute_datapath" \
    [list "$common_rtl/mac_array_9x.sv" \
          "$common_rtl/activation_unit.sv" \
          "$common_rtl/maxpool_2x2.sv" \
          "$cnn_rtl/cnn_compute_datapath.sv"] \
    "$cnn_tb/tb_cnn_compute_datapath.sv" \
    "$cnn_results"

# Test 5: cnn_top (full integration - requires all modules)
run_test "cnn_top" \
    [list "$common_rtl/mac_array_9x.sv" \
          "$common_rtl/activation_unit.sv" \
          "$common_rtl/maxpool_2x2.sv" \
          "$cnn_rtl/cnn_memory_subsystem.sv" \
          "$cnn_rtl/cnn_compute_datapath.sv" \
          "$cnn_rtl/cnn_controller.sv" \
          "$cnn_rtl/cnn_top.sv"] \
    "$cnn_tb/tb_cnn_top.sv" \
    "$cnn_results"

#============================================================================
# Final Summary
#============================================================================

puts "\n========================================"
puts "CNN TEST SUITE SUMMARY"
puts "========================================"
puts "Total tests:  $total_tests"
puts "Passed:       $passed_tests"
puts "Failed:       $failed_tests"
puts "========================================"

puts "\nResults saved to:"
puts "  Common: $common_results"
puts "  CNN:    $cnn_results"

if {$failed_tests == 0} {
    puts "\n    ALL TESTS PASSED"
} else {
    puts "\n    SOME TESTS FAILED"
}
puts "========================================\n"
