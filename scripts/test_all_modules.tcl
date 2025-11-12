# Comprehensive Test Script for All Modules
# Tests shared modules (common/rtl) and MLP modules
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

set mlp_rtl     [file normalize [file join $repo_root mlp rtl]]
set mlp_tb      [file normalize [file join $repo_root mlp tb]]
set mlp_results [file normalize [file join $repo_root mlp results]]

set build_dir   [file normalize [file join $repo_root build test_all]]

puts "========================================"
puts "Comprehensive Module Test Suite"
puts "========================================"
puts "repo_root:       $repo_root"
puts "common_results:  $common_results"
puts "mlp_results:     $mlp_results"
puts "build_dir:       $build_dir"
puts "========================================\n"

# Create directories
file mkdir $build_dir
file mkdir $common_results
file mkdir $mlp_results

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
        # Check if it's a real error or just normal exit
        if {[string match "*FAIL*" $result] || [string match "*ERROR*" $result]} {
            puts "SIMULATION FAILED"
            puts $result
            incr failed_tests

            # Save failed results
            if {[file exists xsim.log]} {
                file copy -force xsim.log [file join $results_dir ${test_name}_FAILED.log]
            }
            return 0
        }
    }

    # Check results
    puts $result
    if {[string match "*ALL TESTS PASSED*" $result]} {
        puts "\n✓ Test PASSED: $test_name"
        incr passed_tests

        # Save successful results
        if {[file exists xsim.log]} {
            file copy -force xsim.log [file join $results_dir ${test_name}.log]
        }
        if {[file exists xvlog.log]} {
            file copy -force xvlog.log [file join $results_dir ${test_name}_compile.log]
        }
        return 1
    } else {
        puts "\n✗ Test FAILED: $test_name"
        incr failed_tests

        # Save failed results
        if {[file exists xsim.log]} {
            file copy -force xsim.log [file join $results_dir ${test_name}_FAILED.log]
        }
        return 0
    }
}

#============================================================================
# Test Common Modules
#============================================================================

puts "\n###################################"
puts "# TESTING COMMON/SHARED MODULES"
puts "###################################\n"

# Test 1: fixed_point_pkg
run_test "fixed_point_pkg" \
    [list "$common_rtl/fixed_point_pkg.sv"] \
    "$common_tb/tb_fixed_point_pkg.sv" \
    "$common_results"

# Test 2: mac_array_8x
run_test "mac_array_8x" \
    [list "$common_rtl/mac_array_8x.sv"] \
    "$common_tb/tb_mac_array_8x.sv" \
    "$common_results"

# Test 3: activation_unit (requires fixed_point_pkg)
run_test "activation_unit" \
    [list "$common_rtl/fixed_point_pkg.sv" "$common_rtl/activation_unit.sv"] \
    "$common_tb/tb_activation_unit.sv" \
    "$common_results"

#============================================================================
# Test MLP Modules
#============================================================================

puts "\n###################################"
puts "# TESTING MLP MODULES"
puts "###################################\n"

# Test 4: mlp_memory_subsystem
run_test "mlp_memory_subsystem" \
    [list "$mlp_rtl/mlp_memory_subsystem.sv"] \
    "$mlp_tb/tb_mlp_memory_subsystem.sv" \
    "$mlp_results"

# Test 5: mlp_compute_datapath
run_test "mlp_compute_datapath" \
    [list "$common_rtl/fixed_point_pkg.sv" \
          "$common_rtl/mac_array_8x.sv" \
          "$common_rtl/activation_unit.sv" \
          "$mlp_rtl/mlp_compute_datapath.sv"] \
    "$mlp_tb/tb_mlp_compute_datapath.sv" \
    "$mlp_results"

# Test 6: mlp_top (integration - requires all modules)
run_test "mlp_top" \
    [list "$common_rtl/fixed_point_pkg.sv" \
          "$common_rtl/mac_array_8x.sv" \
          "$common_rtl/activation_unit.sv" \
          "$mlp_rtl/mlp_memory_subsystem.sv" \
          "$mlp_rtl/mlp_compute_datapath.sv" \
          "$mlp_rtl/mlp_controller.sv" \
          "$mlp_rtl/mlp_top.sv"] \
    "$mlp_tb/tb_mlp_top.sv" \
    "$mlp_results"

#============================================================================
# Final Summary
#============================================================================

puts "\n========================================"
puts "TEST SUITE SUMMARY"
puts "========================================"
puts "Total tests:  $total_tests"
puts "Passed:       $passed_tests"
puts "Failed:       $failed_tests"
puts "========================================"

puts "\nResults saved to:"
puts "  Common: $common_results"
puts "  MLP:    $mlp_results"

if {$failed_tests == 0} {
    puts "\n✓✓✓ ALL TESTS PASSED ✓✓✓"
} else {
    puts "\n✗✗✗ SOME TESTS FAILED ✗✗✗"
}
puts "========================================\n"
