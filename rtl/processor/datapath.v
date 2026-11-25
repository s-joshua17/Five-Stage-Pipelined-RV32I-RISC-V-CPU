// datapath.v
// 5-stage pipelined RISC-V datapath

module datapath (
    input         clk,
    input         reset,

    // Decode-stage control
    input  [1:0]   ResultSrcD,
    input         MemWriteD,
    input         ALUSrcD,
    input         RegWriteD,
    input  [2:0]   ImmSrcD,
    input  [3:0]   ALUControlD,
    input         BranchD,
    input         JumpD,
    input         JalrD,

    // Fetch
    output [31:0] PC,
    input  [31:0] InstrF,

    // Actual data-memory interface (MEM stage)
    output [31:0] Mem_WrAddr,
    output [31:0] Mem_WrData,
    output        MemWriteM,
    output [2:0]  funct3M,
    input  [31:0] ReadData,

    // WB
    output [31:0] Result,

    // Testbench/debug outputs
    output [31:0] PCW,
    output [31:0] ALUResultW,
    output [31:0] WriteDataW,
    output        MemWriteW,

    // IF/ID instruction
    output [31:0] InstrD
);

    // ========================================================
    // PC width: instruction memory is 256 words (1 KB), so only PC[9:0]
    // is stored/pipelined; upper bits are always 0.
    // ========================================================

    localparam PCB = 10;

    // ========================================================
    // IF
    // ========================================================

    wire [PCB-1:0] PC_n;          // narrow PC
    wire [PCB-1:0] PCPlus4F;
    wire [PCB-1:0] PCNext;
    wire           StallF;

    // ========================================================
    // IF/ID
    // ========================================================

    wire [PCB-1:0] PCD;
    wire        StallD;
    wire        FlushD;

    // ========================================================
    // ID
    // ========================================================

    wire [31:0] ImmExtD;

    wire [4:0] Rs1D;
    wire [4:0] Rs2D;
    wire [4:0] RdD;

    // ========================================================
    // ID/EX
    // ========================================================

    wire [31:0] RD1E;
    wire [31:0] RD2E;
    wire [31:0] ImmExtE;
    wire [PCB-1:0] PCE;
    wire [PCB-1:0] PCPlus4E;   // rebuilt from PCE (not pipelined)

    wire [4:0] Rs1E;
    wire [4:0] Rs2E;
    wire [4:0] RdE;

    wire [2:0] Funct3E;
    wire [3:0] ALUControlE;

    wire [1:0] ResultSrcE;

    wire RegWriteE;
    wire MemWriteE;
    wire JumpE;
    wire BranchE;
    wire JalrE;
    wire ALUSrcE;

    wire FlushE;

    // ========================================================
    // EX
    // ========================================================

    wire [1:0] ForwardAE;
    wire [1:0] ForwardBE;

    reg [31:0] ForwardedAE;
    reg [31:0] ForwardedBE;

    wire [31:0] SrcBE;

    wire [31:0] ALUResultCoreE;
    wire [31:0] ALUResultE;

    wire ZeroE;
    wire LtE;
    wire LtuE;
    wire TakeBranchE;

    wire PCSrcE;

    wire [PCB-1:0] PCTargetE;
    wire [PCB-1:0] JALRTargetE;

    wire [31:0] WriteDataE;

    // ========================================================
    // EX/MEM
    // ========================================================

    wire [31:0] ALUResultM;
    wire [31:0] WriteDataM;
    wire [PCB-1:0] PCM;

    wire [4:0] RdM;
    wire [2:0] Funct3M_int;

    wire LoadM;

    wire RegWriteM;
    wire MemWriteM_int;

    // ========================================================
    // MEM
    // ========================================================

    reg [31:0] LoadDataM;

    // ========================================================
    // MEM/WB
    // ========================================================

    // ALUResultW declared in output port
    wire [31:0] ReadDataW;
    wire [31:0] WriteDataW_int;

    wire [PCB-1:0] PCW_n;

    wire [4:0] RdW;
    wire LoadW;

    wire RegWriteW;
    wire MemWriteW_int;

    wire [31:0] ResultW;

    // ========================================================
    // FETCH
    // ========================================================

    assign PC       = {{(32-PCB){1'b0}}, PC_n};
    assign PCPlus4F = PC_n + 4;

    // Redirect on taken branch, JAL or JALR
    assign PCSrcE =
        (BranchE && TakeBranchE) |
        JumpE |
        JalrE;

    // JALR target: clear bit 0
    assign JALRTargetE = {ALUResultCoreE[PCB-1:1], 1'b0};

    // Next PC
    assign PCNext =
        JalrE  ? JALRTargetE :
        PCSrcE ? PCTargetE :
                 PCPlus4F;

    // ========================================================
    // PC REGISTER
    // ========================================================

    /*
     * Your Task 1C reset_ff interface is:
     *
     * reset_ff #(32) (clk, reset, D, Q)
     *
     * Therefore StallF is implemented with a mux here.
     */
    wire [PCB-1:0] PCInput;

    assign PCInput = StallF ? PC_n : PCNext;

    reset_ff #(PCB) pcreg (
        clk,
        reset,
        PCInput,
        PC_n
    );

    // ========================================================
    // IF/ID
    // ========================================================

    pl_reg_fd #(PCB) plfd (
        .clk      (clk),
        .en       (StallD),
        .clr      (FlushD),

        .InstrF   (InstrF),
        .PCF      (PC_n),

        .InstrD   (InstrD),
        .PCD      (PCD)
    );

    // ========================================================
    // DECODE
    // ========================================================

    // LUI is executed as (x0 + imm): point Rs1 at x0 so the ALU's A input is 0
    assign Rs1D = (InstrD[6:2] == 5'b01101) ? 5'd0 : InstrD[19:15];
    assign Rs2D = InstrD[24:20];
    assign RdD  = InstrD[11:7];

    reg_file rf (
        .clk (clk),

        .we3 (RegWriteW),

        .ra1 (Rs1D),
        .ra2 (Rs2D),

        .wa3 (RdW),
        .wd3 (ResultW),

        .rd1 (RD1E),   // registered read ports = ID/EX operand registers
        .rd2 (RD2E)
    );

    imm_extend ext (
        .instr  (InstrD[31:7]),
        .ImmSrc (ImmSrcD),
        .ImmExt (ImmExtD)
    );

    // ========================================================
    // ID/EX
    // ========================================================

    pl_reg_de #(PCB) plde (
        .clk         (clk),
        .en          (1'b0),
        .clr         (FlushE),

        .ImmExtD     (ImmExtD),
        .PCD         (PCD),

        .Rs1D        (Rs1D),
        .Rs2D        (Rs2D),
        .RdD         (RdD),

        .Funct3D     (InstrD[14:12]),
        .ALUControlD (ALUControlD),

        .ResultSrcD  (ResultSrcD),

        .RegWriteD   (RegWriteD),
        .MemWriteD   (MemWriteD),
        .JumpD       (JumpD),
        .BranchD     (BranchD),
        .JalrD       (JalrD),
        .ALUSrcD     (ALUSrcD),

        .ImmExtE     (ImmExtE),
        .PCE         (PCE),

        .Rs1E        (Rs1E),
        .Rs2E        (Rs2E),
        .RdE         (RdE),

        .Funct3E     (Funct3E),
        .ALUControlE (ALUControlE),

        .ResultSrcE  (ResultSrcE),

        .RegWriteE   (RegWriteE),
        .MemWriteE   (MemWriteE),
        .JumpE       (JumpE),
        .BranchE     (BranchE),
        .JalrE       (JalrE),
        .ALUSrcE     (ALUSrcE)
    );

    // ========================================================
    // EXECUTE - FORWARDING
    // ========================================================

    always @(*) begin
        case (ForwardAE)

            2'b10:
                ForwardedAE = ALUResultM;

            2'b01:
                ForwardedAE = ResultW;

            default:
                ForwardedAE = RD1E;

        endcase
    end

    always @(*) begin
        case (ForwardBE)

            2'b10:
                ForwardedBE = ALUResultM;

            2'b01:
                ForwardedBE = ResultW;

            default:
                ForwardedBE = RD2E;

        endcase
    end

    // ALU B input
    assign SrcBE =
        ALUSrcE ? ImmExtE : ForwardedBE;

    // ALU
    alu alu_i (
        .A          (ForwardedAE),
        .B          (SrcBE),
        .ALUControl (ALUControlE),
        .Result     (ALUResultCoreE),
        .Zero       (ZeroE),
        .Lt         (LtE),
        .Ltu        (LtuE)
    );

    // PC+4 for JAL/JALR link
    assign PCPlus4E = PCE + 4;

    // Value sent down the pipe:
    //   10 -> PC+4 (JAL/JALR link)
    //   11 -> PC+imm (AUIPC): U-immediate has zeros in [11:0] and PC < 4 KB,
    //         so PC + imm == imm | PC (no adder needed)
    //   else ALU result
    assign ALUResultE =
        (ResultSrcE == 2'b10) ? {{(32-PCB){1'b0}}, PCPlus4E} :
        (ResultSrcE == 2'b11) ? (ImmExtE | {{(32-PCB){1'b0}}, PCE}) :
                                ALUResultCoreE;

    // Branch target
    assign PCTargetE = PCE + ImmExtE[PCB-1:0];

    // Branch decision
    branching_unit bu (
        .funct3 (Funct3E),
        .Zero   (ZeroE),
        .Lt     (LtE),
        .Ltu    (LtuE),
        .Branch (TakeBranchE)
    );

    // Store data must also be forwarded
    assign WriteDataE = ForwardedBE;

    // ========================================================
    // EX/MEM
    // ========================================================

    pl_reg_em #(PCB) plem (
        .clk        (clk),

        .ALUResultE (ALUResultE),
        .WriteDataE (WriteDataE),
        .PCE        (PCE),

        .RdE        (RdE),
        .Funct3E    (Funct3E),

        .LoadE      (ResultSrcE == 2'b01),

        .RegWriteE  (RegWriteE),
        .MemWriteE  (MemWriteE),

        .ALUResultM (ALUResultM),
        .WriteDataM (WriteDataM),
        .PCM        (PCM),

        .RdM        (RdM),
        .Funct3M    (Funct3M_int),

        .LoadM      (LoadM),

        .RegWriteM  (RegWriteM),
        .MemWriteM  (MemWriteM_int)
    );

    // ========================================================
    // MEMORY INTERFACE
    // ========================================================

    assign Mem_WrAddr = ALUResultM;
    assign Mem_WrData = WriteDataM;

    assign funct3M = Funct3M_int;
    assign MemWriteM = MemWriteM_int;

    // ========================================================
    // LOAD DATA FORMATTING
    // ========================================================

    wire [7:0] byte_data = (ALUResultM[1:0] == 2'b00) ? ReadData[7:0] :
                           (ALUResultM[1:0] == 2'b01) ? ReadData[15:8] :
                           (ALUResultM[1:0] == 2'b10) ? ReadData[23:16] :
                                                        ReadData[31:24];

    wire [15:0] half_data = ALUResultM[1] ? ReadData[31:16] : ReadData[15:0];

    wire byte_sign = ~Funct3M_int[2] & byte_data[7];
    wire half_sign = ~Funct3M_int[2] & half_data[15];

    always @(*) begin
        case (Funct3M_int[1:0])
            2'b00:   LoadDataM = {{24{byte_sign}}, byte_data}; // LB / LBU
            2'b01:   LoadDataM = {{16{half_sign}}, half_data}; // LH / LHU
            default: LoadDataM = ReadData;                      // LW
        endcase
    end

    // ========================================================
    // MEM/WB
    // ========================================================

    pl_reg_mw #(PCB) plmw (
        .clk         (clk),

        .ALUResultM  (ALUResultM),
        .ReadDataM   (LoadDataM),
        .WriteDataM  (WriteDataM),
        .PCM         (PCM),

        .RdM         (RdM),

        .LoadM       (LoadM),

        .RegWriteM   (RegWriteM),
        .MemWriteM   (MemWriteM_int),

        .ALUResultW  (ALUResultW),
        .ReadDataW   (ReadDataW),
        .WriteDataW  (WriteDataW_int),
        .PCW         (PCW_n),

        .RdW         (RdW),

        .LoadW       (LoadW),

        .RegWriteW   (RegWriteW),
        .MemWriteW   (MemWriteW_int)
    );

    // ========================================================
    // WRITEBACK
    // ========================================================

    assign ResultW = LoadW ? ReadDataW : ALUResultW;

    assign Result = ResultW;

    // PCW (PC of the instruction in WB) comes straight out of the MEM/WB register
    assign PCW = {{(32-PCB){1'b0}}, PCW_n};

    // Address of instruction currently in WB
    wire [31:0] DataAdrW;
    assign DataAdrW = ALUResultW;

    // Store data of instruction currently in WB
    assign WriteDataW = WriteDataW_int;

    // Store control aligned with PCW
    assign MemWriteW = MemWriteW_int;

    // ========================================================
    // HAZARD UNIT
    // ========================================================

    hazard_unit hu (
        .Rs1D       (Rs1D),
        .Rs2D       (Rs2D),

        .Rs1E       (Rs1E),
        .Rs2E       (Rs2E),
        .RdE        (RdE),

        .RdM        (RdM),
        .RdW        (RdW),

        .RegWriteM  (RegWriteM),
        .RegWriteW  (RegWriteW),

        .ResultSrcE (ResultSrcE),

        .PCSrcE     (PCSrcE),

        .ForwardAE  (ForwardAE),
        .ForwardBE  (ForwardBE),

        .StallF     (StallF),
        .StallD     (StallD),

        .FlushD     (FlushD),
        .FlushE     (FlushE)
    );

endmodule