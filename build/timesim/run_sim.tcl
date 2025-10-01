
    # Initialize simulation
    when -label init_sim { \$now == 0 } {
        puts "Simulation started at time: \$now"
    }
    
    # Setup SAIF logging
    catch { close_saif }
    open_saif "$SAIF_OUT"
    log_saif [get_objects -r *]
    
    # Optional: Setup VCD logging  
    catch { close_vcd }
    open_vcd "$VCD_OUT"
    log_vcd [get_objects -r *]
    
    # Run simulation (adjust time as needed)
    run 5 ms
    
    # Close files
    close_saif
    close_vcd
    puts "Simulation completed at time: \$now"
    quit

