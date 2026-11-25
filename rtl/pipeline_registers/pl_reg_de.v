// pl_reg_de.v
// ID -> EX
// RD1E / RD2E are NOT here: they are the registered outputs of reg_file.
// LauiPC / PCPlus4 are NOT here: LUI goes through the ALU, AUIPC uses the
// branch-target adder and PC+4 is rebuilt from PCE.

module pl_reg_de #(parameter PCB = 10) (
    input clk,
    input en,
    input clr,

    input [31:0] ImmExtD,
    input [PCB-1:0] PCD,

    input [4:0] Rs1D,
    input [4:0] Rs2D,
    input [4:0] RdD,

    input [2:0] Funct3D,
    input [3:0] ALUControlD,

    input [1:0] ResultSrcD,

    input RegWriteD,
    input MemWriteD,
    input JumpD,
    input BranchD,
    input JalrD,
    input ALUSrcD,

    output reg [31:0] ImmExtE,
    output reg [PCB-1:0] PCE,

    output reg [4:0] Rs1E,
    output reg [4:0] Rs2E,
    output reg [4:0] RdE,

    output reg [2:0] Funct3E,
    output reg [3:0] ALUControlE,

    output reg [1:0] ResultSrcE,

    output reg RegWriteE,
    output reg MemWriteE,
    output reg JumpE,
    output reg BranchE,
    output reg JalrE,
    output reg ALUSrcE
);

    initial begin
        ImmExtE = 0;
        PCE = 0;

        Rs1E = 0;
        Rs2E = 0;
        RdE = 0;

        Funct3E = 0;
        ALUControlE = 0;

        ResultSrcE = 0;

        RegWriteE = 0;
        MemWriteE = 0;
        JumpE = 0;
        BranchE = 0;
        JalrE = 0;
        ALUSrcE = 0;
    end

    always @(posedge clk) begin

        if (clr) begin

            ImmExtE <= 0;
            PCE <= 0;

            Rs1E <= 0;
            Rs2E <= 0;
            RdE <= 0;

            Funct3E <= 0;
            ALUControlE <= 0;

            ResultSrcE <= 0;

            RegWriteE <= 0;
            MemWriteE <= 0;
            JumpE <= 0;
            BranchE <= 0;
            JalrE <= 0;
            ALUSrcE <= 0;

        end

        else if (!en) begin

            ImmExtE <= ImmExtD;
            PCE <= PCD;

            Rs1E <= Rs1D;
            Rs2E <= Rs2D;
            RdE <= RdD;

            Funct3E <= Funct3D;
            ALUControlE <= ALUControlD;

            ResultSrcE <= ResultSrcD;

            RegWriteE <= RegWriteD;
            MemWriteE <= MemWriteD;
            JumpE <= JumpD;
            BranchE <= BranchD;
            JalrE <= JalrD;
            ALUSrcE <= ALUSrcD;

        end

    end

endmodule
