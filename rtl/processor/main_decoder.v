// main_decoder.v

module main_decoder (
    input  [6:0] op,
    input  [2:0] funct3,

    output reg [1:0] ResultSrc,
    output reg       MemWrite,
    output reg       Branch,
    output reg       ALUSrc,
    output reg       RegWrite,
    output reg       Jump,
    output reg       Jalr,
    output reg [2:0] ImmSrc,
    output reg [1:0] ALUOp
);

    always @(*) begin

        // Defaults = NOP
        ResultSrc = 2'b00;
        MemWrite  = 1'b0;
        Branch    = 1'b0;
        ALUSrc    = 1'b0;
        RegWrite  = 1'b0;
        Jump      = 1'b0;
        Jalr      = 1'b0;
        ImmSrc    = 3'b000;
        ALUOp      = 2'b00;

        case (op[6:2])

            // R-type
            5'b01100: begin
                RegWrite  = 1'b1;
                ALUSrc    = 1'b0;
                ResultSrc = 2'b00;
                ALUOp     = 2'b10;
            end

            // I-type ALU
            5'b00100: begin
                RegWrite  = 1'b1;
                ALUSrc    = 1'b1;
                ResultSrc = 2'b00;
                ImmSrc    = 3'b000;
                ALUOp     = 2'b10;
            end

            // Loads: LB, LH, LW, LBU, LHU
            5'b00000: begin
                RegWrite  = 1'b1;
                ALUSrc    = 1'b1;
                ResultSrc = 2'b01;
                ImmSrc    = 3'b000;
                ALUOp     = 2'b00;
            end

            // Stores: SB, SH, SW
            5'b01000: begin
                MemWrite  = 1'b1;
                ALUSrc    = 1'b1;
                ImmSrc    = 3'b001;
                ALUOp     = 2'b00;
            end

            // Branches
            // BEQ, BNE, BLT, BGE, BLTU, BGEU
            5'b11000: begin
                Branch    = 1'b1;
                ALUSrc    = 1'b0;
                ImmSrc    = 3'b010;
                ALUOp     = 2'b01;
            end

            // JAL
            5'b11011: begin
                RegWrite  = 1'b1;
                Jump      = 1'b1;
                ResultSrc = 2'b10;
                ImmSrc    = 3'b011;
                ALUSrc    = 1'b0;
                ALUOp     = 2'b00;
            end

            // JALR
            5'b11001: begin
                RegWrite  = 1'b1;
                Jalr      = 1'b1;
                ResultSrc = 2'b10;
                ImmSrc    = 3'b000;
                ALUSrc    = 1'b1;
                ALUOp     = 2'b00;
            end

            // LUI  (executed as 0 + imm in the ALU: Rs1 is forced to x0 in datapath)
            5'b01101: begin
                RegWrite  = 1'b1;
                ResultSrc = 2'b00;
                ImmSrc    = 3'b100;
                ALUSrc    = 1'b1;
                ALUOp     = 2'b00;
            end

            // AUIPC (value = PC + imm, taken from the branch-target adder)
            5'b00101: begin
                RegWrite  = 1'b1;
                ResultSrc = 2'b11;
                ImmSrc    = 3'b100;
                ALUSrc    = 1'b1;
                ALUOp     = 2'b00;
            end

            default: begin
                // NOP
            end

        endcase
    end

endmodule