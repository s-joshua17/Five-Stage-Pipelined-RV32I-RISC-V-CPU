// pl_reg_mw.v
// MEM -> WB

module pl_reg_mw #(parameter PCB = 10) (
    input clk,

    input [31:0] ALUResultM,
    input [31:0] ReadDataM,
    input [31:0] WriteDataM,
    input [PCB-1:0] PCM,

    input [4:0] RdM,

    input LoadM,

    input RegWriteM,
    input MemWriteM,

    output reg [31:0] ALUResultW,
    output reg [31:0] ReadDataW,
    output reg [31:0] WriteDataW,
    output reg [PCB-1:0] PCW,

    output reg [4:0] RdW,

    output reg LoadW,

    output reg RegWriteW,
    output reg MemWriteW
);

    initial begin
        ALUResultW = 32'b0;
        ReadDataW  = 32'b0;
        WriteDataW = 32'b0;
        PCW        = {PCB{1'b0}};

        RdW        = 5'b0;

        LoadW      = 1'b0;

        RegWriteW  = 1'b0;
        MemWriteW  = 1'b0;
    end

    always @(posedge clk) begin
        ALUResultW <= ALUResultM;
        ReadDataW  <= ReadDataM;
        WriteDataW <= WriteDataM;
        PCW        <= PCM;

        RdW        <= RdM;

        LoadW      <= LoadM;

        RegWriteW  <= RegWriteM;
        MemWriteW  <= MemWriteM;
    end

endmodule
