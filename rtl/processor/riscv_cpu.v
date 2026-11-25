// riscv_cpu.v
// 5-stage pipelined RISC-V CPU

module riscv_cpu (
    input         clk,
    input         reset,

    output [31:0] PC,
    input  [31:0] Instr,

    // Actual MEM-stage memory interface
    output        MemWriteM,
    output [31:0] Mem_WrAddr,
    output [31:0] Mem_WrData,

    input  [31:0] ReadData,

    output [31:0] Result,

    output [2:0] funct3,

    // WB-stage debug/testbench outputs
    output [31:0] PCW,
    output [31:0] ALUResultW,
    output [31:0] WriteDataW,
    output        MemWriteW
);

    // Decode-stage controls
    wire [1:0] ResultSrcD;

    wire MemWriteD;
    wire ALUSrcD;
    wire RegWriteD;
    wire BranchD;
    wire JumpD;
    wire JalrD;

    wire [2:0] ImmSrcD;
    wire [3:0] ALUControlD;

    // IF/ID
    wire [31:0] InstrD;

    // MEM
    wire [2:0] funct3M;

    // --------------------------------------------------------
    // Controller
    // --------------------------------------------------------

    controller c (
        .op         (InstrD[6:0]),
        .funct3     (InstrD[14:12]),
        .funct7b5   (InstrD[30]),

        .ResultSrc  (ResultSrcD),
        .MemWrite   (MemWriteD),
        .ALUSrc     (ALUSrcD),
        .RegWrite   (RegWriteD),
        .Branch     (BranchD),
        .Jump       (JumpD),
        .Jalr       (JalrD),
        .ImmSrc     (ImmSrcD),
        .ALUControl (ALUControlD)
    );

    // --------------------------------------------------------
    // Datapath
    // --------------------------------------------------------

    datapath dp (
        .clk         (clk),
        .reset       (reset),

        .ResultSrcD  (ResultSrcD),
        .MemWriteD   (MemWriteD),
        .ALUSrcD     (ALUSrcD),
        .RegWriteD   (RegWriteD),
        .ImmSrcD     (ImmSrcD),
        .ALUControlD (ALUControlD),
        .BranchD     (BranchD),
        .JumpD       (JumpD),
        .JalrD       (JalrD),

        .PC           (PC),
        .InstrF       (Instr),

        .Mem_WrAddr   (Mem_WrAddr),
        .Mem_WrData   (Mem_WrData),
        .MemWriteM    (MemWriteM),
        .funct3M      (funct3M),

        .ReadData     (ReadData),

        .Result       (Result),

        .PCW          (PCW),
        .ALUResultW   (ALUResultW),
        .WriteDataW   (WriteDataW),
        .MemWriteW    (MemWriteW),

        .InstrD       (InstrD)
    );

    wire [31:0] DataAdrW = ALUResultW;

    assign funct3 = funct3M;

endmodule