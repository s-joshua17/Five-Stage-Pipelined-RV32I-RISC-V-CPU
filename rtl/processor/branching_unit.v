// branching_unit.v
// Uses the ALU's SUB result flags (Zero / signed-less / unsigned-less) instead
// of building a second 32-bit comparator.

module branching_unit (
    input  [2:0] funct3,
    input        Zero,
    input        Lt,
    input        Ltu,
    output reg   Branch
);

    reg cond;
    always @(*) begin
        case (funct3[2:1])
            2'b00:   cond = Zero;  // BEQ / BNE
            2'b10:   cond = Lt;    // BLT / BGE
            2'b11:   cond = Ltu;   // BLTU / BGEU
            default: cond = 1'b0;
        endcase
    end

    // funct3[0] inverts the condition for BNE, BGE, BGEU
    always @(*) begin
        if (funct3[2:1] == 2'b01)
            Branch = 1'b0;
        else
            Branch = cond ^ funct3[0];
    end

endmodule
