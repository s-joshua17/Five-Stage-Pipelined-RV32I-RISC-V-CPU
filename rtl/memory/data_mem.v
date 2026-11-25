// data_mem.v
// Byte-enable RAM: write on the rising edge, read on the falling edge
// (synchronous read -> Quartus infers an M9K block instead of 32 x MEM_SIZE
// flip-flops plus a big read multiplexer).

module data_mem #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MEM_SIZE   = 16
)(
    input                       clk,
    input                       MemWrite,
    input      [2:0]            Store,
    input      [ADDR_WIDTH-1:0] DataAdr,
    input      [DATA_WIDTH-1:0] WriteData,
    output reg [DATA_WIDTH-1:0] ReadData
);

    (* ramstyle = "M9K, no_rw_check" *) reg [DATA_WIDTH-1:0] data_ram [0:MEM_SIZE-1];

    wire [$clog2(MEM_SIZE)-1:0] ram_addr = DataAdr[$clog2(MEM_SIZE)+1:2];
    wire [1:0] off = DataAdr[1:0];

    wire sb = (Store == 3'b000);
    wire sh = (Store == 3'b001);
    wire sw = (Store == 3'b010);

    // per-byte write enables (SB: one byte, SH: aligned half, SW: word)
    wire [3:0] be;
    assign be[0] = MemWrite & ((sb & (off == 2'b00)) | (sh & (off == 2'b00)) | sw);
    assign be[1] = MemWrite & ((sb & (off == 2'b01)) | (sh & (off == 2'b00)) | sw);
    assign be[2] = MemWrite & ((sb & (off == 2'b10)) | (sh & (off == 2'b10)) | sw);
    assign be[3] = MemWrite & ((sb & (off == 2'b11)) | (sh & (off == 2'b10)) | sw);

    // data steering for each byte lane
    wire [7:0] d0 = WriteData[7:0];
    wire [7:0] d1 = sb ? WriteData[7:0]   : WriteData[15:8];
    wire [7:0] d2 = sw ? WriteData[23:16] : WriteData[7:0];
    wire [7:0] d3 = sw ? WriteData[31:24] : (sb ? WriteData[7:0] : WriteData[15:8]);

    integer i;
    initial begin
        for (i = 0; i < MEM_SIZE; i = i + 1)
            data_ram[i] = {DATA_WIDTH{1'b0}};
        ReadData = {DATA_WIDTH{1'b0}};
    end

    always @(posedge clk) begin
        if (be[0]) data_ram[ram_addr][7:0]   <= d0;
        if (be[1]) data_ram[ram_addr][15:8]  <= d1;
        if (be[2]) data_ram[ram_addr][23:16] <= d2;
        if (be[3]) data_ram[ram_addr][31:24] <= d3;
    end

    // Load in MEM stage: address is stable from the rising edge, so the
    // falling-edge read already sees a store that just completed.
    always @(negedge clk)
        ReadData <= data_ram[ram_addr];

endmodule
