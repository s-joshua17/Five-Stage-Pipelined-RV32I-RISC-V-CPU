// alu.v

module alu (
    input  [31:0] A,
    input  [31:0] B,
    input  [3:0]  ALUControl,
    output reg [31:0] Result,
    output        Zero,
    output        Lt,     // signed   A < B  (valid when ALUControl = SUB)
    output        Ltu     // unsigned A < B  (valid when ALUControl = SUB)
);

    // Shared 32-bit Adder / Subtractor / Comparator logic
    wire is_sub = (ALUControl == 4'b0001) || (ALUControl == 4'b0011) || (ALUControl == 4'b0100);
    wire [31:0] b_operand = is_sub ? ~B : B;
    wire [32:0] sum = {1'b0, A} + {1'b0, b_operand} + {{32{1'b0}}, is_sub};

    wire diff_sign = A[31] ^ B[31];
    wire sltu = ~sum[32];
    wire slt  = diff_sign ? A[31] : sum[31];

    // Shared Barrel Shifter logic for SLL, SRL, and SRA
    function [31:0] reverse32;
        input [31:0] val;
        integer k;
        begin
            for (k = 0; k < 32; k = k + 1)
                reverse32[k] = val[31 - k];
        end
    endfunction

    wire is_sll = (ALUControl == 4'b0010);
    wire is_sra = (ALUControl == 4'b0111);

    wire [31:0] shift_in = is_sll ? reverse32(A) : A;
    wire fill_bit = is_sra & A[31];

    wire [31:0] s16 = B[4] ? {{16{fill_bit}}, shift_in[31:16]} : shift_in;
    wire [31:0] s8  = B[3] ? {{8{fill_bit}},  s16[31:8]}       : s16;
    wire [31:0] s4  = B[2] ? {{4{fill_bit}},  s8[31:4]}        : s8;
    wire [31:0] s2  = B[1] ? {{2{fill_bit}},  s4[31:2]}        : s4;
    wire [31:0] s1  = B[0] ? {{1{fill_bit}},  s2[31:1]}        : s2;

    wire [31:0] shift_out = is_sll ? reverse32(s1) : s1;

    always @(*) begin
        case (ALUControl)
            4'b0000,
            4'b0001: Result = sum[31:0];
            4'b0010,
            4'b0110,
            4'b0111: Result = shift_out;
            4'b0011: Result = {31'b0, slt};
            4'b0100: Result = {31'b0, sltu};
            4'b0101: Result = A ^ B;
            4'b1000: Result = A | B;
            4'b1001: Result = A & B;
            default: Result = 32'b0;
        endcase
    end

    assign Zero = (sum[31:0] == 32'b0);
    assign Lt   = slt;
    assign Ltu  = sltu;

endmodule