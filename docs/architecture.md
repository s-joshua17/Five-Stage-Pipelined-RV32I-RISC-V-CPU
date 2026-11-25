# Microarchitecture Specification — Five-Stage Pipelined RV32I CPU

This document details the RTL microarchitecture of the five-stage pipelined RV32I RISC-V processor implemented in `rtl/`. Every signal name, bit width, clocking convention, and control equation below reflects the verified Verilog source files directly.

---

## 1. Module Hierarchy

```text
pl_riscv_cpu (rtl/processor/pl_riscv_cpu.v)        [Top-level SoC wrapper & TB interface]
├── riscv_cpu (rtl/processor/riscv_cpu.v)          [CPU core]
│   ├── controller (rtl/processor/controller.v)    [Decode-stage control unit]
│   │   ├── main_decoder (rtl/processor/main_decoder.v)
│   │   └── alu_decoder (rtl/processor/alu_decoder.v)
│   └── datapath (rtl/processor/datapath.v)        [5-stage pipelined datapath]
│       ├── reset_ff #(10) (rtl/processor/reset_ff.v)          [PC register]
│       ├── pl_reg_fd #(10) (rtl/pipeline_registers/pl_reg_fd.v) [IF/ID register]
│       ├── reg_file (rtl/processor/reg_file.v)                [32x32 M9K regfile + RD1E/RD2E]
│       ├── imm_extend (rtl/processor/imm_extend.v)            [I/S/B/J/U immediate extender]
│       ├── pl_reg_de #(10) (rtl/pipeline_registers/pl_reg_de.v) [ID/EX register]
│       ├── alu (rtl/processor/alu.v)                          [32-bit ALU + barrel shifter]
│       ├── branching_unit (rtl/processor/branching_unit.v)    [6-condition branch evaluator]
│       ├── pl_reg_em #(10) (rtl/pipeline_registers/pl_reg_em.v) [EX/MEM register]
│       ├── pl_reg_mw #(10) (rtl/pipeline_registers/pl_reg_mw.v) [MEM/WB register]
│       └── hazard_unit (rtl/hazard/hazard_unit.v)             [Forwarding, stall & flush]
├── instr_mem (rtl/memory/instr_mem.v)             [256x32 M9K synchronous instruction ROM]
└── data_mem (rtl/memory/data_mem.v)               [16x32 byte-enable M9K data RAM]
```

> **Note on Utility Primitives:** `rtl/processor/` also preserves the standalone parameterized building blocks (`adder.v`, `mux2.v`, `mux3.v`, `mux4.v`) from the original component library. Inside `datapath.v`, muxing and PC arithmetic are written directly in behavioral Verilog for compactness and explicit pipeline integration.

---

## 2. Clocking & FPGA M9K Block RAM Alignment

A key architectural feature of this implementation is its synchronous memory and register-file clocking strategy, designed so Quartus infers embedded **M9K** memory blocks instead of large LUT/FF arrays:

| Block | Module | Read Edge | Write Edge | Rationale in RTL |
|---|---|---|---|---|
| Instruction ROM | `instr_mem` | `negedge clk` | — (`$readmemh`) | `PC` settles after `posedge clk`; instruction is captured mid-cycle so `InstrF` is stable before the next `posedge clk` into `IF/ID`. |
| Register File | `reg_file` | `posedge clk` | `negedge clk` | Writing on `negedge clk` avoids read-during-write hazards in the same cycle; synchronous read on `posedge clk` turns `rd1`/`rd2` directly into the `RD1E`/`RD2E` ID/EX operand registers! |
| Data RAM | `data_mem` | `negedge clk` | `posedge clk` | Store writes commit on `posedge clk` using 4-bit byte enables (`be[3:0]`); loads read on `negedge clk` mid-cycle so `ReadData` is ready for `LoadDataM` formatting before `MEM/WB`. |

All three memories carry `(* ramstyle = "M9K, no_rw_check" *)` synthesis attributes.

---

## 3. Narrow PC Optimization (`PCB = 10`)

Because `instr_mem` holds `MEM_SIZE = 256` words (1 KB address space `0x000`–`0x3FC`), `datapath.v` defines `localparam PCB = 10` and pipelines only `PC[9:0]` across `pcreg`, `pl_reg_fd`, `pl_reg_de`, `pl_reg_em`, and `pl_reg_mw`, zero-extending to 32 bits (`{{(32-PCB){1'b0}}, PC_n}`) at the instruction memory and `PCW` debug outputs.

---

## 4. Pipeline Register Inventory

