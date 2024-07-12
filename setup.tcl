lappend search_path scripts design_data

set TECH_FILE     "../ref/tech/saed32nm_1p9m.tf"
set REFLIB        "../ref/CLIBs"

set REFERENCE_LIBRARY [join "
    $REFLIB/saed32_hvt.ndm
    $REFLIB/saed32_lvt.ndm
    $REFLIB/saed32_rvt.ndm
    $REFLIB/saed32_sram_lp.ndm
"]
