// pl_reg_fd.v
// IF -> ID   (PC+4 is no longer carried; it is rebuilt in EX when needed)

module pl_reg_fd #(parameter PCB = 10) (
    input             clk,
    input             en,
    input             clr,

    input      [31:0] InstrF,
    input      [PCB-1:0] PCF,

    output reg [31:0] InstrD,
    output reg [PCB-1:0] PCD
);

    initial begin
        InstrD = 32'b0;
        PCD    = {PCB{1'b0}};
    end

    always @(posedge clk) begin

        if (clr) begin
            InstrD <= 32'b0;
            PCD    <= {PCB{1'b0}};
        end

        else if (!en) begin
            InstrD <= InstrF;
            PCD    <= PCF;
        end

    end

endmodule
