// imm_extend.v

module imm_extend (
    input  [24:0] instr,
    input  [2:0]  ImmSrc,
    output reg [31:0] ImmExt
);

    always @(*) begin

        case (ImmSrc)

            // I-type
            3'b000:
                ImmExt = {{20{instr[24]}}, instr[24:13]};

            // S-type
            3'b001:
                ImmExt = {{20{instr[24]}}, instr[24:18], instr[4:0]};

            // B-type
            3'b010:
                ImmExt = {{19{instr[24]}},
                          instr[24],
                          instr[0],
                          instr[23:18],
                          instr[4:1],
                          1'b0};

            // J-type
            3'b011:
                ImmExt = {{11{instr[24]}},
                          instr[24],
                          instr[12:5],
                          instr[13],
                          instr[23:14],
                          1'b0};

            // U-type
            3'b100:
                ImmExt = {instr[24:5], 12'b0};

            default:
                ImmExt = 32'b0;

        endcase
    end

endmodule