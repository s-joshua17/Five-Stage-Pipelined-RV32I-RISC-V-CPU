# Instruction Execution Flow & Pipeline Timing

This document traces how RV32I instructions progress stage-by-stage through the pipeline, including exact timing behavior observed in the `work.tb` ModelSim simulation of `simulation/rv32i_test.hex`.

---

## 1. Five-Stage Instruction Lifecycle

Every instruction traverses five pipeline stages synchronized to `posedge clk` (with M9K memory reads and register-file writes occurring on `negedge clk` mid-cycle):

1. **IF (Instruction Fetch):**
   - `pcreg` (`reset_ff #(10)`) presents `PC_n` (`PC[9:0]`).
   - `instr_mem` captures `InstrF <= instr_ram[PC[9:2]]` on `negedge clk`.
   - Combinational `PCPlus4F = PC_n + 4` feeds `PCNext`, overridden if `PCSrcE` redirects PC in EX.
   - `pl_reg_fd` latches `(InstrF, PC_n)` into `(InstrD, PCD)` on the next `posedge clk` unless `StallD = 1` or `FlushD = 1`.

2. **ID (Instruction Decode):**
   - `controller` decodes `InstrD[6:0]` (`op`), `InstrD[14:12]` (`funct3`), and `InstrD[30]` (`funct7b5`) via `main_decoder` and `alu_decoder`.
   - `imm_extend` produces sign/zero-extended `ImmExtD[31:0]` for I, S, B, J, or U immediate formats.
   - `Rs1D` is forced to `5'd0` for `LUI`; otherwise `InstrD[19:15]`. `Rs2D = InstrD[24:20]`, `RdD = InstrD[11:7]`.
   - `reg_file` synchronously reads `regs[Rs1D]` and `regs[Rs2D]` on `posedge clk` directly into `RD1E` and `RD2E`, while `pl_reg_de` latches all decoded control signals, register indices, `ImmExtD`, and `PCD`.

3. **EX (Execute & Branch Resolution):**
   - `ForwardAE` and `ForwardBE` multiplexers select between `RD1E`/`RD2E` (`2'b00`), `ResultW` (`2'b01`), or `ALUResultM` (`2'b10`).
   - `ALUSrcE` selects `ImmExtE` or `ForwardedBE` as ALU input `B`.
   - `alu` computes `ALUResultCoreE` and flags `ZeroE`, `LtE`, `LtuE`.
   - `ALUResultE` selects `PCPlus4E` (`JAL`/`JALR` link), `ImmExtE | PCE` (`AUIPC`), or `ALUResultCoreE`.
   - `branching_unit` evaluates `TakeBranchE`, driving `PCSrcE` and `PCTargetE` / `JALRTargetE`.
   - `WriteDataE = ForwardedBE` forwards store operands into `pl_reg_em`.

4. **MEM (Memory Access):**
   - `data_mem` writes byte/halfword/word data (`SB`/`SH`/`SW`) on `posedge clk` using decoded byte enables `be[3:0]`.
   - On `negedge clk`, `data_mem` reads `ReadData` from `data_ram[ALUResultM[5:2]]`.
   - Combinational load formatting in `datapath.v` extracts byte/halfword lanes using `ALUResultM[1:0]` and sign- or zero-extends into `LoadDataM` for `LB`, `LH`, `LBU`, `LHU`, and `LW`.

5. **WB (Write Back):**
   - `pl_reg_mw` delivers `ALUResultW`, `ReadDataW` (from `LoadDataM`), `WriteDataW`, `PCW`, `RdW`, `LoadW`, `RegWriteW`, and `MemWriteW`.
   - `ResultW = LoadW ? ReadDataW : ALUResultW` writes back to `reg_file` on `negedge clk` when `RegWriteW && (RdW != 5'd0)` and feeds the `2'b01` forwarding path to EX.

---

## 2. Observed Execution Traces from Simulation (`sim.vcd`)

### 2.1 Steady-State & WB-to-EX Forwarding (`0–140 ns`)
From `simulation/rv32i_test.s`:
- `PC = 0x008`: `addi x3, x0, -3` (`ResultW = -3` / `0xFFFFFFFD` in WB at `t = 65 ns`)
- `PC = 0x00C`: `addi x4, x0, 0`
- `PC = 0x010`: `addi x5, x3, 12` (in EX at `t = 65 ns`)

At `t = 65 ns`, `RdW == Rs1E == x3` and `RegWriteW == 1`, so `hazard_unit` asserts `ForwardAE = 2'b01`, routing `ResultW = -3` into the ALU so `x5 = -3 + 12 = 9` without stalling.

### 2.2 MEM-to-EX Forwarding & Branch Loop Exit (`2240–2315 ns`)
During the `BEQ` test loop (`0x11C`–`0x128`):
- At `t = 2305 ns`, `0x120` (`addi x16, x16, 1`) is in MEM while `0x124` (`beq x16, x17, target_6`) is in EX.
- `hazard_unit` asserts `ForwardAE = 2'b10`, forwarding `ALUResultM` into the branch comparator so `x16 == 4 != x17 (3)` resolves cleanly (`PCSrcE = 0`) and exits the loop.
- One cycle later (`t = 2315 ns`), `0x128` (`add x16, x0, x16`) receives `ForwardBE = 2'b01` from `0x120` in WB.

### 2.3 Control Hazard Redirect & 2-Cycle Flush (`2320–2350 ns`)
From `simulation/rv32i_test.s`:
```asm
0x12C: jalr x31, x0, 308       # Jump to 0x134, link x31 = 0x130
0x130: addi x4, x0, -1         # Wrong-path instruction (must be flushed!)
0x134: add  x31, x0, x31       # Target instruction
```
- At `t = 2325 ns`, `jalr` (`PCE = 0x12C`) asserts `PCSrcE = 1`, `FlushD = 1`, `FlushE = 1`, and sets `PCNext = 0x134`.
- At `t = 2335 ns`, `PCD = 0x000` and `PCE = 0x000` (both wrong-path slots flushed to NOP bubbles), while `PC` fetches `0x134`. The speculative `addi x4, x0, -1` never reaches MEM or WB.

---

## 3. Supported RV32I Instruction Set Coverage

All 38 instruction verification checks in `testbench/tb.v` pass with `0` faulty instructions:

| Category | Instructions Verified in `tb.v` | Count |
|---|---|---|
| **I-Type ALU** | `ADDI` (`x0` & `x5`), `SLLI`, `SLTI`, `SLTIU`, `XORI`, `SRLI`, `SRAI`, `ORI`, `ANDI` | 10 |
| **R-Type ALU** | `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND` | 10 |
| **U-Type** | `LUI`, `AUIPC` | 2 |
| **S-Type (Store)** | `SB`, `SH`, `SW` | 3 |
| **I-Type (Load)** | `LB`, `LH`, `LW`, `LBU`, `LHU` | 5 |
| **B-Type (Branch)** | `BLT`, `BGE`, `BLTU`, `BGEU`, `BNE`, `BEQ` | 6 |
| **Jump** | `JALR`, `JAL` | 2 |
| **Total** | **All RV32I Base Unprivileged Integer Instructions Tested** | **38** |
