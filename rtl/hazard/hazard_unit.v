// hazard_unit.v

module hazard_unit (
    input [4:0] Rs1D,
    input [4:0] Rs2D,

    input [4:0] Rs1E,
    input [4:0] Rs2E,
    input [4:0] RdE,

    input [4:0] RdM,
    input [4:0] RdW,

    input RegWriteM,
    input RegWriteW,

    input [1:0] ResultSrcE,

    input PCSrcE,

    output reg [1:0] ForwardAE,
    output reg [1:0] ForwardBE,

    output StallF,
    output StallD,

    output FlushD,
    output FlushE
);

    wire forward_m_a = RegWriteM & (|RdM) & (RdM == Rs1E);
    wire forward_w_a = RegWriteW & (|RdW) & (RdW == Rs1E);
    wire forward_m_b = RegWriteM & (|RdM) & (RdM == Rs2E);
    wire forward_w_b = RegWriteW & (|RdW) & (RdW == Rs2E);

    always @(*) begin
        ForwardAE = forward_m_a ? 2'b10 : (forward_w_a ? 2'b01 : 2'b00);
        ForwardBE = forward_m_b ? 2'b10 : (forward_w_b ? 2'b01 : 2'b00);
    end

    // 01 is Load in our ResultSrc encoding.
    assign lwStall =
        (ResultSrcE == 2'b01) &&
        (|RdE) &&
        ((Rs1D == RdE) || (Rs2D == RdE));

    assign StallF = lwStall;
    assign StallD = lwStall;

    // Taken branch / jump / jalr
    assign FlushD = PCSrcE;

    // Bubble into Execute for either load-use or control hazard
    assign FlushE = lwStall | PCSrcE;

endmodule