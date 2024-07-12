##########################################################################################
# Router
# Script: run.tcl
##########################################################################################

source -echo ./setup.tcl

create_lib -technology $TECH_FILE -ref_libs $REFERENCE_LIBRARY router.dlib

analyze -format verilog [glob router_rtl/*.v]

elaborate router_top
set_top_module router_top

###########################################################
## RC parasitics, placement site and routing layer setup
###########################################################

read_parasitic_tech -layermap ../ref/tech/saed32nm_tf_itf_tluplus.map -tlup ../ref/tech/saed32nm_1p9m_Cmax.lv.nxtgrd -name maxTLU
read_parasitic_tech -layermap ../ref/tech/saed32nm_tf_itf_tluplus.map -tlup ../ref/tech/saed32nm_1p9m_Cmin.lv.nxtgrd -name minTLU

report_lib -parasitic_tech router.dlib


## UPF ##
load_upf ./design_data/router.upf
commit_upf

check_mv_design


# Find available tie-cells
get_lib_cells -filter "function_id==a0.0"
get_lib_cells -filter "function_id==Ia0.0"

# Make tie-cells available to synthesis
set_dont_touch [get_lib_cells */TIE*] false
set_lib_cell_purpose -include optimization [get_lib_cells */TIE*]

## MCMM ##
source -echo ./design_data/mcmm_router.tcl

#reading SDC
read_sdc ./constraint/router.sdc


compile_fusion -from initial_map -to initial_map

compile_fusion -from logic_opto -to logic_opto

####Floorplanning####
initialize_floorplan -boundary {{44.063 -4.318} {166.534 94.804}} -core_offset {3}
set_app_options -name place.coarse.fix_hard_macros -value false
set_app_options -name plan.place.auto_create_blockages -value auto
create_placement -floorplan

compile_fusion -from initial_place -to initial_place
place_pins -self

compile_fusion -from initial_drc -to initial_drc

compile_fusion -from initial_opto -to initial_opto
get_scan_chain_count

#gui scan chains
check_legality
rt
report_optimization_history

compile_fusion -from final_place -to final_place
check_legality
report_qor -summary
report_power

compile_fusion -from final_opto -to final_opto
report_qor -summary
report_power

#powerplanning
connect_pg_net -automatic
create_pg_mesh_pattern mesh_pattern -layers { {{vertical_layer: M6} {width: 0.84} {pitch: 8.4} {spacing: interleaving}}  {{horizontal_layer: M7} {width: 0.84} {pitch: 8.4} {spacing: interleaving}} }
set_pg_strategy mesh_strategy -core -pattern {{pattern: mesh_pattern}{nets: {VDD VSS}}} -blockage {macros: all}
create_pg_std_cell_conn_pattern std_cell_pattern
set_pg_strategy std_cell_strategy -core -pattern {{pattern: std_cell_pattern}{nets: {VDD VSS}}}
compile_pg -ignore_via_drc

check_pg_drc
check_pg_connectivity




####################################
## Clock Tree Targets

report_clock_tree_options


####################################
## CTS Cell Selection

set CTS_CELLS [get_lib_cells "*/NBUFF*LVT */NBUFF*RVT */INVX*_LVT */INVX*_RVT */CGL* */LSUP* */*DFF*"]
set_dont_touch $CTS_CELLS false
set_lib_cell_purpose -exclude cts [get_lib_cells] 
set_lib_cell_purpose -include cts $CTS_CELLS



## CTS NDRs
####################################

source -echo ../lab_8a/scripts/ndr.tcl

report_routing_rules -verbose

report_clock_routing_rules


## Timing and DRC Setup
####################################

report_ports -verbose [get_ports *clock]
report_clocks -skew

###Change the uncertainty for all clocks in all scenarios
foreach_in_collection scen [all_scenarios] {
  current_scenario $scen
  set_clock_uncertainty 0.1 -setup [all_clocks]
  set_clock_uncertainty 0.05 -hold [all_clocks]
}

###Set a max transition for the clocks in func mode only
current_mode func
set_max_transition 0.15 -clock_path [get_clocks] -corners [all_corners]

set_app_options -name time.remove_clock_reconvergence_pessimism -value true

report_clock_settings

set_app_options -name clock_opt.flow.enable_ccd -value false
set_scenario_status [current_scenario] -hold true
report_timing -delay min
check_design -checks pre_clock_tree_stage

########################
clock_opt -to route_clock
clock_opt -from final_opto -to final_opto
save block

#################
route_auto
route_opt
check_routes
check_lvs