| Register | Module | Control Inputs | Stored Signals |
|---|---|---|---|
| **IF/ID** | `pl_reg_fd` | `en` (`StallD`, active-low freeze: updates when `!en`), `clr` (`FlushD`) | `InstrD[31:0]`, `PCD[9:0]` |
| **ID/EX** | `pl_reg_de` | `en` (`1'b0`), `clr` (`FlushE`) | `ImmExtE[31:0]`, `PCE[9:0]`, `Rs1E[4:0]`, `Rs2E[4:0]`, `RdE[4:0]`, `Funct3E[2:0]`, `ALUControlE[3:0]`, `ResultSrcE[1:0]`, `RegWriteE`, `MemWriteE`, `JumpE`, `BranchE`, `JalrE`, `ALUSrcE` *(note: `RD1E`/`RD2E` reside in `reg_file`)* |
| **EX/MEM** | `pl_reg_em` | `clk` only (free-running) | `ALUResultM[31:0]`, `WriteDataM[31:0]`, `PCM[9:0]`, `RdM[4:0]`, `Funct3M[2:0]`, `LoadM` (`ResultSrcE == 2'b01`), `RegWriteM`, `MemWriteM` |
| **MEM/WB** | `pl_reg_mw` | `clk` only (free-running) | `ALUResultW[31:0]`, `ReadDataW[31:0]`, `WriteDataW[31:0]`, `PCW[9:0]`, `RdW[4:0]`, `LoadW`, `RegWriteW`, `MemWriteW` |

Notice how `ALUResultE` resolves `JAL`/`JALR` link addresses (`PCPlus4E`) and `AUIPC` (`ImmExtE | PCE`) inside EX, allowing `EX/MEM` and `MEM/WB` to collapse the 2-bit `ResultSrc` bus into a single 1-bit `LoadE`/`LoadM`/`LoadW` flag!

---

## 5. ALU & Branching Unit Design

- **Shared Adder/Subtractor/Comparator (`alu.v`):** Uses a single 33-bit adder `{1'b0, A} + {1'b0, b_operand} + is_sub` for `ADD`, `SUB`, `SLT`, `SLTU`, and branch flag generation (`Zero`, signed `Lt`, unsigned `Ltu`).
- **Shared Barrel Shifter (`alu.v`):** Uses bit-reversal (`reverse32`) before and after a 5-stage logarithmic right-shift network (`s16 -> s8 -> s4 -> s2 -> s1`) to execute `SLL`, `SRL`, and `SRA` with one shifter datapath.
- **Branch Evaluation (`branching_unit.v`):** Decodes `funct3[2:1]` to select `Zero` (`BEQ`/`BNE`), `Lt` (`BLT`/`BGE`), or `Ltu` (`BLTU`/`BGEU`), and XORs with `funct3[0]` to invert the condition for `BNE`, `BGE`, and `BGEU`.

---

## 6. Hazard Unit Logic (`hazard_unit.v`)

### 6.1 Data Forwarding
```verilog
wire forward_m_a = RegWriteM & (|RdM) & (RdM == Rs1E);
wire forward_w_a = RegWriteW & (|RdW) & (RdW == Rs1E);
wire forward_m_b = RegWriteM & (|RdM) & (RdM == Rs2E);
wire forward_w_b = RegWriteW & (|RdW) & (RdW == Rs2E);

ForwardAE = forward_m_a ? 2'b10 : (forward_w_a ? 2'b01 : 2'b00);
ForwardBE = forward_m_b ? 2'b10 : (forward_w_b ? 2'b01 : 2'b00);
```
- Priority goes to the younger instruction in **MEM** (`2'b10` -> `ALUResultM`) over **WB** (`2'b01` -> `ResultW`).
- Zero-register guard (`|RdM`, `|RdW`) ensures writes targeting `x0` never trigger forwarding.
- `WriteDataE = ForwardedBE` guarantees store instructions (`SB`/`SH`/`SW`) also receive forwarded store values.
- In ID, `datapath.v` forces `Rs1D = 5'd0` for `LUI` (`InstrD[6:2] == 5'b01101`) so the ALU computes `0 + ImmExtE` and `hazard_unit` never falsely stalls or forwards based on bits `[19:15]` of a U-immediate.

### 6.2 Load-Use Stalling
```verilog
assign lwStall = (ResultSrcE == 2'b01) && (|RdE) && ((Rs1D == RdE) || (Rs2D == RdE));
assign StallF  = lwStall;
assign StallD  = lwStall;
```
When an instruction in EX is a load (`ResultSrcE == 2'b01`) writing to a non-zero destination `RdE` needed by the instruction in ID, `StallF` holds `PC_n`, `StallD` freezes `IF/ID`, and `FlushE` injects a NOP bubble into `ID/EX`.

### 6.3 Control Hazard Flushing
```verilog
assign PCSrcE = (BranchE && TakeBranchE) | JumpE | JalrE;
assign FlushD = PCSrcE;
assign FlushE = lwStall | PCSrcE;
```
Branches, `JAL`, and `JALR` resolve in EX (`PCSrcE`). On any redirect, `PCNext` selects `JALRTargetE` (`{ALUResultCoreE[9:1], 1'b0}`) or `PCTargetE` (`PCE + ImmExtE[9:0]`), while `FlushD` and `FlushE` clear the two speculatively fetched/decoded instructions in `IF/ID` and `ID/EX`.
