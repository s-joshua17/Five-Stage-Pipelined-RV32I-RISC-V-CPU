// controller.v

module controller (
    input  [6:0] op,
    input  [2:0] funct3,
    input        funct7b5,

    output [1:0] ResultSrc,
    output       MemWrite,
    output       ALUSrc,
    output       RegWrite,
    output       Branch,
    output       Jump,
    output       Jalr,
    output [2:0] ImmSrc,
    output [3:0] ALUControl
);

    wire [1:0] ALUOp;

    main_decoder md (
        .op        (op),
        .funct3    (funct3),
        .ResultSrc (ResultSrc),
        .MemWrite  (MemWrite),
        .Branch    (Branch),
        .ALUSrc    (ALUSrc),
        .RegWrite  (RegWrite),
        .Jump      (Jump),
        .Jalr      (Jalr),
        .ImmSrc    (ImmSrc),
        .ALUOp     (ALUOp)
    );

    alu_decoder ad (
        .op5       (op[5]),
        .funct3    (funct3),
        .funct7b5  (funct7b5),
        .ALUOp     (ALUOp),
        .ALUControl(ALUControl)
    );

endmodule