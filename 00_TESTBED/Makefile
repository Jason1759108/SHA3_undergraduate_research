#===============================================================================
# VSPLAB ASIC Design Flow Makefile
# Supports: VCS, Cadence (irun/xrun), Verdi, Design Compiler, PrimeTime, Innovus
# Author:   Qun-Kai Lin
# Date:     2026/05/13
#===============================================================================

.PHONY: vcs_rtl vcs_gate vcs_post \
				irun_rtl irun_gate irun_post \
				xrun_rtl xrun_gate xrun_post \
				nWave verdi_rtl verdi_gate \
				setup_dc syn syn_gui check_rtl view_netlist pt apr_init clean

#-------------------------------------------------------------------------------
# 1. Project Configuration
#-------------------------------------------------------------------------------
TOP_DESIGN  = SHA3
SRC_FILE    = "filelist.f"
OUTPUT_NAME = "simv"
LOG_VCS     = "vcs.log"
RC_FILE     = "signal.rc"

# Synthesis & Timing logs/scripts
SYN_TCL     = "syn.tcl"
SYN_LOG     = "syn.log"
PT_TCL      = "pt.tcl"
PT_LOG      = "pt.log"

# Hardware Resources
CPU_CORES   = 4

#-------------------------------------------------------------------------------
# 2. Tool Paths & Simulation Libraries
#-------------------------------------------------------------------------------
VERDI_HOME ?= /usr/cad/synopsys/verdi/cur2/
DW_SIM_LIB ?= /usr/cad/synopsys/synthesis/cur/dw/sim_ver/

# Process Selection
PROCESS ?= TSMC40

# --- TSMC 16nm Settings ---
TSMC16_SIM    = /usr/cad/TN16FFC_P/PDK/process/TN16FFC/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/orig_lib/TSMCHOME/digital/Front_End/verilog/tcbn16ffcllbwp16p90_100a/tcbn16ffcllbwp16p90.v
TSMC16_SEARCH = ./ ../01_RTL ../04_MEM \
                /usr/cad/TN16FFC_P/PDK/process/TN16FFC/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/orig_lib/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn16ffcllbwp16p90_100a/ \
                /usr/cad/TN16FFC_P/PDK/process/TN16FFC/IP/CBTK_TSMC16FFC_core_TSMC_v2.0/orig_lib/TSMCHOME/sram/Compiler/ \
                /usr/cad/synopsys/synthesis/cur/libraries/syn/ \
                /usr/cad/synopsys/synthesis/cur/dw/
TSMC16_TARGET = tcbn16ffcllbwp16p90tt0p8v25c.db \
                ts6n16ffcllulvtb256x128m1wbsho_120a_tt0p8v25c.db \
                ts6n16ffcllulvtb64x128m1wbsho_120a_tt0p8v25c.db \
                ts6n16ffcllulvtb128x32m1wbsho_120a_tt0p8v25c.db

# --- TSMC 28nm Settings ---
TSMC28_SIM    = /raidj/user/t28/t28adm/0_Process/HPC_PLUSE/Library/HVT_9track/TSMCHOME/digital/Front_End/verilog/tcbn28hpcplusbwp30p140hvt_110a/tcbn28hpcplusbwp30p140hvt.v
TSMC28_SEARCH = ./ ../01_RTL ../04_MEM \
                /raidj/user/t28/t28adm/0_Process/HPC_PLUSE/Library/HVT_9track/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn28hpcplusbwp30p140hvt_110c/ \
                /usr/cad/synopsys/synthesis/cur/libraries/syn/ \
                /usr/cad/synopsys/synthesis/cur/dw/
TSMC28_TARGET = tcbn28hpcplusbwp30p140hvttt0p9v25c.db

# --- TSMC 40nm Settings ---
TSMC40_SIM    = /usr/cad/CBDK_TSMC40_Arm_f2.0/CIC/Verilog/sc9_cln40g_base_rvt_neg.v \
                /usr/cad/CBDK_TSMC40_Arm_f2.0/CIC/Verilog/sc9_cln40g_base_rvt_udp.v
TSMC40_SEARCH = ./ ../01_RTL ../04_MEM \
                /usr/cad/CBDK_TSMC40_Arm_f2.0/CIC/SynopsysDC/db/sc9_base_rvt/ \
                /usr/cad/synopsys/synthesis/cur/libraries/syn/ \
                /usr/cad/synopsys/synthesis/cur/dw/
TSMC40_TARGET = sc9_cln40g_base_rvt_tt_typical_max_0p90v_25c.db

