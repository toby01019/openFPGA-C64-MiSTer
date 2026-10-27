# The APF file creates primary clocks and derives PLL clocks before reading this.
set core_clocks [get_clocks {*mp1*}]
set_clock_groups -asynchronous -group {bridge_spiclk} -group {clk_74b} -group [add_to_collection [get_clocks clk_74a] $core_clocks]
# Single-bit synchronizer first stages. Payload buses use held-data handshakes.
set_false_path -to [get_registers {*|*meta*}]
# Bound held-data CDC routing below the handshake synchronization latency.
set_max_delay -from [get_clocks clk_74a] -to $core_clocks 20.0
set_max_delay -from $core_clocks -to [get_clocks clk_74a] 20.0
set_min_delay -from [get_clocks clk_74a] -to $core_clocks 0.0
set_min_delay -from $core_clocks -to [get_clocks clk_74a] 0.0
derive_clock_uncertainty
# Reserve 100 ps on same-edge core-clock hold paths. The dense 72-KiB
# cartridge build exposed a -15 ps envelope-register -> SID DSP hold path.
# This tightens the router's requirement (it does not waive that path).
# '?' matches the literal brackets around output counter [2].
set c64_clock [get_clocks {*mp1*general?2?*divclk}]
if {[get_collection_size $c64_clock] != 1} {
    error "Expected exactly one 31.53-MHz C64 clock for hold guard band"
}
set_clock_uncertainty -hold -enable_same_physical_edge -add \
    -from $c64_clock -to $c64_clock 0.100
