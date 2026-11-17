.PHONY: axi-ro core-count ecc-secded sim core ecc host verify evidence workstation
PYTHON ?= python3
axi-ro:
	$(PYTHON) sim/run_sim.py --mode axi-ro
core-count:
	$(PYTHON) sim/run_sim.py --mode core-count
ecc-secded:
	$(PYTHON) sim/run_sim.py --mode ecc-secded
host:
	$(PYTHON) -m unittest discover -s verification -p 'test_*.py' -v
verify:
	$(PYTHON) verification/check_handoff.py
evidence:
	$(PYTHON) verification/recheck_evidence.py
workstation:
	cd sim && $(MAKE) vcs-core-count && $(MAKE) vcs-ecc-secded && $(MAKE) vcs-axi-ro
sim: axi-ro
core: core-count
ecc: ecc-secded
