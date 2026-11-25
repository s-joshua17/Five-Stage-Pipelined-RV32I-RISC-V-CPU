// alu_decoder.v

module alu_decoder (
    input        op5,
    input  [2:0] funct3,
    input        funct7b5,
    input  [1:0] ALUOp,
    output reg [3:0] ALUControl
);

    // ALUControl encoding
    // 0000 ADD
    // 0001 SUB
    // 0010 SLL
    // 0011 SLT
    // 0100 SLTU
    // 0101 XOR
    // 0110 SRL
    // 0111 SRA
    // 1000 OR
    // 1001 AND

    always @(*) begin

        case (ALUOp)

            // Load/store/JALR/AUIPC
            2'b00:
                ALUControl = 4'b0000; // ADD

            // Branch
            2'b01:
                ALUControl = 4'b0001; // SUB

            // R-type / I-type ALU
            2'b10: begin
                case (funct3)

                    3'b000: begin
                        if (op5 && funct7b5)
                            ALUControl = 4'b0001; // SUB
                        else
                            ALUControl = 4'b0000; // ADD
                    end

                    3'b001:
                        ALUControl = 4'b0010; // SLL

                    3'b010:
                        ALUControl = 4'b0011; // SLT

                    3'b011:
                        ALUControl = 4'b0100; // SLTU

                    3'b100:
                        ALUControl = 4'b0101; // XOR

                    3'b101: begin
                        if (funct7b5)
                            ALUControl = 4'b0111; // SRA
                        else
                            ALUControl = 4'b0110; // SRL
                    end

                    3'b110:
                        ALUControl = 4'b1000; // OR

                    3'b111:
                        ALUControl = 4'b1001; // AND

                    default:
                        ALUControl = 4'b0000;

                endcase
            end

            default:
                ALUControl = 4'b0000;

        endcase
    end

endmodule