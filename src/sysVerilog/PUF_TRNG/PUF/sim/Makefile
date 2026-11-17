.PHONY: vcs-axi-ro vcs-core-count vcs-ecc-secded axi-ro core-count ecc-secded host vcs vcs-core vcs-ecc verilator core ecc
PYTHON ?= python3
vcs-axi-ro:
	vcs -full64 -sverilog -debug_access+all -timescale=1ns/1ps -f filelist_puf_axi_ro.f -top TESTBED_PUF_AXI_RO -o simv_puf_axi_ro
	./simv_puf_axi_ro +vcd
vcs-core-count:
	vcs -full64 -sverilog -debug_access+all -timescale=1ns/1ps -f filelist_puf_core_count.f -top TESTBED_PUF_CORE_COUNT -o simv_puf_core_count
	./simv_puf_core_count
vcs-ecc-secded:
	vcs -full64 -sverilog -debug_access+all -timescale=1ns/1ps -f filelist_puf_ecc_secded.f -top TESTBED_PUF_ECC_SECDED -o simv_puf_ecc_secded
	./simv_puf_ecc_secded
axi-ro:
	$(PYTHON) run_sim.py --mode axi-ro --vcd
core-count:
	$(PYTHON) run_sim.py --mode core-count
ecc-secded:
	$(PYTHON) run_sim.py --mode ecc-secded
host:
	$(PYTHON) ../verification/test_host.py
# Compatible aliases; new documentation uses the descriptive names above.
vcs: vcs-axi-ro
vcs-core: vcs-core-count
vcs-ecc: vcs-ecc-secded
verilator: axi-ro
core: core-count
ecc: ecc-secded