# --- UMC 180nm Settings ---
UMC018_SIM    = /usr/cad/UMC018/verilog/umc18_neg.v
UMC018_SEARCH = ./ ../01_RTL ../04_MEM \
                /usr/cad/UMC018/Synthesis/ \
                /usr/cad/synopsys/synthesis/cur/libraries/syn/ \
                /usr/cad/synopsys/synthesis/cur/dw/
UMC018_TARGET = slow.db

# --- Selection Logic ---
ifeq ($(PROCESS), TSMC16)
  TECH_SIM       = $(TSMC16_SIM)
  DC_SEARCH_PATH = $(TSMC16_SEARCH)
  DC_TARGET_LIB  = $(TSMC16_TARGET)
else ifeq ($(PROCESS), TSMC28)
  TECH_SIM       = $(TSMC28_SIM)
  DC_SEARCH_PATH = $(TSMC28_SEARCH)
  DC_TARGET_LIB  = $(TSMC28_TARGET)
else ifeq ($(PROCESS), TSMC40)
  TECH_SIM       = $(TSMC40_SIM)
  DC_SEARCH_PATH = $(TSMC40_SEARCH)
  DC_TARGET_LIB  = $(TSMC40_TARGET)
else ifeq ($(PROCESS), UMC018)
  TECH_SIM       = $(UMC018_SIM)
  DC_SEARCH_PATH = $(UMC018_SEARCH)
  DC_TARGET_LIB  = $(UMC018_TARGET)
endif

# Simulation Settings
TIMESCALE     = -timescale=1ns/1fs
TIMESCALE_C   = -timescale 1ns/1fs # Cadence format

#-------------------------------------------------------------------------------
# 3. Tool Commands & Options
#-------------------------------------------------------------------------------

# Define handler
VCS_DEF = $(foreach d, $(define), +define+$(d))
CAD_DEF = $(foreach d, $(define), -define $(d))

# --- Synopsys VCS ---
VCS_COMMON_OPTS = vcs $(TIMESCALE) \
                      -j$(CPU_CORES) \
                      -sverilog +v2k -full64 \
                      -Mupdate -R \
                      -debug_access+all \
                      -f $(SRC_FILE) \
                      -o $(OUTPUT_NAME) \
                      -l $(LOG_VCS)

VCS_RTL_SIM  = $(VCS_COMMON_OPTS) +define+RTL $(VCS_DEF) -y $(DW_SIM_LIB) +incdir+$(DW_SIM_LIB) +libext+.v +notimingchecks -debug_region+cell+encrypt
VCS_GATE_SIM = $(VCS_COMMON_OPTS) +define+GATE $(VCS_DEF) -v $(TECH_SIM) +neg_tchk +nowarnNTCDSN
VCS_POST_SIM = $(VCS_COMMON_OPTS) +define+POST $(VCS_DEF) -v $(TECH_SIM) +neg_tchk +maxdelays

# --- Cadence Irun / Xrun ---
CAD_COMMON      = -f $(SRC_FILE) -loadpli1 debpli:novas_pli_boot -debug $(CAD_DEF)

IRUN_COMMON_OPTS = irun $(CAD_COMMON) $(TIMESCALE_C) -override_precision -sdf_precision 1fs
IRUN_RTL_SIM     = $(IRUN_COMMON_OPTS) -incdir $(DW_SIM_LIB) -notimingchecks -define RTL
IRUN_GATE_SIM    = $(IRUN_COMMON_OPTS) -v $(TECH_SIM) -define GATE
IRUN_POST_SIM    = $(IRUN_COMMON_OPTS) -v $(TECH_SIM) -maxdelays -define POST

XRUN_COMMON_OPTS = xrun $(CAD_COMMON) -mcl $(CPU_CORES) $(TIMESCALE_C) -override_precision -sdf_precision 1fs
XRUN_RTL_SIM     = $(XRUN_COMMON_OPTS) -incdir $(DW_SIM_LIB) -notimingchecks -define RTL
XRUN_GATE_SIM    = $(XRUN_COMMON_OPTS) -v $(TECH_SIM) -define GATE
XRUN_POST_SIM    = $(XRUN_COMMON_OPTS) -v $(TECH_SIM) -maxdelays -define POST

# --- Debug Tools (Verdi / nWave) ---
VERDI_OPTS   = -ssf *.fsdb -sv -f $(SRC_FILE) -nologo +v2k -autoalias \
               $(shell [ -f $(RC_FILE) ] && echo "-sswr $(RC_FILE)")

#-------------------------------------------------------------------------------
# 4. Simulation Targets
#-------------------------------------------------------------------------------

# Run Synopsys VCS RTL simulation (behavioral level)
vcs_rtl:
	$(VCS_RTL_SIM)

# Run Synopsys VCS Gate-level simulation (after synthesis, with cell library)
vcs_gate:
	$(VCS_GATE_SIM)

