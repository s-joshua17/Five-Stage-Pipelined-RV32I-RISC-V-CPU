// pl_riscv_cpu.v

module pl_riscv_cpu (
    input         clk,
    input         reset,

    input         Ext_MemWrite,
    input  [31:0] Ext_WriteData,
    input  [31:0] Ext_DataAdr,

    output        MemWrite,
    output [31:0] WriteData,
    output [31:0] DataAdr,
    output [31:0] ReadData,

    output [31:0] PCW,
    output [31:0] Result,
    output [31:0] ALUResultW,
    output [31:0] WriteDataW
);

    wire [31:0] Instr;
    wire [31:0] PC;

    // Actual MEM-stage CPU signals
    wire        MemWriteM_rv32;
    wire [31:0] DataAdr_rv32;
    wire [31:0] WriteData_rv32;

    // WB-stage signals for the testbench
    wire        MemWriteW_rv32;
    wire [31:0] ALUResultW_rv32;
    wire [31:0] WriteDataW_rv32;

    wire [2:0] funct3;

    wire [2:0] Store;

    // ========================================================
    // CPU
    // ========================================================

    riscv_cpu rvcpu (
        .clk        (clk),
        .reset      (reset),

        .PC         (PC),
        .Instr      (Instr),

        .MemWriteM  (MemWriteM_rv32),
        .Mem_WrAddr (DataAdr_rv32),
        .Mem_WrData (WriteData_rv32),

        .ReadData   (ReadData),

        .Result     (Result),

        .funct3     (funct3),

        .PCW        (PCW),
        .ALUResultW (ALUResultW_rv32),
        .WriteDataW (WriteDataW_rv32),
        .MemWriteW  (MemWriteW_rv32)
    );

    // ========================================================
    // Instruction memory
    // ========================================================

    instr_mem instrmem (
        .clk   (clk),
        .PC    (PC),
        .Instr (Instr)
    );

    // ========================================================
    // Store type
    // ========================================================

    wire ext_mode = Ext_MemWrite & reset;

    assign Store = ext_mode ? 3'b010 : funct3;

    // ========================================================
    // Actual data memory signals
    // ========================================================

    wire ActualMemWrite;

    assign ActualMemWrite = ext_mode ? 1'b1 : MemWriteM_rv32;

    assign WriteData = ext_mode ? Ext_WriteData : WriteData_rv32;

    assign DataAdr = ext_mode ? Ext_DataAdr : DataAdr_rv32;

    // ========================================================
    // Top-level MemWrite is W-stage aligned for TB checking
    // ========================================================

    assign MemWrite = ext_mode ? 1'b1 : MemWriteW_rv32;

    // ========================================================
    // WB debug/test outputs
    // ========================================================

    assign ALUResultW = ALUResultW_rv32;
    wire [31:0] DataAdrW = ALUResultW;
    assign WriteDataW = WriteDataW_rv32;

    // ========================================================
    // Data memory
    // ========================================================

    data_mem datamem (
        .clk       (clk),
        .MemWrite  (ActualMemWrite),
        .Store     (Store),
        .DataAdr   (DataAdr),
        .WriteData (WriteData),
        .ReadData  (ReadData)
    );

endmodule