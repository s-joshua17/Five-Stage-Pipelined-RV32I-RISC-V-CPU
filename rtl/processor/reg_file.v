// reg_file.v
// Write on the falling edge, read on the rising edge (synchronous read ->
// M9K). The registered outputs ARE the ID/EX operand registers (RD1E/RD2E).

module reg_file (
    input         clk,
    input         we3,
    input  [4:0]  ra1,
    input  [4:0]  ra2,
    input  [4:0]  wa3,
    input  [31:0] wd3,
    output reg [31:0] rd1,
    output reg [31:0] rd2
);

    (* ramstyle = "M9K, no_rw_check" *) reg [31:0] regs [31:0];

    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'b0;
        rd1 = 32'b0;
        rd2 = 32'b0;
    end

    always @(negedge clk) begin
        if (we3 && (wa3 != 5'd0))
            regs[wa3] <= wd3;
    end

    // x0 is never written, so regs[0] stays 0
    always @(posedge clk) begin
        rd1 <= regs[ra1];
        rd2 <= regs[ra2];
    end

endmodule