# Run Synopsys VCS Post-layout simulation (after APR, with SDF timing)
vcs_post:
	$(VCS_POST_SIM)

# Run Cadence irun RTL simulation
irun_rtl:
	$(IRUN_RTL_SIM)

# Run Cadence irun Gate-level simulation
irun_gate:
	$(IRUN_GATE_SIM)

# Run Cadence irun Post-layout simulation
irun_post:
	$(IRUN_POST_SIM)

# Run Cadence xrun RTL simulation (multi-core supported)
xrun_rtl:
	$(XRUN_RTL_SIM)

# Run Cadence xrun Gate-level simulation
xrun_gate:
	$(XRUN_GATE_SIM)

# Run Cadence xrun Post-layout simulation
xrun_post:
	$(XRUN_POST_SIM)

#-------------------------------------------------------------------------------
# 5. Debugging & Visualization
#-------------------------------------------------------------------------------

# Open nWave waveform viewer and load FSDB files
nWave:
	nWave -ssf *.fsdb $(shell [ -f $(RC_FILE) ] && echo "-sswr $(RC_FILE)") &

# Open Verdi for RTL code debugging and waveform linkage
verdi_rtl:
	verdi $(VERDI_OPTS) +define+RTL &

# Open Verdi for Gate-level debugging (linked with tech library)
verdi_gate:
	verdi $(VERDI_OPTS) +define+GATE &

#-------------------------------------------------------------------------------
# 6. Synthesis, Timing & APR
#-------------------------------------------------------------------------------

# Generate the .synopsys_dc.setup file based on the selected PROCESS
setup_dc:
	@echo "set search_path \" $(DC_SEARCH_PATH) \"" > .synopsys_dc.setup
	@echo "set target_library \" $(DC_TARGET_LIB) \"" >> .synopsys_dc.setup
	@echo "set link_library \" * \$$target_library dw_foundation.sldb standard.sldb \"" >> .synopsys_dc.setup
	@echo "set symbol_library \" *.sdb \"" >> .synopsys_dc.setup
	@echo "set synthetic_library \" dw_foundation.sldb \"" >> .synopsys_dc.setup
	@echo "set verilogout_no_tri true" >> .synopsys_dc.setup
	@echo "set hdlin_enable_presto_for_vhdl TRUE" >> .synopsys_dc.setup
	@echo "set sh_enable_line_editing true" >> .synopsys_dc.setup
	@echo "history keep 100" >> .synopsys_dc.setup
	@echo "alias h history" >> .synopsys_dc.setup

# Run full synthesis flow in background (command line mode)
syn: setup_dc
	dcnxt_shell -f $(SYN_TCL) -x "set_host_options -max_cores $(CPU_CORES)" -output_log_file $(SYN_LOG)

# Run full synthesis flow and open Design Vision GUI upon completion
syn_gui: setup_dc
	dcnxt_shell -f $(SYN_TCL) -x "set_host_options -max_cores $(CPU_CORES)" -output_log_file $(SYN_LOG) -gui

# Quickly check RTL syntax and view GTECH schematic in Design Vision
check_rtl: setup_dc
	dcnxt_shell -x 'read_sverilog $(TOP_DESIGN).v' -gui

# Open Design Vision to view an existing synthesized .ddc netlist file
view_netlist: setup_dc
	dcnxt_shell -x "read_ddc $(TOP_DESIGN)_SYN.ddc" -gui

# Run PrimeTime for static timing analysis (STA)
pt:
	pt_shell -f $(PT_TCL) -x "set_host_options -max_cores $(CPU_CORES)" -output_log_file $(PT_LOG)

# Initialize Innovus APR flow with custom command and log files
apr_init:
	innovus -cpus $(CPU_CORES) -init ./cmd/run_apr.cmd -log ./log/run_apr.log -cmd ./log/run_apr.cmdlog

#-------------------------------------------------------------------------------
# 7. Cleanup
#-------------------------------------------------------------------------------

# Remove all temporary files generated by simulation, synthesis, and APR tools
clean:
	rm -rf *.fsdb ./csrc *.log *.lock $(OUTPUT_NAME)* *.sdf.X *.key ./verdiLog
	rm -rf ./INCA_libs ./xcelium.d *.history ./nWaveLog novas.rc
	rm -rf ./Netlist/* ./Report/* *.svf dwsvf* *.ddc *.pvl *.syn *.mr *.conf .synopsys_dc.setup
	rm -rf vcd.out ./fsdb2vcdLog checkDesign *.rpt* *.CCOPT.spec *.checkPlace
	rm -rf ./StreamOut/* CHIP_SYN.v *.globals extLogDir ./log/* ./DBS/* ./timingReports/* *.bin
