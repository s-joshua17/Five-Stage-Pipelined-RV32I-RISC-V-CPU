# ModelSim simulation script for Five-Stage Pipelined RV32I RISC-V CPU
# Run from the simulation/ directory:
#   vsim -c -do run_sim.do
# Or in ModelSim GUI:
#   do run_sim.do

if {[file exists work]} {
    vdel -lib work -all
}
vlib work

# Compile RTL modules
vlog -work work \
    ../rtl/processor/adder.v \
    ../rtl/processor/alu.v \
    ../rtl/processor/alu_decoder.v \
    ../rtl/processor/branching_unit.v \
    ../rtl/processor/controller.v \
    ../rtl/processor/datapath.v \
    ../rtl/processor/imm_extend.v \
    ../rtl/processor/main_decoder.v \
    ../rtl/processor/mux2.v \
    ../rtl/processor/mux3.v \
    ../rtl/processor/mux4.v \
    ../rtl/processor/reg_file.v \
    ../rtl/processor/reset_ff.v \
    ../rtl/pipeline_registers/pl_reg_fd.v \
    ../rtl/pipeline_registers/pl_reg_de.v \
    ../rtl/pipeline_registers/pl_reg_em.v \
    ../rtl/pipeline_registers/pl_reg_mw.v \
    ../rtl/hazard/hazard_unit.v \
    ../rtl/memory/instr_mem.v \
    ../rtl/memory/data_mem.v \
    ../rtl/processor/riscv_cpu.v \
    ../rtl/processor/pl_riscv_cpu.v

# Compile Testbench
vlog -work work ../testbench/tb.v

# Launch simulation
vsim -voptargs="+acc" work.tb

onbreak {resume}
run -all
quit -f
