#!/bin/sh
cd "`dirname "$0"`" || exit 1
vcs -full64 -sverilog -timescale=1ns/1ps -f filelist.f -top tb_hamming64 -o simv_hamming64
./simv_hamming64
