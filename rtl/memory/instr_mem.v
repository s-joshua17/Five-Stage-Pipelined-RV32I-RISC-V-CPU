// instr_mem.v
// Synchronous-read ROM (read on the falling edge) so Quartus maps it to an
// M9K block instead of building it out of logic cells.

module instr_mem #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MEM_SIZE   = 256
)(
    input                       clk,
    input  [ADDR_WIDTH-1:0]     PC,
    output reg [DATA_WIDTH-1:0] Instr
);

    (* ramstyle = "M9K, no_rw_check" *) reg [DATA_WIDTH-1:0] instr_ram [0:MEM_SIZE-1];

    initial begin
        $readmemh("rv32i_test.hex", instr_ram);
        Instr = {DATA_WIDTH{1'b0}};
    end

    // PC settles after the rising edge; the instruction is captured mid-cycle
    // and is stable when IF/ID samples it on the next rising edge.
    always @(negedge clk)
        Instr <= instr_ram[PC[$clog2(MEM_SIZE)+1:2]];

endmodule
