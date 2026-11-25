// pl_reg_em.v
// EX -> MEM
// ALUResultE already contains PC+4 (JAL/JALR) or the AUIPC value when needed,
// so the MEM/WB stages only need a 1-bit "is load" flag, not ResultSrc.

module pl_reg_em #(parameter PCB = 10) (
    input clk,

    input [31:0] ALUResultE,
    input [31:0] WriteDataE,
    input [PCB-1:0] PCE,

    input [4:0] RdE,
    input [2:0] Funct3E,

    input LoadE,

    input RegWriteE,
    input MemWriteE,

    output reg [31:0] ALUResultM,
    output reg [31:0] WriteDataM,
    output reg [PCB-1:0] PCM,

    output reg [4:0] RdM,
    output reg [2:0] Funct3M,

    output reg LoadM,

    output reg RegWriteM,
    output reg MemWriteM
);

    initial begin
        ALUResultM = 0;
        WriteDataM = 0;
        PCM = 0;
        RdM = 0;
        Funct3M = 0;
        LoadM = 0;
        RegWriteM = 0;
        MemWriteM = 0;
    end

    always @(posedge clk) begin
        ALUResultM <= ALUResultE;
        WriteDataM <= WriteDataE;
        PCM <= PCE;

        RdM <= RdE;
        Funct3M <= Funct3E;

        LoadM <= LoadE;

        RegWriteM <= RegWriteE;
        MemWriteM <= MemWriteE;
    end

endmodule
